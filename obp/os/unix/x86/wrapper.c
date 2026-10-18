/*
 * ========== Copyright Header Begin ==========================================
 *
 * OpenBoot x86 port: Unix wrapper program
 *
 * Copyright 1985-1994 Bradley Forthware
 * Copyright 1994-2006 Sun Microsystems, Inc.  All Rights Reserved
 * Copyright 2026 The OpenBoot x86 port contributors
 * Use is subject to license terms (see any OpenBoot source file).
 *
 * ========== Copyright Header End ============================================
 *
 * wrapper.c -- runs the x86 OpenBoot Forth image as a Linux process.
 *
 * This is the x86 counterpart of the C wrapper that the SPARC OpenBoot
 * build uses (bin/forth, os/unix/sparc/forth).  It loads a Forth memory
 * image (kernel.dic or a dictionary saved with save-forth) at the image's
 * origin, and calls the image's cold-code entry with the address of a table
 * of C functions.  The Forth words "syscall" and "fsyscall"
 * (os/unix/x86/sys.fth) call through that table; the function numbers and
 * argument orders are the ones used by fm/cwrapper/syskey.fth,
 * fm/cwrapper/sysdisk.fth and the rest of the OpenBoot sources.
 *
 * The program is freestanding: it makes Linux i386 system calls directly,
 * so it needs no 32-bit C library.
 *
 * Usage:  forth [ -d dictionary-file ] [ forth-arguments ... ]
 */

typedef unsigned int u32;
typedef int s32;
typedef unsigned long size_t;

#define MEMSIZE		(48 * 1024 * 1024)	/* Dictionary + stacks */
#define HEAPSIZE	(64 * 1024 * 1024)	/* alloc-mem arena */
#define IMAGE_MAGIC	0x3638424f		/* "OB86" */

/* Linux i386 system call numbers */
#define SYS_exit	1
#define SYS_read	3
#define SYS_write	4
#define SYS_open	5
#define SYS_close	6
#define SYS_unlink	10
#define SYS_lseek	19
#define SYS_ioctl	54
#define SYS_munmap	91
#define SYS_poll	168
#define SYS_mmap2	192

#define O_RDONLY	0
#define O_WRONLY	1
#define O_RDWR		2
#define O_CREAT		0100
#define O_TRUNC		01000

#define PROT_READ	1
#define PROT_WRITE	2
#define PROT_EXEC	4
#define MAP_PRIVATE	2
#define MAP_FIXED	0x10
#define MAP_ANONYMOUS	0x20

#define TCGETS		0x5401
#define TCSETS		0x5402

static inline s32
syscall3(s32 n, s32 a, s32 b, s32 c)
{
	s32 ret;
	__asm__ volatile ("int $0x80"
	    : "=a" (ret)
	    : "0" (n), "b" (a), "c" (b), "d" (c)
	    : "memory");
	return ret;
}

/* Six-argument system call, in assembler at the end of this file */
extern s32 syscall6(s32 n, s32 a, s32 b, s32 c, s32 d, s32 e, s32 f);

static void
sys_exit(int code)
{
	for (;;)
		syscall3(SYS_exit, code, 0, 0);
}

static int
xwrite(int fd, const void *buf, int len)
{
	return syscall3(SYS_write, fd, (s32)buf, len);
}

static int
xread(int fd, void *buf, int len)
{
	return syscall3(SYS_read, fd, (s32)buf, len);
}

static size_t
strlen(const char *s)
{
	size_t n = 0;
	while (s[n])
		n++;
	return n;
}

static void *
memcpy(void *d, const void *s, size_t n)
{
	char *dp = d;
	const char *sp = s;
	while (n--)
		*dp++ = *sp++;
	return d;
}

static void *
memset(void *d, int c, size_t n)
{
	char *dp = d;
	while (n--)
		*dp++ = c;
	return d;
}

static int
strncmp(const char *a, const char *b, size_t n)
{
	while (n--) {
		if (*a != *b)
			return (unsigned char)*a - (unsigned char)*b;
		if (*a == 0)
			return 0;
		a++, b++;
	}
	return 0;
}

static void
puts2(const char *s)
{
	xwrite(2, s, strlen(s));
}

