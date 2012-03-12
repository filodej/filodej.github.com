--- 
name: hp-crash-analysis
layout: post
time: 2011-10-05 13:44:00 +02:00
title: HP-UX crash analysis
categories: programming unix
---
Overview
========

  *32-bit HP-UX (PA-RISC) aCC compiler bug*
	   
  The *+hpxstd98* compiler option causes that the compiler generates incorrect assembly code 
  for a perfectly correct source code.

Compiler option description
===========================

      +hpxstd98      Turns on  a new, standard compliant compilation mode.
                     This option provides a rich set of diagnostics, better
                     support for templates (including support for template-
                     template parameters) and is independent of other
                     compilation options.  Objects created using this option
                     are completely binary compatible with those created
                     without using this option and also with the objects
                     created using earlier versions of the compiler.

This option is necessary for building the [Boost C++ libraries](http://www.boost.org/) 
(see [HP aC++ FAQ](http://h21007.www2.hp.com/portal/site/dspp/menuitem.863c3e4cbcdc3f3515b49c108973a801?ciid=4a083a7373f021103a7373f02110275d6e10RCRD#faq-boost-lib)).
  
Compiler version
----------------

If we check the compiler version:
 
    $ aCC --version         
    aCC: HP ANSI C++ B3910B A.03.80

... we can see that the version of the compiler is `A.03.80`, but currently there are two more recent versions available: `A.03.85` and `A.03.90`
(see [HP aC++ release history for PA-RISC servers](http://h21007.www2.hp.com/portal/site/dspp/menuitem.863c3e4cbcdc3f3515b49c108973a801/?ciid=2645dec4c7563110VgnVCM100000275d6e10RCRD#b11.23pa)

Steps to reproduce the problem
==============================

Prepare the program
-------------------

* Download the following simple c++ file demonstrating the problem:

	[crashtest.cxx](https://github.com/filodej/filodej.github.com/blob/master/code/hp/crashtest.cxx)

  ... the program is standard C++ code and is succesfully compiled with the [Comeau compiler test drive](http://www.comeaucomputing.com/tryitout/).

The correct version
-------------------

* Compile the file with the aCC compiler

      autotest@hpux7:~/bld/crash_test$ aCC crashtest.cxx

* Run the program (without and with a command line argument):

      autotest@hpux7:~/bld/crash_test$ ./a.out          
      Stack allocated Noop
      m_state.noop().noop();
      m_state.m_noop.noop();
      OK!
  
      autotest@hpux7:~/bld/crash_test$ ./a.out 1
      Heap allocated Noop
      m_state.noop().noop();
      m_state.m_noop.noop();
      OK!

  ... the program runs without a problem

The incorrect version
---------------------

* Compile the program again, now with the /+hpxstd98/ compiler flag

      autotest@hpux7:~/bld/crash_test$ aCC +hpxstd98 crashtest.cxx
  
* Run the newly compiled program (without and with a command line argument):

      autotest@hpux7:~/bld/crash_test$ ./a.out  
      Stack allocated Noop
      m_state.noop().noop();
      m_state.m_noop.noop();
      Segmentation fault
  
      autotest@hpux7:~/bld/crash_test$ ./a.out 1                  
      Heap allocated Noop
      m_state.noop().noop();
      m_state.m_noop.noop();
      Bus error

Analysis
========

Debug the program
-----------------

* Disable the printf commands

  Uncomment the following statement:
	 
      #define printf(TXT)

* Compile the program with debug info

      autotest@hpux7:~/bld/crash_test$ aCC +hpxstd98 -g0 crashtest.cxx

* Run the debuger

      autotest@hpux7:~/bld/crash_test$ gdb a.out            
      HP gdb 6.1 for PA-RISC 1.1 or 2.0 (narrow), HP-UX 11i 
      and target hppa1.1-hp-hpux11.00.
      Copyright 1986 - 2009 Free Software Foundation, Inc.
      Hewlett-Packard Wildebeest 6.1 (based on GDB) is covered by the
      GNU General Public License. Type "show copying" to see the conditions to
      change it and/or distribute copies. Type "show warranty" for warranty/support.
      ..

* Run the program

      (gdb) r
      Starting program: /home/autotest/bld/crash_test/a.out 
      Stack allocated Noop
      m_state.noop().noop();
      m_state.m_noop.noop();
       
      Program received signal SIGSEGV, Segmentation fault
        si_code: 0 - SEGV_UNKNOWN - Unknown Error.
      0x1864 in $$dyncall_external_20+0 ()

* See where we are	

      (gdb) where
      #0  0x1864 in $$dyncall_external_20+0 ()
      #1  0x2eb4 in main (argc=1, argv=0x7f7f08f4) at crashtest.cxx:64
	 
* Look at the source code

      (gdb) list
      41                      m_state.m_noop.noop(); // crash :-(
      42                      printf("OK!\n");
      43              }
      44      private:
      45          NoopState const& m_state;
      46      };
      47      
      48      int main(int argc, char* argv[])
      49      {
      50              Noop stack_noop;

* Look at the disassembly

      (gdb) disass
      Dump of assembler code for function $$dyncall_external_20:
      0x1864 <$$dyncall_external_20>: ldw 2(%r22),%r19
      0x1868 <$$dyncall_external_20+0x4>:     ldw -2(%r22),%r22
      0x186c <$$dyncall_external_20+0x8>:     bve (%r22)
      0x1870 <$$dyncall_external_20+0xc>:     stw %rp,-0x18(%sp)

* Go one level up

      (gdb) up
      #1  0x2eb4 in main (argc=1, argv=0x7f7f08f4) at crashtest.cxx:64
      64              test.crash();

* Show disassembly again	

      (gdb) disass
      Dump of assembler code for function main:
      ;;; File: crashtest.cxx
      ;;;  49 {
      
      ...
      
      ;;;  62         CrashTest test( state );
      0x2e58 <main+0x78>:     ldo -0x38(%sp),%r20
      0x2e5c <main+0x7c>:     stw %r20,-0x34(%sp)
      ;;;  64         test.crash();
      0x2e60 <main+0x80>:     ldil L'0x3000,%r21
      0x2e64 <main+0x84>:     call 0x2dc0 <printf>
      0x2e68 <main+0x88>:     ldo 0x528(%r21),%r26
      0x2e6c <main+0x8c>:     ldw -0x34(%sp),%r22
      0x2e70 <main+0x90>:     ldw 0(%r22),%r1
      0x2e74 <main+0x94>:     copy %r1,%r26
      0x2e78 <main+0x98>:     ldw 0(%r26),%r31
      0x2e7c <main+0x9c>:     ldo 0x10(%r31),%r19
      0x2e80 <main+0xa0>:     ldw 0(%r19),%r22
      0x2e84 <main+0xa4>:     b,l 0x1864 <$$dyncall_external_20>,%r31
      0x2e88 <main+0xa8>:     copy %r31,%rp
      0x2e8c <main+0xac>:     ldil L'0x3000,%r20
      0x2e90 <main+0xb0>:     call 0x2dc0 <printf>
      0x2e94 <main+0xb4>:     ldo 0x540(%r20),%r26
      0x2e98 <main+0xb8>:     ldw -0x34(%sp),%r21
      0x2e9c <main+0xbc>:     ldw 0(%r21),%r22
      0x2ea0 <main+0xc0>:     ldo 0x10(%r22),%r1
      0x2ea4 <main+0xc4>:     ldw 0(%r1),%r22
      0x2ea8 <main+0xc8>:     copy %r21,%r26
      0x2eac <main+0xcc>:     b,l 0x1864 <$$dyncall_external_20>,%r31
      0x2eb0 <main+0xd0>:     copy %r31,%rp
      0x2eb4 <main+0xd4>:     ldil L'0x3000,%r31
      0x2eb8 <main+0xd8>:     call 0x2dc0 <printf>
      0x2ebc <main+0xdc>:     ldo 0x4e8(%r31),%r26
      0x2ec0 <main+0xe0>:     ldi 0,%ret0
      ;;;  65 }
      0x2ec4 <main+0xe4>:     copy %ret0,%ret0
      0x2ec8 <main+0xe8>:     ldw -0x54(%sp),%rp
      0x2ecc <main+0xec>:     ret 
      End of assembler dump.

Analyse the disassembly
-----------------------

* Dump the disassembly of both compiled versions (without and with the compiler flag) and compare those for differences

* Cut the address prefixes (addresses always differ):

      $ cat /tmp/disass-crash.txt | cut -d':' -f2 > /tmp/disass-crash-cut.txt
      $ cat /tmp/disass-ok.txt | cut -d':' -f2 > /tmp/disass-ok-cut.txt

* Show the assembly diff 

      $ diff -y /tmp/disass-{ok,crash}-cut.txt
      (gdb) disass main                                       (gdb) disass main
      
        crashtest.cxx                                           crashtest.cxx
       ;;;  49 {                                               ;;;  49 {
            stw %rp,-0x14(%sp)                                      stw %rp,-0x14(%sp)
            ldo 0x40(%sp),%sp                                       ldo 0x40(%sp),%sp
            stw %r26,-0x64(%sp)                                     stw %r26,-0x64(%sp)
            call 0x2d98 <_main>                                     call 0x2d98 <_main>
            stw %r25,-0x68(%sp)                                     stw %r25,-0x68(%sp)
       ;;;  50         Noop stack_noop;                        ;;;  50         Noop stack_noop;
            addil L'-0x800,%dp,%r1                                  addil L'-0x800,%dp,%r1
            ldo 0x6c8(%r1),%r1                                      ldo 0x6c8(%r1),%r1
            stw %r1,-0x40(%sp)                                      stw %r1,-0x40(%sp)
       ;;;  51         Noop const* noop(&stack_noop);          ;;;  51         Noop const* noop(&stack_noop);
            ldo -0x40(%sp),%r31                                     ldo -0x40(%sp),%r31
            stw %r31,-0x3c(%sp)                                     stw %r31,-0x3c(%sp)
       ;;;  53         if ( argc == 2 )                        ;;;  53         if ( argc == 2 )
            ldw -0x64(%sp),%r19                                     ldw -0x64(%sp),%r19
            cmpib,<>,n 2,%r19,0x2e10 <main+0x58>                    cmpib,<>,n 2,%r19,0x2e10 <main+0x58>
       ;;;  56                 noop = new Noop;              <
            ldi 0,%r20                                              ldi 0,%r20
            call 0x2da8 <operator new(unsigned long)>               call 0x2da8 <operator new(unsigned long)>
            ldi 4,%r26                                              ldi 4,%r26
            copy %ret0,%r21                                         copy %ret0,%r21
            cmpib,=,n 0,%r21,0x2e08 <main+0x50>                     cmpib,=,n 0,%r21,0x2e08 <main+0x50>
            addil L'-0x800,%dp,%r1                                  addil L'-0x800,%dp,%r1
            ldo 0x6c8(%r1),%r22                                     ldo 0x6c8(%r1),%r22
            stw %r22,0(%r21)                                        stw %r22,0(%r21)
            b 0x2e10 <main+0x58>                             | ;;;  56                 noop = new Noop;
            stw %r21,-0x3c(%sp)                                     stw %r21,-0x3c(%sp)
       ;;;  61         NoopState state( *noop );               ;;;  61         NoopState state( *noop );
                                                             >      b,n 0x2e10 <main+0x58>
            ldw -0x3c(%sp),%r1                                      ldw -0x3c(%sp),%r1
            stw %r1,-0x38(%sp)                                      stw %r1,-0x38(%sp)
       ;;;  62         CrashTest test( state );                ;;;  62         CrashTest test( state );
            ldo -0x38(%sp),%r31                                     ldo -0x38(%sp),%r31
            stw %r31,-0x34(%sp)                                     stw %r31,-0x34(%sp)
       ;;;  64         test.crash();                           ;;;  64         test.crash();
            ldw -0x34(%sp),%r19                                     ldw -0x34(%sp),%r19
            ldw 0(%r19),%r20                                        ldw 0(%r19),%r20
            copy %r20,%r26                                          copy %r20,%r26
            ldw 0(%r26),%r21                                        ldw 0(%r26),%r21
            ldo 0x10(%r21),%r22                                     ldo 0x10(%r21),%r22
            ldw 0(%r22),%r22                                        ldw 0(%r22),%r22
            b,l 0x1850 <$$dyncall_external_20>,%r31                 b,l 0x1850 <$$dyncall_external_20>,%r31
            copy %r31,%rp                                           copy %r31,%rp
            ldw -0x34(%sp),%r1                                      ldw -0x34(%sp),%r1
            ldw 0(%r1),%r31                                         ldw 0(%r1),%r31
            ldw 0(%r31),%r19                                 |      ldo 0x10(%r31),%r19
            ldo 0x10(%r19),%r20                              |      ldw 0(%r19),%r22
            ldw 0(%r20),%r22                                 |      copy %r1,%r26
            copy %r31,%r26                                   <
            b,l 0x1850 <$$dyncall_external_20>,%r31                 b,l 0x1850 <$$dyncall_external_20>,%r31
            copy %r31,%rp                                           copy %r31,%rp
            ldi 0,%ret0                                             ldi 0,%ret0
       ;;;  65 }                                               ;;;  65 }
            copy %ret0,%ret0                                        copy %ret0,%ret0
            ldw -0x54(%sp),%rp                                      ldw -0x54(%sp),%rp
            ret                                                     ret 
       End of assembler dump.                                  End of assembler dump.

  The version of the call realized over two levels of accessed members:  

      m_state.m_noop.noop(); // crash :-(

  ... was generated differently.

  On the other hand the code generated for the first version of the call (withe reference retrieved wia the noop() getter):

      m_state.noop().noop(); // no crash :-)

 ... was generated correctly and identically in both cases.

* Look at the interesting part

      copy %r31,%rp                                           copy %r31,%rp
      ldw -0x34(%sp),%r1                                      ldw -0x34(%sp),%r1
      ldw 0(%r1),%r31                                         ldw 0(%r1),%r31
      ldw 0(%r31),%r19                                 |      ldo 0x10(%r31),%r19
      ldo 0x10(%r19),%r20                              |      ldw 0(%r19),%r22
      ldw 0(%r20),%r22                                 |      copy %r1,%r26
      copy %r31,%r26                                   <
      b,l 0x1850 <$$dyncall_external_20>,%r31                 b,l 0x1850 <$$dyncall_external_20>,%r31
      copy %r31,%rp                                           copy %r31,%rp
      ldi 0,%ret0                                             ldi 0,%ret0

* Pseudocode

  I have no experience with the PA-RISC instruction set so the following is just a wild guess.

  We try to translate the sequence of the instructions to a more readable pseudocode:

  The correct version: 

       r31 = r1[0]
       r19 = r31[0]
       r20 = r19[0x10]
       r22 = r20[0]
       r26 = r31

  The incorrect version:

       r31 = r1[0];
       r19 = r31[0x10];
       r22 = r19[0];
       r26 = r1;

* Substitute the registers

  When we simplify the sequence by substituting the registers for their corresponding values,
  we clearly see the differences:

  The correct version:

       r22 = *(r1[0][0][0x10]);
       r26 = *r1;

  The incorrect version:

       r22 = *(r1[0x10][0]);
       r26 = r1;

Conclusion
----------

   It seems that the two registers above contain:

   * r22 ... virtual function address
   * r26 ... object address

   There are two `r1` register dereferences with the offset 0 bytes, those probably correspond to the code:

    this->m_state.m_noop

   ... then there is one more dereference with offset 16 bytes, it seemingly correspond to a retrieval of the *Noop vtable* 
   and then there is one final dereference corresponding to the *vtable lookup*.
   
   The virtual call itself is realized as so called *long call* with the BLE followed by the COPY instruction
   (see section 2.5.5 of the [The 32-bit PA-RISC Run-time Architecture Document](http://ftp.parisc-linux.org/docs/arch/rad_11_0_32.pdf)).

   For some reason when the *+hpxstd98* compiler option is used the generated code differs considerably, 
   some of the dereferences are completely missing. 
   
   This causes `Bus Error` in some cases, `Segmentation fault` in other.
   That seem to depend on the address of the *Noop* object 
   (in some cases the `LDW` instruction complains about its alignment which causes `SIGBUS` signal just before the `SEGFAULT`).

