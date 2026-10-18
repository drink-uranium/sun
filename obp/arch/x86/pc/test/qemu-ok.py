#!/usr/bin/env python3
"""Boot the OpenBoot x86 image in QEMU, type commands at the ok prompt
and print the console output.

usage: qemu-ok.py [-t timeout] [-q qemu-args] image.elf 'command' ...
"""
import os, select, subprocess, sys, time

def main():
    args = sys.argv[1:]
    timeout = 30.0
    extra = []
    while args and args[0].startswith('-'):
        opt = args.pop(0)
        if opt == '-t':
            timeout = float(args.pop(0))
        elif opt == '-q':
            extra += args.pop(0).split()
    image = args.pop(0)
    cmds = args
    qemu = os.environ.get('QEMU', 'qemu-system-i386')
    p = subprocess.Popen([qemu, '-m', '128', '-nographic', '-no-reboot',
                          '-kernel', image] + extra,
                         stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                         stderr=subprocess.STDOUT)
    out = b''
    deadline = time.time() + timeout
    def read_until(pattern, t):
        nonlocal out
        end = min(deadline, time.time() + t)
        start = len(out)
        while time.time() < end:
            if pattern == b'ok ' and b'More [<space>' in out[start:]:
                return False
            r, _, _ = select.select([p.stdout], [], [], 0.1)
            if r:
                data = os.read(p.stdout.fileno(), 4096)
                if not data:
                    return False
                out += data
                sys.stdout.write(data.decode('latin-1'))
                sys.stdout.flush()
                if pattern in out[start:]:
                    return True
            if p.poll() is not None:
                return False
        return False
    ok = read_until(b'ok ', timeout)
    for c in cmds:
        if not ok:
            break
        p.stdin.write(c.encode() + b'\r')
        p.stdin.flush()
        while True:
            ok = read_until(b'ok ', timeout)
            # Answer OpenBoot's pager with "c" (continue without paging)
            if not ok and b'More [' in out[-120:]:
                p.stdin.write(b'c')
                p.stdin.flush()
                continue
            break
    p.kill()
    p.wait()
    sys.stdout.write('\n')
    return 0 if ok else 1

sys.exit(main())
