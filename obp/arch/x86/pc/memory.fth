id: @(#)memory.fth 1.1 26/10/18
purpose: Physical memory: detection, /memory node, claim and release
copyright: Copyright 1994-2003 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The physical memory allocator is the machine-independent one
\ (os/bootprom/allocph.fth), which creates the /memory node.  This file
\ supplies what the SPARC ports get from their MMU code and memory probe:
\
\  - the client interface "claim" and "release" services and the
\    mem-claim/mem-release interfaces (os/bootprom/clntmem.fth on SPARC),
\    simplified because virtual addresses equal physical addresses;
\  - the list of installed memory, from the Multiboot information, the
\    coreboot tables, or the CMOS memory size registers;
\  - the "reg" and "available" properties of /memory.

fload ${BP}/os/bootprom/memlist.fth     \ Resource list common routines

headerless
variable memory-node
variable mmu-node
headers
' memory-node  " memory" chosen-variable
' mmu-node     " mmu"    chosen-variable

headerless
: mem-claim  ( [ phys.lo phys.hi ] size align -- base.lo base.hi )
   " claim" memory-node @ $call-method
;
: mem-release  ( phys.lo phys.hi size -- )
   " release" memory-node @ $call-method
;
-1 constant mem-mode

headers
\ The client interface memory services.  With identity translation, the
\ virtual address of a claimed region is its physical address.
cif: claim  ( align size virt -- base )
   rot ?dup  if                 ( size virt align )
      nip mem-claim drop        ( base )
   else                         ( size virt )
      swap >r 0 r> 0 mem-claim  ( base.lo base.hi )
      drop                      ( base )
   then
;
cif: release  ( size virt -- )  0 rot mem-release  ;

headerless
also client-services
alias cif-release release
alias cif-claim   claim
previous

: allocate-aligned  ( alignment size virthint -- virtual )
   ?dup  if  nip 0 rot 0  else  swap  then   ( [ phys.lo phys.hi ] size align )
   ['] mem-claim catch  if  2drop 2drop 0  else  drop  then
;

headers
fload ${BP}/os/bootprom/allocph.fth	\ S Physical memory allocator

\ ---- Detecting the installed memory

headerless
d# 32 constant max-ram-ranges
create ram-ranges  max-ram-ranges 2* /n* allot
variable #ram-ranges

: ram-range  ( n -- base len )  2* ram-ranges swap na+ 2@ swap  ;

\ Record a range of RAM.  Memory above 4GB is not usable by the 32-bit
\ firmware and is not reported.
: add-ram  ( base.lo base.hi len.lo len.hi -- )
   rot  if  2drop drop exit  then          ( base len.lo len.hi )
   if  drop -1  then                       ( base len )   \ Clip to 4GB
   over negate  ?dup  if  umin  then       ( base len' )
   dup 0=  if  2drop exit  then
   #ram-ranges @ max-ram-ranges >=  if  2drop exit  then
   swap  #ram-ranges @ 2* ram-ranges swap na+ 2!   \ Stores len, base
   1 #ram-ranges +!
;

\ Multiboot information structure
: mb-flags  ( -- n )  boot-info-adr l@  ;
: mb-memory-map?  ( -- found? )
   mb-flags h# 40 and  0=  if  false exit  then
   boot-info-adr d# 48 + l@  boot-info-adr d# 44 + l@   ( adr len )
   bounds  ?do                             ( )
      i d# 20 + l@ 1 =  if                 \ Type 1 is available RAM
         i 4 + l@  i 8 + l@  i d# 12 + l@  i d# 16 + l@  add-ram
      then
   i l@ la1+ +loop
   #ram-ranges @ 0<>
;
: mb-memory?  ( -- found? )
   mb-flags 1 and  0=  if  false exit  then
   0 0  boot-info-adr 4 + l@ d# 1024 *  0  add-ram     \ Below 640K
   1meg 0  boot-info-adr 8 + l@ d# 1024 *  0  add-ram  \ Above 1MB
   true
;

\ coreboot tables
h# 4f49.424c constant lbio-signature	\ "LBIO"
: lbio-at?  ( adr -- flag )  l@ lbio-signature =  ;
: find-lbio-in  ( start end -- adr true | false )
   swap  ?do  i lbio-at?  if  i true unloop exit  then  h# 10 +loop  false
;
: find-lbio  ( -- adr true | false )
   0 h# 1000 find-lbio-in  if  true exit  then
   h# f.0000 h# 10.0000 find-lbio-in
;
: cb-table  ( header -- table len #entries )
   dup dup 4 + l@ +  over d# 12 + l@  rot d# 20 + l@
;
: cb-memory-records  ( record -- )
   dup la1+ l@ 8 -  swap 8 +  swap        ( adr len )
   bounds  ?do                            ( )
      i d# 16 + l@ 1 =  if                \ CB_MEM_RAM
         i l@  i 4 + l@  i 8 + l@  i d# 12 + l@  add-ram
      then
   d# 20 +loop
;
: cb-scan  ( header -- forward-header | 0 )
   cb-table nip  0  ?do                   ( record )
      dup l@ 1 =  if  dup cb-memory-records  then     \ CB_TAG_MEMORY
      dup l@ h# 11 =  if                  \ CB_TAG_FORWARD
         8 + l@  dup lbio-at?  if  unloop exit  then
         drop 0 unloop exit
      then
      dup la1+ l@ +
   loop                                   ( record )
   drop 0
;
: cb-memory?  ( -- found? )
   find-lbio  0=  if  false exit  then    ( header )
   begin  cb-scan  ?dup 0=  until
   #ram-ranges @ 0<>
;

\ CMOS memory size registers, as set by the BIOS or by QEMU
: cmos@  ( reg -- byte )  h# 70 pc!  h# 71 pc@  ;
: cmos-memory  ( -- )
   0 0  d# 640 d# 1024 *  0  add-ram
   h# 34 cmos@  h# 35 cmos@ bwjoin  ?dup  if        \ 64K blocks above 16MB
      1meg 0  d# 15 1meg * 0  add-ram
      d# 16 1meg * 0  rot h# 10000 * 0  add-ram
   else
      1meg 0  h# 30 cmos@ h# 31 cmos@ bwjoin d# 1024 * 0  add-ram
   then
;

: probe-memory  ( -- )
   #ram-ranges off
   multiboot?  if
      mb-memory-map?  if  exit  then
      mb-memory?  if  exit  then
   then
   cb-memory?  if  exit  then
   cmos-memory
;

headers
: total-ram  ( -- bytes )
   0  #ram-ranges @  0  ?do  i ram-range nip +  loop
;
headerless

\ The firmware's own memory: the boot stub, the dictionary, the stacks,
\ the user area and the heap.
: fw-memory  ( -- adr len )  stub-base  initial-mem-end /fw-heap +  over -  ;

: claim-range  ( adr len -- )
   >r 0 r> 0 ['] mem-claim catch  if  2drop 2drop  else  2drop  then
;

headers
" /memory" find-device
   \ Total installed memory, as phys.lo phys.hi
   : size  ( -- size.lo size.hi )  total-ram 0  ;

   headerless
   : encode-ram-ranges  ( -- adr len )
      0 0 encode-bytes
      #ram-ranges @  0  ?do
         i ram-range  >r encode-int encode+  r> encode-int encode+
      loop
   ;
   : avail-node  ( adr len node -- adr len' false )
      node-range pages>phys-adr,len   ( adr len lo hi size )
      nip >r encode-int encode+  r> encode-int encode+  false
   ;
   : set-available  ( -- )
      here 0  physavail ['] avail-node find-node 2drop  " available" property
   ;

   \ Make the memory known to the physical memory allocator, then remove
   \ the memory that the firmware uses and the first page (the real-mode
   \ interrupt vectors and BIOS data area) from the available list.
   headers
   : init-memory  ( -- )
      probe-memory
      encode-ram-ranges " reg" property
      #ram-ranges @  0  ?do
         i ram-range  0 swap  init-phys-mem
      loop
      0 pagesize claim-range
      fw-memory  claim-range
      set-available
   ;
device-end

stand-init: Probing memory
   " init-memory" memory-node @ $call-method
;
headers
