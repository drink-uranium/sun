id: @(#)checkpt.fth 1.1 26/10/18
purpose: Exception frames (catch/throw) for the x86 kernel
copyright: Copyright 2005 Sun Microsystems, Inc.  All Rights Reserved
copyright: Copyright 2026 The OpenBoot x86 port contributors
copyright: Use is subject to license terms.

\ Checkpt
\ 
\ a checkpt is like a setjmp/longjmp in C. (man setjmp)
\ 
\ push-checkpt : Create an exception frame and push it onto the exception 
\                stack

\ pop-checkpt :  Dispose the current exception frame.
\
\ The catch and throw are special cases of checkpts.
\
\ One of the difference between a push-checkpt and a 'catch' is that 
\ the catch calls the thing it is trying to catch, a checkpoint does 
\ not have this restriction.  Looking at the tail end of 'catch' in 
\ the normal execution case it pops the handler, which is the exact 
\ equivalent of 'pop-checkpt'.
\
\ The primary difference is that you can mark a checkpoint at an arbitrary 
\ point and 'recover' much like a 'catch' does except that you are no 
\ longer on the same descending call frame (e.g., return stack).
\
\ So, consider
\ 	: xxx cmn-error[ ..-1 throw ... ]cmn-end ;
\       : yyy ['] xxx catch ;
\
\ The throw destroys the error frame by returning control to the 'catch'.
\
\ Now if cmn-error[ was implemented:
\
\ 	: (]cmn-end) ... ;
\ 	: cmn-error[
\ 	   push-checkpt ?dup if
\ 		" [truncated]" (]cmn-end)
\ 		throw
\          else
\		<start the message>
\          then
\  	;
\
\	: ]cmn-end (]cmn-end) pop-checkpt ;
\
\ What we have done is ensure that an error inside an error message 
\ frame is constrained in a recoverable manner and the original 'throw' 
\ is propogated to the catch in yyy.
\
\ The magic is that 'cmn-error[' returned to its caller normally and the 
\ caller xxx drove on, but on ERROR the code jumped back into the cmn-error[ 
\ routine which then had to throw. If it had not then the '-1 throw' would 
\ execute again (assuming no other disasterous stack effects).
\ 
\ To be a good citizen you should only 'recover' from an error and
\ not propogate a throw if you know that the throw code is yours (as
\ in the example).
\ 
\ In general it is bad practice to return from the routine that
\ established the check point (ie the routine that called 'push-checkpt'),
\ though a maximum unnest of /check-stack stack elements will permit this
\ to work.
\
\    IT IS BEST *NOT* TO RETURN FROM THE CHECKPOINT FRAME;
\    THOUGH IT WILL WORK IN MANY CASES
\
\ This is a similar restriction to setjmp/longjmp in C.
\
\ Frame Starts		Frame Ends
\    push-checkpt	pop-checkpt, throw
\    catch		throw
\


headers
nuser checkpt				\ most recent checkpoint
nuser checkbase				\ frames
nuser checktrack			\ tracker
nuser checkalloc			\ counter
nuser checkmax				\ max frames
nuser checknested

h# 80 constant /check-max		\ frames alloc'd after dynamic heap
h# 10 constant /check-crit		\ frames alloc'd from critical heap
headerless
8 constant /check-stack			\ How many elements to preserve
					\ sized for known catch stack usage

\ Frame layout.  The SPARC kernel computes these offsets with struct and
\ field in the metacompiler; the code words below depend on them.
\
\   00  >check-prev	previous frame
\   04  >check-ip	checkpt IP
\   08  >check-sp	checkpt DS pointer
\   0c  >check-rp	checkpt RS pointer
\   10  >check-myself	my-self
\   14  >check-age
\   18  >check-ds	a chunk of the DS (/check-stack cells)
\   38  >check-rs	a chunk of the RS (/check-stack cells)
d# 88 constant /check-frame

: >check-prev	( frame -- adr )  ;
: >check-myself	( frame -- adr )  h# 10 +  ;
: >check-age	( frame -- adr )  h# 14 +  ;

headers
0 value my-self
headerless

\ initial 16 frames are allocated from the critical heap
: init-checkpt
   checkpt off
   checkalloc off
   checknested off
   /check-crit checkmax !
   /check-crit dup alloc-mem dup checktrack !		( va )
   swap erase						( len va )
   /check-crit /check-frame * /n +			( sz )
   alloc-mem /n 1- + /n 1- invert and checkbase !	( )
;

\ dynamic heap is installed before we call into this so that the frame alloc
\ requirements can be satisfied by the expanded heap made available.
\ the alloc-mem calls will cause checkpt frames to be alloc/free'd due to 
\ calls to 'catch', relying on a coherent state in the checkpt variables,
\ so the expanded allocations must not be swapped in until after they complete.
\
: alloc-checkpt
   \ alloc max checktrack and copy critical heap checktrack
   checktrack @ >r r@ 				( oldt ) ( r: t )
   /check-max dup alloc-mem 	 		( oldt len newt )
   dup rot erase swap				( newt oldt )
   /check-crit bounds do i c@ over c! 1+ loop	( newt' )
   /check-crit -				( newt )

   \ alloc max checkpt frames and copy critical heap frames
   checkbase @ >r r@ tuck			( oldb newt oldb ) ( r: t b )
   /check-max /check-frame * /n +		( oldb newt oldb len )
   alloc-mem /n 1- + /n 1- invert and		( oldb newt oldb newb )
   swap /check-crit /check-frame * bounds	( oldb newt newb hi lo )
   2dup /check-frame + 2>r			( oldb newt newb hi lo )
   do i @ over ! na1+ /n +loop			( oldb newt newb' )
   /check-crit /check-frame * -			( oldb newt newb )

   \ having copied the old frames to the new now patch the >check-prev ptrs
   \ start at second frame of old and new frames as first frame has null ptr
   2 pick over /check-frame + 2r> do		( oldb newt newb oldb newb' )
      over i @ swap - 3 pick + over !		( oldb newt newb oldb newb'' )
   /check-frame + /check-frame +loop		( oldb newt newb oldb newb'' )
   2drop					( oldb newt newb )

   \ now swap in expanded frame allocations after fully initialized
   \ update checkpt to current frame in newly allocate frames
   checkbase ! checktrack !			( oldb )
   checkpt @ ?dup if				( oldb cur )
      swap - checkbase @ + checkpt !		( )
   else						( oldb )
      drop					( )
   then						( )
   /check-max checkmax !			( ) ( r: t b )

   r> /check-crit /check-frame * free-mem	( ) ( r: t )
   r> /check-crit free-mem			( )
;

\
\ returns false the first time it is called (by push-checkpt)
\ returns the throw code when the saved state is restored by restore-checkpt
\ The /check-stack data stack items below the frame argument and the
\ /check-stack top return stack items are saved in the frame, along with
\ the ip and the stack pointers as they would be with those items removed.
code save-checkpt ( frame -- 0 )
   pop %eax			\ frame
   mov %esi,4(%eax)		\ >check-ip
   mov %esp,%edx		\ data stack walker
   mov %ebp,%ebx		\ return stack walker
   mov $0x20,%ecx		\ /check-stack cells
1: sub $4,%ecx
   mov (%edx),%esi
   add $4,%edx
   mov %esi,0x18(%eax,%ecx)	\ >check-ds
   mov (%ebx),%esi
   add $4,%ebx
   mov %esi,0x38(%eax,%ecx)	\ >check-rs
   test %ecx,%ecx
   jnz 1b
   mov %edx,8(%eax)		\ >check-sp
   mov %ebx,0x0c(%eax)		\ >check-rp
   mov 4(%eax),%esi		\ Restore ip
   push $0
c;

\ restore-checkpt restarts the code following the save-checkpt that
\ created the frame, by restoring the IP and the saved stack items, and
\ then leaving the throw code on the stack.
code restore-checkpt ( code frame -- code )
   pop %eax			\ frame
   pop %edx			\ code
   mov 4(%eax),%esi		\ >check-ip
   mov 8(%eax),%esp		\ >check-sp
   mov 0x0c(%eax),%ebp		\ >check-rp
   xor %ecx,%ecx
1: pushl 0x18(%eax,%ecx)
   mov 0x38(%eax,%ecx),%ebx
   lea -4(%ebp),%ebp
   mov %ebx,(%ebp)
   add $4,%ecx
   cmp $0x20,%ecx
   jne 1b
   push %edx
c;

\ We free 16 frames - and hope this is enough to go interactive again
\ may be useful to increase for debugging
\ we only get here if we ran out of frames
\ 
: free-oldest-frames ( -- )
   h# 10 0 do
     checkalloc @ 0 checkmax @ 0 ?do		( age n )
       over					( age n age )
       checkbase @ i /check-frame * +		( age n age ptr )
       >check-age l@				( age n age age-2 )
       tuck >					( age n age-2 old? )
       checktrack @ i + c@ 0<>			( age n age-2 old? used? )
       and if					( age n age-2 )
          nip nip i leave			( age' i )
       else					( age n age-2 )
          drop					( age n )
       then					( age' i )
     loop					( age n )
     checktrack @ + 0 swap c! drop		( )
   loop
;

\ We track individual allocs so that on an error (no more frames)
\ we can find the 'oldest' and try to reuse them. This will (hopefully)
\ give some insight into what the latest sequence of failures was.
\ 
: alloc-frame ( -- n )
   1 checkalloc +!				( )
   -1 checktrack @ checkmax @ bounds ?do 	( -1 )
      i c@ 0= if				( -1 )
         i c!					( )
         i checktrack @ - leave			( n )
      then					( n )
   loop						( n )
   dup 0< if
      free-oldest-frames			( )
      ." FATAL: no exception frames available, "
      checknested @ checknested on if
         ." NESTED ERRORs, going interactive" cr
         begin interact again
      else
         ." forcing misaligned trap" cr
         -1 @
      then
   then
   /check-frame * checkbase @ +			( n )
   checkalloc @ over >check-age l!		( n )
;

: free-frame ( ptr -- )
   0 swap checkbase @ - /check-frame / checktrack @ + c!
;

: (free-checkpt) ( frame -- )
   dup >check-prev @ checkpt !			( frame )
   free-frame					( )
;

headers

\ free all allocated frames. used to wipe out frames when reentering
\ obp (l1-a, halt, exception, etc). the allocated frames are stale and 
\ we prefer to begin with a complete set. otherwise, frames will
\ slowly leak as we exit/reenter forth (go, breakpoint, etc).
: reset-checkpts ( -- )
   checktrack @ checkmax @ erase
   checkpt off
;

\ Dispose the current exception frame.
\
: pop-checkpt ( -- ) checkpt @ ?dup if  (free-checkpt)  then ;

\ If a non-zero throw is done, then we unwind the current checkpoint
\
: throw ( n -- ) ?dup if  checkpt @ ?dup if  restore-checkpt  then  then ;

\
\ Create an exception frame and push it onto the exception stack
\
: push-checkpt ( ??? -- ??? code )
   alloc-frame >r				( ??? )
   checkpt @ r@ >check-prev !			( ??? )
   my-self r@ >check-myself l!			( ??? )
   r@ save-checkpt dup if			( ??? code )
      r>					( ??? code frame )
      dup >check-myself l@ is my-self		( ??? code frame )
      (free-checkpt)				( ??? code )
   else						( ??? 0 )
      r> checkpt !				( ??? 0 ) 
   then						( ??? code )
;

: catch ( ??? acf -- code )
   push-checkpt ?dup if
      nip
   else
      execute pop-checkpt 0
   then
;

chain: init
   init-checkpt
; 
