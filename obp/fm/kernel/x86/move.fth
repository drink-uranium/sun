id: @(#)move.fth 1.1 26/10/18
purpose: x86 memory move primitive
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ (move) copies cnt bytes from src to dst, correctly handling overlap
\ in either direction.  Longword moves are used for the bulk of the copy.
code (move)  ( src dst cnt -- )
   SAVEIP
   pop %ecx			\ cnt
   pop %edi			\ dst
   pop %esi			\ src
   cmp %esi,%edi
   je 3f
   ja 2f			\ dst > src: copy high-to-low
   mov %ecx,%edx		\ Copy low-to-high
   shr $2,%ecx
   rep movsl
   mov %edx,%ecx
   and $3,%ecx
   rep movsb
   jmp 3f
2: lea -1(%esi,%ecx),%esi	\ Copy high-to-low
   lea -1(%edi,%ecx),%edi
   std
   rep movsb
   cld
3: RESTIP
c;
defer move
' (move) is move
