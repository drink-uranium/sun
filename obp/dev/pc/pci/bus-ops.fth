id: @(#)bus-ops.fth 1.1 26/10/19
purpose: Configuration space access and address mapping for PC PCI
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ PC host bridges implement PCI configuration mechanism #1: the address
\ of a configuration register (enable bit, bus, device, function and the
\ longword-aligned register number) is written to the I/O port cf8, and
\ the register is then accessed at I/O ports cfc to cff.  The register
\ access words do port I/O for port addresses (cpu/x86/regwords.fth).
\
\ PCI memory space addresses are processor physical addresses and PCI
\ I/O space addresses are processor I/O port numbers, so mapping is
\ the identity.

headerless

h# cf8 constant config-address
h# cfc constant config-data

\ Mechanism #1 reaches registers 0-ff; the PCI Express extended
\ configuration space needs memory-mapped access, which isn't used.
: config-setup  ( phys.hi -- data-port )
   dup h# 00ff.fffc and  h# 8000.0000 or  config-address rl!
   3 and  config-data +
;

: cfg-l@  ( phys.hi -- l )  config-setup rl@  ;
: cfg-w@  ( phys.hi -- w )  config-setup rw@  ;
: cfg-b@  ( phys.hi -- b )  config-setup rb@  ;
: cfg-l!  ( l phys.hi -- )  config-setup rl!  ;
: cfg-w!  ( w phys.hi -- )  config-setup rw!  ;
: cfg-b!  ( b phys.hi -- )  config-setup rb!  ;

: (map-in)  ( pa len -- va )  " map-in" $call-parent  ;

: bus-map-io  ( phys.lo phys.mid phys.hi len -- va )
   drop 2drop  h# ffff and			( port )
;
: bus-map-mem  ( phys.lo phys.mid phys.hi len -- va )
   >r drop					( phys.lo phys.mid )  ( r: len )
   if
      r> 2drop  cmn-error[ " PCI memory above 4GB is not addressable" ]cmn-end
      abort
   then
   r> (map-in)					( va )
;
: bus-map-cfg  ( phys.hi len -- va )
   2drop  cmn-error[ " invalid map-in on config space" ]cmn-end  abort
;

headers
