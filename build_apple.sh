lwasm --format=raw -o cpu6502payload.bin -lcpucore.lst cpu6502.asm
lwasm -o apple.bin -lapple2_loader.lst apple2_loader.asm
decb copy -2 -b -r apple.bin cpu.dsk,APPLE.BIN
