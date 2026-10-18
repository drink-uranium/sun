id: @(#)nvram.fth 1.1 26/10/18
purpose: Configuration variable storage device for PCs
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The configuration variable manager (pkg/confvar) keeps the variables in
\ the device whose device_type is "nvram".  The device has three
\ partitions, selected by the open arguments, with the same layout as the
\ sun4v NVRAM (dev/sun4v-devices/nvram/methods.fth):
\
\   "fixed"   fixed-format variables (diag-switch?, security settings)
\   ""        the variable-format variables, nvramrc and aliases
\   "keys"    the security key store
\
\ PCs have no NVRAM of the required size; the contents are kept in RAM, so
\ settings made with setenv last until the machine is reset.  A platform
\ with suitable persistent storage can save and restore nvram-image.

headerless
h#    0           constant  nvram-fixbase
h#   40           constant  nvram-fixsize
nvram-fixbase nvram-fixsize + constant  nvram-nvbase
h# 16c0           constant  nvram-nvsize
nvram-nvbase nvram-nvsize +   constant  nvram-keybase
h# 100            constant  nvram-keysize
nvram-keybase nvram-keysize +  constant  /nvram-image

/nvram-image buffer: nvram-image

headers
root-device
new-device
   " nvram" device-name

   headerless
   0  instance value basepos		\ Absolute offset of this partition
   0  instance value filepos		\ Current position in partition
   0  instance value psize		\ Partition size

   : clip-range ( len -- len' )  psize filepos - min  0 max  ;
   : range-bad? ( offset -- offset flag )  dup 0 psize within  invert  ;
   : >image  ( -- adr )  nvram-image basepos + filepos +  ;

   : $=  ( adr,len adr2,len -- same? )
      rot tuck <> if  3drop false exit  then  comp 0=
   ;

   headers
   : read  ( buf len -- len' )
      clip-range  >image rot  2 pick move  ( len' )
      dup filepos + to filepos
   ;
   : write  ( buf len -- len' )
      clip-range  >image swap  dup >r move  r>
      dup filepos + to filepos
   ;
   : open  ( -- true )
      nvram-nvbase nvram-nvsize
      my-args " keys"  $= if 2drop nvram-keybase nvram-keysize then
      my-args " fixed" $= if 2drop nvram-fixbase nvram-fixsize then
      to psize  to basepos
      0 to filepos
      true
   ;
   : close  ( -- )  ;
   : seek  ( lo hi -- error )
      drop  dup 0<  if  psize +  then
      range-bad? tuck if  drop  else  to filepos  then
   ;
   : size  ( -- n )  psize filepos -  ;
   : sync  ( -- )  ;

   " nvram" device-type
finish-device
device-end
