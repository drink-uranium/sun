id: @(#)startup.fth 1.1 26/10/18
purpose: The latter part of the PC firmware initialization sequence
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ Modeled on arch/sun4u/startup.fth

headers
alias  cd  dev

\ probe-all probes the expansion buses; the PC bus support adds itself
\ to the chain.
chain: probe-all  ( -- )  ;

headerless
variable banner-done?  banner-done? off

\ Service brk char only if diag-switch?=true or OBP banner is up
: (startup-abort)  ( -- )
   diagnostic-mode? banner-done? @ or  if
     (user-abort)
   then
;
' (startup-abort) is user-abort

stand-init: Executing NVRAMRC
   execute-nvramrc
   auto-banner?  if
      probe-all install-console
      ?banner
   then
   banner-done? on
;

headerless
\ Be carefull, this chain is supposed to return a flag!
chain: don't-boot?  ( flag -- flag' )  ;

defer pre-boot-hook  ' noop is pre-boot-hook

headers
: startup  ( -- )
   hex
   warning on
   only forth also definitions

   startup-hook

   #line off

   check-machine-chain ?cr

   false to init-incomplete?		\ OK to [try to] boot

   pre-boot-hook
   auto-boot
;
