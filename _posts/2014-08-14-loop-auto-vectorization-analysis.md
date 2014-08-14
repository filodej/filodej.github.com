---
layout: post
uuid: 2d18665f-1cfa-4f82-a8ac-2400e1591230
title: Loop auto-vectorization analysis
name: loop-auto-vectorization-analysis
created_at: 2014-08-14
updated_at: 2014-08-14
categories: programming cpp
---
Overview
========

Lately I am watching [Alex Stepanov](http://en.wikipedia.org/wiki/Alexander_Stepanov)'s
and [Paramjit Oberoi](https://www.linkedin.com/pub/paramjit-oberoi/1/275/539)'s 
[Programming Conversations](https://www.youtube.com/playlist?list=PLHxtyCq_WDLXFAEA-lYoRNQIezL_vaSX-) 
with great enjoyment.

In [Lecture 8](https://www.youtube.com/watch?v=3K2LmnaLLF8&list=PLHxtyCq_WDLXFAEA-lYoRNQIezL_vaSX-#t=840) 
they introduced a very interesting benchmark. Its source code is available 
[here](https://github.com/psoberoi/stepanov-conversations-course/blob/master/benchmarks/transformbench.cpp) 
on GitHub.

There was a very interesting observation that simple operations (like additions) performed on a highly
optimized data structure (`std::vector`) can be *really really fast* on a modern hardware.

I decided to analyze the case little bit more to make sure I understand what is going on at harrdware level.

Benchmark code
==============

The core of the benchmark is very simple and looks as follows:

```cpp
    template <Sequence S1, Sequence S2, Sequence S3, BinaryOperation Op>
    void time_test(const S1& s1, const S2& s2, S3& s3, Op op, size_t n, size_t m) {
      typedef typename S1::iterator I;
      timer t;
      t.start();
      for (int i = 0; i < m; ++i)
        std::transform(s1.begin(), s1.end(), s2.begin(), s3.begin(), op);
      double time = t.stop()/(double(n) * m);
      std::cout << std::setw(6) << std::fixed << std::setprecision(2) << time << "\t";
    }
```

By default the `M` (batch size) and `N` (number of batches) are set as follows: 

```cpp
    uint64_t n = 1000; 
    uint64_t m(100000000 / n);
```

Basic types used are `int8_t`, `int16_t`, `int32_t`, `int64_t`, `float` and `double`.

Container types used are `std::vector`, `std::deque` and `std::list`.

Binary operations are *addition*, *addition with inlining disabled*, *multiplication*, *norm*,
*conversion*, *division*, *square root* and *cube root (implemented in terms of the `pow` function)*.

An example of simplest binary operation `plus` looks like this:
 
```cpp
    template <typename N>
    struct plus
    {
      N operator() (const N& x, const N& y) { return  x + y; }
    };

```

Benchmark Results
=================

When I built the benchmark with GCC 4.8.1 with following options: `g++ -O3 -std=c++11`

... And run it on my machine with CPU: `Intel(R) Core(TM) i7-3630QM CPU @ 2.40GHz`

... then I get the following results in (quite similar to ones shown in the video):


```
    Applying operation 100000000 times (sequence length 1000 by 100000 iterations)
              type	  plus	 fplus	 times	  norm	 cnvrt	   div	  sqrt	   pow	
     vector<int8_t>	  0.06	  1.81	  0.14	  0.21	  1.04	  2.71	  5.85	 62.31	
    vector<int16_t>	  0.10	  2.13	  0.09	  0.12	  1.05	  2.72	  6.01	 63.85	
    vector<int32_t>	  0.18	  2.14	  0.30	  0.52	  0.74	  2.72	  6.01	 63.80	
    vector<int64_t>	  0.34	  1.86	  0.92	  1.23	  2.09	  9.62	  5.96	 63.89	
      vector<float>	  0.41	  2.14	  0.38	  0.45	  0.38	  2.12	  6.59	 63.81	
     vector<double>	  0.65	  2.14	  0.60	  0.78	  0.61	  4.16	  5.98	 63.41	
      deque<int8_t>	  1.27	  2.41	  1.25	  1.56	  2.10	  3.64	  5.91	 64.44	
     deque<int16_t>	  1.30	  2.22	  1.29	  1.36	  2.20	  3.84	  6.30	 66.68	
     deque<int32_t>	  1.33	  2.25	  1.32	  1.42	  2.17	  3.74	  6.21	 66.48	
     deque<int64_t>	  1.37	  2.57	  1.33	  1.48	  2.09	 10.33	  6.01	 66.18	
       deque<float>	  1.30	  2.19	  1.24	  1.33	  1.24	  2.08	  6.58	 64.26	
      deque<double>	  1.37	  2.27	  1.34	  1.49	  1.29	  4.15	  6.04	 63.92	
       list<int8_t>	  2.36	  2.45	  2.31	  2.28	  2.21	  3.05	  5.88	 63.51	
      list<int16_t>	  2.24	  2.30	  2.17	  2.25	  2.17	  3.02	  6.03	 65.05	
      list<int32_t>	  2.20	  2.48	  2.24	  2.24	  2.27	  3.02	  6.23	 64.90	
      list<int64_t>	  2.22	  2.46	  2.16	  2.30	  2.21	 10.02	  6.13	 65.06	
        list<float>	  2.28	  2.51	  2.19	  2.15	  2.19	  2.33	  6.55	 64.87	
       list<double>	  2.26	  2.51	  2.19	  2.17	  2.20	  4.22	  6.00	 64.31	
```

Benchmark analysis
==================

The benchmark results shown above are in nanoseconds per operation.
If the CPU speed is *2.4 GHz* then a single tick is every *0.417 ns*.
According to the benchmark results it lokks like a single `plus` operations on 8-bit integers 
take roughly *0.06 ns*. It would mean that my CPU is capable of roughly 7 such addition operations 
per single clock tick.

But when we think about it bit more, we find out that conceptually CPU has to perform many more operations 
for every addition operations, namely:

  * 2 loads
  * 1 addition
  * 1 store
  * 3 pointer increments (1st source, 2nd source, destination)
  * 1 compare and conditional jump

It would mean that the CPU is able to achieve a stunning rate of more than 50 instructions per tick.

It does not seem very likely. It is fact that Intel processors are highly 
[superscalar](http://en.wikipedia.org/wiki/Superscalar), but it seems unlikely that they are able 
to achieve such a great level of parallelism we see here.

Something different must be in action here and that "something" seems to be some kind of 
automatic [loop vectorization](http://en.wikipedia.org/wiki/Vectorization_%28parallel_computing%29#Loop-level_automatic_vectorization).

Assembly inspection
===================

Now I will focus on GCC compiler in particular (version 4.8.1) and its 
[auto vectorization capabilities](http://gcc.gnu.org/projects/tree-ssa/vectorization.html).
(Of course similar capabilities are available on other modern compilers like 
[MSVC 2013](http://msdn.microsoft.com/en-us/library/hh872235.aspx) 
or [Intel C++ Compiler](https://software.intel.com/sites/products/documentation/doclib/iss/2013/compiler/cpp-lin/GUID-32ED933F-5E8A-4909-A581-4E9DB59A6933.htm)).

In GCC the *auto-vectorization* is enabled by the flag `-ftree-vectorize` and by default at `-O3`. 
Generated instructions also depend on architecture (on *x86_64* we can use `-msse`/`-msse2`) 
and floating point math settings (`-ffast-math` and `-fassociative-math`).

Scalar code
-----------

First we start with a plain scalar code. We want ot use `-O3` optimization but as this optimization level 
enables *auto-vectorization* by default we have to disable it explicitly. 
We can use the `-fno-tree-vectorize` compiler option for that.

So the resulting compiler options are: `-std=c++11 -O3 -fno-tree-vectorize`.
The assembly code for the `std::transform` loop boody looks as follows 
(see [compiler explorer](http://goo.gl/t8qtzO) for complete program): 

    .L39:
        movzbl	(%r8,%rdx), %ecx
        addb	(%rsi,%rdx), %cl
        movb	%cl, (%rdi,%rdx)
        addq	$1, %rdx
        cmpq	%rax, %rdx
        jne		.L39

We can see that the loop body consists of 6 instructions. That is 2 instruction less than 
we estimated, due to the fact that we expected 3 pointer increments but actually there is 
just a single index (held in the `%RDX` register) incremented in each iteration.

To compute all the 1000 additions there is exactly 1000 loop iterations.

The fact is that such scalar code does not run 0.06 ns, but 0.68 ns instead. It means that our 
super-scalar CPU core can handle between 3 to 4 instructions per cycle on average and *that* 
sounds much more realistic.

> ( 6 instructions / ( 0.68 ns / 0.417 ns/cycle ) = 3.679 instructions/cycle )  


Vectorized code for SSE2
------------------------

Now we can enable the *auto-vectorization* and see how the assembly changes. 

We can use the simple compiler options: `-std=c++11 -O3` (as explicitly using the `-msse` or `-msse2` 
options generates identical assembly code).
The assembly code for the `std::transform` loop body looks as follows
(See [compiler explorer](http://goo.gl/pzozPb) for complete program):

        shrq  $4, %r11
        ...
    .L52:
        movdqu	(%r8,%rdi), %xmm0
        addq	$1, %rbp
        movdqu	(%rdx,%rdi), %xmm1
        paddb	%xmm1, %xmm0
        movdqu	%xmm0, (%rsi,%rdi)
        addq	$16, %rdi
        cmpq	%rbp, %r11
        ja		.L52

We can see that `R11` register containing number 1000 gets divided by 16 (see the right shift instruction by 4 bits).
So now the loop is only 62 interations long and we perform 16 additions at once thanks to [SIMD](http://en.wikipedia.org/wiki/SIMD) 
instructions performed on `XMM` registers.

Number of instructions for each loop is now 8 and CPU is able to perform almost 3.5 instructions per cycle

> ( 8 instructions / ( 16 additions * 0.06 ns/addition / 0.417 ns/cycle ) = 3.475 instructions/cycle ).

So using [SSE2](http://en.wikipedia.org/wiki/SSE2) instructions with 128-bit `XMM` registers enabled us to perfom
vectorized operations (16 additions at once) with roughly same cadency as a plain old scalar code. 

Here is a description of the two instructions used above:

> **[MOVDQU](http://x86.renejeschke.de/html/file_module_x86_id_184.html)**

> Moves a double quadword from the source operand (second operand) to the destination operand (first operand). 
> This instruction can be used to load an XMM register from a 128-bit memory location, to store the contents 
> of an XMM register into a 128-bit memory location, or to move data between two XMM registers. 
> When the source or destination operand is a memory operand, the operand may be unaligned 
> on a 16-byte boundary without causing a general-protection exception (#GP) to be generated.


> **[PADDB](http://x86.renejeschke.de/html/file_module_x86_id_226.html)**

> Performs an SIMD add of the packed integers from the source operand (second operand) and the destination 
> operand (first operand), and stores the packed integer results in the destination operand. 
> [...] Overflow is handled with wraparound, as described in the following paragraphs.
>
>
> These instructions can operate on either 64-bit or 128-bit operands. When operating on 64-bit operands, 
> the destination operand must be an MMX technology register and the source operand can be either an MMX 
> technology register or a 64-bit memory location. When operating on 128- bit operands, the destination 
> operand must be an XMM register and the source operand can be either an XMM register or a 128-bit memory location.
>
>
> The PADDB instruction adds packed byte integers. When an individual result is too large to be represented 
> in 8 bits (overflow), the result is wrapped around and the low 8 bits are written to the destination operand 
> (that is, the carry is ignored).

Vectorized code for AVX
-----------------------

A next step is to use more modern [AVX](http://en.wikipedia.org/wiki/Advanced_Vector_Extensions) instructions
to see if we gain anything by replacing older SSE2.

For that we can use folowing compiler options: `-std=c++11 -O3 -mavx`.
The assembly code for the `std::transform` loop body looks as follows
(See [compiler explorer](http://goo.gl/1pChjt) for complete program):

        shrq	$4, %r11
        ...
    .L55:
        vmovdqu	(%rax,%r8), %xmm1
        addq	$1, %r12
        vmovdqu	(%rdx,%r8), %xmm0
        vpaddb	%xmm0, %xmm1, %xmm0
        vmovdqu	%xmm0, (%rsi,%r8)
        addq	$16, %r8
        cmpq	%r12, %r11
        ja		.L55

Generated assembly looks quite similar, loop body still consists of 8 instructions and there is 62 loop iterations
in total. So the `AVX` is using 128-bit `XMM` registers as well as `SSE2`. It seems that `AVX` instructions do not 
gain us any speedup over `SSE`.

Vectorized code for AVX2
------------------------

Now we can try [AVX2](http://en.wikipedia.org/wiki/Advanced_Vector_Extensions#Advanced_Vector_Extensions_2) instructions 
with 256-bit `YMM` registers.

For that we can use folowing compiler options: `-std=c++11 -O3 -mavx2`.
The assembly code for the `std::transform` loop body looks as follows
(See [compiler explorer](http://goo.gl/uq1Qr1) for complete program):

        shrq	     $5, %r11	
        ...
    .L56:
        vmovdqu	     (%r8,%rcx), %xmm1
        addq	     $1, %r12
        vmovdqu	     (%rax,%rcx), %xmm0
        vinserti128	 $0x1, 16(%r8,%rcx), %ymm1, %ymm1
        vinserti128	 $0x1, 16(%rax,%rcx), %ymm0, %ymm0
        vpaddb		 %ymm0, %ymm1, %ymm0
        vmovdqu		 %xmm0, (%rdi,%rcx)
        vextracti128 $0x1, %ymm0, 16(%rdi,%rcx)
        addq		 $32, %rcx
        cmpq		 %r12, %r11
        ja			 .L56

We can see that now the `R11` register is divided by 32 (right shift by 5 bits) and so the total number of loop iteration
drops to only 31. The loop body consists of 11 instructions. As the 256-bit registers are loaded by 128-bit parts the number 
of instructions is a bit higher, but still this variant has a potential to be significantly faster than `SSE2` of `AVX`.
Unfortunately my CPU does not support `AVX2` instruction set so I cannot confirm that by running the benchmark.

Here is a short description of the vector instruction used:

> [VINSERTI128](http://www.felixcloutier.com/x86/VINSERTI128.html)
>
> Replaces either the lower half or the upper half of a 256-bit YMM register with the value of a 128-bit source operand. 
> The other half of the destination is unchanged.

> [VEXTRACTI128](http://www.felixcloutier.com/x86/VEXTRACTI128.html)
>
> Extracts either the lower half or the upper half of a 256-bit YMM register and copies the value to a 128-bit destination operand.

Vectorized code for AVX-512
---------------------------

The latest variant of `AVX` extensions is upcoming [AVX-512](http://en.wikipedia.org/wiki/AVX-512) 
adding support for 512-bit `ZMM` registers. CPU(s) supporting such instructions will begin to appear 
[during 2015](http://newsroom.intel.com/community/intel_newsroom/blog/2014/06/23/intel-re-architects-the-fundamental-building-block-for-high-performance-computing).

There should be at least some support for `AVX-512` in GCC 4.9 compiler (see the [CHANGES](https://gcc.gnu.org/gcc-4.9/changes.html)).

So I tried the corresponding compiler options: `-std=c++11 -O3 -mavx512f`, but unfortunately was unable to convince 
the compiler to actually utilize the 512-bit instructions and registers
(see the [compiler explorer](http://goo.gl/PBP3Ad) for whole program):

        shrq	     $5, %rax
        ...
    .L56:
        vmovdqu	     (%rbx,%r11), %xmm0
        addq	     $1, %r15
        vinserti128	 $0x1, 16(%rbx,%r11), %ymm0, %ymm0
        vpaddb		 (%r9,%r11), %ymm0, %ymm0
        vmovups		 %xmm0, (%r10,%r11)
        vextracti128 $0x1, %ymm0, 16(%r10,%r11)
        addq		 $32, %r11
        cmpq		 %r15, %rax
        ja			 .L56


At least the GCC compiler version 4.9 seems to generate a better assembly (still using 256-bit registers but shaven off 
2 instruction from the tight loop). It is worth noting that it is the case even for `-mavx2` compiler option, 
so it seems to be some general optimization of the *loop auto-vectorization* logic.

If we were able to utilize the 512-bit registers, then the total number of iterations would have dropped to just 15! 
But we have yet to see a hardware with such wide vectorization capabilities.

Conclusion
==========

In this article I have analyzed an interesting benchmark showing how capable is the contemporary hardware 
and how far the x86 architecture got from its first days.

A look at the assembly exposed simple principles how the *loop auto-vectorization* works and how great potencial
it has in combination with other technologies (like *superscalar architecture* and *parallel processing*).

It is also important to keep in mind that current compiler support for *auto-vectorization* is highly heuristic
and works best for simple numeric types in continuous memory. Every programmer should be aware of potential gains 
when he uses simple arrays instead of more sophisticated data structures.

