id: @(#)xwords.fth 1.1 26/10/18
purpose: 64-bit ("x") data words for the 32-bit x86 port
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ OpenBoot's sun4u and sun4v ports have 64-bit cells, and some of the
\ machine-independent code uses the "x" words to handle 64-bit
\ quantities.  On the 32-bit x86 port, an "x" on the stack is a single
\ cell: lxjoin discards the high half and xlsplit returns a zero high
\ half.  In memory, an x occupies 8 bytes, least significant half first,
\ as on any little-endian machine.  The firmware runs in 32-bit protected
\ mode with paging disabled, so all addresses fit in 32 bits.

headers
: lxjoin  ( l.lo l.hi -- x )  drop  ;
: xlsplit  ( x -- l.lo l.hi )  0  ;

: x@  ( adr -- x )  l@  ;
: x!  ( x adr -- )  >r  s>d  r@ la1+ l!  r> l!  ;
: x,  ( x -- )  here /x allot  x!  ;
: xa+  ( adr index -- adr' )  /x* +  ;
: xa1+  ( adr -- adr' )  /x +  ;
: x?  ( adr -- )  x@  u.  ;

: xwsplit  ( x -- w.lo w.2 w.3 w.hi )  xlsplit >r lwsplit r> lwsplit  ;
: wxjoin  ( w.lo w.2 w.3 w.hi -- x )  wljoin  >r wljoin  r> lxjoin   ;
: xbsplit  ( x -- b.lo b.2 b.3 b.4 b.5 b.6 b.7 b.hi )
   xlsplit >r lbsplit r> lbsplit
;
: bxjoin  ( b.lo b.2 b.3 b.4 b.5 b.6 b.7 b.hi -- x )
   bljoin  >r bljoin  r> lxjoin
;
