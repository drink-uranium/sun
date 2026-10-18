id: @(#)boot.fth 1.1 26/10/18
purpose: x86 cold start code
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Copyright 1991-1996 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ Boot code (cold start).  The cold start code is executed when Forth is
\ initially started.  Its job is to initialize the Forth virtual machine
\ registers.
\
\ cold-code is called as a C function by the Unix wrapper program or by
\ the firmware boot stub:
\
\   cold_code(header-adr, functions, mem_end, argc, argv)
\
\ header-adr is the origin.  functions is the address of the wrapper's
\ system call table, or 0 when running stand-alone.  Memory below mem_end
\ is used for the user area and the stacks.

hex

0 constant main-task

headerless

\ Stuff initialized at cold start time

nuser memtop		\ The top of the memory used by Forth
headers
0 value #args		\ The process's argument count
0 value  args		\ The process's argument list
headerless
label cold-code  ( -- )
   .globl cold_entry
cold_entry:
   cld
   mov %esp,%ebx			\ The C stack; arguments at 4(%ebx)
   mov origin+8,%ecx			\ User area size from the header
   mov 0x0c(%ebx),%edx			\ mem_end
   and $-0x10,%edx
   mov %edx,%ebp			\ Remember mem_end
   sub %ecx,%edx			\ Allocate the RAM copy of the user area
   mov %edx,%edi
   mov origin+4,%esi			\ Text size = offset of user area image
   add $origin,%esi
   shr $2,%ecx
   rep movsl				\ Copy the initial user area image
   mov %edx,%edi			\ Set the user pointer

   mov %edi,{'body main-task}		\ Allow the exception handler to find
					\ the main user area
   mov %ebp,{'user memtop}(%edi)	\ Top of memory
   mov %edi,{'user up0}(%edi)

   mov %edi,%ebp			\ Establish the return stack
   mov %ebp,{'user .rp0}(%edi)
   mov %edi,%eax
   sub ${rs-size-t},%eax
   mov %eax,{'user .sp0}(%edi)		\ Establish the parameter stack
   mov %eax,%esp
   sub ${ps-size-t},%eax
   mov %eax,{'user limit}(%edi)		\ Dictionary limit

   mov 8(%ebx),%eax			\ Address of the system call table
   mov %eax,{'user syscall-vec}(%edi)
   mov %ebx,{'user cstack}(%edi)

   mov origin+4,%eax			\ Set the dictionary pointer
   add $origin,%eax
   mov %eax,{'user dp}(%edi)

   mov 0x10(%ebx),%eax			\ Set the value of #args and args
   mov %eax,{'user #args}(%edi)
   mov 0x14(%ebx),%eax
   mov %eax,{'user args}(%edi)

   mov ${'body cold},%esi		\ Enter Forth
c;

headers
