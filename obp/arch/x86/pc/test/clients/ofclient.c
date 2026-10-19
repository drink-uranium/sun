/*
 * A minimal Open Firmware client program for the x86 port of OpenBoot.
 *
 * OpenBoot starts it with the address of the client interface handler in
 * %eax.  It prints a greeting and some information obtained through the
 * client interface, then returns to the firmware with the "exit" service.
 *
 * Build:  see the Makefile in this directory.
 * Run:    qemu-system-i386 -kernel openboot.elf -initrd ofclient.elf
 *         ok boot ramdisk some arguments
 */

typedef unsigned int cell;

int (*cif_handler)(cell *args);

static int
of_call(const char *service, int nargs, int nret, cell *args, cell *rets)
{
	cell buf[16];
	int i, r;

	buf[0] = (cell)service;
	buf[1] = nargs;
	buf[2] = nret;
	for (i = 0; i < nargs; i++)
		buf[3 + i] = args[i];
	r = cif_handler(buf);
	for (i = 0; i < nret; i++)
		rets[i] = buf[3 + nargs + i];
	return r;
}

static cell stdout_ih;

/* Property values are encoded big-endian (IEEE 1275) */
static cell
decode_int(const void *p)
{
	return __builtin_bswap32(*(const cell *)p);
}

static int
strlen(const char *s)
{
	int n = 0;
	while (s[n])
		n++;
	return n;
}

static void
puts(const char *s)
{
	cell args[3] = { stdout_ih, (cell)s, strlen(s) };
	cell ret;
	of_call("write", 3, 1, args, &ret);
}

static void
puthex(cell v)
{
	char buf[11];
	int i;

	buf[0] = '0';
	buf[1] = 'x';
	for (i = 0; i < 8; i++)
		buf[2 + i] = "0123456789abcdef"[(v >> (28 - 4 * i)) & 0xf];
	buf[10] = 0;
	puts(buf);
}

static cell
finddevice(const char *path)
{
	cell args[1] = { (cell)path }, ph;
	of_call("finddevice", 1, 1, args, &ph);
	return ph;
}

static int
getprop(cell ph, const char *name, void *buf, int len)
{
	cell args[4] = { ph, (cell)name, (cell)buf, len }, size;
	of_call("getprop", 4, 1, args, &size);
	return size;
}

void
cmain(void)
{
	cell chosen, memory, reg[8];
	char buf[128];
	int n, i;

	chosen = finddevice("/chosen");
	getprop(chosen, "stdout", reg, sizeof (cell));
	stdout_ih = decode_int(&reg[0]);

	puts("\r\nHello from an Open Firmware client program on x86!\r\n");

	n = getprop(chosen, "bootargs", buf, sizeof (buf) - 1);
	if (n > 0) {
		buf[n] = 0;
		puts("Boot arguments: ");
		puts(buf);
		puts("\r\n");
	}

	n = getprop(finddevice("/"), "banner-name", buf, sizeof (buf) - 1);
	if (n > 0) {
		buf[n] = 0;
		puts("Machine: ");
		puts(buf);
		puts("\r\n");
	}

	memory = finddevice("/memory");
	n = getprop(memory, "reg", reg, sizeof (reg));
	for (i = 0; i + 1 < n / 4; i += 2) {
		puts("Memory ");
		puthex(decode_int(&reg[i]));
		puts(" size ");
		puthex(decode_int(&reg[i + 1]));
		puts("\r\n");
	}

	puts("Returning to OpenBoot.\r\n");
	of_call("exit", 0, 0, 0, 0);
	for (;;)
		;
}

__asm__ (
	".text\n"
	".globl _start\n"
	"_start:\n"
	"	movl %eax, cif_handler\n"
	"	call cmain\n"
	"1:	hlt\n"
	"	jmp 1b\n"
);
