id: @(#)model.fth 1.1 26/10/18
purpose: /openprom model and version properties
copyright: Copyright 1995-2002 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

headers
" /openprom" find-device
   " OpenBoot,"        encode-bytes
   obp-release count   encode-bytes+
   " ,"                encode-bytes+
   sub-release count   encode-bytes+  " model" property

   " OBP "            encode-bytes
   obp-release count  encode-bytes+
   "  "               encode-bytes+
   compile-signature  compile-date$  encode-string encode+  " version" property
device-end
