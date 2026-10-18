id: @(#)ftrace.fth 1.1 26/10/18
purpose: Display a Forth stack backtrace (x86)
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ Display a Forth stack backtrace
only forth also hidden also  forth definitions

: ftrace  ( -- )   \ Forth stack
   %ip >saved .traceline
   %rp >saved  rssave-end swap  (rstrace
;

only forth also definitions
