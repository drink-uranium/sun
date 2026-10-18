id: @(#)uart.fth 1.1 26/10/18
purpose: Polled 16550 UART driver for the console of last resort (COM1)
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ This driver is used for diagnostic output early in the startup sequence
\ and as the fallback console (os/stand/sysuart.fth).  The ttya device node
\ uses the regular serial driver.

headerless
h# 3f8 value uart-base

: uart@  ( reg# -- byte )  uart-base +  pc@  ;
: uart!  ( byte reg# -- )  uart-base +  pc!  ;

d# 115200 value uart-baud

: init-uart  ( -- )
   0 1 uart!				\ No interrupts
   h# 80 3 uart!			\ Divisor latch access
   d# 115200 uart-baud /  wbsplit	( low high )
   1 uart!  0 uart!
   3 3 uart!				\ 8 data bits, no parity, 1 stop bit
   h# c7 2 uart!			\ Enable and clear the FIFOs
   h# 0b 4 uart!			\ DTR, RTS, OUT2
;

: ukey?  ( -- flag )  5 uart@  1 and  0<>  ;
: ukey  ( -- char )  begin  ukey?  until  0 uart@  ;
: uemit  ( char -- )  begin  5 uart@ h# 20 and  until  0 uart!  ;

\ Diagnostic output that does not depend on the console
: uart-emit  ( char -- )  uemit  ;
: uart-type  ( adr len -- )  bounds  ?do  i c@ uemit  loop  ;
: uart-cr  ( -- )  carret uemit  linefeed uemit  ;
headers
