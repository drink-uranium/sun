id: @(#)loadconfig.fth 1.1 26/10/18
purpose: Configuration variables for PCs
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

fload ${BP}/pkg/confvar/loadcvar.fth                \ NVRAM device support
fload ${BP}/pkg/confvar/definitions/standard.fth    \ standard data types

fload ${BP}/arch/sun4u/config/reset-recovery.fth

fload ${BP}/pkg/confvar/definitions/confvoc/verbosity-types-voc.fth
: verbosity-default ( -- adr,len ) " min" ;

fload ${BP}/arch/x86/pc/fixed.fth
fload ${BP}/arch/sun4u/config/nvramrc.fth

" disk net"   d# 256  config-string  boot-device
" "           d# 128  config-string  boot-file
" boot"       d# 64   config-string  boot-command
" net"        d# 256  config-string  diag-device
" "           d# 128  config-string  diag-file
" "             d# 512  config-long-string      network-boot-arguments

true	              config-flag    auto-boot?

default-load-base     config-int     load-base

false   config-flag    auto-boot-on-error?

" ttya"  d# 32  config-string input-device
" ttya"  d# 32  config-string output-device

headers
: ttya$  " ttya" ;
headerless

' ttya$  is fallback-device

fload ${BP}/arch/sun4u/config/console.fth

" 115200,8,n,1,-" d# 16 config-string ttya-mode
" 115200,8,n,1,-" d# 16 config-string ttyb-mode

fload ${BP}/arch/sun4u/config/termemu.fth
fload ${BP}/arch/sun4u/config/banner.fth
fload ${BP}/arch/sun4u/config/scsi-id.fth

false   config-flag     fcode-debug?
true   	config-flag     local-mac-address?

\ Install hook for fcode-debug?
' fcode-debug?  to (fcode-debug?)

fload ${BP}/pkg/confvar/interfaces/standard.fth     \ support consumers
