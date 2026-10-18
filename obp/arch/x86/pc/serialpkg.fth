id: @(#)serialpkg.fth 1.1 26/10/18
purpose: Package body for a PC serial port
copyright: Copyright 2006 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ Loaded between begin-package and end-package by serial.fth, which sets
\ serial-console$ to the name of the port ("ttya" or "ttyb").

h# 8            constant tty-size
h# 1            constant #channels
my-address      constant tty-base

" serial"	2dup device-name
( serial )	device-type
" su16550"	encode-string
" su"	encode-string encode+ " compatible" property

tty-base h# 3f8 =  if  4  else  3  then  encode-int " interrupts" property

: en+ ( xdr,len int -- xdr',len' ) encode-int encode+ ;

my-space encode-int	tty-base en+	tty-size en+ " reg" property

serial-console$ count encode-string " console" property

fload ${BP}/dev/utilities/get-option.fth

: default-tty-mode     " 115200,8,n,1,-" ;
: (default-ttya-mode)  " ttya-mode" default-tty-mode  get-string-option ;
: (default-ttyb-mode)  " ttyb-mode" default-tty-mode  get-string-option ;

defer default-ttya-mode
defer default-ttyb-mode

: $=  ( adr1 len1 adr2 len2 -- equal? )
   rot tuck  <>  if  3drop false exit  then   ( adr1 adr2 len1 )
   comp 0=
;

: init-tty ( -- )
   " console" get-my-property 0=  if
      decode-string 2swap 2drop
      " ttya" $= if
         ['] (default-ttya-mode)
      else
         ['] (default-ttyb-mode)
      then
   else
      ['] default-tty-mode
   then
   dup  to default-ttya-mode  to default-ttyb-mode
;
init-tty

fload ${BP}/dev/serial/mode-data.fth
fload ${BP}/dev/serial/su16550/ioport.fth
fload ${BP}/dev/serial/mode-decode.fth
d# 115200 is max-baud
fload ${BP}/dev/serial/ttydriver.fth

: write ( adr len -- #written ) uwrite ;

