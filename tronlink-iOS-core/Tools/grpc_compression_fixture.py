#!/usr/bin/env python3
"""Loopback-only HTTP/2 fixture for GRPCCompressionUpgradeTests.

Port 19091 returns a compressed empty Account; 19092 returns a compressed
4 MiB payload. Both compressed messages are smaller than the test's 64 KiB
receive limit. No external nodes, TLS credentials or wallet data are used.
"""

import gzip
import socketserver
import struct
import threading


def frame(kind, flags, stream, payload=b""):
    return len(payload).to_bytes(3, "big") + bytes([kind, flags]) + struct.pack(">I", stream) + payload


def literal_header(name, value):
    # HPACK literal header without indexing, no Huffman coding; short strings.
    return b"\x00" + bytes([len(name)]) + name + bytes([len(value)]) + value


HEADERS = b"\x88" + literal_header(b"content-type", b"application/grpc") + literal_header(b"grpc-encoding", b"gzip")
TRAILERS = literal_header(b"grpc-status", b"0")


class Handler(socketserver.BaseRequestHandler):
    def read_exact(self, count):
        data = bytearray()
        while len(data) < count:
            block = self.request.recv(count - len(data))
            if not block:
                raise EOFError
            data.extend(block)
        return bytes(data)

    def handle(self):
        self.request.settimeout(30)
        try:
            if self.read_exact(24) != b"PRI * HTTP/2.0\r\n\r\nSM\r\n\r\n":
                return
            self.request.sendall(frame(4, 0, 0))
            while True:
                header = self.read_exact(9)
                length = int.from_bytes(header[:3], "big")
                kind, flags = header[3:5]
                stream = int.from_bytes(header[5:], "big") & 0x7fffffff
                if length > 65536:
                    return
                payload = self.read_exact(length)
                if kind == 4 and not flags & 1:
                    self.request.sendall(frame(4, 1, 0))
                elif kind == 6 and not flags & 1:
                    self.request.sendall(frame(6, 1, 0, payload))
                elif stream and kind in (0, 1) and flags & 1:
                    compressed = self.server.compressed_response
                    message = b"\x01" + struct.pack(">I", len(compressed)) + compressed
                    self.request.sendall(frame(1, 4, stream, HEADERS)
                                         + frame(0, 0, stream, message)
                                         + frame(1, 5, stream, TRAILERS))
                    print(f"port={self.server.server_address[1]} stream={stream} compressed={len(compressed)}", flush=True)
        except (EOFError, OSError):
            pass


class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address = True
    daemon_threads = True


if __name__ == "__main__":
    servers = []
    try:
        for port, payload in [(19091, b""), (19092, b"\x00" * (4 * 1024 * 1024))]:
            server = Server(("127.0.0.1", port), Handler)
            server.compressed_response = gzip.compress(payload, mtime=0)
            servers.append(server)
            threading.Thread(target=server.serve_forever, daemon=True).start()
        print("Ready: 127.0.0.1:19091 (valid), 127.0.0.1:19092 (oversized)", flush=True)
        threading.Event().wait()
    except KeyboardInterrupt:
        pass
    finally:
        for server in servers:
            server.shutdown()
            server.server_close()
