id: @(#)metainit.fth 1.1 26/10/18
purpose: x86 kernel image header and metacompiler initialization
copyright: Copyright 1994-2003 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ The x86 Forth image is a memory image that is loaded at a fixed address
\ (the origin).  The first 32 bytes of the image are a header that tells
\ the loader (the Unix wrapper program or the firmware boot stub) how to
\ start Forth.  The user area initialization image follows the dictionary,
\ at origin + text-size.  The header is updated when the image is saved
\ again with save-forth.
\
\    origin+00  magic "OB86"
\    origin+04  text size: the offset of the initial user area image
\    origin+08  user area size
\    origin+0c  address of cold-code
\    origin+10  origin (the address at which the image must be loaded)
\    origin+14  reserved (0)
\    origin+18  reserved (0)
\    origin+1c  reserved (0)

hex

code-field: image-header
   .ascii "OB86"
   .long dict_end - origin
   .long user_size
   .long cold_entry
   .long origin
   .long 0, 0, 0
end-code

\ Stack sizes
/n-t th 1000 * constant ps-size-t
/n-t th 1000 * constant rs-size-t
/l-t constant /user#-t
