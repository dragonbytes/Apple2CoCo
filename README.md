# Apple2CoCo v1.0
A simple Apple II emulator written for the Tandy Color Computer 3<br>
Written by Todd Wallace
<br>
YouTube: https://www.youtube.com/@tekdragon  
Website: https://tektodd.com<br><br>
<p align="center"><img width="641" alt="Screenshot 2023-02-16 131143" src="https://user-images.githubusercontent.com/17234382/219452025-69a8fe24-284a-431e-b401-70d3daa60aec.png"></p>
<br>

**Version 1.0 Update**

I think i've finally gotten this emulator into a state that I feel comfortable calling it a version 1.0! In no particular order, here are some of the major changes/updates:
- Simplified loader. All you need is the emulator's single executable BIN file and a copy of APPLE2.ROM.
- Rudimentary Apple II+ Lo-Res Graphics mode support
- Optional build flag to include a basic 6502 debugger that uses CoCo3 Hi-Res Text screen to display a trace of 6502 instructions as the emulator runs them
- Simple BASH build script to create the executable and CoCo DSK image

This emulator is mostly a proof-of-concept project and is by no means a complete emulation of the Apple II+. While the 6502 CPU emulation is pretty complete, apple-specific hardware support is limited to keyboard input and two video output modes. The emulator supports the Lo-Res "stock" 40 column text-only video mode as well as the Lo-Res "Graphics" mode. The video stuff isn't cycle-accurate and probably could have been implemented in a more effective manner, but hey it works! I do hope to expand the functionality of this emulator in the future, the video graphics modes and floppy support in particular.

**The Apple II+ ROM Image**

A 20KB ROM image from an Apple II+ is required for the emulator work. For obvious reasons I cannot bundle this with my emulator, but it shouldn't be too difficult to obtain one. The filename of the ROM you need for my emulator is APPLE2.ROM. Copy this file onto the same CoCo-formatted disk that the emulator is located on. That's all you have to do!

**Running The Emulator**

Once you have your CoCo disk with the emulator and a copy of APPLE2.ROM on it, type:
<pre>LOADM"APPLEEMU.BIN"</pre>
Then run the program with the EXEC command. The loader will automatically search the disk for the required APPLE2.ROM file, and when found, will load it into the CoCo 3's RAM. As soon as it finishes, the Apple II+ emulation will boot and you should soon see the familiar "Apple II" text at the top of the screen. By default, a real Apple II+ tries to boot off the floppy drive when you power it on. Unfortuantely, floppy drives are not yet supported by my emulator so all you can really do is jump into AppleSoft BASIC. To do this on real hardware, you would press the APPLE + RESET keys together. I have mapped this function to the CoCo 3's CLEAR key. After pressing this key, you should find yourself at the AppleSoft BASIC prompt! The rest is up to you! Have fun tinkering!

**Building Instructions**

If you want to build the emulator from source, I wrote a simple BASH script named <pre>build_apple.sh</pre> that automates the process. First, it checks to make sure you have the two required tools, LWASM and DECB (from the Toolshed project). Next it will assemble the emulator core into a raw binary payload file. Finally, it will assemble the loader (which automatically includes the payload we built in the previous step) into a normal CoCo BIN. After the project is built, the script will attempt to use Toolshed's DECB tool to create (or update) the DSK image file apple2coco.dsk and copy the BIN file over to it. If you don't have the Toolshed tools in your PATH, then you can manually copy the executable to your own CoCo-foramtted disk using whichever tool you want.
