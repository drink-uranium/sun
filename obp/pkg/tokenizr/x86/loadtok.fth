id: @(#)loadtok.fth 1.1 26/10/19
purpose: Load file for the tokenizer program (x86 host)
copyright: Copyright 1994-2002 Sun Microsystems, Inc. All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The same as pkg/tokenizr/sparc/loadtok.fth, run with the x86 forth.dic.
\ The output file name is given on the command line as  -D tokenize-dic=...

: $call-parent ;

[define] v2-compat

fload ${BP}/pkg/tokenizr/tokenize.fth

" tokenize-dic" d# 55 d# 45 fsyscall  ( adr len | 0 0 )
dup 0= abort" ERROR: tokenize-dic is not defined"
dup 1+ alloc-mem pack save-forth
