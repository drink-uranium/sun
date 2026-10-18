id: @(#)loadpkg.fth 1.1 26/10/18
purpose: Load file for the support packages (x86)
copyright: Copyright 1994 Firmworks  All Rights Reserved
copyright: Copyright 2005 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The same as pkg/loadpkg.fth, with the x86 versions of the
\ machine-dependent parts.

fload ${BP}/dev/deblock.fth             \ Block-to-byte conversion package
fload ${BP}/pkg/boot/sunlabel.fth       \ Sun Disk Label package
fload ${BP}/arch/x86/pc/loadfb.fth	\ Frame buffer & terminal emulator
fload ${BP}/pkg/boot/bootparm.fth       \ S boot command parser
fload ${BP}/os/bootprom/callback.fth    \ Client callbacks
fload ${BP}/pkg/console/instcons.fth    \ install-console
fload ${BP}/arch/x86/pc/go.fth          \ Initial program state
fload ${BP}/os/bootprom/dlbin.fth       \ Serial line loading
fload ${BP}/pkg/dhcp/macaddr.fth
fload ${BP}/os/bootprom/dload.fth       \ Diagnostic loading
fload ${BP}/pkg/sunlogo/logo.fth
fload ${BP}/pkg/console/sysconfig.fth   \ System configuration information
fload ${BP}/pkg/console/banner.fth      \ Banner with logo
fload ${BP}/arch/sun4u/help.fth         \ Help package
