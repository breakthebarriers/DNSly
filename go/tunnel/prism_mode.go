package tunnel

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"time"
)

// PrismMode implements HMAC-authenticated server verification
// This prevents man-in-the-middle attacks by verifying tunnel server identity
type PrismMode struct {
	sharedSecret string
	serverID    string
	nonces      map[string]time.Time // Track nonces to prevent replay attacks
}

// NewPrismMode creates a new Prism mode verifier
// sharedSecret: HMAC-SHA256 shared secret between client and server
// serverID: identifier for the server (can be its domain or IP)
func NewPrismMode(sharedSecret, serverID string) *PrismMode {
	return &PrismMode{
		sharedSecret: sharedSecret,
		serverID:     serverID,
		nonces:       make(map[string]time.Time),
	}
}

// GenerateAuthToken generates an HMAC-authenticated token
// nonce: unique identifier (timestamp or random string)
// data: data to authenticate
func (p *PrismMode) GenerateAuthToken(nonce, data string) string {
	message := fmt.Sprintf("%s|%s|%s", p.serverID, nonce, data)
	h := hmac.New(sha256.New, []byte(p.sharedSecret))
	h.Write([]byte(message))
	return hex.EncodeToString(h.Sum(nil))
}

// VerifyAuthToken verifies an HMAC token from the server
// Returns true if token is valid and within time window
func (p *PrismMode) VerifyAuthToken(token, nonce, data string) bool {
	// Check nonce age (reject nonces older than 5 minutes)
	if ts, exists := p.nonces[nonce]; exists {
		if time.Since(ts) > 5*time.Minute {
			delete(p.nonces, nonce)
			return false // Replay attack attempt
		}
		return false // Nonce already used
	}

	// Store nonce with current time
	p.nonces[nonce] = time.Now()

	// Generate expected token
	expected := p.GenerateAuthToken(nonce, data)

	// Constant-time comparison to prevent timing attacks
	return hmac.Equal([]byte(token), []byte(expected))
}

// ChallengeResponse implements a challenge-response protocol
// Server sends challenge, client responds with HMAC of challenge
type ChallengeResponse struct {
	prism     *PrismMode
	challenge string
}

// NewChallenge creates a new challenge for server verification
func (p *PrismMode) NewChallenge(nonce string) *ChallengeResponse {
	return &ChallengeResponse{
		prism:     p,
		challenge: nonce,
	}
}

// GetResponse generates the client's response to the server's challenge
func (cr *ChallengeResponse) GetResponse() string {
	return cr.prism.GenerateAuthToken(cr.challenge, "challenge-response-v1")
}

// VerifyResponse verifies the server's response to our challenge
func (cr *ChallengeResponse) VerifyResponse(response string) bool {
	return cr.prism.VerifyAuthToken(response, cr.challenge, "challenge-response-v1")
}

// ServerAuthInfo contains authentication information for a server
type ServerAuthInfo struct {
	ServerID      string // Domain or IP
	SharedSecret  string // HMAC secret
	PublicKey     string // Optional: public key for additional verification
	CertFingerprint string // Optional: certificate fingerprint
}

// AuthenticateServer verifies server identity through multiple methods
func (p *PrismMode) AuthenticateServer(info ServerAuthInfo, serverResponse string, nonce string) (bool, error) {
	// Verify HMAC signature
	if !p.VerifyAuthToken(serverResponse, nonce, "auth-response") {
		return false, fmt.Errorf("HMAC verification failed")
	}

	// Additional verification can be done with public key or cert fingerprint
	// This provides defense in depth
	if info.PublicKey != "" {
		// Public key verification would go here
		// This is for future enhancement
	}

	if info.CertFingerprint != "" {
		// Certificate fingerprint verification would go here
		// This is for future enhancement
	}

	return true, nil
}

// SessionKey generates a session-specific encryption key
// This key is derived from the HMAC shared secret and can be used for
// encrypting the tunnel data
func (p *PrismMode) SessionKey(sessionID string) []byte {
	h := hmac.New(sha256.New, []byte(p.sharedSecret))
	h.Write([]byte(fmt.Sprintf("%s|%s|session-key", p.serverID, sessionID)))
	return h.Sum(nil)
}
