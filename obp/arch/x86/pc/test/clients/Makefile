# Test client programs for the x86 port of OpenBoot
CC	?= gcc
CFLAGS	:= -m32 -O2 -Wall -ffreestanding -fno-pic -no-pie -fno-stack-protector \
	-fno-builtin -nostdlib -static

all: ofclient.elf mbkernel.elf

ofclient.elf: ofclient.c
	$(CC) $(CFLAGS) -Wl,-Ttext=0x400000 -Wl,--build-id=none -o $@ $<

mbkernel.elf: mbkernel.c mbkernel.ld
	$(CC) $(CFLAGS) -Wl,-T,mbkernel.ld -Wl,--build-id=none -o $@ $<

clean:
	rm -f *.elf
