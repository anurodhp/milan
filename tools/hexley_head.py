#!/usr/bin/env python3 -I
"""Cuts Hexley's head and hat out of icons/app/hexley_fork_450.png (opaque white background) into
icons/app/hexley_head.png with a real alpha channel. stdlib only.
  flood fill from the border turns the white background transparent (the eyes are enclosed by the
  outline, so they stay white); the anti-aliased fringe is un-blended so no white halo remains."""
import struct, sys, zlib

SRC, DST = "icons/app/hexley_fork_450.png", "icons/app/hexley_head.png"
BOX = (158, 24, 412, 240)       # x0, y0, x1, y1: the head and hat
ERASES = [(0, 0, 186, 147), (186, 0, 198, 100)]   # the trident's right prong pokes into the crop here
FADE = 18                       # rows over which the neck fades out at the bottom


def read_png(path):
    d = open(path, "rb").read()
    pos, idat = 8, b""
    while pos < len(d):
        n, = struct.unpack(">I", d[pos:pos + 4])
        t, body = d[pos + 4:pos + 8], d[pos + 8:pos + 8 + n]
        if t == b"IHDR":
            w, h, bd, ct = struct.unpack(">IIBB", body[:10])
            assert bd == 8 and ct == 6, "expects 8-bit RGBA"
        elif t == b"IDAT":
            idat += body
        pos += 12 + n
    raw, stride, bpp = zlib.decompress(idat), w * 4, 4
    rows, prev, i = [], bytearray(stride), 0
    for _ in range(h):
        f, line = raw[i], bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1: line[x] = (line[x] + a) & 255
            elif f == 2: line[x] = (line[x] + b) & 255
            elif f == 3: line[x] = (line[x] + ((a + b) >> 1)) & 255
            elif f == 4:
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else (b if pb <= pc else c))) & 255
        rows.append(line)
        prev = line
    return w, h, rows


def write_png(path, w, h, rows):
    def chunk(t, b):
        c = struct.pack(">I", len(b)) + t + b
        return c + struct.pack(">I", zlib.crc32(t + b) & 0xffffffff)
    raw = b"".join(b"\0" + bytes(r) for r in rows)
    open(path, "wb").write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                           + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


w, h, rows = read_png(SRC)
lum = lambda x, y: (rows[y][x * 4] * 3 + rows[y][x * 4 + 1] * 6 + rows[y][x * 4 + 2]) // 10
bg = [[False] * w for _ in range(h)]
stack = [(x, y) for x in range(w) for y in (0, h - 1)] + [(x, y) for y in range(h) for x in (0, w - 1)]
while stack:
    x, y = stack.pop()
    if 0 <= x < w and 0 <= y < h and not bg[y][x] and lum(x, y) >= 232:
        bg[y][x] = True
        stack += [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
out = [bytearray(w * 4) for _ in range(h)]
for y in range(h):
    for x in range(w):
        r, g, b = rows[y][x * 4:x * 4 + 3]
        if bg[y][x]:
            continue
        near = any(0 <= x + dx < w and 0 <= y + dy < h and bg[y + dy][x + dx]
                   for dx in (-2, -1, 0, 1, 2) for dy in (-2, -1, 0, 1, 2))
        a = 255
        if near and lum(x, y) > 120:        # a light blend of outline and white: peel the white off
            a = max(0, min(255, int((255 - lum(x, y)) * 255 / 135)))
            if a:
                r, g, b = [max(0, min(255, int((c - 255 * (1 - a / 255)) * 255 / a))) for c in (r, g, b)]
        out[y][x * 4:x * 4 + 4] = bytes((r, g, b, a))
x0, y0, x1, y1 = BOX
for ex0, ey0, ex1, ey1 in ERASES:
    for y in range(ey0, ey1):
        for x in range(ex0, ex1):
            out[y][x * 4 + 3] = 0
for y in range(y1 - FADE, y1):
    for x in range(x0, x1):
        out[y][x * 4 + 3] = out[y][x * 4 + 3] * (y1 - 1 - y) // FADE
write_png(DST, x1 - x0, y1 - y0, [bytearray(out[y][x0 * 4:x1 * 4]) for y in range(y0, y1)])
print("wrote", DST, x1 - x0, "x", y1 - y0)
