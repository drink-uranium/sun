id: @(#)reset.fth 1.1 26/10/19
purpose: Resetting a PC: reset-all and the reboot information
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ reset-all resets the machine with the reset control register of the
\ chipset (I/O port cf9, present on Intel chipsets and their successors
\ and on most others), falling back to the keyboard controller's reset
\ line.  The boot command for a reboot ("boot" after a program has run,
\ or the client interface "boot" service) is kept in the reboot-info
\ configuration variable (pkg/confvar/definitions/reboot.fth), which
\ survives a warm reset (see nvram.fth).

headerless

: cf9-reset  ( -- )
   h# cf9 pc@ h# f1 and  dup 2 or  h# cf9 pc!	\ System reset, not CPU only
   h# 4 or  h# cf9 pc!				\ Reset
   d# 100 ms
;

: kbc-reset  ( -- )
   d# 100 0  do  h# 64 pc@ 2 and 0=  ?leave  1 ms  loop	\ Input buffer empty
   h# fe h# 64 pc!					\ Pulse the reset line
   d# 100 ms
;

: pc-reset-all  ( -- )
   cli
   cf9-reset
   kbc-reset
   ." Reset failed" cr
   begin  hlt  again
;
' pc-reset-all is reset-all

\ The reboot information is valid if the variable holds a boot command
stand-init: Reboot information
   get-reboot-info 2drop nip 0<> to reboot?
;

headers
