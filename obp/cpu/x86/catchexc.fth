id: @(#)catchexc.fth 1.1 26/10/18
purpose: Processor exception handling for the x86 firmware
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Copyright 1990-2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The boot stub's interrupt descriptor table vectors the processor
\ exceptions to code that saves the processor state in the save area
\ described in cpu/x86/register.fth and then jumps to the kernel's
\ exception-entry, which runs exception-handler with fresh stacks.

headerless

: exception-save-area  ( -- adr )  exception-state  ;
' exception-save-area is cpu-state

string-array exception-names
( 00 ) ," Divide Error"		," Debug Trap"
( 02 ) ," NMI"			," Breakpoint Trap"
( 04 ) ," Overflow"		," Bound Range Exceeded"
( 06 ) ," Invalid Opcode"	," Device Not Available"
( 08 ) ," Double Fault"		," Coprocessor Segment Overrun"
( 0a ) ," Invalid TSS"		," Segment Not Present"
( 0c ) ," Stack Fault"		," General Protection Fault"
( 0e ) ," Page Fault"		," Reserved Exception"
( 10 ) ," Floating Point Error"	," Alignment Check"
( 12 ) ," Machine Check"	," SIMD Floating Point Exception"
end-string-array

: (.exception)  ( -- )
   %vector d# 20 <  if
      %vector exception-names count type
   else
      ." Exception " %vector .x
   then
;
' (.exception) is .exception

\ Breakpoint and debug traps can be resumed with "go"
: breakpoint-trap?  ( -- flag )  %vector 1 =  %vector 3 =  or  ;

: (exception-handler)  ( -- )
   state-valid on
   breakpoint-trap?  restartable? !
   ??cr .exception  ."  at %eip " %eip .x
   %vector h# 0e =  if  ." address " %cr2 .x  then
   cr
;
' (exception-handler) is handle-breakpoint
' handle-breakpoint is exception-handler

headers
stand-init: Install exception handlers
   init-client-entries
   exception-entry  exception-entry-adr l!
;
