id: @(#)register.fth 1.1 26/10/18
purpose: Display and modify the saved state of the machine (x86)
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Copyright 2000-2002 Sun Microsystems, Inc. All rights reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ This version uses multiple-code-field defining words for the self-fetching
\ register names.
\
\ Display and modify the saved state of the machine.
\
\ This code is highly machine-dependent.
\
\ Version for the x86 processor (32-bit protected mode)
\
\ Requires:
\
\ >state  ( offset -- addr )
\	Returns an address within the processor state array given the
\	offset into that array
\
\ Defines:
\
\ %eax %ebx %ecx %edx %esi %edi %ebp %esp %eip %eflags
\ %cs %ds %es %fs %gs %ss %error-code %cr2
\ .registers

needs action: objects.fth

decimal

only forth hidden also forth also definitions

3 actions
action:  @ >state @  ;
action:  @ >state !  ; ( is )
action:  @ >state    ; ( addr )
transient
: global-reg  \ name  ( offset -- offset+/n )
   create  allocate-reg ,
   use-actions
;
: global-regs  \ name name ... ( offset #regs -- offset' )
   ( offset #regs )  0  ?do  global-reg  loop  ( offset' )
;
: offset-of  \ name  ( -- offset )
   parse-word ['] forth $vfind  if
      >body @ 1
   else
      ." offset-of can't find " type  cr
      where
   then
   do-literal
; immediate
resident

\ The order of these registers matches the save area layout used by the
\ exception handler (see the x86 catchexc.fth): the general registers are
\ in "pushad" order, followed by the values pushed by the processor.

8 global-regs %edi  %esi  %ebp  %esp  %ebx  %edx  %ecx  %eax
6 global-regs %ds  %es  %fs  %gs  %ss  %cr2
4 global-regs %vector  %error-code  %eip  %cs
global-reg %eflags

\ The Forth virtual machine registers
alias %ip %esi
alias %up %edi
alias %rp %ebp
alias %sp %esp

2 global-regs %state-valid  %restartable?
\ Following words defined here to satisfy the
\ references to these "variables" anywhere else
: state-valid   ( -- addr )  addr %state-valid   ;
: restartable?  ( -- addr )  addr %restartable?  ;

[ifdef] firmware
3 global-regs %saved-my-self  last-trap#  error-reset-trap

\ Following words defined here to satisfy the
\ references to these "variables" anywhere else
: saved-my-self ( -- addr )  addr %saved-my-self  ;
[then]

false value standalone?	\ Can be used to turn off stuff in stand.exe
headerless

: aligned?  ( adr -- flag )  3 and 0=  ;
defer accessible?   ( adr -- flag )
: yes-accessible  ( adr -- true )  drop true  ;
' yes-accessible is accessible?

\ Invalid, unaligned, or inaccessible call point
: pointer-bad?  ( adr -- flag )   \ True if the address is not a good pointer
   dup 0<>   over aligned? and  swap accessible? and  0=
;

headers

headerless
defer .other-regs  ' noop is .other-regs
headers
: .registers ( -- )
   ??cr
."          EAX      EBX      ECX      EDX      ESI      EDI      EBP      ESP" cr
."     "  %eax .nx %ebx .nx %ecx .nx %edx .nx %esi .nx %edi .nx %ebp .nx %esp .nx
   cr
."          EIP   EFLAGS       CS       DS       ES       SS   Vector    Error" cr
."     "  %eip .nx %eflags .nx %cs .nx %ds .nx %es .nx %ss .nx
   %vector .nx  %error-code .nx  cr
.other-regs
;

\ There are no register windows on the x86
: .locals  ( -- )  ;
: init-window  ( -- )  ;
: w  ( n -- )  drop  ;
: .window  ( window# -- )  drop  ;
