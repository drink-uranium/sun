id: @(#)loadmach.fth 1.1 26/10/18
purpose: Load file for the CPU and OS-specific tools (x86)
copyright: Copyright 1991-1994 Firmworks  All Rights Reserved
copyright: Copyright 1994-2003 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ This is the x86 counterpart of os/sun/sparc/loadmach.fth.  The x86
\ port does not yet have a resident assembler and disassembler; the code
\ words that the SPARC version assembles in these files are metacompiled
\ into the kernel instead (fm/kernel/x86/cpucode.fth).

warning on

fload ${BP}/cpu/x86/xwords.fth		\ 64-bit data words

fload ${BP}/cpu/x86/disassem.fth	\ Exports dis , pc , dis1 , +dis

fload ${BP}/fm/lib/instdis.fth

fload ${BP}/fm/lib/x86/decompm.fth

fload ${BP}/os/stand/x86/notmeta.fth

fload ${BP}/os/sun/nlist.fth	\ Not transient; Used by symdebug.fth

fload ${BP}/os/sun/elf.fth

transient fload ${BP}/fm/cwrapper/x86/savefort.fth	resident

warning @ warning off  alias save-forth save-forth  warning !

fload ${BP}/fm/lib/x86/objsup.fth
fload ${BP}/fm/lib/objects.fth
fload ${BP}/fm/lib/action-primitives.fth

fload ${BP}/cpu/x86/cpustate.fth
fload ${BP}/cpu/x86/register.fth

fload ${BP}/fm/lib/savedstk.fth
fload ${BP}/fm/lib/rstrace.fth
fload ${BP}/fm/lib/x86/ftrace.fth
fload ${BP}/fm/lib/x86/ctrace.fth

fload ${BP}/os/sun/aout.fth

\ Locking primitives.  The firmware runs with interrupts disabled.
headerless
: (lock[  ( -- )  ;
: (]unlock  ( -- )  ;
headers

\ Calling a 32-bit client function is the same as calling any C function
alias call32 call
