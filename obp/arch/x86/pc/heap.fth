id: @(#)heap.fth 1.1 26/10/18
purpose: Initial memory layout of the firmware
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ Physical memory used by the firmware (paging is disabled, so virtual
\ addresses are physical addresses):
\
\   stub-base  .. stub-end      The boot stub, its stack, IDT
\   origin     .. limit         The Forth dictionary
\   limit      .. mem-end       Data stack, return stack, user area
\   mem-end    .. +/fw-heap     The heap used by alloc-mem
\
\ mem-end is set by the boot stub.  The firmware is placed at 16MB
\ (STUB_BASE in the Makefile) so that the memory below, where operating
\ systems are usually loaded, is free for client programs.

headerless
d# 16 1meg * constant /fw-heap

: fw-heap  ( -- adr len )  initial-mem-end  /fw-heap  ;
' fw-heap is initial-heap
headers
