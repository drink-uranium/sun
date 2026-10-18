id: @(#)startup.fth 1.1 26/10/18
purpose: The latter part of the PC firmware initialization sequence
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

headers
: startup  ( -- )
   hex
   warning on
   only forth also definitions
   startup-hook
   #line off
   ." OpenBoot x86" cr
;