static void
fatal(const char *s1, const char *s2)
{
	puts2("forth: ");
	puts2(s1);
	if (s2) {
		puts2(" ");
		puts2(s2);
	}
	puts2("\n");
	sys_exit(1);
}

static void *
xmmap(void *addr, size_t len, int prot, int flags)
{
	return (void *)syscall6(SYS_mmap2, (s32)addr, len, prot, flags, -1, 0);
}

/*
 * Memory allocator for alloc-mem and free-mem: first fit with coalescing,
 * on an arena obtained from the system once.
 */
struct blk {
	u32 size;		/* Including this header; low bit = in use */
	u32 pad[3];		/* Keep allocations 16-byte aligned */
};

static struct blk *heap_base, *heap_end;

static void
heap_init(void)
{
	heap_base = xmmap(0, HEAPSIZE, PROT_READ | PROT_WRITE | PROT_EXEC,
	    MAP_PRIVATE | MAP_ANONYMOUS);
	if ((u32)heap_base >= 0xfffff000)
		fatal("can't allocate the heap", 0);
	heap_end = (struct blk *)((char *)heap_base + HEAPSIZE);
	heap_base->size = HEAPSIZE;
}

#define NEXTBLK(b)	((struct blk *)((char *)(b) + ((b)->size & ~1)))

static void *
f_alloc_mem(u32 nbytes)
{
	struct blk *b, *n;
	u32 need = (nbytes + sizeof (struct blk) + 15) & ~15;

	for (b = heap_base; b < heap_end; b = NEXTBLK(b)) {
		if (b->size & 1)
			continue;
		/* Coalesce following free blocks */
		while ((n = NEXTBLK(b)) < heap_end && !(n->size & 1))
			b->size += n->size;
		if (b->size >= need) {
			if (b->size - need >= 2 * sizeof (struct blk)) {
				n = (struct blk *)((char *)b + need);
				n->size = b->size - need;
				b->size = need;
			}
			b->size |= 1;
			memset(b + 1, 0, (b->size & ~1) - sizeof (struct blk));
			return b + 1;
		}
	}
	return 0;
}

static s32
f_free_mem(u32 nbytes, void *adr)
{
	struct blk *b = (struct blk *)adr - 1;

	if (adr == 0 || b < heap_base || b >= heap_end)
		return -1;
	b->size &= ~1;
	return 0;
}

/* Environment variable expansion in file names, e.g. ${BP}/fm/lib/... */
static char **envp;

static const char *
getenv2(const char *name, int len)
{
	char **e;

	for (e = envp; *e; e++)
		if (strncmp(*e, name, len) == 0 && (*e)[len] == '=')
			return *e + len + 1;
	return 0;
}

static char pathbuf[1024];

static const char *
expand(const char *s)
{
	char *d = pathbuf, *end = pathbuf + sizeof (pathbuf) - 1;
	const char *v;
	int len;

	while (*s && d < end) {
		if (s[0] == '$' && s[1] == '{') {
			for (len = 0; s[2 + len] && s[2 + len] != '}'; len++)
				;
			v = getenv2(s + 2, len);
			if (v == 0) {
				puts2("forth: undefined environment variable in ");
				puts2(s);
				puts2("\n");
				v = "";
			}
			while (*v && d < end)
				*d++ = *v++;
			s += len + 2;
			if (*s == '}')
				s++;
		} else
			*d++ = *s++;
	}
	*d = 0;
	return pathbuf;
}

static s32 last_errno;

static s32
check(s32 r)
{
	if (r < 0 && r > -4096) {
		last_errno = -r;
		return -1;
	}
	return r;
}

/* ---- The system call table functions ---- */

static s32
f_key(void)
{
	unsigned char c;

	if (xread(0, &c, 1) != 1)
		sys_exit(0);
	return c;
}

static s32
f_emit(s32 c)
{
	char ch = c;
	xwrite(1, &ch, 1);
	return 0;
}

static s32
f_open(char *name, s32 mode, s32 prot)
{
	s32 flags = mode & 3;

	if (flags == O_WRONLY)
		flags |= O_CREAT | O_TRUNC;
	if (prot == -1)
		prot = 0666;
	return check(syscall3(SYS_open, (s32)expand(name), flags, prot));
}

