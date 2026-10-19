id: @(#)loadutil.fth 1.1 26/10/19
purpose: Load file for the hosted x86 Forth tools dictionary (forth.dic)
copyright: Copyright 1994-2003 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The x86 counterpart of os/sun/sparc/loadutil.fth.  It is loaded by
\ arch/x86/preload.fth, which has already loaded the transient-space,
\ headerless and conditional-compilation tools, and builds the Forth that
\ runs under the Unix wrapper program and is used to run the tokenizer.

warning off
only forth also definitions
decimal

true value command-completion?

fload ${BP}/fm/lib/loadcomm.fth		\ Generic CPU-independent Forth tools
fload ${BP}/os/sun/x86/loadmach.fth	\ CPU and OS-specific extensions

\ fm/lib/debug.fth needs the single-stepping support (fm/lib/*/cpubpsup.fth)
\ that the x86 port does not have yet.

fload ${BP}/fm/lib/version.fth

headers
alias lvariable variable
: unix-init-io ( -- )  unix-init-io  ;
: unix-init    ( -- )  unix-init  ;
: init ( -- )  init  ;

dispose 0 0 set-transize

\ The conditional-compilation words were transient and are gone now, so
\ fetch the symbol with the wrapper's get-symbol service directly.
" dic-file-name" d# 55 d# 45 fsyscall  ( adr len | 0 0 )
dup 0= abort" ERROR: dic-file-name is not defined, Can't save"
dup 1+ alloc-mem pack save-forth
