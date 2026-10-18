id: @(#)cpustate.fth 1.1 26/10/18
purpose: Buffers for saving program state (x86)
copyright: Copyright 1990 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ cpustate.fth 2.9 94/08/25
\ Copyright 1985-1990 Bradley Forthware

headers
\ Data structures defining the CPU state saved by a breakpoint trap.
\ This must be loaded before either catchexc.fth or register.fth,
\ and is the complete interface between those 2 modules.

\ Offset into the register save array of the window register save area.
\ During compilation, we use this as an allocation pointer for the
\ global register save area, and then when we're finished allocating
\ global registers, it's final value will be the offset to the the
\ window register save area.
headerless
0 value window-registers

headers
\ A place to save the CPU registers when we take a trap
defer cpu-state ( -- adr ) ' 0 to cpu-state \ Pointer to CPU state save area

\ Compile-time allocator for saved register space
transient
: allocate-reg  ( -- offset )
   window-registers  dup na1+  to window-registers
;
resident

headerless
: >state  ( offset -- adr )  cpu-state  +  ;

h# 40 constant ua-size

0 value pssave		\ A place to save the Forth data stack
0 value rssave		\ A place to save the Forth return stack

headers
defer .exception	\ Display the exception type
defer handle-breakpoint	\ What to do after saving the state
0 constant #windows	\ The x86 has no register windows
