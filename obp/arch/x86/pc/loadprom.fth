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

fload ${BP}/arch/x86/pc/rootnode.fth	\ The root of the device tree
fload ${BP}/arch/x86/pc/mmu.fth		\ Identity address translation
fload ${BP}/arch/x86/pc/memory.fth	\ Physical memory
fload ${BP}/arch/x86/pc/cpu.fth		\ Processor and timing
fload ${BP}/arch/x86/pc/model.fth		\ /openprom model and version props.

fload ${BP}/arch/x86/pc/loadconfig.fth	\ Configuration variables
fload ${BP}/arch/x86/pc/nvram.fth	\ Configuration variable storage
' diag-switch? is diagnostic-mode?

fload ${BP}/arch/x86/pc/dropins.fth	\ FCode drivers for onboard devices

fload ${BP}/cpu/x86/catchexc.fth	\ Processor exceptions
fload ${BP}/arch/x86/pc/ramdisk.fth	\ Multiboot modules as a boot device

fload ${BP}/cpu/x86/restart.fth		\ go

headerless
\ Host ID: there is no ID PROM on a PC, so this is derived from the
\ processor signature and the amount of memory.
: hostid  ( -- n )  cpu-signature  total-ram d# 20 >>  xor  h# 80.0000 or  ;
headers
: .keyboard-type  ( -- )  ." Keyboard Present"  ;

\ Packages
fload ${BP}/arch/x86/pc/loadpkg.fth

fload ${BP}/arch/x86/pc/probe.fth	\ probe-all
fload ${BP}/arch/x86/pc/startup.fth

fload ${BP}/arch/x86/pc/cleanup.fth
