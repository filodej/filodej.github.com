--- 
name: pdf-stream-anatomy
layout: post
time: 2012-03-09 17:17
title: PDF stream content anatomy
categories: linux pdf
---
PDF stream content anatomy
==========================

Overview
========
This post describes how to analyze the content of a PDF file with using just low level linux command-line 
tools, namely: [ls](http://en.wikipedia.org/wiki/Ls), [head](http://en.wikipedia.org/wiki/Head_%28Unix%29), 
[tail](http://en.wikipedia.org/wiki/Tail_%28Unix%29), [dd](http://en.wikipedia.org/wiki/Dd_%28Unix%29),
[awk](http://en.wikipedia.org/wiki/AWK), [sed](http://en.wikipedia.org/wiki/Sed), 
[wc](http://en.wikipedia.org/wiki/Wc_%28Unix%29), [gzip](http://en.wikipedia.org/wiki/Gzip) and 
[chmod](http://en.wikipedia.org/wiki/Chmod).

It was inspired by a screencast available [here](http://www.youtube.com/watch?v=k34wRxaxA_c).

Basic operations
================

Parsing XREF table
------------------

Given we have a pdf file called `trest.pdf`. We can simply look at its cross reference table. 
Its byte offset is stored just at the end of the PDF file:

    $ tail test.pdf 
    0000588961 00000 n 
    0000589014 00000 n 
    trailer
    << /Size 315
    /Root 313 0 R
    /Info 314 0 R
    /ID [<E571FA644538D6F88683F97FDE1B2C10> <E571FA644538D6F88683F97FDE1B2C10>] >>
    startxref
    589220
    %%EOF

So we can see that the table starts at offset `589220`.

With this information we can use the `dd` command to extract just part of the file beginning at given byte offset:

    $ dd if=test.pdf bs=1 skip=589220 2>/dev/null | head
    xref
    0 315
    0000000000 65535 f 
    0000004897 00000 n 
    0000004792 00000 n 
    0000000015 00000 n 
    0000588020 00000 n 
    0000572747 00000 n 
    0000587850 00000 n 
    0000571755 00000 n 

With help of `sed` tool we skip the first 3 lines (`xref` identifier, object number 
  and so called `ZERO` object) and with we `awk` generate the sequential object numbers
  in front of each table line:

    $ dd if=test.pdf bs=1 skip=589220 2>/dev/null | sed 1,3d | awk '{print NR,$0}' | head
    1 0000004897 00000 n 
    2 0000004792 00000 n 
    3 0000000015 00000 n 
    4 0000588020 00000 n 
    5 0000572747 00000 n 
    6 0000587850 00000 n 
    7 0000571755 00000 n 
    8 0000552423 00000 n 
    9 0000571586 00000 n 
    10 0000551777 00000 n 
  
The result looks good so we can extract such cross reference table to a separate file 
for later use:

    $ dd if=test.pdf bs=1 skip=589220 2>/dev/null | sed 1,3d | awk '{print NR,$0}' > test.pdf.xref

We can encapsulate this functionality to a helper script. 

It is available here: [initxref.sh](https://github.com/filodej/filodej.github.com/blob/master/code/pdf/initxref.sh) and its usage is as follows:

    $ ./initxref.sh test.pdf

Extracting object
-----------------

Now we look at the bottom of the PDF file once again:

    $ tail test.pdf 
    0000588961 00000 n 
    0000589014 00000 n 
    trailer
    << /Size 315
    /Root 313 0 R
    /Info 314 0 R
    /ID [<E571FA644538D6F88683F97FDE1B2C10> <E571FA644538D6F88683F97FDE1B2C10>] >>
    startxref
    589220
    %%EOF

... we can see that the document `Info` is stored as object number `314` and document Root as `313`.

Now we try to convert the oject numbers to corresponding document offsets, we can use our `test.pdf.xref` for it:

    $ OBJ=313; grep -e "^$OBJ " test.pdf.xref
    314 0000589014 00000 n

Good, now we cut just the second column containing value representing a byte offset:

    $ OBJ=314; grep -e "^$OBJ " test.pdf.xref | cut -d" " -f2
    0000589014

... and convert the value to its numeric representation:

    $ OBJ=314; grep -e "^$OBJ " test.pdf.xref | cut -d" " -f2 | bc
    589014

Now we can use the offset to actually extract the corresponding data from the PDF stream:

    $ OBJ=314; OFFSET=$(grep -e "^$OBJ " test.pdf.xref | cut -d" " -f2 | bc); dd if=test.pdf bs=1 skip=$OFFSET 2>/dev/null | head
    314 0 obj <<
    /Producer (pdfeTeX-1.30.4)
    /Creator (TeX)
    /CreationDate (D:20060829204334-05'00')
    /PTEX.Fullbanner (This is pdfeTeX, Version 3.141592-1.30.4-2.2 (Web2C 7.5.5) kpathsea version 3.5.5)
    >> endobj
    ...

Before we proceed, we can encapsulate the functionality to a simple script.

It is available here: [catobj.sh](https://github.com/filodej/filodej.github.com/blob/master/code/pdf/catobj.sh) and its usage is as follows:

    $ ./catobj.sh test.pdf 314

Traversing hierarchy
--------------------

And now we can start to inspect the document hierarchy:

Document info:

	$ ./catobj.sh test.pdf 314
	314 0 obj <<
       /Producer (pdfeTeX-1.30.4)
       /Creator (TeX)
       /CreationDate (D:20060829204334-05'00')
       /PTEX.Fullbanner (This is pdfeTeX, Version 3.141592-1.30.4-2.2 (Web2C 7.5.5) kpathsea version 3.5.5)
    >> endobj


Document root:

    $ ./catobj.sh test.pdf 313
    313 0 obj <<
       /Type /Catalog
       /Pages 312 0 R
    >> endobj

Document pages tree root:

    $ ./catobj.sh test.pdf 312
    312 0 obj <<
       /Type /Pages
       /Count 11
       /Kids [22 0 R 245 0 R]
    >> endobj

Document pages left sub-tree root: 

    $ ./catobj.sh test.pdf 22
    22 0 obj <<
       /Type /Pages
       /Count 6
       /Parent 312 0 R
       /Kids [2 0 R 24 0 R 30 0 R 48 0 R 58 0 R 179 0 R]
    >> endobj

Left-most (first) page:

    $ ./catobj.sh test.pdf 2
    2 0 obj <<
       /Type /Page
       /Contents 3 0 R
       /Resources 1 0 R
       /MediaBox [0 0 612 792]
       /Parent 22 0 R
    >> endobj

Its content:

    $ ./catobj.sh test.pdf 3
    3 0 obj <<
       /Length 4698      
       /Filter /FlateDecode
    >>
    stream
    ...

Extracting content
------------------

We see that the content has a form of a deflated stream, so we have to pass is through a zlib filter.

But, first we have to skip the first 5 lines before the actual start of the stream data. So we compute the size of first 5 lines in bytes:

    $ ./catobj.sh test.pdf 3 | head -n5 | wc -c
    61

We also know the length of the compressed data is 4698 bytes, so now we can use the additional two parameters of our script 
(we do not want to print the binary data to the terminal, so for now we just count number of bytes): 

    $ ./catobj.sh test.pdf 3 4698 61 | wc -c
    4698

In order to be able to actually read the content of the stream, we have to inflate it. We can use the *gzip* command for that, 
but first we have to prepare a wrapper script adding an artificial gzip header:

    $ cat ./inflate.sh 
    #!/bin/sh
    ( /bin/echo -ne '\037\0213\010\0\0\0\0\0' ; cat "$@" ) | gzip -dc 2>/dev/null

Now we make the script executable:

    $ chmod +x inflate.sh
	
The helper script is available here: [inflate.sh](https://github.com/filodej/filodej.github.com/blob/master/code/pdf/inflate.sh).

Now we are ready to extract the content of deflated PDF stream (we can see the actual PDF interpreter commands):

    $ ./catobj.sh test.pdf 3 4698 61 | ./inflate.sh | head -n15
    1 0 0 1 54 720 cm
    0 g 0 G
    1 0 0 1 502.117 0 cm
    0 g 0 G
    1 0 0 1 -502.117 0 cm
    0 g 0 G
    1 0 0 1 46.144 -19.329 cm
    0 g 0 G
    0 g 0 G
    1 0 0 1 -100.144 -700.671 cm
    BT
    /F30 17.933 Tf 103.631 700.671 Td[(An)-250(Incr)18(emental)-250(A)25(ppr)18(oach)-250(to)-250(Compiler)...
    ET
    1 0 0 1 54 608.267 cm
    0 g 0 G

With a simple `sed` expression we can split and inspect the individual content command sequences
(individual text strings interleaved with horizontal moves are apparent there):

    $ ./catobj.sh test.pdf 3 4698 61 | ./inflate.sh | awk 'NR==12' | sed -e "s/)/\"\n/g" -e "s/(/\n\"/g"
    /F30 17.933 Tf 103.631 700.671 Td[
    "An"
    -250
    "Incr"
    18
    "emental"
    -250
    "A"
    25
    "ppr"
    18
    "oach"
    -250
    "to"
    -250
    "Compiler"
    -250
    "Construction"
    ]TJ/F31 10.959 Tf 156.836 -35.866 Td[
    "Abdulaziz"
    -250
    "Ghuloum"
    ]TJ/F31 8.966 Tf -96.018 -14.944 Td[
    "Department"
    -250
    "of"
    -250
    ...

It is clearly visible how the text content is represented. We can easily distinguish individual text elements
interleaved with horizontal text cursor moves.

However, this is not the only possible way how the texts are stored in a PDF file. The following section will 
demonstrate other possibility how the texts can be represented.

Cairo library output
====================

I am using the [Cairo library](http://cairographics.org/) for generating both rasters and PDF documents. 

There are various ways how to render texts in the Cairo API. Let's look at the individual variants:

Only text
=========

Here we can see the output where all texts are realized via 
the [cairo_show_text()](http://cairographics.org/manual/cairo-text.html#cairo-show-text) call.

The text in PDF is not correctly shaped in some cases, but the original text is preserved if we copy 
it to clipboard or print its text content.

PDF document
------------

[hb-deva-text.pdf](/docs/pdf/hb-deva-text.pdf)

Text output
-----------

      $ pdftotext hb-deva-text.pdf -
      Marathi:
      स्वागत आहे
      आपले नाव काय आहे?
      Hindi:
      सवागत हैं
      तुम्हारा नाम क्या है?
      Sanskrit:
      द + ् + ध + ् + र + ् + य = द्ध्र्य
      पूर्वेभिर्र्षिभिरीड्यो

Only glyphs
===========

Here we can see the output where all texts are realized via 
the [cairo_show_glyphs()](http://cairographics.org/manual/cairo-text.html#cairo-show-glyphs) call.

The text looks visually correct, but the original text input is not preserved. It seems 
that someone is trying to heuristically map glyphs back to original text and store such text 
to the resulting PDF stream, but obviously this approach does not work well 
for [CTL texts](http://en.wikipedia.org/wiki/Complex_text_layout).

PDF document
------------

[hb-deva-glyphs.pdf](/docs/pdf/hb-deva-glyphs.pdf)

Text output
-----------

       $ pdftotext hb-deva-glyphs.pdf -
       Marathi:
       �वागत आहे
       आपले नाव काय आहे?
       Hindi:
       सवागत हंै
       तु�हारा नाम �या है?
       Sanskrit:
       द + ् + ध + ् + र + ् + य = द्ध्र्य
       पूव�िभ��ष�िभरी�ो

PDF content inspection
----------------------

Several methods how the glyph -> char mapping is being realized is decribed in [this page](http://www.glyphandcog.com/textext.html).

Let's make a quick analysis of the *glyph-only* generated PDF file:

First let's initialize the cross-reference table:

    $ ./initxref.sh hb-deva-glyphs.pdf

Now we look at the end of the file to see where the object hierarchy starts:

	 $ tail hb-deva-glyphs.pdf -n8
	 trailer
	 << /Size 15
	    /Root 14 0 R
		/Info 13 0 R
	 >>
	 startxref
	 21826
	 %%EOF

We can see that the root of the PDF object hierarchy starts at the object number 14, so let's look at it:

	 $ ./catobj.sh hb-deva-glyphs.pdf 14
	 14 0 obj
	 << /Type /Catalog
	     /Pages 1 0 R
	 >>
	 endobj

We can see that the /Pages/ hierarchy starts at index 1:
 
	 $ ./catobj.sh hb-deva-glyphs.pdf 1
	 1 0 obj
	 << /Type /Pages
	     /Kids [ 6 0 R ]
	     /Count 1
	 >>
	 endobj

We can go deeper to print the first (and only) /Page/ object - it is object number 6:

	 $ ./catobj.sh hb-deva-glyphs.pdf 6
	 6 0 obj
	 << /Type /Page
	    /Parent 1 0 R
	    /MediaBox [ 0 0 595.28 841.89 ]
	    /Contents 3 0 R
	    /Group <<
	        /Type /Group
	        /S /Transparency
	        /CS /DeviceRGB
	    >>
	    /Resources 2 0 R
	 >>
	 endobj

We can see that the page /Contents/ is in object number 3:

	 $ ./catobj.sh hb-deva-glyphs.pdf 3
	 3 0 obj
	 << /Length 4 0 R
	    /Filter /FlateDecode
	 >>
	 stream
	 ...
	 endstream
	 endobj

The stream content looks like a garbage. That's because it is deflated. So let's inflate it 
in order to see its content. For that we need to know the *exact start offset* and also 
the *size* of the stream.
	 
First we count the offset by counting number of characters of the object header:

	 $ ./catobj.sh hb-deva-glyphs.pdf 3 | head -n5 | wc -c
	 59

Then we print the content of the object 10 representing the soze of the stream:

	 $ ./catobj.sh hb-deva-glyphs.pdf 4
	 4 0 obj
	     339
	 endobj

Now we are ready to read the actual stream content and pass it through the inflate filter:

	 $ ./catobj.sh hb-deva-glyphs.pdf 3 339 59 | ./inflate.sh
	 q
	 0 841.89 595 -841 re W n
	 0.784314 0.784314 0.392157 rg /a0 gs
	 50 791.89 500 -300 re f*
	 0 0 0 rg BT
	 24 0 0 24 50 766.237656 Tm
	 /f-0-0 1 Tf
	 <00010002000300020004000500060007>Tj
	 0 -1.339844 Td
	 [<00080009000a000b000c000d000e000f>-13<0010>]TJ
	 0 -1.339844 Td
	 [<000e001100120010000d0013000a0009000d0014000a0015000d000e000f>-13<0010>13<00
	 16>]TJ
	 0 -1.339844 Td
	 <001700060018001900060007>Tj
	 0 -1.339844 Td
	 [<001a0009000a000b000c000d000f>-13<001b001c>]TJ
	 0 -1.339844 Td
	 [<000c001d001e000f000a001f000a000d0013000a0020000d00210015000a000d000f>-13<00
	 1c>13<0016>]TJ
	 0 -1.339844 Td
	 <002200020018002300240003000600040007>Tj
	 0 -1.339844 Td
	 [<0025000d0026000d0027000d0026000d0028000d0026000d0027000d0026000d001f
	 000d0026000d0027000d0026000d0015000d0029000d0025>-34<0027>34<00280027
	 001f>22<0027>-22<0015>]TJ
	 0 -1.339844 Td
	 <0011002a0009002b002c002d002e002f00300031002c002d001f003200330034000d>Tj
	 ET
	 Q

So we can distinguish the following kinds of commands:

 * `q`/`Q` ... save/restore *graphics state*
 * `re W n` ... *rectangle* with winding rule specification and no fill/stroke
 * `rg /a0 gs` ... set *RGB color* and further manipulation of the *graphic state*
 * `re f*` ... another *rectangle* with *fill rule*
 * `rg` ... *RGB color* manipulation again
 * `BT`/`ET` ... begin/end of the *text object*
 * `Tm` ... setting *text matrix*
 * `Tf` ... setting *text font*
 * `Tj` ... *show text* command
 * `Td` ... moving *text position*
 * `TJ` ... *show text* command with individual glyph positioning

If we look at an individual `Tj` command then we can see that there is a sequence of 
4-character glyph identifiers generated sequentially as the text on the page flows:

The glyph sequence:

	 < 0001 0002 0003 0002 0004 0005 0006 0007 > Tj

represents text:

	    M    a    r    a    t    h    i    :

(Note that the glyph `0002` is present at two places as it represents the `a` character)
 
The `TJ` sequence represents sub-sequences of glyphs interleaved with horizontal cursor moves:

  	 [ < 0008 0009 000a 000b 000c 000d 000e 000f > -13 < 0010 > ] TJ

But the question remains how we map the abstract *glyph IDs* back to a readable text?

To be able to answer this question we need to extract the font resource associated with this text.
 
Now we can look at the page resources. First lets dump the `Page` object again:

	 $ ./catobj.sh hb-deva-glyphs.pdf 6
	 6 0 obj
	 << /Type /Page
	    /Parent 1 0 R
	    /MediaBox [ 0 0 595.28 841.89 ]
	    /Contents 3 0 R
	    /Group <<
		     /Type /Group
		     /S /Transparency
		     /CS /DeviceRGB
	    >>
	    /Resources 2 0 R
	 >>
	 endobj

We can see that PDF object `2` represents the `Resources`:

	 $ ./catobj.sh hb-deva-glyphs.pdf 2
	 2 0 obj
	 <<
	    /ExtGState <<
	       /a0 << /CA 1 /ca 1 >>
	    >>
	    /Font <<
	       /f-0-0 5 0 R
	    >>
	 >>
	 endobj

The only `Font` resource is stored as object `5`:

	 $ ./catobj.sh hb-deva-glyphs.pdf 5
	 5 0 obj
	 << /Type /Font
	    /Subtype /Type0
	    /BaseFont /ZGXMCR+ArialUnicodeMS
	    /Encoding /Identity-H
	    /DescendantFonts [ 12 0 R]
	    /ToUnicode 9 0 R
	 >>
	 endobj

We can see that there is a `ToUnicode` table stored as part of the `Font` resource:

	 $ ./catobj.sh hb-deva-glyphs.pdf 9
	 9 0 obj
	 << /Length 10 0 R
	    /Filter /FlateDecode
	 >>
	 stream
	 ...
	 endstream
	 endobj

Obviously its content is in a deflated stream. So again we have to determine 
the font header size:
 
	 $ ./catobj.sh hb-deva-glyphs.pdf 9 | head -n5 | wc -c
	 60
	 
And the stream size:

	 $ ./catobj.sh hb-deva-glyphs.pdf 10
	 10 0 obj
	    447
	 endobj

And now we are ready to inflate the contents of the `ToUnicode` table:
 
	 $ ./catobj.sh hb-deva-glyphs.pdf 9 447 60 | ./inflate.sh
	 /CIDInit /ProcSet findresource begin
	 12 dict begin
	 begincmap
	 /CIDSystemInfo
	 << /Registry (Adobe)
	    /Ordering (UCS)
	    /Supplement 0
	 >> def
	 /CMapName /Adobe-Identity-UCS def
	 /CMapType 2 def
	 1 begincodespacerange
	 <0000> <ffff>
	 endcodespacerange
	 52 beginbfchar
	 <0001> <004d>
	 <0002> <0061>
	 <0003> <0072>
	 <0004> <0074>
	 <0005> <0068>
	 <0006> <0069>
	 <0007> <003a>
	 <0008> <fffd>
	 <0009> <0935>
	 <000a> <093e>
	 <000b> <0917>
	 <000c> <0924>
	 <000d> <0020>
	 <000e> <0906>
	 <000f> <0939>
	 <0010> <0947>
	 <0011> <092a>
	 <0012> <0932>
	 <0013> <0928>
	 <0014> <0915>
	 <0015> <092f>
	 <0016> <003f>
	 <0017> <0048>
	 <0018> <006e>
	 <0019> <0064>
	 <001a> <0938>
	 <001b> <0902>
	 <001c> <0948>
	 <001d> <0941>
	 <001e> <fffd>
	 <001f> <0930>
	 <0020> <092e>
	 <0021> <fffd>
	 <0022> <0053>
	 <0023> <0073>
	 <0024> <006b>
	 <0025> <0926>
	 <0026> <002b>
	 <0027> <094d>
	 <0028> <0927>
	 <0029> <003d>
	 <002a> <0942>
	 <002b> <fffd>
	 <002c> <093f>
	 <002d> <092d>
	 <002e> <fffd>
	 <002f> <fffd>
	 <0030> <0937>
	 <0031> <fffd>
	 <0032> <0940>
	 <0033> <fffd>
	 <0034> <094b>
	 endbfchar
	 endcmap
	 CMapName currentdict /CMap defineresource pop
	 end
	 end

Let's print the `"Marathi:"` text as a sequence of hexadecimal characters:

	 $ hexdump<<<"Marathi:"
	 0000000 614d 6172 6874 3a69 000a
	 0000009
	 
When we reorder the character pairs then we get the following ASCII values:

	 004d 0061 0072 0061 0074 0068 0069 003a

which is exactly what the following glyph sequence maps to: 

	 < 0001 0002 0003 0002 0004 0005 0006 0007 >

So now we have an exact idea how the *glyph -> char* mapping is implemented.

Text & glyphs
=============

Here we can see the output where all texts are realized via 
the [cairo_show_text_glyphs()](http://cairographics.org/manual/cairo-text.html#cairo-show-text-glyphs) call.

This approach has best from both previous approaches. It provides a correct visual text representation
as well as preserves the original text content.

PDF output
----------
	  [hb-deva-text-glyphs.pdf](/docs/pdf/hb-deva-text-glyphs.pdf)

Text output
-----------

      $ pdftotext hb-deva-text-glyphs.pdf -
      Marathi:
      स्वागत आहे
      आपले नाव काय आहे?
      Hindi:
      सवागत हैं
      तुम्हारा नाम क्या है?
      Sanskrit:
      द + ् + ध + ् + र + ् + य = द्ध्र्य
      पूर्वेभिर्र्षिभिरीड्यो

PDF code inspection
-------------------

First we have to initialize the cross-reference table dump:

	 $ ./initxref.sh hb-deva-text-glyphs.pdf

Now we can go down the object hierarchy exactly the same way as in the prevous case.
The difference is that now the text content is slightly different:

	  $ ./catobj.sh hb-deva-text-glyphs.pdf 3 529 59 | ./inflate.sh 
	  q
	  0 841.89 595 -841 re W n
	  0.784314 0.784314 0.392157 rg /a0 gs
	  50 791.89 500 -300 re f*
	  0 0 0 rg BT
	  24 0 0 24 50 766.237656 Tm
	  /f-0-0 1 Tf
	  <00010002000300020004000500060007>Tj
	  0 -1.339844 Td
	  <0008>Tj
	  /Span << /ActualText <feff0935093e> >> BDC
	  <0009000a>Tj
	  EMC
	  <000b000c000d000e>Tj
	  /Span << /ActualText <feff09390947> >> BDC
	  [<000f>-13<0010>]TJ
	  EMC
	  0 -1.339844 Td
	  <000e0011>Tj
	  /Span << /ActualText <feff09320947> >> BDC
	  <00120010>Tj
	  EMC
	  <000d>Tj
	  /Span << /ActualText <feff0928093e> >> BDC
	  <0013000a>Tj
	  EMC
	  <0009000d>Tj
	  /Span << /ActualText <feff0915093e> >> BDC
	  <0014000a>Tj
	  EMC
	  <0015000d000e>Tj
	  /Span << /ActualText <feff09390947> >> BDC
	  [<000f>-13<0010>]TJ
	  EMC
	  [<>13<0016>]TJ
	  0 -1.339844 Td
	  <001700060018001900060007>Tj
	  0 -1.339844 Td
	  <001a>Tj
	  /Span << /ActualText <feff0935093e> >> BDC
	  <0009000a>Tj
	  EMC
	  <000b000c000d>Tj
	  /Span << /ActualText <feff093909480902> >> BDC
	  [<000f>-13<001b001c>]TJ
	  EMC
	  /Span << /ActualText <feff09240941> >> BDC
	  0 -1.339844 Td
	  ...

So we can distinguish the following new commands:

* `BDC`/`EDC` ... begin/end marked content sequence

So in this variant we can see that individual clusters of presentation glyphs are interleaved with 
`ActualText` spans. That is the case just for texts where it is necessary - e.g. The first line 
containing ascii text `"Marathi:"` is still encoded the same way as in the previous case containing 
just glyphs.
