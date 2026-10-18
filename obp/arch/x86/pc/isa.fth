id: @(#)isa.fth 1.1 26/10/18
purpose: The ISA bus of a PC: legacy devices at fixed I/O addresses
copyright: Copyright 1996-2002 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The address format is the same as for the ISA bus of Sun's southbridge
\ (dev/southbridge/isa/isa.fth):  phys.hi is the space (0 = I/O ports,
\ 1 = memory), phys.lo is the address within the space; unit addresses
\ are written as "space,address", e.g. serial@0,3f8.
\
\ map-in of an I/O space address returns the port number, which drivers
\ access with pc@ pc! pw@ pw! pl@ pl!.  Memory space addresses are
\ physical addresses, which are used directly.

headers
root-device
new-device
   " isa" device-name
   2 " #address-cells" integer-property
   1 " #size-cells" integer-property

   external
   : map-in  ( pa.lo pa.hi len -- va )  2drop  ;
   : map-out  ( va len -- )  2drop  ;

   : dma-alloc  ( n -- vaddr )  " dma-alloc" $call-parent  ;
   : dma-free   ( vaddr n -- )  " dma-free"  $call-parent  ;
   : dma-map-in   ( vaddr n cache? -- devaddr )  " dma-map-in"  $call-parent  ;
   : dma-map-out  ( vaddr devaddr n -- )         " dma-map-out" $call-parent  ;
   : dma-sync  ( vaddr devaddr n -- )  3drop  ;

   : decode-unit  ( adr len -- pa.lo pa.hi )  parse-2int  ;
   : encode-unit  ( pa.lo pa.hi -- adr len )
      push-hex  swap <# u#s drop ascii , hold u#s u#>  pop-base
   ;
   : open  ( -- ok? )  true  ;
   : close ( -- )  ;
finish-device
device-end
