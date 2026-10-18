id: @(#)restart.fth 1.1 26/10/18
purpose: Resuming client programs (x86)
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Copyright 1990-2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ go resumes the program whose state is in the CPU state save area.  The
\ SPARC ports get go from the breakpoint package (fm/lib/breakpt.fth).

headers
chain: go-chain
   \ Put stuff to do before returning to a client in this chain.
;
defer go-hook ' go-chain is go-hook

defer restart  ( -- )
: (restart)  ( -- )  cpu-state (go)  ;
' (restart) is restart

headerless
false value in-enter?		\ True while the "enter" service runs

headers
: go  ( -- )
   in-enter?  if  true to exit-interact?  exit  then
   restartable? @  0= abort" No program is active."
   go-hook
   client-starting-chain
   restart
;

defer reclaim-machine  ' noop is reclaim-machine
