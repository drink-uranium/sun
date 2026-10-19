/*
 * A minimal Multiboot kernel, to test booting Multiboot kernels with the
 * x86 port of OpenBoot.  It prints the Multiboot information on COM1 and
 * exits QEMU through the isa-debug-exit device (if present).
 *
 * Run:  qemu-system-i386 -kernel openboot.elf -initrd mbkernel.elf \
 *           -device isa-debug-exit,iobase=0xf4,iosize=4
 *       ok boot ramdisk console=ttyS0
 */

typedef unsigned int u32;

static inline void outb(int port, int v)
{ __asm__ volatile ("outb %b0,%w1" : : "a" (v), "Nd" (port)); }
static inline int inb(int port)
{ int v; __asm__ volatile ("inb %w1,%b0" : "=a" (v) : "Nd" (port)); return v & 0xff; }

static void putc(int c)
{
	while (!(inb(0x3f8 + 5) & 0x20))
		;
	outb(0x3f8, c);
}
static void puts(const char *s) { while (*s) putc(*s++); }
static void puthex(u32 v)
{
	int i;
	puts("0x");
	for (i = 0; i < 8; i++)
		putc("0123456789abcdef"[(v >> (28 - 4 * i)) & 0xf]);
}

struct mb_header { u32 magic, flags, checksum; };
__attribute__((section(".multiboot"), used, aligned(4)))
static const struct mb_header header = { 0x1badb002, 0, -0x1badb002 };

void
kmain(u32 magic, u32 *mbi)
{
	u32 *mmap, *end;

	puts("\r\nMultiboot kernel started, magic ");
	puthex(magic);
	puts("\r\n");
	if (magic != 0x2badb002)
		goto out;
	puts("mem_lower ");
	puthex(mbi[1]);
	puts(" KB, mem_upper ");
	puthex(mbi[2]);
	puts(" KB\r\n");
	if (mbi[0] & 4) {
		puts("command line: ");
		puts((char *)mbi[4]);
		puts("\r\n");
	}
	if (mbi[0] & 0x200) {
		puts("boot loader: ");
		puts((char *)mbi[16]);
		puts("\r\n");
	}
	if (mbi[0] & 0x40) {
		mmap = (u32 *)mbi[12];
		end = (u32 *)(mbi[12] + mbi[11]);
		while (mmap < end) {
			puts("  base ");
			puthex(mmap[1]);
			puts(" length ");
			puthex(mmap[3]);
			puts(" type ");
			puthex(mmap[5]);
			puts("\r\n");
			mmap = (u32 *)((char *)mmap + mmap[0] + 4);
		}
	}
out:
	puts("Multiboot test done.\r\n");
	outb(0xf4, 0x10);		/* isa-debug-exit */
	for (;;)
		__asm__ volatile ("hlt");
}

__asm__ (
	".text\n"
	".globl _start\n"
	"_start:\n"
	"	movl $stack_top, %esp\n"
	"	pushl %ebx\n"
	"	pushl %eax\n"
	"	call kmain\n"
	".pushsection .bss\n"
	".space 8192\n"
	"stack_top:\n"
	".popsection\n"
);
