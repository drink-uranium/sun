id: @(#)dropins.fth 1.1 26/10/19
purpose: FCode drivers for the onboard devices of PCs
copyright: Copyright 1996-2003 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ As on the SPARC systems, the drivers for the onboard devices are FCode
\ programs, tokenized at build time (see the Makefile) and kept in the
\ firmware image.  They are byte-loaded when the devices are probed:
\ the PCI host bridge by the platform's probe sequence, PCI functions
\ through the SUNW,builtin-drivers package (see dev/pci/fcode-rom.fth),
\ and the legacy ISA devices by the ISA probe.

headerless

\ fcode-image: name file  creates  name ( -- adr len )  that returns the
\ contents of the FCode file, which is read when the firmware is built.
: fcode-image:  \ name filename  ( -- )
   create
   safe-parse-word 2dup r/o open-file  if         ( name$ fd )
      drop ." Can't open FCode image " type cr abort
   then  nip nip  >r                              ( r: fd )
   r@ file-size 2drop                             ( size )
   dup ,  here over allot                         ( size adr )
   swap r@ read-file 2drop                        ( )
   r> close-file drop
   does>  dup na1+ swap @
;

headers
: fcode-load  ( adr len -- )  drop 1 byte-load  ;
headerless

headers
fcode-image: pcihost-fcode  pcihost.fc
fcode-image: isa-fcode      isa.fc
fcode-image: serial-fcode   serial.fc
fcode-image: ide-fcode      ide.fc
fcode-image: vgatext-fcode  vgatext.fc
fcode-image: kbd-fcode      kbd.fc
