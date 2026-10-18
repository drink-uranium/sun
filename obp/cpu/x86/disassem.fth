id: @(#)disassem.fth 1.1 26/10/18
purpose: x86 disassembler framework
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The interface is the same as that of the SPARC disassembler
\ (cpu/sparc/disforw.fth):  dis ( adr -- ), +dis, dis1, pc, udis. .
\ Instructions that are not decoded are shown as bytes.

headers
vocabulary disassembler
also disassembler also definitions

decimal
variable end-found
variable display-offset  0 display-offset !
variable branch-target		\ Help for tracing/single-stepping
variable start-column

headers
variable pc
: pc@ ( -- adr ) pc @ ;
: pc! ( adr -- ) pc ! ;
: (inst@ ( adr -- byte )   c@  ;
defer inst@  ' (inst@  is  inst@

headerless
: 4u# ( n -- n' )     u# u# u# u#        ;
: 4u#. ( n -- n' )    4u#  ascii . hold  ;

headers
defer showaddr  ( addr -- )
: udis. ( n -- )  <#  4u#.  4u#  u#>  type  ;
' udis.  is showaddr

headerless
: +offset  ( adr -- adr' )  display-offset @  -  ;
: next-byte  ( -- byte )  pc@ inst@  pc@ 1+ pc!  ;
: .byte  ( byte -- )  <# u# u# u#> type space  ;

\ Decode one instruction; unknown instructions are shown as a byte
: disasm  ( -- )
   next-byte  dup h# c3 =  if  drop ." ret"  end-found on  exit  then
   ." db " .byte
;

: (dis1)  ( -- )
   ??cr
   pc@ +offset  showaddr  4 spaces  #out @  start-column !
   disasm  cr
;
: +(dis)  ( -- )
   push-hex
   end-found off
   begin   (dis1)  end-found @  exit? or  until
   pop-base
;
: (dis)  ( adr -- )  pc!  +(dis)  ;

headers
forth definitions
alias disasm disasm
: dis1  ( -- )  ['] (inst@ is inst@  (dis1)  ;
: +dis  ( -- )  ['] (inst@ is inst@  +(dis)  ;
: dis  ( adr -- )  ['] (inst@ is inst@  (dis)  ;

headerless
alias (dis dis
headers

previous previous definitions
