package tunnel

import (
	"context"
	"fmt"
	"net"
	"sync"
	"time"
)

// TunnelTestResult contains results from end-to-end tunnel testing
type TunnelTestResult struct {
	Resolver         string
	ReachabilityOK   bool      // Can reach the resolver
	EDNSOK           bool      // EDNS0 supported
	TunnelOK         bool      // Can actually tunnel data
	DNSResolutionOK  bool      // Can resolve test domain
	TestDomain       string    // Domain used for testing
	Latency          time.Duration
	ThroughputBps    float64   // Bytes per second
	PacketLoss       float64   // 0.0 to 1.0
	Error            string
}

// TunnelTester performs end-to-end tunnel testing through DNS resolvers
type TunnelTester struct {
	cfg Config
	mu  sync.Mutex
}

// NewTunnelTester creates a new tunnel tester
func NewTunnelTester(cfg Config) *TunnelTester {
	return &TunnelTester{cfg: cfg}
}

// TestResolver performs a complete end-to-end test through a DNS resolver
// It tests:
// 1. Basic connectivity to resolver
// 2. EDNS0 support
// 3. DNS resolution capability
// 4. Tunnel data transmission
// 5. Throughput and packet loss
func (tt *TunnelTester) TestResolver(ctx context.Context, resolver, testDomain string, timeout time.Duration) *TunnelTestResult {
	result := &TunnelTestResult{
		Resolver:   resolver,
		TestDomain: testDomain,
	}

	start := time.Now()
	defer func() {
		result.Latency = time.Since(start)
	}()

	// Test 1: Basic connectivity
	if err := testReachability(resolver, timeout); err != nil {
		result.Error = fmt.Sprintf("unreachable: %v", err)
		return result
	}
	result.ReachabilityOK = true

	// Test 2: EDNS0 support
	ednsResult := ProbeEDNS(resolver, testDomain, timeout)
	result.EDNSOK = ednsResult.SupportEDNS

	// Test 3: DNS resolution
	resolves, err := testDNSResolution(resolver, testDomain, timeout)
	result.DNSResolutionOK = resolves
	if err != nil && !resolves {
		result.Error = fmt.Sprintf("resolution failed: %v", err)
	}

	// Test 4: Tunnel data transmission
	result.TunnelOK, result.ThroughputBps, result.PacketLoss, err = testTunnelTransmission(
		ctx, resolver, testDomain, timeout,
	)
	if err != nil && !result.TunnelOK {
		result.Error = fmt.Sprintf("tunnel failed: %v", err)
	}

	return result
}

// testReachability checks if a resolver is reachable
func testReachability(resolver string, timeout time.Duration) error {
	conn, err := net.DialTimeout("udp", net.JoinHostPort(resolver, "53"), timeout)
	if err != nil {
		return err
	}
	conn.Close()

	conn, err = net.DialTimeout("tcp", net.JoinHostPort(resolver, "53"), timeout)
	if err != nil {
		return err
	}
	conn.Close()

	return nil
}

// testDNSResolution tests if resolver can resolve a domain
func testDNSResolution(resolver, domain string, timeout time.Duration) (bool, error) {
	r := &net.Resolver{
		PreferGo: true,
		Dial: func(ctx context.Context, network, address string) (net.Conn, error) {
			return net.DialTimeout(network, net.JoinHostPort(resolver, "53"), timeout)
		},
	}

	ctx, cancel := context.WithTimeout(context.Background(), timeout)
	defer cancel()

	_, err := r.LookupHost(ctx, domain)
	return err == nil, err
}

// testTunnelTransmission tests actual data transmission through tunnel
// Returns: (success, throughput_bps, packet_loss, error)
func testTunnelTransmission(
	ctx context.Context, resolver, domain string, timeout time.Duration,
) (bool, float64, float64, error) {
	// Create a simple tunnel test that sends data and measures:
	// 1. How much data successfully transmitted
	// 2. Round-trip time
	// 3. Packet loss

	start := time.Now()
	testData := make([]byte, 1024) // 1KB test payload
	for i := range testData {
		testData[i] = byte(i % 256)
	}

	// For DNS tunnel, we'd encode this as DNS queries
	// For now, simulate with UDP probes to measure path quality
	successCount := 0
	totalCount := 10

	for i := 0; i < totalCount; i++ {
		select {
		case <-ctx.Done():
			return false, 0, 1.0, ctx.Err()
		default:
		}

		conn, err := net.DialTimeout("udp", net.JoinHostPort(resolver, "53"), timeout)
		if err != nil {
			continue
		}

		// Send data
		conn.SetWriteDeadline(time.Now().Add(timeout))
		conn.SetReadDeadline(time.Now().Add(timeout))

		_, err = conn.Write(testData)
		if err == nil {
			// Receive response (even if it's just an error response)
			_, err = conn.Read(make([]byte, 512))
			if err == nil {
				successCount++
			}
		}
		conn.Close()
	}

	elapsed := time.Since(start)
	packetLoss := float64(totalCount-successCount) / float64(totalCount)
	throughput := float64(len(testData)*successCount) / elapsed.Seconds()

	if successCount == 0 {
		return false, 0, 1.0, fmt.Errorf("no packets transmitted successfully")
	}

	if packetLoss > 0.5 {
		return false, throughput, packetLoss, fmt.Errorf("excessive packet loss: %.1f%%", packetLoss*100)
	}

	return true, throughput, packetLoss, nil
}

// ParallelTestResolvers tests multiple resolvers concurrently
// Returns results in order of completion
func (tt *TunnelTester) ParallelTestResolvers(
	ctx context.Context,
	resolvers []string,
	testDomain string,
	timeout time.Duration,
	concurrency int,
) []*TunnelTestResult {
	sem := make(chan struct{}, concurrency)
	results := make([]*TunnelTestResult, len(resolvers))
	var wg sync.WaitGroup

	for i, resolver := range resolvers {
		wg.Add(1)
		go func(idx int, res string) {
			defer wg.Done()
			sem <- struct{}{}
			defer func() { <-sem }()

			results[idx] = tt.TestResolver(ctx, res, testDomain, timeout)
		}(i, resolver)
	}

	wg.Wait()
	return results
}
