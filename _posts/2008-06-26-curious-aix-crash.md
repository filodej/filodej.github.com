--- 
name: curious-aix-crash
layout: post
time: 2008-06-26 17:20:00 +02:00
title: A curious AIX crash
categories: programming unix
---

Few days ago we had to solve an odd crash on AIX platform (powerpc chip). The company I am working in as a developer uses mainly 
MS Windows as a development platform but supports Linux as well as Unix platforms (namely AIX, HP-UX and Solaris). 

The crash was only on AIX and we was not able to replicate it on any other platform. Our Unix experience is not such as it 
should be so it is always painful process to solve it when such a platform specific bug appears.

What I am going to describe here is too technical and boring for a majority of people, and on the other side 
maybe too trivial for those UNIX developers more experienced than me, but I hope there could be some (evenly non-practiced) developers
out there who could find this information helpful or at least interesting.

The crash we experienced was easily replicable and was always at the same place - there was a totally innocent looking member
function, its code is something like the following:

    virtual T const& get( unsigned int id ) const
    {    <---------------------------- The crash was right here before anything happen
        if ( id < static_cast<unsigned int>( m_values.size() ) )
        return get_internal( id );
        throw ExceptionNotFound( LOCARG, id, count() );
        UNREACHABLE_RETURN( T() );
    }

