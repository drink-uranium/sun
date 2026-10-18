id: @(#)serial.fth 1.1 26/10/18
purpose: The PC serial ports (16550 UARTs at the standard I/O addresses)
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The serial port package is the same as the one in
\ dev/southbridge/isa-devices/serial/serial.tok, compiled into the
\ firmware instead of tokenized, with the I/O port version of the 16550
\ access routines.

headerless
create serial-console$  8 allot

headers
" ttya" serial-console$ place
0 0 " 0,3f8" " /isa" begin-package
   fload ${BP}/arch/x86/pc/serialpkg.fth
end-package

" ttyb" serial-console$ place
0 0 " 0,2f8" " /isa" begin-package
   fload ${BP}/arch/x86/pc/serialpkg.fth
end-package

stand-init: Serial port aliases
   " ttya" " /isa/serial@0,3f8" $devalias
   " ttyb" " /isa/serial@0,2f8" $devalias
;
