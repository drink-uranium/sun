id: @(#)pci.fth 1.1 26/10/19
purpose: PCI interface of the PC IDE controller driver
copyright: Copyright 2005 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The PC version of dev/ide/pci/pci.fth.
\
\ A PCI IDE controller channel is either in native mode, with its command
\ and control blocks at the addresses in base address registers 0-3, or
\ in compatibility mode, decoding the legacy ISA addresses: 1f0-1f7 and
\ 3f6 for the primary channel, 170-177 and 376 for the secondary
\ channel, as the IDE controllers built into PC chipsets usually are.
\ Bits 0 and 2 of the programming interface byte of the class code say
\ which mode each channel is in.
\
\ The addresses are I/O ports, which the register access words use
\ directly (cpu/x86/regwords.fth); I/O space map-in is the identity.

headerless

fload ${BP}/dev/pci/config-access.fth

fload ${BP}/dev/pci/compatible.fth
make-compatible-property

external

: map-in	" map-in" $call-parent ;
: map-out	" map-out" $call-parent ;

headerless

: prog-if  ( -- n )  9 my-b@  ;
: native?  ( channel -- flag )  2* 1 swap <<  prog-if and  0<>  ;

: bar>offset ( n -- offset ) h# 4 * h# 10 +  ;
: bar@  ( bar -- port )  bar>offset my-l@ 3 invert and  ;

\ Command and control block ports of a channel.  The control block of
\ the IDE driver starts 2 bytes below the alternate status register.
: legacy-ports  ( channel -- cmd ctrl )
   if  h# 170 h# 374  else  h# 1f0 h# 3f4  then
;
: native-ports  ( channel -- cmd ctrl )
   2* dup bar@  swap 1+ bar@
;
: channel-ports  ( channel -- cmd ctrl )
   dup native?  if  native-ports  else  legacy-ports  then
;

\ The "reg" property: configuration space, then for each channel the
\ command block (8 bytes) and the control block (4 bytes).  Legacy
\ addresses are non-relocatable I/O space addresses.
: en+ ( xdr,len int -- xdr',len' )	encode-int encode+  ;
: 0+  ( xdr,len 0 -- xdr',len' )	0 en+  ;

: io-reg+  ( xdr,len channel bar port len -- xdr,len' )
   >r >r >r                                ( xdr,len channel ) ( r: len port bar )
   native?  if
      r> bar>offset h# 0100.0000 or my-space or en+  0+  0+
      r> drop
   else
      r> drop  h# 8100.0000 my-space or en+  0+  r> en+
   then
   0+  r> en+
;

0 value ctrl-port
: create-reg-property ( -- )
  my-space encode-int 0+ 0+ 0+ 0+		( xdr,len )
  2 0 do
     i channel-ports  to ctrl-port		( xdr,len cmd )
     i  i 2*  rot  8  io-reg+			( xdr,len )
     i  i 2* 1+  ctrl-port  4  io-reg+		( xdr,len )
  loop
  " reg" property
;

create-reg-property

\ Both channels of a chipset controller are normally present
-1 is secondary?

: enable-ide ( on|off -- )
  4 my-w@  1 rot  if  or  else  invert and  then  4 my-w!
;

: map-regs ( -- )
  reg-array @ if  exit  then
  2 0 do
     i channel-ports  reg-array i 2* 1+ na+ !  reg-array i 2* na+ !
  loop
  1 enable-ide
;

: unmap-regs ( -- )
  4 0  do  0 reg-array i na+ !  loop
;
