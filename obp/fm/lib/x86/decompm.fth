id: @(#)decompm.fth 1.1 26/10/18
purpose: Machine-dependent definitions for the decompiler (x86)
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ Machine/implementation-dependent definitions
decimal
headerless

only forth also hidden also  definitions
: dictionary-base  ( -- adr )  origin  ;

: ram/rom-in-dictionary?  ( adr -- flag )
   dup  #talign 1-  and  0=  if
      dup  lo-segment-base lo-segment-limit  within
      swap hi-segment-base hi-segment-limit  within  or
   else
      drop false
   then
;

' ram/rom-in-dictionary? is in-dictionary?

\ True if adr is a reasonable value for the interpreter pointer
: reasonable-ip?  ( adr -- flag )
   dup  in-dictionary?  if  ( ip )
      #talign 1- and 0=  \ must be token-aligned
   else
      drop false
   then
;

headerless0
only forth also definitions
headers
