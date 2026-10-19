id: @(#)probe.fth 1.1 26/10/19
purpose: Probing the devices of a PC: PCI, the ISA bus, legacy devices
copyright: Copyright 1996-2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ probe-all builds the I/O part of the device tree:
\
\  1. The PCI host bridge driver (dev/pc/pci/pcihost.tok) is loaded into
\     /pci, and its master-probe method creates nodes for the PCI
\     functions with the generic PCI bus code.  A function with an FCode
\     expansion ROM gets its driver from the ROM.  The functions of the
\     chipset have drivers in the SUNW,builtin-drivers package, found by
\     driver name ("pciVVVV,DDDD") or class ("classCCCCCC") as on SPARC.
\  2. The ISA bridge driver records where the ISA bus is, and the legacy
\     devices on it, which can't be enumerated, are probed at their
\     standard addresses.

headerless

fload ${BP}/dev/builtin.fth		\ The SUNW,builtin-drivers package

0 value isa-node			\ phandle of the ISA bus, or 0

\ Methods of SUNW,builtin-drivers execute in the context of the node
\ being created, with my-space, my-address set.
['] builtin-drivers-package push-package
headers
   : class060100  ( -- )		\ PCI-to-ISA bridge
      current-device to isa-node  isa-fcode fcode-load
   ;
headerless
pop-package

\ ---- 1. PCI

: probe-pci  ( -- )
   0 0 " " " /" begin-package  pcihost-fcode fcode-load  end-package
   \ The probe creates the device nodes as children of the current
   \ device, so it runs with /pci selected
   " /pci" select-dev  " master-probe" my-self $call-method  unselect-dev
;

\ ---- 2. Legacy ISA devices

d# 80 buffer: isa-path
d# 96 buffer: alias-path

\ A 16550 UART is present if its scratch register holds a value
: uart-present?  ( port -- flag )
   7 +  dup pc@ >r                        ( scratch-port )
   h# 5a over pc!  dup pc@ h# 5a =        ( scratch-port flag )
   h# a5 2 pick pc!  over pc@ h# a5 = and ( scratch-port flag )
   r> rot pc!
;

\ Create the node for an ISA device by loading its FCode driver
: isa-device  ( unit$ fcode-adr fcode-len -- )
   2>r  0 0 2swap  isa-path count  begin-package   ( r: fcode$ )
      2r> fcode-load
   end-package
;

\ Set a device alias to a device on the ISA bus
: isa-alias  ( alias$ node$ -- )
   isa-path count alias-path place  alias-path $cat
   alias-path count $devalias
;

: probe-serial  ( port unit$ alias$ -- )
   2>r 2>r  uart-present?  if
      2r@  serial-fcode isa-device
      2r> 2r>  2swap  " /serial@" pad place  pad $cat  pad count
      isa-alias
   else
      2r> 2drop 2r> 2drop
   then
;

: probe-isa  ( -- )
   isa-node 0=  if  exit  then
   isa-node phandle>devname isa-path place
   h# 3f8 " i3f8" " ttya" probe-serial
   h# 2f8 " i2f8" " ttyb" probe-serial
;

headers
chain: probe-all  ( -- )
   probe-pci
   probe-isa
;
