id: @(#)sys.fth 1.1 26/10/18
purpose: Low-level interfaces to the x86 Unix wrapper program
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Copyright 1990-2002 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ Very-low-level interfaces to the wrapper program (os/unix/x86/wrapper.c)
\ that runs Forth as a Unix process.  The wrapper passes the address of a
\ table of C functions to cold-code, which stores it in syscall-vec.
\
\ The names and the stack diagrams are the same as in the SPARC version.

decimal

headerless

/l ualloc-t  dup equ syscall-user#
headers
user syscall-vec   \ long address of system call vector
headerless

nuser sysretval
nuser cstack	   \ The wrapper's C stack pointer, saved by cold-code

\ I/O for running under Unix with a C program providing actual I/O routines

headers

\ The arguments are passed to the C routine in the usual C order: the
\ item that was on top of the stack (after the call# is removed) is the
\ first argument.  The C routines run on the wrapper's own stack.
code syscall ( ?? call# -- ?? )
   pop %eax
   mov {syscall-user#}(%edi),%edx	\ Address of system call table
   mov (%edx,%eax,4),%edx		\ Address of routine
   mov %esp,%ebx			\ Forth stack pointer
   mov {'user cstack}(%edi),%esp
   and $-16,%esp
   pushl 20(%ebx)			\ Six arguments
   pushl 16(%ebx)
   pushl 12(%ebx)
   pushl 8(%ebx)
   pushl 4(%ebx)
   pushl (%ebx)
   call *%edx
   mov %ebx,%esp
   mov %eax,{'user sysretval}(%edi)	\ Save the result
c;

\ A syscall wrapper that uses the stack so that the wrapper can return
\ data on the forth stacks.  The C routine receives the Forth stack pointer
\ and returns the new Forth stack pointer.
code fsyscall ( ?? call# -- ?? )
   pop %eax
   mov {syscall-user#}(%edi),%edx
   mov (%edx,%eax,4),%edx
   mov %esp,%ebx
   mov {'user cstack}(%edi),%esp
   and $-16,%esp
   sub $12,%esp
   push %ebx
   call *%edx
   mov %eax,%esp			\ New stack pointer
c;

: retval   ( -- return_value )     sysretval @  ;
: lretval  ( -- l.return_value )   sysretval @ n->l ;

headers
nuser errno	\ The last system error code
headerless

: error?  ( return-value -- return-value error? )
   dup 0< dup  if  15 syscall retval errno !  then   ( return-value flag )
;

headers
\ Depends on null-termination of Forth strings
overload: cstr  ( pstr -- cstr )  1+  ;

hex
headerless

chain: unix-init-io
   install-wrapper-io

   \ Don't poll the keyboard under Unix; block waiting for a key
   ['] (key              ['] key            (is
;
' unix-init-io is init-io

: unix-init ;  \ Environment initialization chain
' unix-init is init-environment
decimal
headers
