id: @(#)go.fth 1.1 26/10/18
purpose: Starting client programs on PCs
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The x86 counterpart of arch/sun4u/go.fth.
\
\ A client program is started in 32-bit protected mode with flat segments,
\ paging and interrupts disabled, and:
\
\   Open Firmware client programs (ELF32 executables)
\      %eax  address of the client interface handler,
\            int cif_handler(cell args[]), called with the C calling
\            convention
\      %esp  a 64K stack
\
\   Multiboot kernels (ELF32 executables with a Multiboot header)
\      %eax  0x2badb002
\      %ebx  address of the Multiboot information structure
\
\ The client interface services "exit" and "enter" return to the ok
\ prompt; after "enter", "go" returns to the client program.

headerless

h# 1.0000 constant /client-stack
0 value client-stack

defer client-entry-hook  ( -- )  ' noop is client-entry-hook

headers
: set-pc  ( adr -- )  to %eip  ;

: (init-program)  ( -- )
   cif-32
   cpu-state  d# 19 /n*  erase
   client-stack 0=  if  /client-stack alloc-mem  to client-stack  then
   client-stack /client-stack +  to %esp
   h# 08 to %cs   h# 10 to %ds   h# 10 to %es   h# 10 to %ss
   h# 2 to %eflags			\ Interrupts disabled
   cif-entry to %eax			\ Client interface handler
   load-base set-pc
   state-valid on  restartable? on
   true to already-go?
   client-entry-hook
;

\ Client interface services that return to the firmware

: exittomon  ( -- )
   client-exited-chain
   restartable? off  state-valid off
   ??cr ." Program terminated" cr
   quit
;

cif: exit  ( -- )  exittomon  ;

cif: enter  ( -- )
   ??cr ." Type  'go' to resume" cr
   true to in-enter?
   interact
   false to in-enter?
   false to exit-interact?
;

\ ---- Multiboot kernels

headerless
h# 1bad.b002 constant multiboot-header-magic

\ Find a Multiboot header in the first 8K of the image
: multiboot-header  ( adr len -- false | header true )
   h# 2000 min  bounds  ?do
      i l@ multiboot-header-magic =  if
         i la1+ l@  i 2 la+ l@ +  i l@ +  0=  if  i true unloop exit  then
      then
   /l +loop
   false
;

\ The Multiboot information structure that we pass to the kernel
d# 88 constant /mbi
0 value mbi
0 value mb-mmap
d# 256 buffer: mb-cmdline
create mb-loader-name  ," OpenBoot x86" 0 c,

: build-mbi  ( cmdline$ -- )
   /mbi alloc-mem to mbi   mbi /mbi erase
   d# 255 min  mb-cmdline place-cstr  mbi d# 16 + l!	\ cmdline
   \ Memory sizes in KB below 1MB and above 1MB
   d# 640  mbi 4 + l!
   total-ram 1meg - 0 max  d# 1024 /  mbi 8 + l!
   \ Memory map
   #ram-ranges @  d# 24 *  dup mbi d# 44 + l!		( len )
   alloc-mem dup to mb-mmap  mbi d# 48 + l!
   #ram-ranges @  0  ?do
      mb-mmap i d# 24 * +  >r
      d# 20 r@ l!				\ Entry size
      i ram-range  swap r@ 4 + l!  0 r@ 8 + l!	\ Base
      r@ d# 12 + l!  0 r@ d# 16 + l!		\ Length
      1 r> d# 20 + l!				\ Type: RAM
   loop
   mb-loader-name 1+  mbi d# 64 + l!		\ boot_loader_name
   h# 245  mbi l!				\ flags: mem cmdline mmap name
;

headers
: multiboot-program  ( cmdline$ -- )
   build-mbi
   multiboot-magic to %eax
   mbi to %ebx
;

\ Allow dropin drivers to be standalone programs.

\ Load an ELF32 executable and prepare to start it
tail-chain: execute-buffer  ( adr len -- )
   over adjust-elf32-header  if         ( adr,len entry )
      >r  (init-program)  r> set-pc     ( adr,len )
      multiboot-header  if              ( header )
         drop  args-buf cscount multiboot-program
      then
      go
      exit
   then                                 ( adr,len )
tail;

headers
: init-program ( -- )
   load-base file-size @  'execute-buffer execute  (init-program)
;