static s32
f_creat(char *name, s32 prot)
{
	if (prot == -1)
		prot = 0666;
	return check(syscall3(SYS_open, (s32)expand(name),
	    O_RDWR | O_CREAT | O_TRUNC, prot));
}

static s32
f_close(s32 fd)
{
	return check(syscall3(SYS_close, fd, 0, 0));
}

static s32
f_read(s32 fd, void *adr, s32 len)
{
	return check(xread(fd, adr, len));
}

static s32
f_write(s32 fd, void *adr, s32 len)
{
	return check(xwrite(fd, adr, len));
}

static s32
f_keyq(void)
{
	struct { s32 fd; short events, revents; } pfd = { 0, 1, 0 };

	return syscall3(SYS_poll, (s32)&pfd, 1, 0) > 0 ? -1 : 0;
}

static s32
f_bye(s32 code)
{
	sys_exit(code);
	return 0;
}

static s32
f_lseek(s32 fd, s32 offset, s32 whence)
{
	return check(syscall3(SYS_lseek, fd, offset, whence));
}

static s32
f_unlink(char *name)
{
	return check(syscall3(SYS_unlink, (s32)expand(name), 0, 0));
}

static int
isatty(int fd)
{
	char termios[64];
	return syscall3(SYS_ioctl, fd, TCGETS, (s32)termios) == 0;
}

/* Returns 0 if the input stream is interactive */
static s32
f_redirected(void)
{
	return isatty(0) ? 0 : 1;
}

static s32
f_type(s32 len, char *adr)
{
	if (len > 0)
		xwrite(1, adr, len);
	return 0;
}

static s32
f_accept(s32 len, char *adr)
{
	s32 n = 0;
	unsigned char c;

	while (n < len) {
		if (xread(0, &c, 1) != 1) {
			if (n == 0)
				sys_exit(0);
			break;
		}
		if (c == '\n')
			break;
		adr[n++] = c;
	}
	return n;
}

static s32
f_errno(void)
{
	return last_errno;
}

static s32
f_cr(void)
{
	xwrite(1, "\n", 1);
	return 0;
}

static unsigned char newline_pstr[] = { 1, '\n', 0 };

static s32
f_newline(void)
{
	return (s32)newline_pstr;
}

static s32
f_sync_cache(void *adr, s32 len)
{
	return 0;
}

static s32
f_nosys(void)
{
	return -1;
}

/*
 * Extended operations through fsyscall 45.  The argument is the Forth
 * stack pointer; sp[0] is the sub-operation code.  Returns the new stack
 * pointer.
 */
static s32 *
f_extended(s32 *sp)
{
	s32 op = *sp++;
	s32 fd, size, n;
	char *name, *buf;

	switch (op) {
	case 46:		/* ( name len -- adr len ) read a whole file */
		size = sp[0];
		name = (char *)sp[1];
		if (size >= (s32)sizeof (pathbuf))
			size = sizeof (pathbuf) - 1;
		memcpy(pathbuf, name, size);
		pathbuf[size] = 0;
		fd = syscall3(SYS_open, (s32)expand(pathbuf), O_RDONLY, 0);
		if (fd < 0) {
			sp[0] = 0;
			sp[1] = 0;
			break;
		}
		size = syscall3(SYS_lseek, fd, 0, 2);
		syscall3(SYS_lseek, fd, 0, 0);
		buf = f_alloc_mem(size + 1);
		n = buf ? xread(fd, buf, size) : 0;
		syscall3(SYS_close, fd, 0, 0);
		sp[0] = n < 0 ? 0 : n;
		sp[1] = (s32)buf;
		break;
	default:		/* Compile-time error marks, xref, etc. */
		break;
	}
	return sp;
}

typedef s32 (*func_t)();

static func_t functions[64];

