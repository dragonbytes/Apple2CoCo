# Apple2CoCo
A simple Apple II emulator written for the Tandy Color Computer 3<br>
Written by Todd Wallace (https://tektodd.com)

**BUILDING INSTRUCTIONS**

In it's current form, building the disk image to run the emulator is
unfortunately a little convuluted. I hope to implement a more convienient and
practical method in the future, but for now, these are the steps required to
build a working disk image. NOTE: I use LWASM for my assembler and so all 
my example commands will use LWASM's syntax and parameters, etc. 

**The Apple II+ ROM Image**

The ROM used in my loader is the one specifically from an Apple II+ model and
it is 20KB in size. For obvious reasons, I cannot distribute that ROM image 
so you must obtain one on your own. When you do, it must be copied onto a
RS-DOS formatted floppy disk starting at Track 24 Sector 1 and should end
after Track 28 Sector 8. You will have to make sure on your own that there is
no data already there and that files you create don't overwrite it, so I
recommend you copy all the files FIRST, and do the ROM image data last.

**Assemble the ROM Image Loader Program**

The next step is to assemble the ROM loader program that will pull the ROM
off the disk and populate it into memory where the emulator will expect it.
Use the following command to do this: 

<pre>lwasm -o applerom.bin apple2_load_rom.asm</pre>

**Assembling the Main CPU Core and I/O Emulation Component**

I wrote the 6502 emulation core to be mostly modular so that it could be easily
used in other projects as well. Also because it resides in memory where DECB lives,
I needed to write my own customized loader since using LOADM directly would
crash the machine. Assemble the loader's "payload" using the following command: 

<pre>lwasm --format=raw -o cpu6502payload.bin cpu6502.asm</pre>

This will generate a raw binary file that will be incorprorated into the
next step, which is assembling the Apple-specific emulation code for
stuff like rendering it's screen on the coco etc. This process will 
also import the raw binary "payload" we created in the previous step
automatically.

<pre>lwasm -o apple.bin apple2_loader.asm</pre>

Finally, copy the two BIN files we created, <b>applerom.bin</b> and <b>apple.bin</b>, to the disk you
made earlier with the ROM on it using your copy tool of choice. Personally, I
use the <a href="https://sourceforge.net/projects/toolshed/">ToolShed</a> command-line tools to do this.

**Running The Emulator**

First load the Apple II+ ROM into RAM using: <pre>LOADM"APPLEROM.BIN"</pre>Then type
the EXEC command to run it. You will see a number in the upper-left corner, which
is a representation of the MMU block number currently being populated from the disk. The Apple II+
ROM is now loaded.

Finally, load the main emulator with: <pre>LOADM"APPLE.BIN"</pre>And again, run it with the EXEC command,
and that should be it! The emulator should boot up and you should soon see the
familiar Apple II text at the top of the screen. By default, the Apple II+
tries to boot off of a floppy drive and since that functionality is not yet
supported, you must press the CLEAR key to simulate a "APPLE Key + RESET"
keypress which will bring you into an AppleSoft BASIC prompt! The rest is up
to you! XD Hope you enjoy and have some fun!!
