id: @(#)parseline.fth 1.1 26/10/18
purpose: x86 line splitting primitive
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Copyright 1990-2002 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ Splits a buffer into two parts around the first line delimiter
\ sequence.  A line delimiter sequence is either CR, LF, CR followed by LF,
\ or LF followed by CR.
\ adr1 len2 is the initial substring before, but not including,
\ the first line delimiter sequence.
\ adr2 len3 is the trailing substring after, but not including,
\ the first line delimiter sequence.

code parse-line  ( adr1 len1 -- adr1 len2  adr1+len2 len1-len2 )
   pop %ecx			\ len1
   mov (%esp),%edx		\ adr1
   xor %ebx,%ebx		\ Index
1: cmp %ecx,%ebx
   jae 3f			\ No delimiter in the string
   movzbl (%edx,%ebx),%eax
   cmp $0x0a,%eax
   je 2f
   cmp $0x0d,%eax
   je 2f
   inc %ebx
   jmp 1b
2: push %ebx			\ len2
   inc %ebx			\ Consume the first delimiter
   cmp %ecx,%ebx
   jae 4f
   xor $0x07,%eax		\ The other delimiter (0a <-> 0d)
   cmpb %al,(%edx,%ebx)
   jne 4f
   inc %ebx			\ Consume the other delimiter too
4: lea (%edx,%ebx),%eax
   push %eax			\ adr1+len2
   sub %ebx,%ecx
   push %ecx			\ len1-len2
   NEXT
3: push %ecx			\ len2 = len1
   lea (%edx,%ecx),%eax
   push %eax
   push $0
c;
