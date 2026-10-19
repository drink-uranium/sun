id: @(#)methods.fth 1.1 26/10/19
purpose: Methods of the PC PCI host bridge node
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ Modeled on dev/sun4v-devices/vpci/methods.fth.

headerless

\ The devices to probe on bus 0
: probe-list$  ( -- adr len )
   " 0,1,2,3,4,5,6,7,8,9,a,b,c,d,e,f,10,11,12,13,14,15,16,17,18,19,1a,1b,1c,1d,1e,1f"
;

external

: config-b@ ( phys.hi -- b ) cfg-b@ ;
: config-b! ( b phys.hi -- ) cfg-b! ;
: config-w@ ( phys.hi -- w ) cfg-w@ ;
: config-w! ( w phys.hi -- ) cfg-w! ;
: config-l@ ( phys.hi -- l ) cfg-l@ ;
: config-l! ( l phys.hi -- ) cfg-l! ;

: my-pci-bus  ( -- bus# )  0  ;

: decode-unit ( adr len -- phys.lo phys.mid phys.hi )
   pci-decode-unit lwsplit drop  my-pci-bus  wljoin
;

: encode-unit  ( phys.lo phys.mid phys.hi -- adr len ) pci-encode-unit ;

: map-in ( p.low p.mid p.hi len -- vaddr ) pci-map-in ;
: map-out ( va len -- ) " map-out" $call-parent ;

\ The processor and PCI agree about memory addresses; DMA is from memory
\ that the root node allocates.
: dma-alloc  ( size -- virt )  " dma-alloc" $call-parent  ;
: dma-free   ( virt size -- )  " dma-free" $call-parent  ;
: dma-map-in  ( virt size cacheable? -- devaddr )
   " dma-map-in" $call-parent
;
: dma-map-out  ( virt devaddr size -- )  " dma-map-out" $call-parent  ;
: dma-sync  ( virt devaddr size -- )  3drop  ;

variable my-memlist  my-memlist off
variable my-io-list  my-io-list off

: allocate-bus# ( n mem-aln mem-sz io-aln io-sz -- . . . . . . . )
                      ( . . . . . -- mem-l io-l dma-l mem-h io-h dma-h bus# )
   pci-allocate-bus#
;

\ coreboot or the BIOS has routed the interrupts and set the interrupt
\ line registers; leave them alone.
: assign-int-line ( int phys.hi -- false )  2drop false  ;

: prober ( adr len -- )  pci-prober  ;
: prober-xt ( -- adr )  ['] pci-prober  ;

: master-probe  ( -- )
   bar-struct-addr my-memlist @ my-io-list @		( reg mem io )
   set-pointers						( -- )
   probe-list$ pci-master-probe
   make-available-property				( -- )
   get-pointers						( reg mem io )
   my-io-list ! my-memlist ! drop			( -- )
;

: open true ;
: close ;

headerless
