id: @(#)fb8-ops.fth 1.1 26/10/18
purpose: fb8 package support routines (x86)
copyright: Copyright 1990 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The same interfaces as pkg/termemu/sparc/fb8-ops.fth, in Forth.

headerless
decimal

\ Cursor toggle: exchange the foreground and background colors
0 value inv-fg   0 value inv-bg   0 value inv-bpl   0 value inv-width
: cfb8-invert  ( adr width height bytes/line fg-color bg-color -- )
   to inv-bg  to inv-fg  to inv-bpl  swap to inv-width   ( adr height )
   0  ?do                             ( adr )
      dup inv-width bounds  ?do
         i c@ inv-fg =  if
            inv-bg i c!
         else
            i c@ inv-bg =  if  inv-fg i c!  then
         then
      loop
      inv-bpl +
   loop
   drop
;
defer fb8-invert  ' cfb8-invert is fb8-invert

\ Draws a character from a 1-bit-deep font into an 8-bit-deep frame buffer
\ The font rows are fontbytes bytes, most significant bit first.
0 value fg-pixel   0 value bg-pixel   0 value font-width
: cfb8-paint
   ( fontadr fontbytes width height screenadr bytes/line fg-color bg-color -- )
   to bg-pixel  to fg-pixel           ( fontadr fontbytes width height scr bpl )
   2swap swap to font-width           ( fontadr fontbytes scr bpl height )
   0  ?do                             ( fontadr fontbytes scr bpl )
      3 pick  font-width 0  ?do       ( fontadr fontbytes scr bpl fontadr )
         dup i 3 >> + c@              ( ... byte )
         h# 80  i 7 and >>  and  if  fg-pixel  else  bg-pixel  then
         3 pick i + c!
      loop  drop                      ( fontadr fontbytes scr bpl )
      tuck + swap                     ( fontadr fontbytes scr' bpl )
      2swap tuck + swap 2swap         ( fontadr' fontbytes scr' bpl )
   loop
   2drop 2drop
;
defer fb8-paint   ' cfb8-paint  is fb8-paint

\ Window move, for scrolling.  Moves #move/line out of every bytes/line
\ bytes; src and dst are separated by n*bytes/line, and src > dst.
4 constant fbalign
: cfb8-window-move  ( src-start dst-start size bytes/line #move/line -- )
   to inv-width  to inv-bpl           ( src dst size )
   0  ?do                             ( src dst )
      over i +  over i +  inv-width move
   inv-bpl +loop
   2drop
;
defer fb8-window-move  ' cfb8-window-move  is fb8-window-move
