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

\ preload.fth loaded these as transient; the tools need them resident
fload ${BP}/fm/lib/brackif.fth
fload ${BP}/fm/lib/needs.fth

\ Keep every header; the tokenizer uses words that the libraries define
\ as headerless.
true is suppress-headerless?

fload ${BP}/fm/lib/loadcomm.fth		\ Generic CPU-independent Forth tools
fload ${BP}/os/sun/x86/loadmach.fth	\ CPU and OS-specific extensions

\ loadcomm.fth and loadmach.fth load these as transient; the tools and the
\ tokenizer need them after dispose
fload ${BP}/fm/lib/filetool.fth
fload ${BP}/fm/cwrapper/x86/savefort.fth

\ fm/lib/debug.fth needs the single-stepping support (fm/lib/*/cpubpsup.fth)
\ that the x86 port does not have yet.

fload ${BP}/fm/lib/version.fth

headers
alias lvariable variable
: unix-init-io ( -- )  unix-init-io  ;
: unix-init    ( -- )  unix-init  ;
: init ( -- )  init  ;

dispose 0 0 set-transize

\ fm/lib/headless.fth was loaded as transient by preload.fth, so it is gone.
\ Everything in the tools dictionary is headered from here on.
: headers  ( -- )  ;
: headerless  ( -- )  ;
: headerless0  ( -- )  ;
alias external headers

[ifndef] dic-file-name
-1 abort" ERROR: dic-file-name is not defined, Can't save"
[then]
[defined] dic-file-name dup 1+ alloc-mem pack save-forth
