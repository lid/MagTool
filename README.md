MagTool
=======

MagTool lives on as [MagStriper](http://kevinbrewster.github.com/MagStriper/)!

Visit http://dustin.li/code/magtool/ for more information.

MagTool is software for magnetic stripe readers & writers. The tools that ship with most magnetic stripe readers, writers, and encoders are generally Windows-only and pretty crufty. MagTool provides a simple, intuitive interface to MSR206-compatible devices. The software features read, write, duplicate, and erase support for MSR206-compatible readers and writers (including MSRW MSR606, MSR505C, MSR106, MSR406, MSR210, MSR210U, and others).

System Requirements
-------------------
* Mac OS X 10.5 (Leopard) or higher
* Serial or USB interface on the device
* Drivers are required to expose the serial interface. USB drivers for some devices are available directly from [Prolific](http://www.prolific.com.tw/US/supportDownload.aspx?FileType=56&FileID=133&pcid=85&Page=0)

Known issues
------------
* Erase operation locks up GUI until operation is complete
* Read operation does yet recognize non-ISO formats, despite what the UI says
* Raw formats are not working yet
* No documentation
