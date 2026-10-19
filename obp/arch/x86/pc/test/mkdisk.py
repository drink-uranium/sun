#!/usr/bin/env python3
"""Make a test disk image with a PC partition table:
partition 1 holds an ELF boot program as is, partition 2 another one.

usage: mkdisk.py disk.img part1.elf part2.elf [active-partition]
"""
import struct, sys

def main():
    out, p1, p2 = sys.argv[1:4]
    active = int(sys.argv[4]) if len(sys.argv) > 4 else 0
    img = bytearray(16 * 1024 * 1024)
    parts = [(2048, p1), (8192, p2)]
    for i, (start, name) in enumerate(parts):
        data = open(name, 'rb').read()
        entry = struct.pack('<B3sB3sII', 0x80 if active == i + 1 else 0,
                            b'\0\0\0', 0x83, b'\0\0\0', start, 4096)
        img[446 + 16 * i:462 + 16 * i] = entry
        img[start * 512:start * 512 + len(data)] = data
    img[510:512] = b'\x55\xaa'
    open(out, 'wb').write(img)

main()
