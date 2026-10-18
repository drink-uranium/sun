id: @(#)fwio.fth 1.1 26/10/18
purpose: Character I/O and other setup for running as firmware
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ When the dictionary runs as firmware, init-io is stand-init-io.  The
\ first piece of the stand-init-io chain (os/bootprom/instmall.fth)
\ installs the heap allocator; this one installs the UART as the console.

headerless

: fw-bye  ( -- )  ." Use reset-all to restart the machine." cr  ;

overload: stand-init-io  ( -- )
   stand-init-io
   init-uart
   install-uart-io
   uart-cr  " OpenBoot x86: console initialized" uart-type  uart-cr
   ['] fw-bye  ['] bye  (is
;
headers
