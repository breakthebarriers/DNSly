package tunnel

import (
	"context"
	"fmt"
	"net"

	"golang.org/x/crypto/ssh"
)

// handleSOCKS5Connection handles one incoming SOCKS5 connection by forwarding
// it through the given SSH client using ssh.Client.Dial (direct-tcpip channel).
// Reuses socks5Handshake / socks5Reply / relay from ssh_proxy.go.
func handleSOCKS5Connection(_ context.Context, conn net.Conn, client *ssh.Client) {
	defer conn.Close()

	host, port, err := socks5Handshake(conn)
	if err != nil {
		return
	}

	remote, err := client.Dial("tcp", fmt.Sprintf("%s:%d", host, port))
	if err != nil {
		socks5Reply(conn, 0x05) // connection refused
		return
	}
	defer remote.Close()

	socks5Reply(conn, 0x00) // success
	relay(conn, remote)
}
