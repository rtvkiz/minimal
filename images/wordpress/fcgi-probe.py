import socket, struct, sys
host, port, script = sys.argv[1], int(sys.argv[2]), sys.argv[3]
def rec(t, rid, data=b""):
    pad = (8 - len(data) % 8) % 8
    return struct.pack("!BBHHBB", 1, t, rid, len(data), pad, 0) + data + b"\0" * pad
def enc(n, v):
    n, v = n.encode(), v.encode()
    def ln(x): return struct.pack("!B", len(x)) if len(x) < 128 else struct.pack("!I", len(x) | 0x80000000)
    return ln(n) + ln(v) + n + v
params = {
    "SCRIPT_FILENAME": script, "SCRIPT_NAME": "/index.php", "REQUEST_METHOD": "GET",
    "REQUEST_URI": "/", "QUERY_STRING": "", "DOCUMENT_ROOT": "/usr/share/wordpress",
    "SERVER_PROTOCOL": "HTTP/1.1", "GATEWAY_INTERFACE": "CGI/1.1",
    "SERVER_SOFTWARE": "smoketest", "REMOTE_ADDR": "127.0.0.1", "SERVER_NAME": "localhost",
}
s = socket.create_connection((host, port), timeout=25)
s.sendall(rec(1, 1, struct.pack("!HB5x", 1, 0)))
s.sendall(rec(4, 1, b"".join(enc(k, v) for k, v in params.items())))
s.sendall(rec(4, 1))
s.sendall(rec(5, 1))
out = b""
while True:
    hdr = s.recv(8)
    if len(hdr) < 8: break
    _, t, _, clen, plen, _ = struct.unpack("!BBHHBB", hdr)
    body = b""
    while len(body) < clen + plen:
        chunk = s.recv(clen + plen - len(body))
        if not chunk: break
        body += chunk
    if t == 6: out += body[:clen]
    elif t == 7: sys.stderr.write(body[:clen].decode("utf8", "replace"))
    elif t == 3: break
sys.stdout.write(out.decode("utf8", "replace"))