static void
init_functions(void)
{
	int i;

	for (i = 0; i < 64; i++)
		functions[i] = (func_t)f_nosys;
	functions[0] = (func_t)f_key;
	functions[1] = (func_t)f_emit;
	functions[2] = (func_t)f_open;
	functions[3] = (func_t)f_creat;
	functions[4] = (func_t)f_close;
	functions[5] = (func_t)f_read;
	functions[6] = (func_t)f_write;
	functions[8] = (func_t)f_keyq;
	functions[9] = (func_t)f_bye;
	functions[10] = (func_t)f_lseek;
	functions[11] = (func_t)f_unlink;
	functions[12] = (func_t)f_redirected;
	functions[13] = (func_t)f_type;
	functions[14] = (func_t)f_accept;
	functions[15] = (func_t)f_errno;
	functions[26] = (func_t)f_alloc_mem;
	functions[27] = (func_t)f_cr;
	functions[28] = (func_t)f_newline;
	functions[29] = (func_t)f_sync_cache;
	functions[32] = (func_t)f_free_mem;
	functions[45] = (func_t)f_extended;
}

/* ---- Loading and starting the image ---- */

struct header {
	u32 magic;
	u32 text_size;
	u32 user_size;
	u32 entry;
	u32 origin;
	u32 reserved[3];
};

typedef void (*cold_t)(void *, func_t *, void *, int, char **);

int
main(int argc, char **argv, char **env)
{
	const char *dicname = 0;
	struct header hdr;
	char *mem;
	int fd, n, total;

	envp = env;
	if (argc >= 3 && argv[1][0] == '-' && argv[1][1] == 'd' &&
	    argv[1][2] == 0) {
		dicname = argv[2];
		argv[2] = argv[0];
		argv += 2;
		argc -= 2;
	}
	if (dicname == 0)
		dicname = getenv2("FORTH_DIC", 9);
	if (dicname == 0)
		fatal("no dictionary file; use -d file or set FORTH_DIC", 0);

	fd = syscall3(SYS_open, (s32)expand(dicname), O_RDONLY, 0);
	if (fd < 0)
		fatal("can't open", dicname);
	if (xread(fd, &hdr, sizeof (hdr)) != sizeof (hdr) ||
	    hdr.magic != IMAGE_MAGIC)
		fatal("not an x86 OpenBoot dictionary:", dicname);

	mem = xmmap((void *)hdr.origin, MEMSIZE,
	    PROT_READ | PROT_WRITE | PROT_EXEC,
	    MAP_PRIVATE | MAP_ANONYMOUS | MAP_FIXED);
	if (mem != (char *)hdr.origin)
		fatal("can't map memory at the dictionary origin", 0);

	total = hdr.text_size + hdr.user_size;
	if (total > MEMSIZE / 2)
		fatal("dictionary file too large:", dicname);
	memcpy(mem, &hdr, sizeof (hdr));
	n = xread(fd, mem + sizeof (hdr), total - sizeof (hdr));
	if (n != (int)(total - sizeof (hdr)))
		fatal("short dictionary file:", dicname);
	syscall3(SYS_close, fd, 0, 0);

	heap_init();
	init_functions();

	((cold_t)hdr.entry)(mem, functions, mem + MEMSIZE, argc, argv);
	return 0;
}

/* Process entry point: the kernel leaves argc, argv, envp on the stack */
__asm__ (
	".text\n"
	".globl syscall6\n"
	"syscall6:\n"
	"	push %ebp\n"
	"	push %edi\n"
	"	push %esi\n"
	"	push %ebx\n"
	"	mov 20(%esp),%eax\n"
	"	mov 24(%esp),%ebx\n"
	"	mov 28(%esp),%ecx\n"
	"	mov 32(%esp),%edx\n"
	"	mov 36(%esp),%esi\n"
	"	mov 40(%esp),%edi\n"
	"	mov 44(%esp),%ebp\n"
	"	int $0x80\n"
	"	pop %ebx\n"
	"	pop %esi\n"
	"	pop %edi\n"
	"	pop %ebp\n"
	"	ret\n"
	".globl _start\n"
	"_start:\n"
	"	xor %ebp,%ebp\n"
	"	mov (%esp),%eax\n"	/* argc */
	"	lea 4(%esp),%ecx\n"	/* argv */
	"	lea 4(%ecx,%eax,4),%edx\n" /* envp */
	"	and $-16,%esp\n"
	"	push %edx\n"
	"	push %ecx\n"
	"	push %eax\n"
	"	call main\n"
	"	push %eax\n"
	"	call sys_exit_entry\n"
	"	hlt\n"
);

void
sys_exit_entry(int code)
{
	sys_exit(code);
}
