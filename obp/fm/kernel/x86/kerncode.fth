id: @(#)kerncode.fth 1.1 26/10/18
purpose: Kernel code words for the x86 (i386, 32-bit protected mode) port
copyright: Copyright 1994-2003 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ This is the x86 counterpart of fm/kernel/sparc/kerncode.fth.  It is
\ processed by the stage-0 metacompiler (fm/meta/x86/meta86.py); the bodies
\ of code words are AT&T-syntax i386 assembler, and {expr} inside a code
\ body is evaluated by the metacompiler (e.g. {'user up0} is the user
\ number of up0).
\
\ Threading model: 32-bit indirect threaded code with absolute tokens.
\ The code field of every word contains the address of its machine code.
\ For code words that address is the parameter field, which holds the
\ code itself.
\
\ Forth virtual machine registers
\
\   %esi   ip    Interpreter pointer
\   %esp   sp    Data stack pointer; the top of stack is in memory at (%esp)
\   %ebp   rp    Return stack pointer
\   %edi   up    User area pointer
\   %eax   w     Code field address of the word being executed (set by next)
\   %ebx %ecx %edx  scratch
\
\ The direction flag is always clear while Forth code runs.
\
\ Null links and null tokens are represented by the address of the origin,
\ as in the SPARC kernel.

hex

\ ---- Action code for target words classes.

code-field: dolabel
   lea 4(%eax),%ecx		\ The parameter field is already aligned
   push %ecx
c;

code-field: docolon
   lea -4(%ebp),%ebp
   mov %esi,(%ebp)		\ Save the ip on the return stack
   lea 4(%eax),%esi		\ Reload ip with apf of colon definition
c;

code-field: docreate
   lea 4(%eax),%ecx		\ Push the apf
   push %ecx
c;

code-field: douser
   mov 4(%eax),%ecx		\ Get the user number
   add %edi,%ecx		\ Add the base address of the user area
   push %ecx
c;

code-field: dovalue
   mov 4(%eax),%ecx		\ Get the user number
   pushl (%edi,%ecx)		\ Get the contents of the user area location
c;

code-field: dodefer
   mov 4(%eax),%ecx		\ Get the user number
   mov (%edi,%ecx),%eax		\ Get the acf stored in that user location
   jmp *(%eax)			\ Execute that word
end-code

code-field: doconstant
   pushl 4(%eax)
c;

code-field: do2constant
   pushl 4(%eax)		\ The bottom value
   pushl 8(%eax)		\ The top value
c;

\ The code field of a child word of a does> definer contains the address
\ of the does> clause.  The clause starts with an 8-byte call to dodoes,
\ followed by the high-level code.  The call pushes its return address,
\ which is 3 bytes before the high-level code, onto the data stack.
code-field: dodoes
   pop %edx			\ Address following the call instruction
   lea 4(%eax),%ecx		\ Push the apf of the child word
   push %ecx
   lea -4(%ebp),%ebp
   mov %esi,(%ebp)		\ Save the ip
   lea 3(%edx),%esi		\ The high level code of the does> clause
c;

\ ---- Run-time words compiled by compiling words.

headerless
code (lit)  ( -- n )
   lodsl
   push %eax
c;

code (wlit)  ( -- n )
   lodsl
   push %eax
c;

code (llit)  ( -- n )
   lodsl
   push %eax
c;

\ High level branch. The branch offset is compiled in-line, and is relative
\ to the location of the offset itself.
code branch ( -- )
   add (%esi),%esi
c;

\ High level conditional branch.
code ?branch ( f -- )  \ Takes the branch if the flag is false
   pop %eax
   test %eax,%eax
   jz 1f
   add $4,%esi			\ Skip the branch offset
   NEXT
1: add (%esi),%esi
c;

\ The loop parameters on the return stack are:
\    0(%ebp)  index - (limit + 80000000)   The overflow flag ends the loop
\    4(%ebp)  limit + 80000000
\    8(%ebp)  address of the do offset, for leave

\ Run time word for loop
code (loop)  ( -- )
   addl $1,(%ebp)		\ increment loop index
   jo 1f			\ Overflow means done
   add (%esi),%esi		\ branch back
   NEXT
1: add $0x0c,%ebp			\ done; remove loop params from stack
   add $4,%esi			\ Skip the branch offset
c;

\ Run time word for +loop
code (+loop) ( increment -- )
   pop %eax
   add %eax,(%ebp)		\ increment loop index
   jo 1f
   add (%esi),%esi
   NEXT
1: add $0x0c,%ebp
   add $4,%esi
c;

\ Run time word for do
code (do)  ( l i -- )
   pop %ecx			\ i
   pop %edx			\ l
   lea -0x0c(%ebp),%ebp
   mov %esi,8(%ebp)		\ remember the do offset address
   add $4,%esi			\ skip the do offset
   add $0x80000000,%edx
   mov %edx,4(%ebp)
   sub %edx,%ecx
   mov %ecx,(%ebp)
c;

\ Run time word for ?do
code (?do)  ( l i -- )
   pop %ecx			\ i
   pop %edx			\ l
   cmp %edx,%ecx
   je 1f
   lea -0x0c(%ebp),%ebp
   mov %esi,8(%ebp)
   add $4,%esi
   add $0x80000000,%edx
   mov %edx,4(%ebp)
   sub %edx,%ecx
   mov %ecx,(%ebp)
   NEXT
1: add (%esi),%esi		\ Skip the loop
c;

headers
\ Loop index for current do loop
code i  ( -- n )
   mov (%ebp),%eax
   add 4(%ebp),%eax
   push %eax
c;

\ Loop index for next enclosing do loop
code j   ( -- n )
   mov 0x0c(%ebp),%eax
   add 0x10(%ebp),%eax
   push %eax
c;

headerless
code (leave)  ( -- )
   mov 8(%ebp),%esi		\ Get the address of the ending offset
   add $0x0c,%ebp			\ get rid of the loop indices
   add (%esi),%esi		\ branch
c;

code (?leave)  ( f -- )
   pop %eax
   test %eax,%eax
   jz 1f
   mov 8(%ebp),%esi
   add $0x0c,%ebp
   add (%esi),%esi
1:
c;

headers
code unloop  ( -- )  add $0x0c,%ebp  c;  \ Discard the loop indices

headerless
code (of)  ( selector test -- [ selector ] )
   pop %eax			\ test
   cmp %eax,(%esp)
   jne 1f
   add $4,%esp			\ Discard the selector
   add $4,%esi			\ Skip the branch offset
   NEXT
1: add (%esi),%esi		\ Take the branch
c;

\ (endof) is the same as branch, and (endcase) is the same as drop,
\ but redefining them this way makes the decompiler much easier.

code (endof)  ( -- )  add (%esi),%esi  c;
code (endcase)  ( n -- )  add $4,%esp  c;

\ ---- Ordinary Forth words.

headers
\ Execute a Forth word given a code field address
code execute   ( acf -- )
   pop %eax
   jmp *(%eax)
end-code

\ Convert a character to a digit according to the current base
code digit  ( char base -- digit true | char false )
   pop %ecx			\ base
   mov (%esp),%eax		\ char
   cmp $0x30,%eax
   jl 3f			\ Anything less than ascii 0 isn't a digit
   cmp $0x39,%eax
   jle 2f
   cmp $0x41,%eax
   jl 3f			\ bad if > '9' and < 'A'
   cmp $0x5a,%eax
   jle 1f
   cmp $0x61,%eax
   jl 3f
   cmp $0x7a,%eax
   jg 3f
   sub $0x20,%eax			\ Lower case letter
1: sub $7,%eax			\ Letter: 'A' becomes 3a
2: sub $0x30,%eax
   cmp %ecx,%eax
   jae 3f			\ Not a digit in this base
   mov %eax,(%esp)		\ Replace the char on the stack with the digit
   push $-1			\ True to indicate success
   NEXT
3: push $0
c;

\ Copy cnt characters starting at from-addr to to-addr.  Copying is done
\ strictly from low to high addresses, so be careful of overlap between the
\ two buffers.

code cmove  ( src dst cnt -- )  \ Copy from bottom to top
   SAVEIP
   pop %ecx
   pop %edi
   pop %esi
   rep movsb
   RESTIP
c;

code cmove>  ( src dst cnt -- )  \ Copy from top to bottom
   SAVEIP
   pop %ecx
   pop %edi
   pop %esi
   lea -1(%esi,%ecx),%esi
   lea -1(%edi,%ecx),%edi
   std
   rep movsb
   cld
   RESTIP
c;

code and ( n1 n2 -- n3 )  pop %eax ; and %eax,(%esp)  c;
code or  ( n1 n2 -- n3 )  pop %eax ; or %eax,(%esp)   c;
code xor ( n1 n2 -- n3 )  pop %eax ; xor %eax,(%esp)  c;

code <<      ( n1 cnt -- n2 )  pop %ecx ; shll %cl,(%esp)  c;
code >>      ( n1 cnt -- n2 )  pop %ecx ; shrl %cl,(%esp)  c;
code >>a     ( n1 cnt -- n2 )  pop %ecx ; sarl %cl,(%esp)  c;
code lshift  ( n1 cnt -- n2 )  pop %ecx ; shll %cl,(%esp)  c;
code rshift  ( n1 cnt -- n2 )  pop %ecx ; shrl %cl,(%esp)  c;

code +   ( n1 n2 -- n3 )  pop %eax ; add %eax,(%esp)  c;
code -   ( n1 n2 -- n3 )  pop %eax ; sub %eax,(%esp)  c;

code invert  ( n1 -- n2 )  notl (%esp)  c;
code negate  ( n1 -- n2 )  negl (%esp)  c;

\  Mark the first code-definition in the dictionary;
\  we will need it later...
headerless
: first-code-word ( -- acf )  (') (lit) ;
headers

: abs   ( n1 -- n2 )  dup 0<  if  negate  then   ;

: min  ( n1 n2 -- n3 )  2dup  >  if  swap  then  drop  ;
: max  ( n1 n2 -- n3 )  2dup  <  if  swap  then  drop  ;
: umin ( u1 u2 -- u3 )  2dup u>  if  swap  then  drop  ;
: umax ( u1 u2 -- u3 )  2dup u<  if  swap  then  drop  ;

code up@  ( -- addr )  push %edi  c;
code sp@  ( -- addr )  push %esp  c;	\ Pushes the value before the push
code rp@  ( -- addr )  push %ebp  c;
code up!  ( addr -- )  pop %edi   c;
code sp!  ( addr -- )  pop %esp   c;
code rp!  ( addr -- )  pop %ebp   c;
code >r   ( n -- )     pop %eax ; lea -4(%ebp),%ebp ; mov %eax,(%ebp)  c;
code r>   ( -- n )     pushl (%ebp) ; lea 4(%ebp),%ebp  c;
code r@   ( -- n )     pushl (%ebp)  c;
code >user ( pfa -- addr )
   pop %eax
   mov (%eax),%eax
   add %edi,%eax
   push %eax
c;
code 2>r  ( n1 n2 -- )
   pop %eax
   pop %ecx
   lea -8(%ebp),%ebp
   mov %ecx,4(%ebp)
   mov %eax,(%ebp)
c;
code 2r>  ( -- n1 n2 )
   pushl 4(%ebp)
   pushl (%ebp)
   lea 8(%ebp),%ebp
c;
code 2r@  ( -- n1 n2 )
   pushl 4(%ebp)
   pushl (%ebp)
c;

code >ip   ( n -- )     pop %eax ; lea -4(%ebp),%ebp ; mov %eax,(%ebp)  c;
code ip>   ( -- n )     pushl (%ebp) ; lea 4(%ebp),%ebp  c;
code ip@   ( -- n )     pushl (%ebp)  c;
: ip>token  ( ip -- token-adr )  /token -  ;

code exit ( -- )       mov (%ebp),%esi ; lea 4(%ebp),%ebp  c;
code unnest ( -- )     mov (%ebp),%esi ; lea 4(%ebp),%ebp  c;

code tuck  ( n1 n2 -- n2 n1 n2 )
   pop %eax
   pop %ecx
   push %eax
   push %ecx
   push %eax
c;
code nip   ( n1 n2 -- n2 )
   pop %eax
   mov %eax,(%esp)
c;
code flip  ( w1 -- w2 )  \  byte-swap the low two bytes; clear the rest.
   pop %eax
   xchg %al,%ah
   movzwl %ax,%eax
   push %eax
c;

code 0=  ( n -- f )  TEST1 e   c;
code 0<> ( n -- f )  TEST1 ne  c;
code 0<  ( n -- f )  TEST1 l   c;
code 0<= ( n -- f )  TEST1 le  c;
code 0>  ( n -- f )  TEST1 g   c;
code 0>= ( n -- f )  TEST1 ge  c;

code <   ( n1 n2 -- f )  COMPARE l   c;
code >   ( n1 n2 -- f )  COMPARE g   c;
code =   ( n1 n2 -- f )  COMPARE e   c;
code <>  ( n1 n2 -- f )  COMPARE ne  c;
code u>  ( n1 n2 -- f )  COMPARE a   c;
code u<= ( n1 n2 -- f )  COMPARE be  c;
code u<  ( n1 n2 -- f )  COMPARE b   c;
code u>= ( n1 n2 -- f )  COMPARE ae  c;
code >=  ( n1 n2 -- f )  COMPARE ge  c;
code <=  ( n1 n2 -- f )  COMPARE le  c;

code drop ( n -- )      add $4,%esp  c;
code ?dup ( n -- 0|n,n)
   mov (%esp),%eax
   test %eax,%eax
   jz 1f
   push %eax
1:
c;
code dup  ( n -- n n )  pushl (%esp)  c;
code over ( n1 n2 -- n1 n2 n1 )  pushl 4(%esp)  c;
code swap ( n1 n2 -- n2 n1 )
   pop %eax
   pop %ecx
   push %eax
   push %ecx
c;
code rot  ( n1 n2 n3 -- n2 n3 n1 )
   pop %eax
   pop %ecx
   pop %edx
   push %ecx
   push %eax
   push %edx
c;
code -rot ( n1 n2 n3 -- n3 n1 n2 )
   pop %eax
   pop %ecx
   pop %edx
   push %eax
   push %edx
   push %ecx
c;
code 2drop  ( d -- )      add $8,%esp  c;
code 2dup   ( d -- d d )
   pushl 4(%esp)
   pushl 4(%esp)
c;
code 2over  ( d1 d2 -- d1 d2 d1 )
   pushl 0x0c(%esp)
   pushl 0x0c(%esp)
c;
code 2swap  ( d1 d2 -- d2 d1 )
   pop %eax
   pop %ecx
   pop %edx
   pop %ebx
   push %ecx
   push %eax
   push %ebx
   push %edx
c;
code 3drop  ( n1 n2 n3 -- )  add $0x0c,%esp  c;
code 3dup   ( n1 n2 n3 -- n1 n2 n3 n1 n2 n3 )
   pushl 8(%esp)
   pushl 8(%esp)
   pushl 8(%esp)
c;

code pick   ( nm ... n1 n0 k -- nm ... n2 n0 nk )
   pop %eax
   pushl (%esp,%eax,4)
c;

code 1+  ( n1 -- n2 )  incl (%esp)    c;
code 2+  ( n1 -- n2 )  addl $2,(%esp)  c;
code 1-  ( n1 -- n2 )  decl (%esp)    c;
code 2-  ( n1 -- n2 )  subl $2,(%esp)  c;

code 2/  ( n1 -- n2 )  sarl (%esp)     c;
code u2/ ( n1 -- n2 )  shrl (%esp)     c;
code 2*  ( n1 -- n2 )  shll (%esp)     c;
code 4*  ( n1 -- n2 )  shll $2,(%esp)  c;
code 8*  ( n1 -- n2 )  shll $3,(%esp)  c;

code on  ( addr -- )  pop %eax ; movl $-1,(%eax)  c;
code off ( addr -- )  pop %eax ; movl $0,(%eax)   c;

code +! ( n addr -- )
   pop %eax
   pop %ecx
   add %ecx,(%eax)
c;

code @   ( addr -- n )  pop %eax ; pushl (%eax)  c;

\ d@ and 2@ leave the cell at addr on top of the stack
code d@  ( addr -- nlow nhigh )
   pop %eax
   pushl 4(%eax)
   pushl (%eax)
c;

code l@ ( addr -- l )  pop %eax ; pushl (%eax)  c;
code <l@ ( addr -- l )  pop %eax ; pushl (%eax)  c;
code w@ ( addr -- w )  pop %eax ; movzwl (%eax),%eax ; push %eax  c;
code <w@ ( addr -- w )  pop %eax ; movswl (%eax),%eax ; push %eax  c;
code c@ ( addr -- c )  pop %eax ; movzbl (%eax),%eax ; push %eax  c;

\ The x86 tolerates misaligned accesses, so the unaligned versions are the
\ same as the aligned ones.  The "be-" versions use big-endian byte order.
code unaligned-@  ( addr -- l )  pop %eax ; pushl (%eax)  c;
code unaligned-l@ ( addr -- l )  pop %eax ; pushl (%eax)  c;
code unaligned-w@ ( addr -- w )  pop %eax ; movzwl (%eax),%eax ; push %eax  c;
code be-l@  ( addr -- l )
   pop %eax
   mov (%eax),%eax
   bswap %eax
   push %eax
c;

code !   ( n addr -- )
   pop %eax
   pop %ecx
   mov %ecx,(%eax)
c;

headerless
\  These two words implement a very fast  IS
\  The first is applied to USER definitions (VALUEs and VARIABLEs)
\  and the second to DEFER words.  The target word's acf follows in-line.
code (is-user)  ( n -- )
   lodsl			\  ACF of the next token in the caller
   mov 4(%eax),%eax		\  User number
   pop %ecx
   mov %ecx,(%edi,%eax)
c;

code (is-defer)  ( acf -- )
   lodsl
   mov 4(%eax),%eax
   pop %ecx
   mov %ecx,(%edi,%eax)
c;

headers

code d!  ( n-low n-high addr -- )
   pop %eax
   pop %ecx
   pop %edx
   mov %ecx,(%eax)
   mov %edx,4(%eax)
c;

code l!   ( n addr -- )  pop %eax ; pop %ecx ; mov %ecx,(%eax)  c;
code w!   ( w addr -- )  pop %eax ; pop %ecx ; mov %cx,(%eax)   c;
code c!   ( c addr -- )  pop %eax ; pop %ecx ; mov %cl,(%eax)   c;

\ unaligned-d! stores the low cell at addr, the high cell at addr+4
code unaligned-d!   ( d addr -- )
   pop %eax
   pop %ecx
   pop %edx
   mov %edx,(%eax)
   mov %ecx,4(%eax)
c;
code unaligned-!   ( n addr -- )  pop %eax ; pop %ecx ; mov %ecx,(%eax)  c;
code be-l!   ( n addr -- )
   pop %eax
   pop %ecx
   bswap %ecx
   mov %ecx,(%eax)
c;
\ In some versions, be-l, needs to set a swap bit
: be-l,  ( l -- )  here /l allot  be-l!  ;
code unaligned-l!   ( n addr -- )  pop %eax ; pop %ecx ; mov %ecx,(%eax)  c;
code unaligned-w!   ( w addr -- )  pop %eax ; pop %ecx ; mov %cx,(%eax)   c;

code 2@  ( addr -- d )
   pop %eax
   pushl 4(%eax)
   pushl (%eax)
c;
code 2!  ( d addr -- )
   pop %eax
   pop %ecx
   pop %edx
   mov %ecx,(%eax)
   mov %edx,4(%eax)
c;

code fill  ( start-addr count char -- )
   SAVEIP
   pop %eax
   pop %ecx
   pop %edi
   rep stosb
   RESTIP
c;

code noop ( -- )  c;

code n->l ( n.unsigned -- l )  c;
: s>d  ( n -- d )  dup 0<  ;  \ Depends on  true=-1, false=0

code wbsplit ( l -- b.low b.high )
   pop %eax
   movzbl %al,%ecx
   push %ecx
   movzbl %ah,%eax
   push %eax
c;

code bwjoin ( b.low b.high -- w )
   pop %eax
   pop %ecx
   movzbl %al,%eax
   movzbl %cl,%ecx
   shl $8,%eax
   or %ecx,%eax
   push %eax
c;

code lwsplit ( l -- w.low w.high )  \ split a long into two words
   pop %eax
   movzwl %ax,%ecx
   push %ecx
   shr $16,%eax
   push %eax
c;
code wljoin ( w.low w.high -- l )
   pop %eax
   pop %ecx
   movzwl %cx,%ecx
   shl $16,%eax
   or %ecx,%eax
   push %eax
c;

1 constant /c
2 constant /w
4 constant /l
8 constant /x

/l constant /n

code ca+  ( addr index -- addr+index*/c )  pop %eax ; add %eax,(%esp)  c;
code wa+  ( addr index -- addr+index*/w )
   pop %eax
   shl $1,%eax
   add %eax,(%esp)
c;
code la+  ( addr index -- addr+index*/l )
   pop %eax
   shl $2,%eax
   add %eax,(%esp)
c;
code na+  ( addr index -- addr+index*/n )
   pop %eax
   shl $2,%eax
   add %eax,(%esp)
c;
code ta+  ( addr index -- addr+index*/t )
   pop %eax
   shl $2,%eax
   add %eax,(%esp)
c;

code ca1+  ( addr -- addr+/c )      incl (%esp)    c;
code char+ ( addr -- addr+/c )      incl (%esp)    c;
code wa1+  ( addr -- addr+/w )      addl $2,(%esp)  c;
code la1+  ( addr -- addr+/l )      addl $4,(%esp)  c;
code na1+  ( addr -- addr+/n )      addl $4,(%esp)  c;
code cell+ ( addr -- addr+/n )      addl $4,(%esp)  c;
code ta1+  ( addr -- addr+/token )  addl $4,(%esp)  c;

code /c*   ( n -- n*/c )  c;
code chars ( n -- n*/c )  c;
code /w*   ( n -- n*/w )  shll $1,(%esp)  c;
code /l*   ( n -- n*/l )  shll $2,(%esp)  c;
code /x*   ( n -- n*/x )  shll $3,(%esp)  c;
code /n*   ( n -- n*/n )  shll $2,(%esp)  c;
code cells ( n -- n*/n )  shll $2,(%esp)  c;

code upc ( char -- upper-case-char )
   mov (%esp),%eax
   cmp $0x61,%eax
   jl 1f
   cmp $0x7a,%eax
   jg 1f
   subl $0x20,(%esp)
1:
c;
code lcc ( char -- lower-case-char )
   mov (%esp),%eax
   cmp $0x41,%eax
   jl 1f
   cmp $0x5a,%eax
   jg 1f
   addl $0x20,(%esp)
1:
c;

\ string compare - case sensitive
code comp ( addr1 addr2 len -- -1 | 0 | 1 )
   SAVEIP
   pop %ecx
   pop %edi
   pop %esi
   xor %eax,%eax
   test %ecx,%ecx
   jz 1f
   repe cmpsb
   je 1f
   mov $1,%eax
   ja 1f			\ The byte from addr1 is greater
   mov $-1,%eax
1: RESTIP
   push %eax
c;

\ string compare - case insensitive
code caps-comp ( addr1 addr2 len -- -1 | 0 | 1 )
   SAVEIP
   pop %ecx
   pop %edi
   pop %esi
   xor %eax,%eax
1: test %ecx,%ecx
   jz 4f
   movzbl (%esi),%ebx
   movzbl (%edi),%edx
   inc %esi
   inc %edi
   dec %ecx
   cmp $0x61,%ebx
   jb 2f
   cmp $0x7a,%ebx
   ja 2f
   sub $0x20,%ebx
2: cmp $0x61,%edx
   jb 3f
   cmp $0x7a,%edx
   ja 3f
   sub $0x20,%edx
3: cmp %edx,%ebx
   je 1b
   mov $1,%eax
   ja 4f
   mov $-1,%eax
4: RESTIP
   push %eax
c;

\ Copies from the top down so that "to" may overlap the source string
code pack  ( str-addr len to -- to )
   SAVEIP
   pop %edx			\ to
   pop %ecx			\ len
   pop %esi			\ from
   and $0xff,%ecx		\ Never store more than 257 bytes
   mov %cl,(%edx)		\ Place length byte
   movb $0,1(%edx,%ecx)		\ Put a null byte at the end
   lea (%edx,%ecx),%edi		\ Last destination byte
   lea -1(%esi,%ecx),%esi	\ Last source byte
   std
   rep movsb
   cld
   RESTIP
   push %edx
c;

code (')  ( -- acf )
   lodsl
   push %eax
c;

\ Modifies caller's ip to skip over an in-line string
code skipstr ( -- addr len)
   mov (%ebp),%eax		\ Get string address
   movzbl (%eax),%ecx		\ Get length byte
   lea 1(%eax),%edx		\ Address of data bytes
   push %edx
   push %ecx
   lea 4(%edx,%ecx),%eax	\ Skip the data and the null byte,
   and $-4,%eax			\ round up to a token boundary
   mov %eax,(%ebp)		\ Put the modified ip back
c;
code (")  ( -- addr len)
   movzbl (%esi),%ecx		\ Get length byte
   lea 1(%esi),%edx		\ Address of data bytes
   push %edx
   push %ecx
   lea 4(%edx,%ecx),%esi
   and $-4,%esi
c;
code count  ( addr -- addr+1 len )
   pop %eax
   movzbl (%eax),%ecx
   inc %eax
   push %eax
   push %ecx
c;

code between ( n min max -- f )
   pop %ecx			\ max
   pop %edx			\ min
   pop %eax			\ n
   xor %ebx,%ebx
   cmp %edx,%eax
   jl 1f
   cmp %ecx,%eax
   jg 1f
   dec %ebx
1: push %ebx
c;

code within ( n1 min max+1 -- f )
   pop %ecx			\ max
   pop %edx			\ min
   pop %eax			\ n
   xor %ebx,%ebx
   cmp %edx,%eax
   jl 1f
   cmp %ecx,%eax
   jge 1f
   dec %ebx
1: push %ebx
c;

code bounds ( adr len -- adr+len adr )
   pop %ecx
   pop %eax
   add %eax,%ecx
   push %ecx
   push %eax
c;

code origin  ( -- addr )  push $origin  c;
code origin+  ( n -- adr )  addl $origin,(%esp)  c;
code origin-  ( n -- adr )  subl $origin,(%esp)  c;

\ The x86 keeps the instruction cache coherent with data stores
code i-flush  ( adr -- )  add $4,%esp  c;
code instruction!  ( bits adr -- )
   pop %eax
   pop %ecx
   mov %ecx,(%eax)
c;

: instruction, ( opcode -- )
   here /l allot instruction!
;

\ ---- Support words for the incremental compiler

headerless

\ Put a 5-byte relative call instruction to target-addr at where
: put-call  ( target-addr where -- )
   h# e8 over c!  tuck 5 + -  swap 1+ l!
;

\ Put a 5-byte relative jump instruction to target-addr at where
: put-branch  ( target-addr where -- )
   h# e9 over c!  tuck 5 + -  swap 1+ l!
;

\ The does> clause of a defining word:  "call dodoes" padded to 8 bytes
: place-call  ( action-adr -- )
   acf-align  here  8 allot     ( action-adr adr )
   tuck put-call                ( adr )
   5 +  3 h# 90 fill
;

\ Place the "standard" code field, a token for the action code
: place-cf  ( action-adr -- )  acf-align  token,  ;

: code-cf  ( -- )  acf-align  here ta1+ token,  ;

: >code  ( acf-of-code-word -- address-of-start-of-machine-code )
   >body
;
: code? ( acf -- f )  dup token@ swap >body =  ;

headers
\ Assemble "next":   lodsl   jmp *(%eax)
: next  ( -- )  h# ad c,  h# 20ff w,  ;

headerless

\ The "word type" is a number that distinguishes one type of
\ word from another.  This is highly implementation-dependent.
\ For the x86 implementation, it is the address of the action code.

headers

: word-type  ( acf -- word-type )  token@  ;

headerless

: create-cf    ( -- )  docreate   place-cf  ;
: place-does   ( -- )  dodoes     place-call  ;
: place-;code  ( -- )  ;

\ Ip is assumed to point to (;code .  flag is true if
\ the code at ip is a does> clause as opposed to a ;code clause.
: does-ip?  ( ip -- ip' flag )
   dup token@  ['] (does>) =  ( ip flag )
   if   ta1+ acf-aligned la1+ la1+  true  else  ta1+ acf-aligned false  then
;

: put-cf  ( action-clause-addr where -- )  token!  ;

\  used  sets the code field of the most-recently-defined word
\ so that it executes the code at action-clause-addr
: used  ( action-clause-addr -- )  lastacf put-cf  ;

\  Indicate whether the given address has the code-field of a does-clause.
\      (I.e., the call to  dodoes).
\  Leave the address, return a flag.
: does-clause? ( addr -- addr flag )
   dup c@ h# e8 =  if
      dup 1+ l@  over 5 + +  dodoes =  exit
   then
   false
;

\  Indicate whether given ACF is of a word that was defined with
\       does> .  If so, return the  does-cfa  under the  true.
: does-cf? ( possible-acf -- does-cfa true | false )
   word-type  does-clause?  ?dup nip
;

headers
\ Need this to make headerless work
: colon-cf  ( -- )  docolon place-cf  ;
headerless
: colon-cf?  ( possible-acf -- flag )  token@  docolon =  ;
: user-cf  ( -- )  douser place-cf  ;
: value-cf  ( -- )  dovalue place-cf  ;
: constant-cf  ( -- )  doconstant place-cf  ;
: defer-cf  ( -- )  dodefer place-cf  ;
\  Indicate whether the word whose ACF is given
\  was defined with  defer .
: defer?  ( acf -- flag )  word-type dodefer =  ;
: 2constant-cf  ( -- )  do2constant place-cf  ;

4 constant /branch
: branch, ( offset -- )  l,  ;
: branch! ( offset where -- )  l!  ;
: branch@ ( where -- offset )  <l@  ;
\ >target depends on the way that branches are compiled
: >target  ( ip-of-branch-instruction -- target )  ta1+ dup branch@ +  ;

\ ---- More ordinary Forth words.

headers
/l constant /a
code a@  ( adr -- adr' )  pop %eax ; pushl (%eax)  c;
code a!  ( adr1 adr2 -- )  pop %eax ; pop %ecx ; mov %ecx,(%eax)  c;
: a,  ( adr -- )  here  /a allot  a!  ;

/l constant /token
code token@ ( addr -- cfa )  pop %eax ; pushl (%eax)  c;
code token! ( cfa addr -- )  pop %eax ; pop %ecx ; mov %ecx,(%eax)  c;

: token, ( cfa -- )  here  /token allot  token!  ;

code null  ( -- token )  push $origin  c;
: !null-link   ( adr -- )  null swap link!  ;
: !null-token  ( adr -- )  null swap token!  ;
code non-null?  ( link -- false | link true )
   pop %eax
   cmp $origin,%eax
   je 1f
   push %eax
   push $-1
   NEXT
1: push $0
c;
: get-token?     ( adr -- false | acf  true )  token@ non-null?  ;
: another-link?  ( adr -- false | link true )  link@  non-null?  ;

code body> ( pfa -- cfa )  subl $4,(%esp)  c;
code >body ( cfa -- pfa )  addl $4,(%esp)  c;
/l constant /user#

\ Move to a machine alignment boundary.
\ The x86 does not require alignment, but we align cells for speed and
\ code fields so that the dictionary layout matches the other ports.

: round-down  ( adr granularity -- adr' )  1- invert and  ;
: round-up  ( adr granularity -- adr' )  1-  tuck +  swap invert and  ;
: (align)  ( size granularity -- )
   1-  begin  dup here and  while  0 c,  repeat  drop
;
: aligned  ( adr -- adr' )  3 + -4 and  ;

code acf-aligned  ( adr -- adr' )
   addl $3,(%esp)
   andl $-4,(%esp)
c;
: acf-align  ( -- )  #acf-align (align)  here 'lastacf token!  ;

headers
: /mod  ( dividend divisor -- remainder quotient )
  \ Check if either factor is negative
    2dup               ( n1 n2 n1 n2)
    or 0< if           ( n1 n2)

        \ Both factors not non-negative do division by:
        \ Take absolute value and do unsigned division
        \ Convert to truncated signed divide by:
        \  if dividend is negative then negate the remainder
        \  if dividend and divisor have opposite signs then negate the quotient
        \ Then convert to floored signed divide by:
        \  if quotient is negative and remainder is non-zero
        \    add divisor to remainder and decrement  quotient

        2dup swap abs swap abs  ( n1 n2 u1 u2)     \ Absolute values

        u/mod              ( n1 n2 urem uqout)     \ Unsigned divide
        >r >r              ( n1 n2) ( uquot urem)

        over 0< if         ( n1 n2) ( uquot urem)
            r> negate >r                   \ Negative dividend; negate remainder
        then               ( n1 n2) ( uquot trem)

        swap over          ( n2 n1 n2) ( uquot trem)
        xor 0< if          ( n2) ( uquot trem)
            r> r>
            negate         ( n2 trem tquot)  \ Opposite signs; negate quotient
           -rot            ( tquot n2 trem)
            dup 0<>  if
                +          ( tquot rem) \ Negative quotient & non-zero remainder
                swap 1-    ( rem quot)  \ add divisor to rem. & decrement  quot.
            else
                nip swap   ( rem quot)
            then
        else
            drop r> r>     ( rem quot)
        then

    else   \ Both factors non-negative

        u/mod          ( rem quot)
    then
;

: /     ( n1 n2 -- quot )   /mod  nip ;

: mod   ( n1 n2 -- rem )    /mod  drop  ;

headerless
\ The x86 version is linked at a fixed address, so we don't need a
\ relocation bitmap
: clear-relocation-bits  ( adr len -- )  2drop  ;
headers
