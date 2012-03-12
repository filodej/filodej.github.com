--- 
name: print-server
layout: post
time: 2009-11-19 09:35:00 +01:00
title: WMU-6500FS - Print server installation
categories: wmu6500fs linux
updated_at: 2012-03-12
---

> Note: this is just a slightly modified version of my [original post](http://filodej.blogspot.com/2009/11/print-server.html). 
> I have copied it here just to have some content to experiment with (test the rewrite from raw HTML to [MarkDown](http://en.wikipedia.org/wiki/Markdown)).

Introduction
============

Since I have one LPT printer and several computers at home I considered buing a print server for a long time. What reliably discouraged me however was the price - for example [HP print server](http://h10010.www1.hp.com/wwpc/us/en/sm/WF02d/18972-18972-236253.html) price starts at around *$140*. 

Unfortunately I haven't bought a router with USB ports like [Asus WL-500W](http://reviews.cnet.com/routers/asus-wl-500w-802/4505-3319_7-32076385.html), but rather [Linksys WRT54GL](http://www.linksysbycisco.com/US/en/products/WRT54GL) and so the printer sharing as described at [DD-WRT wiki](http://www.dd-wrt.com/wiki/index.php/USB_printer_sharing) was not applicable in my case.

Then I noticed that there is a [p910nd](http://p910nd.sourceforge.net) print daemon 
[package](http://mgb111.pradnik.net/addons/servers-print/p910nd-0.92-081017.tar) available at the JoKer's site.

There was not much information about the installation on the Web and so I was pretty unsure but I decided to give it a try. 

> Note: Before you follow the steps I describe here, please, make sure your printer is compliant with the [JetDirect](http://en.wikipedia.org/wiki/JetDirect) technology.

Hardware installation
=====================

My [HP LaserJet 1100](http://h20000.www2.hp.com/bizsupport/TechSupport/Document.jsp?objectID=bpl05920&prodTypeId=18972&prodSeriesId=25470)
printer is not USB but LPT, so there is some USB to LPT reduction necessary.

I also realized that there is not a [standard printer cable](http://sewelldirect.com/ParallelCable15Foot.asp)
but rather a [Mini Centronics cable](http://sewelldirect.com/ParallelCableMiniCentronics10Foot.asp) 
used for the printer connection.

So it seemed that besides something like the [USB to Parallel port adapter](http://sewelldirect.com/usbtoparallel.asp) ($14)
also another reduction like [Centronics to Mini Centronics adapter](http://sewelldirect.com/centronicstomini.asp) ($11) 
was necessary (there is also [a combo](http://sewelldirect.com/USB-to-Mini-Centronics-Combo-Cable-Set.asp) for $24 
so you can spare a buck ;).

Since I already had a standard printer cable the best choice for me was the [ST Lab U-370 Dongle](http://www.sunrichtech.com.hk/assign.asp?keyid=ba13).
For only $11 does the job very well.

So that's it regarding to hardware installation.

Software installation
=====================

We download and install the *p910nd* print daemon (I use the [0.92 version](http://mgb111.pradnik.net/addons/servers-print/p910nd-0.92-081017.tar) as I had no luck with the latest [version 0.93](http://mgb111.pradnik.net/addons/servers-print/p910nd-0.93%2BminiLpd-0.4-090618.tar), I got a `/var/lock/subsys/p9100d file not found` error. 

*Edit: now the problem with 0.93 is solved, see the discussion below*

    box# cd /mnt/C
    box# wget http://mgb111.pradnik.net/addons/servers-print/p910nd-0.92-081017.tar
    box# tar xvf p910nd-0.92-081017.tar
    ./sys/
    ./sys/etc/
    ./sys/man/
    ./sys/man/man8/
    ./sys/man/man8/p910nd.8
    ./sys/sbin/
    ./sys/sbin/p910nd

Now we are ready to plug the printer to USB port (suppose you use the USB1 port specifically) and run the daemon:

    box# /mnt/C/sys/sbin/p910nd -b -f /dev/usblp0

We can see that the process is now up and running. The fact that it is named `p9100d` (instead of original `p910nd`) 
means that it is listening at port `9100`.

    box# ps | grep p910
      271 root        284 S   /mnt/C/sys/sbin/p9100d -b -f /dev/usblp0
     1863 root        216 S   grep p910

We can make sure it is actually listening at the port; when we run the [network statistics](http://en.wikipedia.org/wiki/Netstat) 
to list all the ports all the processes are are listening for, newly we can see the 
[jetdirect](http://en.wikipedia.org/wiki/JetDirect) port.

    box# netstat -l
    Active Internet connections (only servers)
    Proto Recv-Q Send-Q Local Address           Foreign Address         State      
    ...
    tcp        0      0 *:jetdirect             *:*                     LISTEN      
    ...

We can also look at the [system log](http://en.wikipedia.org/wiki/Syslog)
(with help of the [dmesg command](http://en.wikipedia.org/wiki/Dmesg) ).
There we can find something similar to the following:

    box# dmesg
    ...
    hub.c: new USB device 00:0a.0-2, assigned address 2
    printer.c: usblp0: USB Bidirectional printer dev 2 if 0 alt 1 proto 2 vid 0x067B pid 0x2305
    ...

When we retrieve the description string of the USB device, we get that there is a 
[IEEE-1284 (parallel communication) controller](http://en.wikipedia.org/wiki/IEEE_1284) 
made by the [Prolific Technology Inc.](http://www.prolific.com.tw/eng/product.asp).

    box# cat /proc/printer/usblp0
    Prolific Technology Inc. IEEE-1284 Controller
    0x18

Note that in case you have a USB printer you should probably expect somewhat more meaningful string like 

    Hewlett-Packard HP LaserJet 1005 series

Now we are ready to try some printing:

    box# echo "printer test" &gt; /dev/usblp0 
    ...

Initially I got the following error message:

    bash: /dev/usblp0: Device or resource busy

... then I realized that there is a `mini-lpd` process running holding the device. 

[mini-lpd](http://nico.schotteli.us/papers/linux/cconfig/cconfig/node14.html)
is a small, non-queueing [LPD](http://en.wikipedia.org/wiki/Line_Printer_Daemon_protocol) 
implementation. I do not know why there is *mini-lpd* active on the box, I have not tried 
to make it work, I just killed it and used *p910nd* daemon instead:

    box# killall mini-lpd

After that everything started to work.

To make the changes permanent, I have added add the following lines:

    ### printserv
    killall mini-lpd
    /mnt/C/sys/sbin/p910nd -b -f /dev/usblp0 &

to the `/mnt/C/sys/etc/rc-local` file.

Ok, that's it on the server side, let's look at the clients...

Client installation
===================

Now it is time to install the print clients:

Windows XP
----------

I presume you already have the printer installed locally, and so the only thing you need is to create 
a new port and set it up as a *Standard TCP/IP Port*:

<a onblur="try {parent.deselectBloggerImageGracefully();} catch(e) {}" href="http://1.bp.blogspot.com/_xFBIBcRhwFQ/SwUkXHBhkQI/AAAAAAAADXk/z3jzSXoj_JM/s1600/AddPort.png"><img style="display:block; margin:0px auto 10px; text-align:center;cursor:pointer; cursor:hand;width: 400px; height: 367px;" src="http://1.bp.blogspot.com/_xFBIBcRhwFQ/SwUkXHBhkQI/AAAAAAAADXk/z3jzSXoj_JM/s400/AddPort.png" border="0" alt=""id="BLOGGER_PHOTO_ID_5405766907169181954" /></a>

Now you select the box IP or network name:

<a onblur="try {parent.deselectBloggerImageGracefully();} catch(e) {}" href="http://2.bp.blogspot.com/_xFBIBcRhwFQ/SwUkXfBtjxI/AAAAAAAADXs/Ois8pkBCuqg/s1600/AddPort2.png"><img style="display:block; margin:0px auto 10px; text-align:center;cursor:pointer; cursor:hand;width: 400px; height: 312px;" src="http://2.bp.blogspot.com/_xFBIBcRhwFQ/SwUkXfBtjxI/AAAAAAAADXs/Ois8pkBCuqg/s400/AddPort2.png" border="0" alt=""id="BLOGGER_PHOTO_ID_5405766913612418834" /></a>

As a device type you choose the *Hewlett Pacjkard Jet Direct*:

<a onblur="try {parent.deselectBloggerImageGracefully();} catch(e) {}" href="http://4.bp.blogspot.com/_xFBIBcRhwFQ/SwUkXvWS70I/AAAAAAAADX0/gwfbpkaLmxY/s1600/DeviceType.png"><img style="display:block; margin:0px auto 10px; text-align:center;cursor:pointer; cursor:hand;width: 295px; height: 400px;" src="http://4.bp.blogspot.com/_xFBIBcRhwFQ/SwUkXvWS70I/AAAAAAAADX0/gwfbpkaLmxY/s400/DeviceType.png" border="0" alt=""id="BLOGGER_PHOTO_ID_5405766917993721666" /></a>

Here is a result page ([SNMP](http://en.wikipedia.org/wiki/Simple_Network_Management_Protocol) not supported, RAW protocol, port 9100):

<a onblur="try {parent.deselectBloggerImageGracefully();} catch(e) {}" href="http://4.bp.blogspot.com/_xFBIBcRhwFQ/SwUkX7PF0BI/AAAAAAAADX8/ZIDoMIS6Sh4/s1600/Result.png"><img style="display:block; margin:0px auto 10px; text-align:center;cursor:pointer; cursor:hand;width: 400px; height: 311px;" src="http://4.bp.blogspot.com/_xFBIBcRhwFQ/SwUkX7PF0BI/AAAAAAAADX8/ZIDoMIS6Sh4/s400/Result.png" border="0" alt=""id="BLOGGER_PHOTO_ID_5405766921184727058" /></a>

Here we see the newly created port:

<a onblur="try {parent.deselectBloggerImageGracefully();} catch(e) {}" href="http://3.bp.blogspot.com/_xFBIBcRhwFQ/SwUkYFnzTsI/AAAAAAAADYE/Y3BP6N_I2JA/s1600/Ports.png"><img style="display:block; margin:0px auto 10px; text-align:center;cursor:pointer; cursor:hand;width: 400px; height: 362px;" src="http://3.bp.blogspot.com/_xFBIBcRhwFQ/SwUkYFnzTsI/AAAAAAAADYE/Y3BP6N_I2JA/s400/Ports.png" border="0" alt=""id="BLOGGER_PHOTO_ID_5405766923972726466" /></a>

And finally we are ready to print test page:

<a onblur="try {parent.deselectBloggerImageGracefully();} catch(e) {}" href="http://1.bp.blogspot.com/_xFBIBcRhwFQ/SwUkuTlgpPI/AAAAAAAADYM/-JNOc1gd_sM/s1600/PrintTestPage.png"><img style="display:block; margin:0px auto 10px; text-align:center;cursor:pointer; cursor:hand;width: 400px; height: 362px;" src="http://1.bp.blogspot.com/_xFBIBcRhwFQ/SwUkuTlgpPI/AAAAAAAADYM/-JNOc1gd_sM/s400/PrintTestPage.png" border="0" alt=""id="BLOGGER_PHOTO_ID_5405767305678333170" /></a>

Ubuntu 9.10
--------------

In menu *System/Administration/Printing* we choose to create a new printer and 
in device selection choose *Network Printer* and *AppSocket/HP JetDirect*.
In *Host* and *Port* fields we fill the box IP or network name and as port we use 9100:

<a onblur="try {parent.deselectBloggerImageGracefully();} catch(e) {}" href="http://4.bp.blogspot.com/_xFBIBcRhwFQ/SwUm69kdNVI/AAAAAAAADYs/NKrfdJIfWGA/s1600/NewPrinter.png"><img style="display:block; margin:0px auto 10px; text-align:center;cursor:pointer; cursor:hand;width: 388px; height: 400px;" src="http://4.bp.blogspot.com/_xFBIBcRhwFQ/SwUm69kdNVI/AAAAAAAADYs/NKrfdJIfWGA/s400/NewPrinter.png" border="0" alt=""id="BLOGGER_PHOTO_ID_5405769722129888594" /></a>

The next step is the Printer model and driver selection:

<a onblur="try {parent.deselectBloggerImageGracefully();} catch(e) {}" href="http://2.bp.blogspot.com/_xFBIBcRhwFQ/SwUm6kOACyI/AAAAAAAADYk/hkbpQyoygBU/s1600/PrinterDriver.png"><img style="display:block; margin:0px auto 10px; text-align:center;cursor:pointer; cursor:hand;width: 400px; height: 357px;" src="http://2.bp.blogspot.com/_xFBIBcRhwFQ/SwUm6kOACyI/AAAAAAAADYk/hkbpQyoygBU/s400/PrinterDriver.png" border="0" alt=""id="BLOGGER_PHOTO_ID_5405769715324816162" /></a>

Now we can specify the printer name and description:

<a onblur="try {parent.deselectBloggerImageGracefully();} catch(e) {}" href="http://4.bp.blogspot.com/_xFBIBcRhwFQ/SwUm6Z5TxjI/AAAAAAAADYc/MREPBvVeA74/s1600/DescribePrinter.png"><img style="display:block; margin:0px auto 10px; text-align:center;cursor:pointer; cursor:hand;width: 400px; height: 357px;" src="http://4.bp.blogspot.com/_xFBIBcRhwFQ/SwUm6Z5TxjI/AAAAAAAADYc/MREPBvVeA74/s400/DescribePrinter.png" border="0" alt=""id="BLOGGER_PHOTO_ID_5405769712553674290" /></a>

And finally we are ready to print test page:

<a onblur="try {parent.deselectBloggerImageGracefully();} catch(e) {}" href="http://2.bp.blogspot.com/_xFBIBcRhwFQ/SwUm6Nhm1QI/AAAAAAAADYU/O37QpA5nahk/s1600/PrintTestPage.png"><img style="display:block; margin:0px auto 10px; text-align:center;cursor:pointer; cursor:hand;width: 400px; height: 357px;" src="http://2.bp.blogspot.com/_xFBIBcRhwFQ/SwUm6Nhm1QI/AAAAAAAADYU/O37QpA5nahk/s400/PrintTestPage.png" border="0" alt=""id="BLOGGER_PHOTO_ID_5405769709233034498" /></a>

Links
=====

*  For those who interested in a variety of connectors, here is a link to a  [Connector guide PDF](http://www.systemconnection.com/downloads/PDFs/connector_guide.pdf)
*  Here is a [forum regarding HP LaserJet 1100 USB connection](http://forums13.itrc.hp.com/service/forums/questionanswer.do?admit=109447627+1258624587582+28353475&threadId=778999)
*  Here is a document regarding [Making HP Jetdirect Print Servers Secure on a Network](http://h20000.www2.hp.com/bizsupport/TechSupport/Document.jsp?objectID=bpj05999) I do not know whether it has any relevance, I did not look at it so far
*  Here is an [AirLive WMU-6000FS installation manual (PDF)](ftp://airliveftp.dyndns.org/Multimedia/WMU-6000FS/AirLive_WMU-6000FS_Manual.pdf) containing print server installation

