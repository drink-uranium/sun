id: @(#)loadkern.fth 1.1 26/10/18
purpose: Load file for the x86 OpenBoot kernel
copyright: Copyright 1994-2003 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ This is the x86 counterpart of fm/kernel/sparc/loadkern.fth.  It is
\ processed by the stage-0 metacompiler fm/meta/x86/meta86.py, which
\ produces kernel.S; that is assembled and linked at the origin address to
\ produce kernel.dic.  The machine-independent kernel sources are shared
\ with the SPARC kernel.

\ Assembler macros used by the code words
gas-prologue
	.macro NEXT
	lodsl
	jmp *(%eax)
	.endm

	# Save the ip and up registers on the return stack, so that the
	# code word can use %esi and %edi (for the string instructions)
	.macro SAVEIP
	lea -8(%ebp),%ebp
	mov %esi,(%ebp)
	mov %edi,4(%ebp)
	.endm

	.macro RESTIP
	mov (%ebp),%esi
	mov 4(%ebp),%edi
	lea 8(%ebp),%ebp
	.endm

	# Leave a flag according to a test of the top of stack
	.macro TEST1 cc
	pop %eax
	xor %edx,%edx
	test %eax,%eax
	set\cc %dl
	neg %edx
	push %edx
	.endm

	# Leave a flag according to a comparison of the top two stack items
	.macro COMPARE cc
	pop %eax
	pop %ecx
	xor %edx,%edx
	cmp %eax,%ecx
	set\cc %dl
	neg %edx
	push %edx
	.endm
end-prologue

fload ${BP}/fm/kernel/x86/metainit.fth

\ always-headers    \ Keep all the headers
\ sometimes-headers \ Keep some instead

sometimes-headers

fload ${BP}/fm/kernel/x86/kerncode.fth

fload ${BP}/fm/kernel/uservars.fth	\ I init task link.
fload ${BP}/fm/kernel/x86/move.fth

[ifdef] XREF
headers
defer xref-on			' noop is xref-on
defer xref-off			' noop is xref-off
defer xref-header-hook		' noop is xref-header-hook
defer xref-find-hook		' noop is xref-find-hook
defer xref-hide-hook		' noop is xref-hide-hook
defer xref-reveal-hook		' noop is xref-reveal-hook
defer xref-string-hook		' noop is xref-string-hook
[then]

fload ${BP}/fm/lib/xref.fth
fload ${BP}/fm/kernel/x86/extra.fth

fload ${BP}/fm/kernel/x86/double.fth
fload ${BP}/fm/kernel/double.fth

fload ${BP}/fm/kernel/dmuldiv.fth
defer title ' noop is title		\ Set later in loadutil.fth

fload ${BP}/fm/kernel/io.fth		\ I init #-buf

fload ${BP}/fm/kernel/stresc.fth	\ I init stringbuf
fload ${BP}/fm/kernel/comment.fth
fload ${BP}/fm/kernel/kernel2.fth
fload ${BP}/fm/kernel/compiler.fth	\ I init 'compile-buffer
fload ${BP}/fm/kernel/interp.fth
fload ${BP}/fm/kernel/kernport.fth

fload ${BP}/fm/kernel/definers.fth	\ I clear buffers
fload ${BP}/fm/kernel/tagvoc.fth
fload ${BP}/fm/kernel/voccom.fth	\ I init canonical-words and
					\   prev-canonical-word

fload ${BP}/fm/kernel/order.fth		\ I init search order
fload ${BP}/fm/kernel/is.fth
fload ${BP}/fm/kernel/x86/field.fth

fload ${BP}/fm/kernel/cold.fth

fload ${BP}/fm/kernel/x86/checkpt.fth

fload ${BP}/fm/kernel/guarded.fth

fload ${BP}/fm/lib/cstrings.fth		\ I init cstrbuf

fload ${BP}/fm/kernel/x86/filecode.fth
fload ${BP}/fm/kernel/filecomm.fth	 \ I init 'word and fds
fload ${BP}/fm/kernel/disk.fth
fload ${BP}/fm/kernel/readline.fth
fload ${BP}/fm/cwrapper/sysdisk.fth

fload ${BP}/fm/cwrapper/syskey.fth
fload ${BP}/os/unix/x86/sys.fth

fload ${BP}/fm/lib/alias.fth

fload ${BP}/fm/kernel/cmdline.fth

fload ${BP}/fm/kernel/nswapmap.fth

fload ${BP}/fm/kernel/ansio.fth		\ I init error-file
fload ${BP}/fm/kernel/x86/parseline.fth

fload ${BP}/fm/kernel/fileio.fth

fload ${BP}/fm/cwrapper/x86/boot.fth
fload ${BP}/fm/kernel/init.fth
fload ${BP}/fm/kernel/x86/finish.fth
