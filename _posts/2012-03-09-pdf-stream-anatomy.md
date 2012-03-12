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
This post describes how to analyze the content of a PDF file with using just simple linux command-line tools
like: [ls](http://en.wikipedia.org/wiki/Ls), [head](http://en.wikipedia.org/wiki/Head_%28Unix%29), 
[tail](http://en.wikipedia.org/wiki/Tail_%28Unix%29), [dd](http://en.wikipedia.org/wiki/Dd_%28Unix%29),
[awk](http://en.wikipedia.org/wiki/AWK), [sed](http://en.wikipedia.org/wiki/Sed), 
[wc](http://en.wikipedia.org/wiki/Wc_%28Unix%29), [gzip](http://en.wikipedia.org/wiki/Gzip) and 
[chmod](http://en.wikipedia.org/wiki/Chmod).

It was inspired by a screencast available [here](http://www.youtube.com/watch?v=k34wRxaxA_c).

Basic operations
================

Parsing XREF table
------------------

Given we have a pdf file:

    $ ls *.pdf
    test.pdf
  
We can simply look at its cross reference table. Its byte offset is stored just at the end of the PDF file:

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

Wit this information we can use the `dd` command to extract just part of the file beginning at given byte offset:

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
  
The result looks good, now we can extract such cross reference table to a separate file 
for later use:

    $ dd if=test.pdf bs=1 skip=589220 2>/dev/null | sed 1,3d | awk '{print NR,$0}' > test.pdf.xref

We can encapsulate this functionality to a helper script. 

It is available [here](https://github.com/filodej/filodej.github.com/blob/master/code/pdf/initxref.sh) and its usage is as follows:

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

It is available [here](https://github.com/filodej/filodej.github.com/blob/master/code/pdf/catobj.sh) and its usage is as follows:

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
	
The helper script is available [here](https://github.com/filodej/filodej.github.com/blob/master/code/pdf/inflate.sh).

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
