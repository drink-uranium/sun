id: @(#)regwords.fth 1.1 26/10/19
purpose: Device register access words for x86 (memory and I/O ports)
copyright: Copyright 1990-2000 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The x86 replacement for os/bootprom/regwords.fth.
\
\ x86 processors have two address spaces for devices: memory and the
\ 64K I/O port space.  A map-in of an I/O space address (PCI I/O space,
\ ISA I/O space) returns the port number, and a map-in of a memory space
\ address returns the (identity-mapped) physical address, which is always
\ above 64K for device registers.  The register access words, which are
\ also the FCode register access primitives, use I/O instructions for
\ addresses below 64K and memory references otherwise, so that the same
\ driver code works with registers in either space.

headerless
h# 1.0000 constant /io-space
: io-port?  ( adr -- flag )  /io-space u<  ;

headers
: rb@  ( adr -- b )  dup io-port?  if  pc@  else  c@  then  ;
: rw@  ( adr -- w )  dup io-port?  if  pw@  else  w@  then  ;
: rl@  ( adr -- l )  dup io-port?  if  pl@  else  l@  then  ;
: rb!  ( b adr -- )  dup io-port?  if  pc!  else  c!  then  ;
: rw!  ( w adr -- )  dup io-port?  if  pw!  else  w!  then  ;
: rl!  ( l adr -- )  dup io-port?  if  pl!  else  l!  then  ;
