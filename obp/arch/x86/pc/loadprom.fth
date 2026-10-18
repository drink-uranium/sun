id: @(#)loadprom.fth 1.1 26/10/18
purpose: Load file for OpenBoot on PC-compatible x86 systems
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

decimal
warning off
caps on

fload ${BP}/fm/lib/loadcomm.fth		\ Generic CPU-independent Forth tools
fload ${BP}/os/sun/x86/loadmach.fth	\ CPU and OS-specific extensions
fload ${BP}/os/sun/x86/loadfw.fth	\ Platform-independent Open Firmware

\ ===========================================================================
\ Up to this point, we haven't loaded any machine-dependent code

fload ${BP}/arch/x86/pc/bootinfo.fth	\ How the boot stub started us
fload ${BP}/arch/x86/pc/uart.fth	\ Diagnostic and fallback console
fload ${BP}/os/stand/sysuart.fth
fload ${BP}/arch/x86/pc/heap.fth	\ Memory layout
fload ${BP}/arch/x86/pc/fwio.fth	\ stand-init-io

fload ${BP}/arch/x86/pc/startup.fth

fload ${BP}/arch/x86/pc/cleanup.fth
