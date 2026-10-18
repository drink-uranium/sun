id: @(#)mmu.fth 1.1 26/10/18
purpose: Address translation interface for the x86 firmware (identity)
copyright: Copyright 1990-2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The PC firmware runs in 32-bit protected mode with paging disabled, so
\ every virtual address is the physical address with the same value.  This
\ file provides the page-size definitions and the address translation words
\ that the machine-independent parts of OpenBoot expect from the MMU code
\ (cpu/sparc/ultra/mmu.fth on the SPARC ports), with identity semantics.

headers
h# 0c                  constant pageshift	\ 4K pages
1 pageshift lshift     constant pagesize
pagesize 1-            constant pagemask
pagesize negate        constant page#mask

alias mmu-pagesize pagesize

\ Round the region to enclose the appropriate page restrictions.
: >mmu-boundaries ( va len size -- va' len' )
   1-  >r                         ( va len )  ( r: mask )
   over + r@ +  r@ invert and     ( va end' )
   swap r> invert and             ( end' va' )
   tuck -                         ( va' len' )
;
: >page-boundaries ( va len -- va' len' )  pagesize >mmu-boundaries  ;

\ Physical addresses are passed as phys.lo phys.hi; phys.hi is always 0
\ for memory below 4GB, which is all that the 32-bit firmware can use.
: >physical-identity  ( virtual -- phys.lo phys.hi )  0  ;
' >physical-identity is >physical

\ map-in for the root node and other "transparent" buses
: identity-map-in  ( phys size -- virtual )  drop  ;
: identity-map-out  ( virtual size -- )  2drop  ;

\ memmap is used by drivers to map physical ranges
: memmap  ( pa.lo pa.hi size -- virtual )  2drop  ;
