id: @(#)field.fth 1.1 26/10/18
purpose: x86 structure field defining word
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ field creates words which add their offset within the structure
\ to the base address of the structure

: struct  ( -- 0 )  0  ;

: field  \ name  ( offset size -- offset+size )
   create over l, +
\  does> l@ + ;
   ;code  ( struct-adr -- field-adr )
   mov 4(%eax),%ecx		\ Get the offset
   add %ecx,(%esp)		\ Return the structure member address
c;
