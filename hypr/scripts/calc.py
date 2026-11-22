"""Binary-exploitation scratch REPL. Start with: python3 -i calc.py
Plain Python plus a few helpers, no dependencies. Try:
    info(0xdeadbeef + 0x20)      dec / hex / bin / little-endian bytes
    p64(0x401136)                pack little-endian
    u64(b"\\x36\\x11\\x40")        unpack
    xor(b"secret", b"k")         repeating-key xor
    hexdump(open("a.out","rb").read(64))
"""
import struct


def p32(x):
    return struct.pack("<I", x & 0xFFFFFFFF)


def p64(x):
    return struct.pack("<Q", x & 0xFFFFFFFFFFFFFFFF)


def u32(b):
    return struct.unpack("<I", b.ljust(4, b"\0")[:4])[0]


def u64(b):
    return struct.unpack("<Q", b.ljust(8, b"\0")[:8])[0]


def xor(data, key):
    if isinstance(key, int):
        key = bytes([key])
    return bytes(c ^ key[i % len(key)] for i, c in enumerate(data))


def hexdump(data, width=16):
    for off in range(0, len(data), width):
        chunk = data[off:off + width]
        hexs = " ".join(f"{c:02x}" for c in chunk).ljust(width * 3 - 1)
        text = "".join(chr(c) if 32 <= c < 127 else "." for c in chunk)
        print(f"{off:08x}  {hexs}  |{text}|")


def info(x):
    print(f"dec   {x}")
    print(f"hex   {hex(x)}")
    print(f"bin   {bin(x)}")
    print(f"le32  {p32(x)!r}")
    print(f"le64  {p64(x)!r}")


print("helpers: info p32 p64 u32 u64 xor hexdump")
