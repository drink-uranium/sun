id: @(#)ramdisk.fth 1.1 26/10/18
purpose: Boot device for images passed as Multiboot modules
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ When the firmware is started by a Multiboot loader with modules (e.g.
\ "qemu -kernel openboot.elf -initrd client.elf"), the first module is
\ available as the device /ramdisk, so that it can be booted with
\ "boot ramdisk".

headerless
0 value ramdisk-base
0 value ramdisk-size

: find-multiboot-module  ( -- )
   multiboot?  0=  if  exit  then
   boot-info-adr l@  8 and  0=  if  exit  then	\ No modules
   boot-info-adr d# 20 + l@  0=  if  exit  then	\ mods_count
   boot-info-adr d# 24 + l@			( module )
   dup l@ to ramdisk-base
   dup la1+ l@  ramdisk-base -  to ramdisk-size
   drop
;

headers
root-device
new-device
   " ramdisk" device-name
   " block" device-type

   headerless
   0 instance value position

   headers
   : open  ( -- ok? )  0 to position  ramdisk-size 0<>  ;
   : close  ( -- )  ;
   : size  ( -- d.size )  ramdisk-size 0  ;
   : seek  ( d.offset -- error? )
      drop  dup ramdisk-size u>  if  drop true exit  then
      to position  false
   ;
   : read  ( adr len -- actual )
      ramdisk-size position - min  0 max     ( adr len' )
      ramdisk-base position +  -rot          ( src adr len' )
      dup >r move  r>                        ( len' )
      dup position + to position
   ;
   : load  ( adr -- size )
      ramdisk-base swap ramdisk-size move  ramdisk-size
   ;
finish-device
device-end

stand-init: Multiboot modules
   find-multiboot-module
   " ramdisk" " /ramdisk" $devalias
;
