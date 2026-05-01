package tunnel

import (
	"fmt"
	"net"
	"strings"
	"time"

	"golang.org/x/net/dns/dnsmessage"
)

// EDNSProbeResult contains results from EDNS0 probing and NXDOMAIN hijack detection.
type EDNSProbeResult struct {
	Resolver         string
	SupportEDNS      bool
	NXDOMAINHijacked bool
	Latency          time.Duration
	Error            string
}

// ProbeEDNS tests a resolver for EDNS0 support and NXDOMAIN hijacking.
func ProbeEDNS(resolver, testDomain string, timeout time.Duration) *EDNSProbeResult {
	result := &EDNSProbeResult{Resolver: resolver}
	start := time.Now()

	result.SupportEDNS = testEDNSSupport(resolver, testDomain, timeout)
	result.NXDOMAINHijacked = checkNXDOMAINHijacking(
		resolver,
		"nxcheck-dnsly-probe."+testDomain,
		timeout,
	)

	result.Latency = time.Since(start)
	return result
}

// fqdn ensures a domain name ends with a dot (required by dnsmessage).
func fqdn(domain string) string {
	if !strings.HasSuffix(domain, ".") {
		return domain + "."
	}
	return domain
}

// testEDNSSupport sends a query with an EDNS0 OPT record and checks whether
// the response also contains an OPT record (indicating EDNS0 support).
func testEDNSSupport(resolver, domain string, timeout time.Duration) bool {
	conn, err := net.DialTimeout("udp", net.JoinHostPort(resolver, "53"), timeout)
	if err != nil {
		return false
	}
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(timeout)) //nolint:errcheck

	name, err := dnsmessage.NewName(fqdn(domain))
	if err != nil {
		return false
	}

	msg := dnsmessage.Message{
		Header: dnsmessage.Header{ID: 0x1234, RecursionDesired: true},
		Questions: []dnsmessage.Question{
			{Name: name, Type: dnsmessage.TypeA, Class: dnsmessage.ClassINET},
		},
		Additionals: []dnsmessage.Resource{
			{
				Header: dnsmessage.ResourceHeader{
					Name:  dnsmessage.MustNewName("."), // root label for OPT
					Type:  dnsmessage.TypeOPT,
					Class: 4096, // UDP payload size advertised
				},
				Body: &dnsmessage.OPTResource{},
			},
		},
	}

	buf, err := msg.Pack()
	if err != nil {
		return false
	}
	if _, err := conn.Write(buf); err != nil {
		return false
	}

	resp := make([]byte, 1024)
	n, err := conn.Read(resp)
	if err != nil || n < 12 {
		return false
	}

	var respMsg dnsmessage.Message
	if err := respMsg.Unpack(resp[:n]); err != nil {
		return false
	}
	for _, rr := range respMsg.Additionals {
		if rr.Header.Type == dnsmessage.TypeOPT {
			return true
		}
	}
	return false
}

// checkNXDOMAINHijacking queries a definitely non-existent subdomain.
// A clean resolver returns NXDOMAIN (RCode 3, no answers).
// A hijacking resolver returns NOERROR with answer records.
func checkNXDOMAINHijacking(resolver, nxdomain string, timeout time.Duration) bool {
	conn, err := net.DialTimeout("udp", net.JoinHostPort(resolver, "53"), timeout)
	if err != nil {
		return false
	}
	defer conn.Close()
	conn.SetDeadline(time.Now().Add(timeout)) //nolint:errcheck

	name, err := dnsmessage.NewName(fqdn(nxdomain))
	if err != nil {
		return false
	}

	msg := dnsmessage.Message{
		Header: dnsmessage.Header{ID: 0xABCD, RecursionDesired: true},
		Questions: []dnsmessage.Question{
			{Name: name, Type: dnsmessage.TypeA, Class: dnsmessage.ClassINET},
		},
	}

	buf, err := msg.Pack()
	if err != nil {
		return false
	}
	if _, err := conn.Write(buf); err != nil {
		return false
	}

	resp := make([]byte, 512)
	n, err := conn.Read(resp)
	if err != nil || n < 12 {
		return false
	}

	var respMsg dnsmessage.Message
	if err := respMsg.Unpack(resp[:n]); err != nil {
		return false
	}

	// RCode 3 (NXDOMAIN) with no answers = clean resolver.
	if respMsg.Header.RCode == dnsmessage.RCodeNameError {
		return false
	}
	// NOERROR with answers = hijacked.
	if respMsg.Header.RCode == dnsmessage.RCodeSuccess && len(respMsg.Answers) > 0 {
		return true
	}
	return false
}

// EDNSScore returns a score 0–6 for a resolver based on EDNS probe results.
// Used to rank resolvers for DNS tunnel suitability.
func EDNSScore(resolver, domain string, timeout time.Duration) (int, error) {
	result := ProbeEDNS(resolver, domain, timeout)
	if result.Error != "" {
		return 0, fmt.Errorf("%s", result.Error)
	}

	score := 0
	// Reachable at all: +2
	score += 2
	// EDNS0 supported: +2
	if result.SupportEDNS {
		score += 2
	}
	// Not hijacking NXDOMAIN: +2 (hijacked = useless for VayDNS)
	if !result.NXDOMAINHijacked {
		score += 2
	}
	return score, nil
}
