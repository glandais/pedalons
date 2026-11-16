"""The e2e stack on the local network, for a device that cannot reach this machine's loopback — a
physical iPhone (no `adb reverse` on iOS). `scripts/recette.sh mobile --ios` starts it.

    /usr/bin/python3 scripts/recette-lan-relay.py <listen port> <target port>

Listens on every interface and forwards each request to 127.0.0.1:<target port> (the stack, or the
tunnel to it), rewriting `Host` to `localhost:<target port>`: the backend resolves its site from the
host (DomainResolver) and the e2e stack's only domain is `localhost`. So no alias in the database,
and one relay serves a local stack as well as a tunnelled one.

Python, Apple's own (/usr/bin/python3), on purpose: the macOS application firewall lets signed
built-in software accept connections, while it silently drops those to Homebrew's node — the
handshake succeeds, the request never arrives. Standard library only, Python 3.9.

Whole bodies, no streaming nor WebSocket: the app's API needs neither. Anyone on the network
reaches the stack while it runs — throwaway accounts, mail to mailpit only, and it stops with the
recette.
"""
import http.client
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HOP_BY_HOP = {
    "connection", "keep-alive", "proxy-connection", "transfer-encoding", "te", "trailer", "upgrade",
}


def main():
    if len(sys.argv) != 3:
        sys.exit("usage: recette-lan-relay.py <listen port> <target port>")
    listen_port, target_port = int(sys.argv[1]), int(sys.argv[2])
    target_host = f"localhost:{target_port}"

    class Relay(BaseHTTPRequestHandler):
        protocol_version = "HTTP/1.1"

        def relay(self):
            length = int(self.headers.get("Content-Length") or 0)
            body = self.rfile.read(length) if length else None
            headers = {k: v for k, v in self.headers.items() if k.lower() not in HOP_BY_HOP}
            headers["Host"] = target_host
            upstream = http.client.HTTPConnection("127.0.0.1", target_port, timeout=120)
            try:
                upstream.request(self.command, self.path, body=body, headers=headers)
                answer = upstream.getresponse()
                data = answer.read()
            except OSError as error:
                self.send_error(502, f"recette-lan-relay: {error}")
                return
            finally:
                upstream.close()
            self.send_response_only(answer.status, answer.reason)
            for name, value in answer.getheaders():
                if name.lower() not in HOP_BY_HOP and name.lower() != "content-length":
                    self.send_header(name, value)
            self.send_header("Content-Length", str(len(data)))
            self.end_headers()
            if self.command != "HEAD":
                self.wfile.write(data)

        do_GET = do_POST = do_PUT = do_PATCH = do_DELETE = do_HEAD = do_OPTIONS = relay

        def log_message(self, fmt, *args):
            sys.stderr.write(f"recette-lan-relay: {self.address_string()} {fmt % args}\n")

    server = ThreadingHTTPServer(("0.0.0.0", listen_port), Relay)
    print(f"recette-lan-relay: :{listen_port} -> {target_host}", flush=True)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
