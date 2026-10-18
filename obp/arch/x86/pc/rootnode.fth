id: @(#)rootnode.fth 1.1 26/10/18
purpose: Root node of the PC device tree
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The root node represents the processor's physical address space.  The
\ firmware runs with paging disabled, so addresses in the root node's
\ address space are used directly.

root-device
   " i86pc" device-name
   " i86pc" " compatible" string-property
   " PC compatible (x86)" " banner-name" string-property
   " PC compatible (x86)" " model" string-property

   1 " #address-cells" integer-property
   1 " #size-cells" integer-property

   : open  ( -- true )  true  ;
   : close  ( -- )  ;

   : map-in  ( phys size -- virtual )  drop  ;
   : map-out  ( virtual size -- )  2drop  ;

   : dma-alloc  ( size -- virtual )  alloc-mem  ;
   : dma-free  ( virtual size -- )  free-mem  ;
   : dma-map-in  ( virtual size cacheable? -- devaddr )  2drop  ;
   : dma-map-out  ( virtual devaddr size -- )  3drop  ;
   : dma-sync  ( virtual devaddr size -- )  3drop  ;

   : encode-unit  ( phys -- adr len )  push-hex (u.) pop-base  ;
   : decode-unit  ( adr len -- phys )  $number  if  0  then  ;
device-end
