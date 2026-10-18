id: @(#)bootinfo.fth 1.1 26/10/18
purpose: Access to the boot stub's boot-info block
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The boot stub (arch/x86/pc/start.S) is linked at stub-base.  It records
\ how the firmware was started in the boot-info block, which must match
\ the layout in start.S.

headerless
h# 10.0000 constant stub-base
stub-base h# 100 + constant boot-info

: boot-magic      ( -- n )    boot-info          l@  ;	\ %eax at entry
: boot-info-adr   ( -- adr )  boot-info h# 04 +  l@  ;	\ %ebx at entry
: initial-mem-end ( -- adr )  boot-info h# 08 +  l@  ;	\ Forth's memory
: exception-entry ( -- adr )  boot-info h# 0c +      ;
: exception-state ( -- adr )  boot-info h# 10 +  l@  ;
: idt-base        ( -- adr )  boot-info h# 14 +  l@  ;
: stub-end        ( -- adr )  boot-info h# 18 +  l@  ;

h# 2bad.b002 constant multiboot-magic
: multiboot?  ( -- flag )  boot-magic multiboot-magic =  ;
headers
