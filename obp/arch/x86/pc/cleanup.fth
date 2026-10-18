id: @(#)cleanup.fth 1.1 26/10/18
purpose: Final steps of the PC firmware build: dispose and save the image
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

headers

' (cold-hook is cold-hook

chain: finalize-chain ( -- )  here fence a! ;
overload: stand-init    ( -- )
   stand-init finalize-chain
   ['] startup catch ?dup if .error  then
;
overload: stand-init-io ( -- )  stand-init-io  ;
overload: init          ( -- )  init  ;

\ Install the various boot chains
' check-machine-state is check-machine-chain
' don't-boot? is interrupt-auto-boot?
' client-starting is client-starting-chain
' client-exited is client-exited-chain

\ Save the firmware image.  The image is the dictionary from the origin,
\ followed by the user area; the header at the origin records the sizes
\ (see fm/kernel/x86/metainit.fth).
: save-prom-image  ( file$ -- )
   2>r
   " stand-init-io"  $find-name is init-io
   " stand-init"     init-save
   here origin - aligned  origin 4 + l!	\ Text size
   user-size              origin 8 + l!	\ User area size
   up@ user-size  origin  here origin - aligned  2r>  ( up,len dic,len file$ )
   d# 45 d# 45 fsyscall
;

resident

\ Align dp to 16 bytes
here h# 10 round-up here - 0 ?do 0 c, loop

warning on

dispose 0 0 set-transize

' noop is title         \ Turn off the Bradley Forthware copyright message

\ If SAVEFILE is not [define]'d then we dont save an image.
" SAVEFILE" d# 55 d# 45 fsyscall dup 0=  if  2drop  else  save-prom-image  then

warning off
