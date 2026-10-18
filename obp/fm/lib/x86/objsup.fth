id: @(#)objsup.fth 1.1 26/10/18
purpose: Machine-dependent support routines for the objects package (x86)
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ x86 version.
\ Machine dependent support routines used for the objects package.
\ These words know intimate details about the Forth virtual machine
\ implementation.  The code that the SPARC version assembles here is in
\ the kernel (fm/kernel/x86/cpucode.fth).

headerless

: start-code ( -- )  code-cf !csp  ;

\ Assembles the code which begins a ;code clause
: start-;code  ( -- )  start-code  ;

\ Code for executing an object action.  The action's code field is a
\ colon definition code field; the object's apf is on the stack.
: doaction  ( -- )  acf-align colon-cf  ;

\ Returns the address of the code executed by the word whose code field
\ address is acf
: >code-adr  ( acf -- code-adr )  token@  ;

: >action-adr  ( object-acf action# -- )
  ( ... -- object-acf action# #actions true | object-apf action-adr false )
   over token@ /l - l@             ( object-acf action# #actions )
   2dup >=  if  true exit  then    ( object-acf action# #actions )
   drop                            ( object-acf action# )
   over token@ swap /token * -     ( object-acf adr )
   /n - token@                     ( object-acf action-adr )
   swap >body swap false           ( object-apf action-adr false )
;

headers
: action-name  \ name  ( action# -- )
   create  l,   'doaction-name used
;

: >action#  ( apf -- action# )  l@  ;
