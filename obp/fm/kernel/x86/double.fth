id: @(#)double.fth 1.1 26/10/18
purpose: x86 double-number primitives
copyright: Copyright 2003-2004 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 1985-1994 Bradley Forthware
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The low cell is compiled first, the high cell second
code (dlit) ( -- d )
   lodsl
   push %eax
   lodsl
   push %eax
c;

\ Double-precision arithmetic
code dnegate  ( d# -- d#' )
   negl 4(%esp)
   adcl $0,(%esp)
   negl (%esp)
c;

code dabs  ( dbl.lo dbl.hi -- dbl.lo' dbl.hi' )
   testl $0x80000000,(%esp)
   jz 1f
   negl 4(%esp)
   adcl $0,(%esp)
   negl (%esp)
1:
c;

code d+  ( x1 x2 -- x3 )
   pop %eax			\ x2.hi
   pop %ecx			\ x2.lo
   add %ecx,4(%esp)
   adc %eax,(%esp)
c;

code d-  ( x1 x2 -- x3 )
   pop %eax			\ x2.hi
   pop %ecx			\ x2.lo
   sub %ecx,4(%esp)
   sbb %eax,(%esp)
c;
