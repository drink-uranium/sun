id: @(#)extra.fth 1.1 26/10/18
purpose: x86 kernel code words not used in the "run-time" version
copyright: Copyright 1994-2003 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 1985-1994 Bradley Forthware
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ Definitions originally from kerncode.fth which are not used in the
\ "run-time" version.  This file also contains the multiply and divide
\ primitives, which are in separate files in the SPARC port.
hex

\ Execute a Forth word given a pointer to a code field address
code perform ( addr-of-acf -- )
   pop %eax
   mov (%eax),%eax
   jmp *(%eax)
end-code

\ Select a vocabulary thread by hashing the lookup name.
\ There is only one thread per vocabulary in this implementation.
headerless
code hash  ( str-addr voc-apf -- thread )
   pop %eax
   mov 4(%eax),%eax		\ Get the user number
   add %edi,%eax		\ Find the address of the threads
   mov %eax,(%esp)
c;
headers

\ Search a vocabulary thread (link) for a name matching string.
\ The link argument is the address of a cell containing the code field
\ address of the most recent word in the thread.  The link field of each
\ word contains the code field address of the next word in the thread,
\ or the origin at the end of the thread.
\
\ Name field:
\     name: forth-style string, count byte at the END
\     count byte: 80 bit always set, 40 bit is immediate, 20 bit is alias
\ The link field follows the count byte, then the code field.

code ($find-next)  ( adr len link -- adr len alf true  |  adr len false )
   SAVEIP
   pop %ebx			\ Address of the first link
   mov (%esp),%ecx		\ String length
   mov 4(%esp),%edx		\ String address
1: mov (%ebx),%ebx		\ Next acf
   cmp $origin,%ebx		\ Test for end of list
   je 3f
   sub $4,%ebx			\ >link
   movzbl -1(%ebx),%eax		\ Count byte
   and $0x1f,%eax
   cmp %ecx,%eax		\ Compare lengths
   jne 1b
   lea -1(%ebx),%edi		\ Start of the name
   sub %ecx,%edi
   mov %edx,%esi
   mov %ecx,%eax
   repe cmpsb
   mov %eax,%ecx
   jne 1b			\ The names did not match
   RESTIP
   push %ebx			\ Push alf above str$
   push $-1			\ True on top of stack means "found"
   NEXT
3: RESTIP
   push $0
c;

headers
: ?negate  ( n1 n2 -- n3 )  if  negate  then  ;

code wflip ( l1 -- l2 )  \ word-swap the low two words
   roll $16,(%esp)
c;

code toggle  ( addr byte-mask -- )
   pop %eax
   pop %ecx
   xor %al,(%ecx)
c;
code log2 ( n -- log2-of-n )
   pop %eax
   mov $-1,%ecx			\ Return -1 if N was zero
   test %eax,%eax
   jz 1f
   bsr %eax,%ecx
1: push %ecx
c;
\
\  Extract some of the rightmost bits from a cell
code bits ( mask #bits -- mask' bits )
   pop %ecx			\ #bits
   mov (%esp),%eax		\ mask
   mov %eax,%edx
   shr %cl,%edx
   mov %edx,(%esp)		\ mask' => next-on-stack
   mov $1,%edx
   shl %cl,%edx
   dec %edx
   and %edx,%eax		\ lowbits
   push %eax
c;

code s->l ( n.signed -- l )  c;
code l->n ( l -- n )  c;
code n->a     ( n -- a )  c;
code l->w ( l -- w )  andl $0xffff,(%esp)  c;
code n->w ( n -- w )  andl $0xffff,(%esp)  c;

code l>r  ( l -- )     pop %eax ; lea -4(%ebp),%ebp ; mov %eax,(%ebp)  c;
code lr>  ( -- l )     pushl (%ebp) ; lea 4(%ebp),%ebp  c;
code lr@  ( -- l )     pushl (%ebp)  c;

headerless
code /t* ( n -- n*/t )  shll $2,(%esp)  c;
headers

#talign-t constant #talign	\ Alignment of tokens compiled in colon defs.

/l constant #linkalign
/l constant #align		\ Hardware alignment: instruction, word fetches

/l constant #acf-align		\ Code field alignment

: align  ( -- )  #align (align)  ;
: talign  ( -- )  #talign (align)  ;
: taligned  ( adr -- adr' )  #talign round-up  ;
\ headerless
: linkalign  ( -- )  #linkalign (align)  ;
headers

\ Multiplication and division

code um*   ( u1 u2 -- ud[lo hi] )
   pop %eax
   mull (%esp)
   mov %eax,(%esp)
   push %edx
c;

: *  ( n1 n2 -- n3 )  um* drop  ;

code u/mod  (s u.dividend u.divisor -- u.remainder u.quotient )
   pop %ecx
   pop %eax
   test %ecx,%ecx
   jz 1f
   xor %edx,%edx
   div %ecx
   push %edx			\ remainder
   push %eax			\ quotient
   NEXT
1: push $-10			\ Division by zero
   mov $f_throw,%eax
   jmp *(%eax)
end-code

: u*  ( un1 un2 -- product )  um* drop  ;
