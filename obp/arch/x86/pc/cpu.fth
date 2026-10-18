id: @(#)cpu.fth 1.1 26/10/18
purpose: Processor identification and the /cpus node
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

headerless

\ ---- Timing.  The time stamp counter is calibrated against channel 2
\ of the 8254 programmable interval timer, which counts at 1.193182 MHz.

d# 1193182 constant pit-hz

\ Wait for about n PIT ticks using channel 2 in one-shot mode
: pit-wait  ( ticks -- )
   h# 61 pc@  h# fd and  1 or  h# 61 pc!	\ Gate on, speaker off
   h# b0 h# 43 pc!				\ Channel 2, mode 0, binary
   wbsplit swap h# 42 pc!  h# 42 pc!		\ Count, low byte first
   begin  h# 61 pc@ h# 20 and  until		\ Wait for OUT2 to go high
;

0 value tsc-hz
: calibrate-tsc  ( -- )
   rdtsc  d# 11932 pit-wait  rdtsc  2swap d-	( d.ticks-in-10ms )
   drop  d# 100 *  to tsc-hz
;

: tsc@  ( -- d )  rdtsc  ;

\ Milliseconds since startup, derived from the time stamp counter
: tsc-msecs  ( -- ms )
   tsc@  tsc-hz d# 1000 /  um/mod nip
;
: tsc-us  ( us -- )
   tsc-hz d# 1000000 / um*  tsc@ d+    ( d.end )
   begin  2dup tsc@ du<  until  2drop
;
: tsc-ms  ( ms -- )  0  ?do  d# 1000 tsc-us  loop  ;

\ ---- Processor identification (CPUID)

: cpuid-max  ( -- n )  0 0 cpuid  3drop  ;
: ext-cpuid-max  ( -- n )  h# 8000.0000 0 cpuid  3drop  ;

create vendor-buf  d# 16 allot
: vendor$  ( -- adr len )
   0 0 cpuid                     ( eax ebx ecx edx )
   vendor-buf 8 + l!  vendor-buf 4 + l!  vendor-buf l!  drop
   vendor-buf d# 12
;

create brand-buf  d# 52 allot
: brand$  ( -- adr len )
   ext-cpuid-max h# 8000.0004 u<  if  " "  exit  then
   3 0  do
      h# 8000.0002 i + 0 cpuid    ( eax ebx ecx edx )
      brand-buf i d# 16 * + >r
      r@ d# 12 + l!  r@ 8 + l!  r@ 4 + l!  r> l!
   loop
   brand-buf cscount -leading -trailing
;

: cpu-signature  ( -- eax )  1 0 cpuid 3drop  ;
: cpu-features  ( -- edx ecx )  1 0 cpuid  >r nip nip r>  swap  ;
: cpu-family  ( -- n )
   cpu-signature dup 8 >> h# f and  dup h# f =  if
      swap d# 20 >> h# ff and +
   else
      nip
   then
;
: cpu-model#  ( -- n )
   cpu-signature dup 4 >> h# f and  swap d# 12 >> h# f0 and  or
;
: cpu-stepping  ( -- n )  cpu-signature h# f and  ;

headers
: .cpu  ( -- )
   brand$ dup  if  type  else  2drop vendor$ type  then
   tsc-hz  if  ."  at "  tsc-hz d# 1000000 / .d ." MHz"  then
;

headerless
: make-cpu-node  ( -- )
   0 0 " 0" " /cpus" begin-package
      " cpu" device-name
      " cpu" device-type
      0 " reg" integer-property
      vendor$ encode-string  " vendor-id" property
      brand$ dup  if  encode-string " brand-string" property  else  2drop  then
      cpu-family    " family" integer-property
      cpu-model#    " cpu-model" integer-property
      cpu-stepping  " stepping" integer-property
      cpu-features  " feature-flags-ecx" integer-property
                    " feature-flags-edx" integer-property
      tsc-hz  ?dup  if  " clock-frequency" integer-property  then
      " x86" " compatible" string-property
   end-package
;

headers
root-device
   new-device
      " cpus" device-name
      1 " #address-cells" integer-property
      0 " #size-cells" integer-property
      : open  ( -- true )  true  ;
      : close  ( -- )  ;
      : encode-unit  ( phys -- adr len )  push-hex (u.) pop-base  ;
      : decode-unit  ( adr len -- phys )  $number  if  0  then  ;
   finish-device
device-end

stand-init: Making cpu nodes
   calibrate-tsc
   ['] tsc-msecs is get-msecs
   ['] tsc-ms    is ms
   ['] tsc-us    is us
   make-cpu-node
;
