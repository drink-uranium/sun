id: @(#)filecode.fth 1.1 26/10/18
purpose: x86 code words to support the file system interface
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Copyright 1990-2002 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

headerless
\ signed mixed mode addition (same as + on the x86)
code ln+   (s n1 n2 -- n3 )  pop %eax ; add %eax,(%esp)  c;

\ &ptr is the address of a pointer.  fetch the pointed-to
\ character and post-increment the pointer

code @c@++ ( &ptr -- char )
   pop %eax
   mov (%eax),%ecx		\ Fetch the pointer
   incl (%eax)			\ Increment the pointer
   movzbl (%ecx),%ecx		\ Get the byte
   push %ecx
c;

\ &ptr is the address of a pointer.  store the character into
\ the pointed-to location and post-increment the pointer

code @c!++ ( char &ptr -- )
   pop %eax
   pop %edx			\ char
   mov (%eax),%ecx		\ Fetch the pointer
   mov %dl,(%ecx)		\ Put the byte
   incl (%eax)			\ Increment the pointer
c;

\ "adr1 len2" is the longest initial substring of the string "adr1 len1"
\ that does not contain the character "char".  "adr2 len1-len2" is the
\ trailing substring of "adr1 len1" that is not included in "adr1 len2".
\ Accordingly, if there are no occurrences of that character in "adr1 len1",
\ "len2" equals "len1", so the return values are "adr1 len1  adr1+len1 0"

code split-string  ( adr1 len1 char -- adr1 len2  adr1+len2 len1-len2 )
   pop %eax			\ char
   pop %ecx			\ len1
   mov (%esp),%edx		\ adr1
   SAVEIP
   mov %ecx,%ebx		\ len1
   mov %edx,%edi
   test %ecx,%ecx
   jz 1f
   repne scasb
   jne 1f
   dec %edi			\ Point to the delimiter
1: mov %edi,%ecx		\ adr1+len2
   mov %edi,%eax
   sub %edx,%eax		\ len2
   sub %eax,%ebx		\ len1-len2
   RESTIP
   push %eax
   push %ecx
   push %ebx
c;

headers

nuser delimiter  \ delimiter actually found at end of word

nuser file

\ Run-time action for file descriptor fields.  The fields are defined
\ with file-field, which the metacompiler implements.
code-field: dofield
   mov 4(%eax),%ecx		\ Get the structure member offset
   add {'user file}(%edi),%ecx	\ Add the structure base address
   push %ecx
c;
