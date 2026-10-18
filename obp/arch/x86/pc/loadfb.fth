id: @(#)loadfb.fth 1.1 26/10/18
purpose: Load file for terminal emulator and framebuffer packages (x86)
copyright: Copyright 1990-2000 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The same as pkg/termemu/loadfb.fth, with the x86 raster operations and
\ the Gallant font built in.

decimal

fload ${BP}/pkg/termemu/datatype.fth
fload ${BP}/pkg/termemu/fontdi.fth

headers
dev /packages
   new-device
      " terminal-emulator" device-name
      0 0  encode-bytes  " iso6429-1983-colors"  property

      fload ${BP}/pkg/termemu/framebuf.fth \ Variables used by most framebuffers
      fload ${BP}/pkg/termemu/font.fth	    \ Character font
      fload ${BP}/pkg/termemu/fwritstr.fth  \ ANSI terminal emulator
   finish-device
device-end

defer fb-move  ' move  is fb-move
defer fb-fill  ' fill  is fb-fill

fload ${BP}/pkg/termemu/x86/fb8-ops.fth     \ 8-bit raster ops
fload ${BP}/pkg/termemu/fb8.fth	            \ Generic 8-bit raster ops

headers
fload ${BP}/pkg/termemu/install.fth	\ Install terminal emulator
fload ${BP}/pkg/fcode/fb-fcodes.fth

\ The Gallant font is written as a "label" containing big-endian longwords,
\ assembled by the SPARC assembler.  Here it is compiled as data.
transient
vocabulary font-data
also font-data definitions
: label  ( "name" -- )  create  ;
: l,  ( l -- )  be-l,  ;
: end-code  ( -- )  ;
previous definitions
resident
also font-data
fload ${BP}/pkg/termemu/gallant.fth
previous
