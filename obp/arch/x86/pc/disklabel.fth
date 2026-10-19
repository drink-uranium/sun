id: @(#)disklabel.fth 1.1 26/10/19
purpose: Disk label (disk-label) package for PCs: MBR partitions, Sun labels
copyright: Copyright 1990 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The PC version of pkg/boot/sunlabel.fth.  The disk-label package is
\ opened by disk drivers (e.g. dev/ide/ata/disk.fth) with the partition
\ part of the device arguments, and supplies the byte offset of the
\ partition ("offset") and the "load" method used by "boot".
\
\ Arguments:  [partition][,file]
\
\   1 2 3 4   A primary partition in the PC partition table (MBR).
\   a b ... h A partition of a Sun (VTOC) label, as on SPARC.
\   nolabel   The whole disk, without looking at the label.
\   (none)    With an MBR: the active partition, or the first one in use.
\             With a Sun label: partition a.  Otherwise the whole disk.
\
\ "load" reads a boot program from the start of the partition: an ELF
\ executable (an Open Firmware client program or a Multiboot kernel)
\ stored there as is, e.g. with  dd if=kernel.elf of=/dev/sda1.  For a
\ Sun label, it reads the boot block after the label, as on SPARC.

" /packages" find-device
new-device
" disk-label" device-name

headerless
d# 512 constant ublock		\ Logical block size.  Also size of label.
ublock d# 15 *  constant /bootblk \ Size of "bootblk" code stored after label
0 instance value dklabel	\ Label buffer; used temporarily during open
instance variable part-lo	\ Byte offset of the partition
instance variable part-hi
: part-offset!  ( d -- )  part-hi ! part-lo !  ;
: part-offset@  ( -- d )  part-lo @ part-hi @  ;
false instance value sun-label?

: label@  ( offset -- short )  dklabel + w@  ;	\ Sun labels are big-endian
: label-w@  ( offset -- w )  dklabel + dup c@ swap 1+ c@ bwjoin  ;
: label-be-w@  ( offset -- w )  dklabel + dup 1+ c@ swap c@ bwjoin  ;
: label-le-l@  ( offset -- l )
   dklabel +  dup c@  over 1+ c@  2 pick 2+ c@  3 roll 3 + c@  bljoin
;
: label-be-l@  ( offset -- l )
   dklabel +  dup 3 + c@  over 2+ c@  2 pick 1+ c@  3 roll c@  bljoin
;

\ ---- Sun (VTOC) labels

: sun-label-valid?  ( -- flag )
   d# 508 label-be-w@  h# dabe <>  if  false exit  then
   0   dklabel  ublock  bounds  ?do  i w@ xor  /w +loop  ( checksum )
   0=
;
: sun-partition  ( partition# -- )
   8 *  d# 444 +  label-be-l@        ( start-cyl )
   d# 436 label-be-w@  *             ( start-trk )
   d# 438 label-be-w@  *             ( start-block )
   ublock um*  part-offset!
;

\ ---- PC partition tables

: mbr?  ( -- flag )  d# 510 label-w@  h# aa55 =  ;
: mbr-entry  ( n -- offset )  4 lshift  d# 446 +  ;	\ n = 0..3
: entry-used?  ( n -- flag )  mbr-entry 4 + dklabel + c@  0<>  ;
: entry-active?  ( n -- flag )  mbr-entry dklabel + c@  h# 80 =  ;
: default-entry  ( -- n | -1 )
   4 0  do  i entry-used?  i entry-active? and  if  i unloop exit  then  loop
   4 0  do  i entry-used?  if  i unloop exit  then  loop
   -1
;
: mbr-partition  ( n -- ok? )
   dup 0 4 within 0=  if  drop false exit  then
   dup entry-used? 0=  if  drop false exit  then
   mbr-entry 8 + label-le-l@  ublock um*  part-offset!
   true
;

headers
: read   ( len buf -- actual-len )  " read"  $call-parent  ;
: write  ( len buf -- actual-len )  " write" $call-parent  ;
: seek   ( offset-low offset-high -- okay? )  " seek" $call-parent  ;
: offset  ( offset-low offset-high -- offset-low' offset-high' )
   part-offset@ d+
;

headerless
\ Select the partition given by part$ in the label in dklabel
: select-partition  ( part$ -- ok? )
   dup 0=  if                                       \ Default partition
      2drop
      mbr?  if
         default-entry  dup 0<  if  drop true exit  then  mbr-partition exit
      then
      sun-label-valid?  if  true to sun-label?  0 sun-partition  then
      true exit
   then
   drop c@                                          ( char )
   dup ascii 1 ascii 5 within  if
      mbr? 0=  if  drop ." No partition table" cr false exit  then
      ascii 1 - mbr-partition                       ( ok? )
      dup 0=  if  ." No such partition" cr  then  exit
   then
   upc dup ascii A ascii I within  if
      sun-label-valid? 0=  if  drop ." Bad Sun disk label" cr false exit  then
      true to sun-label?
      ascii A - sun-partition  true exit
   then
   drop ." Invalid partition" cr false
;

: open-part  ( file$ part$ -- file$ okay? )
   0 0 part-offset!
   \ The "nolabel" partition maps the entire disk, and does not look at the label
   2dup  " nolabel"  $=  if  2drop true exit  then
   ublock alloc-mem is dklabel				( file$ part$ )
   dklabel 0=  if					( file$ part$ )
      ." Can't allocate memory for disk label"		( file$ part$ )
      2drop false exit					( file$ false )
   then							( file$ part$ )
   0 0 seek drop					( file$ part$ )
   dklabel  ublock  read  ublock <>  if			( file$ part$ )
      ." Can't read disk label." cr  2drop false	( file$ false )
   else							( file$ part$ )
      select-partition					( file$ okay? )
   then							( file$ okay? )
   dklabel ublock free-mem				( file$ okay? )
;

\ The size of the ELF executable at adr, from its program headers
: elf-size  ( adr -- size )
   >r  r@ h# 1c + l@  r@ h# 2c + w@ h# 20 * +         ( size )
   r@ h# 1c + l@  r@ +                                ( size phdr )
   r> h# 2c + w@  0  ?do                              ( size phdr )
      dup 4 + l@  over h# 10 + l@ +  rot max swap     ( size' phdr )
      h# 20 +
   loop  drop
;
: elf32?  ( adr -- flag )
   dup l@ h# 464c.457f =  over 4 + c@ 1 = and  swap 5 + c@ 1 = and
;

headers
: open  ( -- okay? )
   \ Arg string is <part>[,<filespec>]
   my-args  ascii , left-parse-string			( file$ part$ )
   open-part 0=  if  2drop  false exit  then		( file$ )
   ?dup  if
      " ufs-file-system" find-package  if
	interpose
      else
        ." No file system support for " type cr  false exit
      then
   else
      drop
   then
   true
;
: close  ( -- )  ;

: load  ( adr -- size )		\ Pass in load-base
   sun-label?  if
      ublock 0 seek  drop			( adr )
      ublock d# 15 *  tuck  read		( len actual-len )
      tuck <>  if  ." Short disk read" cr   then  ( actual-len )
      exit
   then
   0 0 seek drop				( adr )
   dup ublock 8 * read  ublock 8 * <>  if
      drop ." Can't read the boot program" cr  0 exit
   then						( adr )
   dup elf32?  0=  if
      drop ." No ELF boot program in the partition" cr  0 exit
   then
   dup elf-size  ublock round-up  >r		( adr )  ( r: size )
   0 0 seek drop  r@ read				( actual )
   r> tuck <>  if  ." Short disk read" cr  then	( size )
;
: size ( -- d.size )  /bootblk s>d  ;

finish-device
device-end
