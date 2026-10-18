id: @(#)ctrace.fth 1.1 26/10/18
purpose: C stack backtrace (x86)
copyright: Copyright 1990-2004 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ After a crash, displays a backtrace of C stack frames.
\ This assumes the usual i386 frame layout, with %ebp chaining the frames:
\    0(%ebp)  caller's %ebp
\    4(%ebp)  return address

only forth also hidden also forth definitions

headerless
defer .subname  ( adr -- )
' .x is .subname

: .c-frame  ( frame -- frame' exit? )
   dup pointer-bad?  if  drop 0 true exit  then
   dup la1+ l@  ."    called from "  .subname  cr   ( frame )
   l@  exit?
;

headers
: ctrace  ( -- )   \ C stack backtrace
   state-valid @  0=  if   ." No saved state"  exit  then
   ." PC: "  %eip .subname cr
   %ebp  begin  .c-frame  over 0=  or  until  drop
;
