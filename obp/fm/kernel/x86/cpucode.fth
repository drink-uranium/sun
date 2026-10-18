id: @(#)cpucode.fth 1.1 26/10/18
purpose: x86 code words used by the tools and the firmware
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Copyright 1994-2004 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The SPARC port defines these words with its resident assembler, in
\ fm/lib/sparc/dfill.fth, fm/lib/sparc/lmove.fth, fm/lib/sparc/bitops.fth,
\ fm/lib/sparc/objsup.fth, os/bootprom/sparc/instance.fth and
\ os/stand/probe.fth.  The x86 port metacompiles them into the kernel,
\ together with the words that give Forth access to x86-specific
\ instructions (I/O ports, CPU identification, model-specific and control
\ registers).

hex

\ ---- Memory fill and move (dfill.fth, lmove.fth)

headers
code cfill  (s start-addr count char -- )
   SAVEIP
   pop %eax
   pop %ecx
   pop %edi
   rep stosb
   RESTIP
c;

code wfill  (s start-addr count shortword -- )
   SAVEIP
   pop %eax
   pop %ecx
   pop %edi
   shr $1,%ecx
   rep stosw
   RESTIP
c;

code lfill  (s start-addr count longword -- )
   SAVEIP
   pop %eax
   pop %ecx
   pop %edi
   shr $2,%ecx
   rep stosl
   RESTIP
c;

\ Fill with a repeating 64-bit pattern
code dfill  (s start-addr count odd-word even-word -- )
   SAVEIP
   pop %eax			\ even-word
   pop %edx			\ odd-word
   pop %ecx			\ count
   pop %edi
   shr $3,%ecx
   jz 2f
1: mov %eax,(%edi)
   mov %edx,4(%edi)
   add $8,%edi
   dec %ecx
   jnz 1b
2: RESTIP
c;

headerless
\ Read every longword in a range, e.g. to load it into the cache
code ltouch  ( adr len -- )
   pop %ecx
   pop %edx
   shr $2,%ecx
   jz 2f
1: mov (%edx),%eax
   add $4,%edx
   dec %ecx
   jnz 1b
2:
c;

code dtouch  ( adr len -- )
   pop %ecx
   pop %edx
   shr $3,%ecx
   jz 2f
1: mov (%edx),%eax
   mov 4(%edx),%eax
   add $8,%edx
   dec %ecx
   jnz 1b
2:
c;

headers
code lmove  (s from-addr to-addr cnt -- )
   SAVEIP
   pop %ecx
   pop %edi
   pop %esi
   shr $2,%ecx
   rep movsl
   RESTIP
c;

code wmove  (s from-adr to-adr #bytes -- )
   SAVEIP
   pop %ecx
   pop %edi
   pop %esi
   shr $1,%ecx
   rep movsw
   RESTIP
c;

\ ---- Bit arrays (bitops.fth).  Bit 0 is the 80 bit of the first byte.

code bitset  ( bit# array -- )
   pop %edx			\ Array
   pop %ecx			\ Bit#
   mov %ecx,%eax
   shr $3,%eax			\ Byte offset
   and $7,%ecx
   xor $7,%ecx			\ Bit within the byte, from the top
   bts %ecx,(%edx,%eax)
c;
code bitclear ( bit# array -- )
   pop %edx
   pop %ecx
   mov %ecx,%eax
   shr $3,%eax
   and $7,%ecx
   xor $7,%ecx
   btr %ecx,(%edx,%eax)
c;
code bittest ( bit# array -- flag )
   pop %edx
   pop %ecx
   mov %ecx,%eax
   shr $3,%eax
   and $7,%ecx
   xor $7,%ecx
   xor %ebx,%ebx
   bt %ecx,(%edx,%eax)
   sbb %ebx,%ebx
   push %ebx
c;

\ ---- Objects support (objsup.fth)

headerless
\ Run-time code for words created by action-name.  The parameter field
\ holds the action number; the next token in the caller is the object.
code-field: doaction-name
   mov 4(%eax),%ecx		\ Action#
   lodsl			\ Object acf
   lea 4(%eax),%edx
   push %edx			\ Object apf
   mov (%eax),%eax		\ Default action code address
   shl $2,%ecx
   sub %ecx,%eax		\ Skip back action# tokens
   mov -4(%eax),%eax		\ Action-adr token
   jmp *(%eax)
end-code
doaction-name constant 'doaction-name

\ ---- Instance data (os/bootprom/sparc/instance.fth)

\ The parameter field of an instance value contains its offset in the
\ instance data area of the current package instance.
code >instance-data ( pfa -- adr )
   mov {'user my-self}(%edi),%ecx
   test %ecx,%ecx
   jz 1f
   pop %eax
   mov (%eax),%eax
   add %ecx,%eax
   push %eax
   NEXT
1: mov $f_no_2dinstance,%eax
   jmp *(%eax)
end-code
: no-instance  ( pfa -- )
   true  abort" Tried to access instance-specific data with no current instance"
;

\ ---- Memory probing (probe.fth)

\ Operation:  0 c@  1 w@  2 l@  4 c!  5 w!  6 l!
\ Accesses to nonexistent locations on a PC do not normally fault; if they
\ do, the fault is caught by guarded-execute.
code safe-touch  ( [value] adr op -- [value] )
   pop %eax			\ Operation
   pop %edx			\ Address
   cmp $4,%eax
   jae 4f
   cmp $1,%eax
   jb 1f
   je 2f
   pushl (%edx)
   NEXT
1: movzbl (%edx),%eax
   push %eax
   NEXT
2: movzwl (%edx),%eax
   push %eax
   NEXT
4: pop %ecx			\ Value
   cmp $5,%eax
   jb 5f
   je 6f
   mov %ecx,(%edx)
   NEXT
5: mov %cl,(%edx)
   NEXT
6: mov %cx,(%edx)
c;

\ ---- I/O ports

headers
code pc@  ( port -- byte )
   pop %edx
   xor %eax,%eax
   inb %dx,%al
   push %eax
c;
code pw@  ( port -- word )
   pop %edx
   xor %eax,%eax
   inw %dx,%ax
   push %eax
c;
code pl@  ( port -- long )
   pop %edx
   inl %dx,%eax
   push %eax
c;
code pc!  ( byte port -- )
   pop %edx
   pop %eax
   outb %al,%dx
c;
code pw!  ( word port -- )
   pop %edx
   pop %eax
   outw %ax,%dx
c;
code pl!  ( long port -- )
   pop %edx
   pop %eax
   outl %eax,%dx
c;

\ ---- Processor identification and control

code cpuid  ( eax-in ecx-in -- eax ebx ecx edx )
   pop %ecx
   pop %eax
   cpuid
   push %eax
   push %ebx
   push %ecx
   push %edx
c;

code rdtsc  ( -- d.count )
   rdtsc
   push %eax
   push %edx
c;

code rdmsr  ( msr# -- lo hi )
   pop %ecx
   rdmsr
   push %eax
   push %edx
c;
code wrmsr  ( lo hi msr# -- )
   pop %ecx
   pop %edx
   pop %eax
   wrmsr
c;

code cr0@  ( -- n )  mov %cr0,%eax ; push %eax  c;
code cr0!  ( n -- )  pop %eax ; mov %eax,%cr0  c;
code cr2@  ( -- n )  mov %cr2,%eax ; push %eax  c;
code cr3@  ( -- n )  mov %cr3,%eax ; push %eax  c;
code cr3!  ( n -- )  pop %eax ; mov %eax,%cr3  c;
code cr4@  ( -- n )  mov %cr4,%eax ; push %eax  c;
code cr4!  ( n -- )  pop %eax ; mov %eax,%cr4  c;

code eflags@  ( -- n )  pushf  c;
code eflags!  ( n -- )  popf  c;

code cli  ( -- )  cli  c;
code sti  ( -- )  sti  c;
code hlt  ( -- )  hlt  c;
code wbinvd  ( -- )  wbinvd  c;

\ Descriptor table registers
code sidt  ( adr -- )  pop %eax ; sidt (%eax)  c;
code lidt  ( adr -- )  pop %eax ; lidt (%eax)  c;
code sgdt  ( adr -- )  pop %eax ; sgdt (%eax)  c;

\ From Forth, call the C subroutine whose address is on the stack.
\ Up to 6 arguments are passed; they are left on the stack.  The stack
\ pointers are saved for callbacks.
code call  ( [ arg5 .. arg0 ] adr -- [ arg5 .. arg0 ] result )
   pop %eax
   mov %esp,{'user saved-sp}(%edi)
   mov %ebp,{'user saved-rp}(%edi)
   mov %esp,%ebx
   pushl 20(%ebx)
   pushl 16(%ebx)
   pushl 12(%ebx)
   pushl 8(%ebx)
   pushl 4(%ebx)
   pushl (%ebx)
   call *%eax
   mov %ebx,%esp
   push %eax			\ Return subroutine result
c;

\ ---- Running client programs

\ The client interface handler and the exception handler are entered from
\ code that is not Forth: a client program calls the client interface
\ handler as a C function, and the boot stub jumps to the exception entry
\ after saving the processor state.  Both locate the user area through
\ main-task.

headers
defer cif-handler  ( arg-array -- result )	\ Set to do-cif
defer exception-handler  ( -- )			\ Set to handle-breakpoint

create cif-thread  0 , 0 ,	\ cif-handler (cif-return)
create exception-thread  0 , 0 ,	\ exception-handler quit
create client-sp  0 ,		\ The client's stack pointer during a call

\ int cif_entry(void *args) -- called by client programs.
\ The client's callee-saved registers are preserved.  Forth runs on the
\ stacks that were current when the client program was started.
label cif-entry
   .globl cif_entry
cif_entry:
   push %ebp
   push %ebx
   push %esi
   push %edi
   mov 0x14(%esp),%eax			\ The argument array
   mov %esp,{' client-sp >body}
   mov {'body main-task},%edi
   mov {'user saved-sp}(%edi),%esp
   mov {'user saved-rp}(%edi),%ebp
   cld
   push %eax
   mov ${' cif-thread >body},%esi
c;

code (cif-return)  ( result -- )
   pop %eax
   mov {' client-sp >body},%esp
   pop %edi
   pop %esi
   pop %ebx
   pop %ebp
   ret
end-code

\ Entered from the boot stub after an exception.  The processor state has
\ been saved; Forth starts again with empty stacks.
label exception-entry
   .globl exception_entry
exception_entry:
   mov {'body main-task},%edi
   mov {'user .rp0}(%edi),%ebp
   mov {'user .sp0}(%edi),%esp
   cld
   mov ${' exception-thread >body},%esi
c;

: init-client-entries  ( -- )
   ['] cif-handler        cif-thread token!
   ['] (cif-return)       cif-thread ta1+ token!
   ['] exception-handler  exception-thread token!
   ['] quit               exception-thread ta1+ token!
;

headers
\ Start (or resume) a program with the processor state in the save area.
\ The layout of the save area is given in cpu/x86/register.fth.
\ The Forth stack pointers are saved for callbacks.
code (go)  ( state-adr -- )
   pop %eax
   mov %esp,{'user saved-sp}(%edi)
   mov %ebp,{'user saved-rp}(%edi)
   mov %eax,%esi
   mov 0x0c(%esi),%esp			\ %esp
   pushl 0x48(%esi)			\ %eflags
   pushl $0x08				\ %cs
   pushl 0x40(%esi)			\ %eip
   mov 0x1c(%esi),%eax			\ %eax
   mov 0x18(%esi),%ecx			\ %ecx
   mov 0x14(%esi),%edx			\ %edx
   mov 0x10(%esi),%ebx			\ %ebx
   mov 0x08(%esi),%ebp			\ %ebp
   mov (%esi),%edi			\ %edi
   mov 0x04(%esi),%esi			\ %esi
   iret
end-code
