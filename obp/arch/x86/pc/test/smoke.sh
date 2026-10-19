#!/bin/sh
# Smoke test of the OpenBoot x86 image in QEMU.
#
# usage: test/smoke.sh [build-dir]
#
# Boots build/openboot.elf in QEMU (qemu-system-i386 with the default
# i440FX machine) and checks the banner, the device tree built by the PCI
# and ISA probe, the client interface (an Open Firmware client program
# booted from a Multiboot module), booting Multiboot kernels from disk
# partitions, and the reboot cycle through reset-all.

B=${1:-build}
T=$(dirname "$0")
OK="python3 $T/qemu-ok.py"
TMP=${TMPDIR:-/tmp}/openboot-smoke.$$
mkdir -p "$TMP"
trap 'rm -rf "$TMP"' EXIT

make -s -C "$T/clients" >/dev/null || exit 1
OFCLIENT=$T/clients/ofclient.elf
MBKERNEL=$T/clients/mbkernel.elf

fail=0
check() {   # check name file pattern...
    name=$1; file=$2; shift 2
    for pat in "$@"; do
        if ! grep -aq -- "$pat" "$file"; then
            echo "FAIL: $name: missing \"$pat\""
            fail=1
            return
        fi
    done
    echo "ok:   $name"
}

$OK -t 30 "$B/openboot.elf" 'show-devs' 'devalias' 'printenv boot-device' \
    > "$TMP/1" 2>&1
check "banner" "$TMP/1" "OpenBoot 4.0.0" "MB memory installed" "Host ID"
check "device tree" "$TMP/1" "/pci/isa@1/serial@i3f8" "/pci/ide@1,1/disk" \
    "/pci/display@2" "/pci/isa@1/keyboard@i60" "/cpus/cpu@0" "/memory@0"
check "aliases" "$TMP/1" "ttya  *  */pci/isa@1/serial@i3f8" "disk  *  */pci/ide@1,1/disk@0,0"

$OK -t 30 -q "-initrd $OFCLIENT" "$B/openboot.elf" 'boot ramdisk hello world' \
    > "$TMP/2" 2>&1
check "client interface" "$TMP/2" "Boot arguments: hello world" \
    "Machine: PC compatible" "Program terminated"

python3 "$T/mkdisk.py" "$TMP/disk.img" "$OFCLIENT" "$MBKERNEL" 2
$OK -t 30 -q "-drive file=$TMP/disk.img,format=raw,if=ide" "$B/openboot.elf" \
    > "$TMP/3" 2>&1
check "auto-boot from disk" "$TMP/3" "Boot device: disk" \
    "Multiboot kernel started, magic 0x2badb002" "boot loader: OpenBoot x86"

python3 "$T/mkdisk.py" "$TMP/disk.img" "$OFCLIENT" "$MBKERNEL" 1
$OK -t 30 -r -q "-drive file=$TMP/disk.img,format=raw,if=ide" "$B/openboot.elf" \
    'boot disk:2 first' > "$TMP/4" 2>&1
check "partition, reboot" "$TMP/4" "Boot arguments: " \
    "Rebooting with command: boot disk:2 first" "command line: first"

exit $fail
