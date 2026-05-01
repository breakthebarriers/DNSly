package tunnel

import (
	"context"
	"fmt"
	"net"
	"strings"
	"sync"
	"time"
)

// CountryRanges represents IP ranges for a country (CIDR format)
type CountryRanges struct {
	Country string
	Ranges  []string // CIDR notation
}

// GeoIPScanner scans DNS resolvers in specific countries based on IP ranges
type GeoIPScanner struct {
	mu           sync.RWMutex
	countryRanges map[string]*CountryRanges
}

// NewGeoIPScanner creates a new geo-based IP scanner
func NewGeoIPScanner() *GeoIPScanner {
	return &GeoIPScanner{
		countryRanges: make(map[string]*CountryRanges),
	}
}

// AddCountryRanges adds IP ranges for a country
// ranges: list of CIDR blocks (e.g., "8.8.0.0/16", "1.1.1.0/24")
func (gs *GeoIPScanner) AddCountryRanges(country string, ranges []string) error {
	gs.mu.Lock()
	defer gs.mu.Unlock()

	// Validate all ranges before storing
	for _, cidr := range ranges {
		_, _, err := net.ParseCIDR(cidr)
		if err != nil {
			return fmt.Errorf("invalid CIDR %s for country %s: %w", cidr, country, err)
		}
	}

	gs.countryRanges[country] = &CountryRanges{
		Country: country,
		Ranges:  ranges,
	}
	return nil
}

// GetCountriesForIP returns the country code for an IP address
// Returns empty string if not found in ranges
func (gs *GeoIPScanner) GetCountriesForIP(ipStr string) []string {
	gs.mu.RLock()
	defer gs.mu.RUnlock()

	ip := net.ParseIP(ipStr)
	if ip == nil {
		return nil
	}

	var countries []string
	for country, cr := range gs.countryRanges {
		for _, cidr := range cr.Ranges {
			_, network, _ := net.ParseCIDR(cidr)
			if network != nil && network.Contains(ip) {
				countries = append(countries, country)
				break
			}
		}
	}
	return countries
}

// FilterResolversByCountry filters resolvers to only those in specified countries
func (gs *GeoIPScanner) FilterResolversByCountry(resolvers []string, countries []string) []string {
	if len(countries) == 0 {
		return resolvers
	}

	gs.mu.RLock()
	defer gs.mu.RUnlock()

	// Build set of target countries for quick lookup
	countrySet := make(map[string]bool)
	for _, c := range countries {
		countrySet[strings.ToUpper(c)] = true
	}

	var filtered []string
	for _, resolver := range resolvers {
		// Extract country from IP
		resolverCountries := gs.GetCountriesForIP(resolver)
		for _, rc := range resolverCountries {
			if countrySet[strings.ToUpper(rc)] {
				filtered = append(filtered, resolver)
				break
			}
		}
	}
	return filtered
}

// PopulateGlobalRanges adds major public DNS resolvers' country ranges
// This is a sample implementation - in production, you'd fetch from RIPE NCC or APNIC
func (gs *GeoIPScanner) PopulateGlobalRanges() error {
	// Sample global DNS provider ranges
	// In production, fetch these from authoritative sources like:
	// - RIPE NCC (https://ftp.ripe.net/ripe/asnames/)
	// - APNIC (https://ftp.apnic.net/apnic/stats/)
	// - AfriNIC, LACNIC, etc.

	globalRanges := map[string][]string{
		"US": {
			"8.8.0.0/16",           // Google DNS
			"1.1.1.0/24",           // Cloudflare
			"208.67.222.0/24",      // OpenDNS
			"76.76.19.0/24",        // Comodo
		},
		"DE": {
			"146.112.61.0/24",      // OpenDNS (DE)
			"199.85.126.0/24",      // Norton DNS (EU)
		},
		"JP": {
			"210.173.160.0/24",     // ISP DNS examples
		},
		"NL": {
			"213.154.169.0/24",     // Quad9 (NL)
		},
		"GB": {
			"217.146.104.0/24",     // DNS provider UK
		},
		"AU": {
			"202.12.27.0/24",       // APNIC example
		},
		"IN": {
			"203.119.81.0/24",      // Indian ISP
		},
	}

	for country, ranges := range globalRanges {
		if err := gs.AddCountryRanges(country, ranges); err != nil {
			return err
		}
	}

	return nil
}

// ScanResolversInCountry performs a scanning test in specific country
// It filters resolvers to those in the country then tests them
func (gs *GeoIPScanner) ScanResolversInCountry(
	country string,
	resolvers []string,
	testDomain string,
	timeout time.Duration,
	concurrency int,
) []*TunnelTestResult {
	// Filter to resolvers in this country
	countryResolvers := gs.FilterResolversByCountry(resolvers, []string{country})

	if len(countryResolvers) == 0 {
		return nil
	}

	// Test the country-specific resolvers
	tester := NewTunnelTester(Config{})
	results := tester.ParallelTestResolvers(
		context.Background(),
		countryResolvers,
		testDomain,
		timeout,
		concurrency,
	)

	return results
}

// ImportRangesFromText parses IP ranges in text format
// Format: country,cidr[,cidr,...]
func (gs *GeoIPScanner) ImportRangesFromText(lines []string) error {
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := strings.Split(line, ",")
		if len(parts) < 2 {
			continue
		}

		country := strings.TrimSpace(parts[0])
		ranges := make([]string, 0, len(parts)-1)
		for i := 1; i < len(parts); i++ {
			ranges = append(ranges, strings.TrimSpace(parts[i]))
		}

		if err := gs.AddCountryRanges(country, ranges); err != nil {
			return err
		}
	}
	return nil
}
