id: @(#)resources.fth 1.1 26/10/19
purpose: The PCI address space available for assignment on a PC
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The generic PCI prober (dev/pci) assigns addresses to the base address
\ registers of devices that are disabled, and keeps the assignments of
\ devices that are enabled (read-bar-resources), since reprogramming an
\ active device isn't safe.  On a PC, coreboot or the BIOS has normally
\ already assigned and enabled everything, so the address space available
\ for new assignments is the PCI window of the chipset minus whatever
\ enabled devices and bridges already decode.  This file finds that
\ space by scanning configuration space before the probe.
\
\ The windows are:
\   memory  from the top of RAM below 4GB (rounded up to 256MB)
\           to fec00000, where the I/O APIC, HPET, local APIC and
\           boot flash begin
\   I/O     from 1000 to ffff; 0-fff is the legacy ISA I/O space
\
\ The free space goes in my-memlist and my-io-list, which master-probe
\ makes the bus's allocation lists (pci-memlist, pci-io-list).
\
\ Like read-bar-resources, the size of a range in use is taken to be the
\ largest power of two that its address is aligned to, which may be too
\ big but never too small, and avoids sizing active BARs.

headerless

h# fec0.0000 constant pci-mem-limit
h#      1000 constant pci-io-base
h#   1.0000  constant pci-io-limit

\ ---- Tables of ranges in use, kept sorted by address

d# 64 constant max-ranges
struct
   /n field >#ranges
   max-ranges 2* /n* field >ranges
constant /range-table

/range-table buffer: mem-in-use
/range-table buffer: io-in-use

0 value cur-table

: range@  ( n table -- adr len )  >ranges swap 2* na+ 2@  ;
: range!  ( adr len n table -- )  >ranges swap 2* na+ 2!  ;

: add-range  ( adr len table -- )
   to cur-table
   over 0= over 0= or  if  2drop exit  then		( adr len )
   cur-table >#ranges @ max-ranges >=  if  2drop exit  then
   \ Insertion sort: move the ranges above adr up by one
   cur-table >#ranges @					( adr len n )
   begin
      dup  if  dup 1- cur-table range@ drop  3 pick u>  else  false  then
   while						( adr len n )
      dup 1- cur-table range@  2 pick cur-table range!	( adr len n )
      1-
   repeat						( adr len n )
   cur-table range!					( )
   1 cur-table >#ranges +!
;

\ The size implied by the alignment of an address
: implied-size  ( adr -- size )  dup negate and  ;

0 value win-list
0 value win-hi
0 value range-end
: u-min  ( u1 u2 -- u )  2dup u> if  swap  then  drop  ;
: u-max  ( u1 u2 -- u )  2dup u< if  swap  then  drop  ;

: free-gap  ( start end -- )
   2dup u<  if  over -  win-list free-memrange  else  2drop  then
;

\ Free the parts of [lo,hi) that are not in use
: free-window  ( lo hi list table -- )
   to cur-table  to win-list  to win-hi		( lo )
   cur-table >#ranges @  0  ?do			( cursor )
      i cur-table range@  over + to range-end	( cursor adr )
      win-hi u-min  over u-max			( cursor start )
      over swap free-gap			( cursor )
      range-end u-max  win-hi u-min		( cursor' )
   loop						( cursor )
   win-hi free-gap
;

\ ---- Scanning configuration space for decoded ranges

0 value scan-cmd	\ Command register of the function being scanned

: note-io   ( adr -- )  dup implied-size io-in-use add-range  ;
: note-mem  ( adr -- )  dup implied-size mem-in-use add-range  ;

\ Record the range decoded by a base address register.  Returns the
\ configuration address of the next one.
: scan-bar  ( phys.hi -- phys.hi' )
   dup cfg-l@					( phys.hi bar )
   dup 1 and  if				( phys.hi bar )
      3 invert and  h# ffff and			( phys.hi port )
      scan-cmd 1 and  if  ?dup if  note-io  then  else  drop  then
      la1+ exit
   then						( phys.hi bar )
   dup 1 >> 3 and 2 =  if			\ 64-bit BAR
      over la1+ cfg-l@  if			\ Above 4GB; not ours
         drop 2 la+ exit
      then
      swap la1+ swap				( phys.hi' bar )
   then
   h# f invert and				( phys.hi adr )
   scan-cmd 2 and  if  ?dup if  note-mem  then  else  drop  then
   la1+
;

: scan-bars  ( phys.hi #bytes -- )
   over + h# 10 + >r  h# 10 +		( phys.hi' )  ( r: end )
   begin  dup r@ u<  while  scan-bar  repeat
   r> 2drop
;

\ The windows of an enabled PCI-to-PCI bridge
0 value bridge-cfg
: scan-bridge-windows  ( phys.hi -- )
   to bridge-cfg
   bridge-cfg h# 1c + cfg-b@ h# f0 and 8 <<	( io-base )
   bridge-cfg h# 1d + cfg-b@ h# f0 and 8 << h# fff +	( io-base io-limit )
   2dup u<  if					( io-base io-limit )
      over - 1+ io-in-use add-range
   else  2drop  then
   h# 20 h# 24  do				\ Memory, prefetchable memory
      bridge-cfg i + cfg-w@ h# fff0 and d# 16 <<	( base )
      bridge-cfg i + 2+ cfg-w@ h# fff0 and d# 16 << h# f.ffff +  ( base limit )
      2dup u<  if
         over - 1+ mem-in-use add-range
      else  2drop  then
   4 +loop
;

\ An expansion ROM address that has been assigned stays reserved even
\ while the ROM's decoder is disabled.
: scan-rom  ( phys.hi -- )
   cfg-l@ h# 7ff invert and  ?dup  if  note-mem  then
;

: scan-function  ( phys.hi -- )
   dup 4 + cfg-w@ 3 and  dup to scan-cmd  0=  if  drop exit  then
   dup h# e + cfg-b@ h# 7f and  case		( phys.hi )
      0 of  dup h# 18 scan-bars  h# 30 + scan-rom  endof	\ BARs 10-27
      1 of  dup 8 scan-bars  dup scan-bridge-windows  h# 38 + scan-rom  endof
      ( default )  nip
   endcase
;

: present?  ( phys.hi -- flag )  cfg-w@ h# ffff <>  ;

: scan-device  ( phys.hi -- )
   dup present?  0=  if  drop exit  then
   dup h# e + cfg-b@ h# 80 and  if  8  else  1  then	( phys.hi #fns )
   0  do
      dup i fcn#>cfg +  dup present?  if  scan-function  else  drop  then
   loop
   drop
;

: scan-config-space  ( -- )
   mem-in-use /range-table erase  io-in-use /range-table erase
   h# 100 0  do
      h# 20 0  do  j bus#>cfg i dev#>cfg + scan-device  loop
   loop
;

\ ---- The top of RAM below 4GB, from the "reg" property of /memory

: top-of-ram  ( -- adr )
   0  " /memory" find-package  0=  if  exit  then	( top phandle )
   " reg" rot get-package-property  if  exit  then	( top adr len )
   begin  dup  while
      decode-int >r decode-int r> +		( top adr' len' end )
      3 roll u-max -rot
   repeat  2drop
;

0 value pci-mem-base
: init-resources  ( -- )
   scan-config-space
   top-of-ram  h# 1000.0000 round-up  to pci-mem-base
   pci-mem-base pci-mem-limit  my-memlist mem-in-use free-window
   pci-io-base pci-io-limit    my-io-list io-in-use  free-window
;

headers
