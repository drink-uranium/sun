id: @(#)fixed.fth 1.1 26/10/18
purpose: Layout of the fixed configuration variable partition
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The same layout as sun4v (arch/sun4v/niagara/fixed.fth)

1			fixed-ptr !				\ 0x01
false			fixed-flag diag-switch?			\ 0x01
h# e			fixed-ptr !
verbosity-default	' verbosity-types fixed-vocab-variable verbosity \ 0x0e

h# 20			constant security-start

security-start		fixed-ptr !				\ 0x20
nodefault-fixed-int				security-#badlogins
d# 08			config-password:	security-password
config-security:				security-mode

stand-init: Track diagnostic-mode?
   ['] diag-switch? to diagnostic-mode?
;
