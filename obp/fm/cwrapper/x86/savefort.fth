id: @(#)savefort.fth 1.1 26/10/18
purpose: Save the Forth dictionary to a file (x86)
copyright: Copyright 1985-1990 Bradley Forthware
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ save-forth  ( filename -- )
\	Saves the Forth dictionary to a file so it may be later used under Unix
\
\ save-image  ( init-routine-name filename -- )
\	Primitive save routine.  Saves the dictionary image to a file.
\	The latest definition whose name is the same as the
\	"init-routine-name" argument is installed as the init-environment
\	routine.
\
\ The x86 image file is a memory image of the dictionary, starting at the
\ origin, followed by the initial user area image.  The header at the
\ origin (see fm/kernel/x86/metainit.fth) records the sizes, so there is
\ no separate file header.

only forth also hidden also  forth definitions

headerless
: text-size  ( -- size-of-dictionary )  here origin - aligned  ;

\ Record the image layout in the header at the origin
: set-image-header  ( -- )
   text-size  origin 4 + l!
   user-size  origin 8 + l!
;

: save-image  ( init-routine-name filename -- )
   new-file   ( init-routine-name )

   init-save  ( )
   set-image-header

   origin   text-size     ofd @  fputs		\ Write dictionary
   up@      user-size     ofd @  fputs		\ Write user area
   ofd @ fclose
;
headers

\ Save an image of the target system in a file.
: save-forth  ( str -- )
   >r
   " unix-init-io"  $find-name is init-io
   " unix-init" r>  save-image
;

only forth also definitions
