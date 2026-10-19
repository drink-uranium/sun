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

\ Machines without a serial port (most laptops) read ff from the
\ registers, which looks like a UART that always has input.  The UART is
\ there if its scratch register holds what is written to it.
false value uart-present?
: probe-uart  ( -- )
   h# 5a 7 uart!  7 uart@ h# 5a =  h# a5 7 uart!  7 uart@ h# a5 =  and
   to uart-present?
;

: init-uart  ( -- )
   probe-uart  uart-present? 0=  if  exit  then
   0 1 uart!				\ No interrupts
   h# 80 3 uart!			\ Divisor latch access
   d# 115200 uart-baud /  wbsplit	( low high )
   1 uart!  0 uart!
   3 3 uart!				\ 8 data bits, no parity, 1 stop bit
   h# c7 2 uart!			\ Enable and clear the FIFOs
   h# 0b 4 uart!			\ DTR, RTS, OUT2
;

: ukey?  ( -- flag )  uart-present?  if  5 uart@  1 and  0<>  else  false  then  ;
: ukey  ( -- char )  begin  ukey?  until  0 uart@  ;
: uemit  ( char -- )
   uart-present?  if  begin  5 uart@ h# 20 and  until  0 uart!  else  drop  then
;

\ Diagnostic output that does not depend on the console
: uart-emit  ( char -- )  uemit  ;
: uart-type  ( adr len -- )  bounds  ?do  i c@ uemit  loop  ;
: uart-cr  ( -- )  carret uemit  linefeed uemit  ;
headers