The object instance was ok, the *id* parameter was in range <0, m_values.size() ), there was no apparent 
reason why it should crash. So it was necessary to sink at the assembly level. The code for this function
started as follows ([PowerPC Stack Attacks](http://felinemenace.org/~nemo/docs/ppcasm/ppc-stack-1.html) 
helped us to interpret the code):

    0x39927250 (get(unsigned int) const)      7c0802a6       mflr   r0            Function call prologue 
    0x39927254 (get(unsigned int) const+0x4)  93e1fffc        stw   r31,-4(r1)    routine (seems like the  
    0x39927258 (get(unsigned int) const+0x8)  93c1fff8        stw   r30,-8(r1)    registers are associated 
    0x3992725c (get(unsigned int) const+0xc)  93a1fff4        stw   r29,-12(r1)   with individual local
    0x39927260 (get(unsigned int) const+0x10) 9381fff0        stw   r28,-16(r1)   variables)
    0x39927264 (get(unsigned int) const+0x14) 9361ffec        stw   r27,-20(r1)
    0x39927268 (get(unsigned int) const+0x18) 9341ffe8        stw   r26,-24(r1)
    0x3992726c (get(unsigned int) const+0x1c) 90010008        stw   r0,0x8(r1)
    0x39927270 (get(unsigned int) const+0x20) 9421ed30       stwu   r1,-4816(r1) -> !Here was the segfault!
    0x39927274 (get(unsigned int) const+0x24) 83e2017c        lwz   r31,0x17c(r2)    
    0x39927278 (get(unsigned int) const+0x28) 83c20180        lwz   r30,0x180(r2)  What this code does is 
    ...                                                                            that a new stack frame 
                                                                                   is "created" and the 
                                                                                   stack pointer register 
                                                                                   (r1) is updated.
                                                                                   The "stwu" instruction  
                                                                                   stores the current  
                                                                                   content of the r1  
                                                                                   register at address  
                                                                                   computed as (r1-offset)  
                                                                                   and decrements the r1  
                                                                                   by offset at the same  
                                                                                   time (offset is 4816 
                                                                                   bytes in this case)

Initially we thought that due to the stack corruption the the stack pointer (`r1`) contain 
incorrect address (pointing to a read-only memory page) and so the write operation to that 
address failed. 

Here is the stack pointer register value:

    (dbx) registers
      $r0:0x3d1dd854  $stkp:0x400f5cb0   $toc:0x3a7071dc    $r3:0x40146fb0
      ...

When we looked to the address `0x400f5cb0` we could see an address of the previous frame,
at that address was the previous one and over and over. This way was possible to traverse
down to the stack and everything seemed consistent. The stack did not seem to be corrupted
at all.

    (dbx) 0x400f5cb0/4X
    0x400f5cb0:  400f5d00 00000000 3d2b2854 00000000      (   80 bytes)
    (dbx) 0x400f5d00/4X
    0x400f5d00:  400f7010 00000000 3d2b228c 00000000      ( 4880 bytes)
    (dbx) 0x400f7010/4X
    0x400f7010:  400f70e0 00000000 3d2b410c 00000000      (  208 bytes)
    (dbx) 0x400f70e0/4X
    0x400f70e0:  400fd560 00000000 3d287294 00000000      (25728 bytes)
    (dbx) 0x400fd560/4X
    0x400fd560:  401026e0 00000000 3d289bd0 00000000      (20864 bytes)
    (dbx) 0x401026e0/4X
    0x401026e0:  40102750 00000000 3d28a0cc 00000000      (  112 bytes)

The interesting part was the stack frame size (4816 bytes) - the fact that the memory at 
the current `stkp` address seemed to contain a consistent data while the 
attempt to write to an address computed as `0x400f5cb0-4816 == 0x400f49e0` results in 
the segmentation violation brought us to an idea that it could be the stack overflow.

The documentation at the IBM Systems Information Center describes the following structure of call stack and 
related data structures (for whole documentation see 
[this page](http://publib.boulder.ibm.com/infocenter/systems/topic/com.ibm.aix.prftungd/doc/prftungd/thread_env_vars.htm) ):

     *      +-----------------------+
     *      | page alignment 2      |
     *      | [8K-4K+PTH_FIXED-a1]  |
     *      +-----------------------+
     *      | pthread ctx [368]     |
     *      +-----------------------+<--- pthread->pt_attr
     *      | pthread attr [112]    |
     *      +-----------------------+ <--- pthread->pt_attr
     *      | pthread struct [960]  |
     *      +-----------------------+ <--- pthread
     *      | pthread stack         |         pthread->pt_stk.st_limit
     *      |   |[96K+4K-PTH_FIXED] |
     *      |   V                   |
     *      +-----------------------+ <--- pthread->pt_stk.st_base
     *      | RED ZONE [4K]         |
     *      +-----------------------+ <--- pthread->pt_guardaddr
     *      | pthread key data [4K] |
     *      +-----------------------+ <--- pthread->pt_data
     *      | page alignment 1 (a1) |
     *      | [<4K]                 |
     *      +-----------------------+
     
    The RED ZONE on this illustration is called the Guardpage.

    The decimal number of guard pages to add to the end of the pthread stack is n, which overrides 
    the attribute values that are specified at pthread creation time. If the application specifies 
    its own stack, no guard pages are created. The default is 0 and n must be a positive value.
    The guardpage size in bytes is determined by multiplying n by the PAGESIZE. Pagesize is 
    a system-determined size.

The relatively small default call stack size (96K) supported our hypothesis. We needed just to find
a proof that the address being written to is actually the RED ZONE.

Here is the memory dump retrieved from the `dbx` along with my comments (please note that the address 
orientation is reversed relatively to previous schema):

    (dbx) 0x400f3fe8/2048X
    0x400f3fe8:  00000000 00000000 00000000 00000000  ------> Bottom of another thread's call stack
    0x400f3ff8:  00000001 40135cac 40135cac 40135cac  ----> 
    0x400f4008:  f0286708 f0286708 f0286708 f0286708  ----> Guard page (aka "Red zone")
    0x400f4018:  f0286708 f0286708 f0286708 f0286708        Read/write protected memory region
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~   (4096 bytes)
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    0x400f49c8:  f0286708 f0286708 f0286708 f0286708
    0x400f49d8:  f0286708 f0286708(f0286708)f0286708  <---.  BOOM (Segmentation fault)
    0x400f49e8:  f0286708 f0286708 f0286708 f0286708      |  Attempt to write to the 
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ |  "red zone" (guard page
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ |   
    0x400f4fe8:  f0286708 f0286708 f0286708 f0286708      |
    0x400f4ff8:  f0286708 f0286708 00000000 00000000   ---+-> Top of the current thread's call stack
    0x400f5008:  00000000 00000000 00000000 00000000      |   
    0x400f5018:  00000000 00000000 00000000 00000000      |
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  |
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~  |
    0x400f5988:  00000000 00000000 00000000 00000000      | 
    0x400f5c78:  00000000 00000000 400f5cd0 00000000      | 4816 bytes
    0x400f5c88:  00000000 00000000 00000000 00000000      |
    0x400f5c98:  400fd5b8 401ad028 4019fa58 40165f90    --'
    0x400f5ca8:  3d4263e8 3d9981e8(400f5d00)00000000  <---.
    0x400f5cb8:  3d2b2854 00000000 401ad028 3d9bd578      |
    0x400f5cc8:  00000000 00000000 400f5d20 00000000      |
    0x400f5cd8:  39a87794 00000000 00000000 00000000      |
    0x400f5ce8:  40165cc4 00000000 00000000 00000000    --'   80 bytes 
    0x400f5cf8:  00000000 00000000(400f7010)00000000  <---.
    0x400f5d08:  3d2b228c 00000000 401ad028 00000000      |
    0x400f5d18:  40165f90 00000000 400f6ff0 00000000      |
    0x400f5d28:  39a74c24 00000000 00000000 00000000      |
    0x400f5d38:  40165cc0 00000000 00000000 00000000      |  4880 bytes
    0x400f5d48:  00000000 00000000 00000000 00000000      |
    0x400f5d58:  00000000 00000000 00000000 00000000      | 
    0x400f5d68:  00000000 00000000 00000000 00000000      . Linked list of current thread's stack frames
    0x400f5d78:  00000000 00000000 00000000 00000000      . 
    (dbx)

Those almost 5 kilobytes stack frames were caused by Exception objects residing on stack. Our exception implementation holds relatively big array of wide characters (to avoid heap allocations in case of a failure) and so in some cases the exceptions (though not thrown, just prepared on stack to be thrown in case something fails) consume substantial portion of stack memory and finally cause the stack overflow error.

Just now I am quite happy that we have found and solved this problem and 
at the same time have learned something new.

It is necessary to a priori know the maximum call stack size and the default values for AIX system are relatively low. 
Since the architecture has no special support for the call stack, the only available diagnostics is a *Guard page*
(aka *Red zone*). It is implemented as *N* read/write protected memory pages mapped above the call stack limit 
(please, node that regarding the documentation this functionality is disabled by default). A Stack overflow event then 
(if you are lucky) causes the "normal" segmentation violation - the same as as any other invalid access to a protected 
memory region and so it is relatively difficult to diagnose for a developers with not much platform-specific experience.

*Post note:* There is an interesting [document](http://www.priorartdatabase.com/IPCOM/000117422/) about method called 
"Automatically Extensible Discontinuous Stacks" - a method eliminating the need of the stack size pre-knowledge.
