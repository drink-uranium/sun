id: @(#)common.fth 1.1 26/10/19
purpose: Definitions shared by the PC PCI host bridge driver
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The PC counterpart of dev/sun4v-devices/vpci/common.fth.  PCI is
\ little-endian, like the processor, so unlike the SPARC host bridges this
\ one doesn't load dev/utilities/swapped-access.fth.

fload ${BP}/dev/utilities/misc.fth

h# 1000                 value pagesize
alias mmu-pagesize pagesize
pagesize invert 1+      value page#mask
h# c                    value pageshift
h# 100000               constant 1meg
variable pci-memlist    pci-memlist off
variable pci-io-list    pci-io-list off
0 value  bar-struct-addr

fload ${BP}/dev/utilities/memlist.fth
fload ${BP}/dev/pci/debug.fth
fload ${BP}/dev/pci/cfgio.fth
fload ${BP}/dev/pci/memstack.fth

: builtin-drivers " SUNW,builtin-drivers" ;
