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
- Simplified loader. Only one BIN file to load.
- Rudimentary Apple II+ Lo-Res Graphics mode support
- Optional build flag to include a basic 6502 debugger that uses CoCo3 Hi-Res Text screen to display a trace of 6502 instructions as the emulator runs them
- Simple BASH build script to create the executable and CoCo DSK image

This emulator is mostly a proof-of-concept project and by no means a complete emulation of the Apple II. While the 6502 CPU emulation is complete, the only two apple-specific things that work are the keyboard I/O and the Lo Res "stock" 40 column text-only video mode. The video stuff isn't cycle-accurate and probably not implemented in the smartest way, but it works! I have plans to expand this in the future to support additional video modes and maybe make some optimizations to the process.

**Building Instructions**

In it's current form, building the disk image to run the emulator is
unfortunately a little convuluted. I hope to implement a more convienient and
practical method in the future, but for now, these are the steps required to
build a working disk image. NOTE: I use LWASM for my assembler and so all 
my example commands will use LWASM's syntax and parameters, etc. 

**The Apple II+ ROM Image**

A 20KB ROM image from an Apple II+ is required for the emulator work. For obvious reasons I cannot bundle this with my emulator, but they aren't too difficult to locate. The filename you want is usually called APPLE2.ROM. Once you have it, copy it onto the same CoCo-formatted disk that the emulator is located on.

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
