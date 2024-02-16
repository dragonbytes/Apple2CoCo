#!/bin/bash
echo "Apple2CoCo v1.0"
echo -e "Written by Todd Wallace"
echo "https://www.youtube.com/@tekdragon"
echo "https://github.com/dragonbytes"
echo -e "https://tektodd.com\\n"
# First check if LWASM from LWTOOLS is installed
if ! command -v lwasm > /dev/null 2>&1; then
	echo "Error: lwasm could not be found in your path and is required for this script to work."
else
	echo -n "Assembling the source... "
	lwasm --format=raw -o cpu6502payload.bin -lcpu6502.lst cpu6502.asm
	lwasm -o appleemu.bin -lapple_emu.lst apple2_loader.asm
	echo "Done"
	# Check if DECB from ToolShed is installed and in path
	if ! command -v decb > /dev/null 2>&1; then
		echo "Warning: Toolshed's DECB command not found and is needed for making/modifying CoCo disk images."
		echo "You will need to copy the appleemu.bin executable manually yourself."
	else
		if ! test -f ./apple2coco.dsk; then
			echo "Creating new disk image apple2coco.dsk."
			decb dskini -3 apple2coco.dsk
		fi
		echo "Copying executable appleemu.bin to disk image apple2coco.dsk."
		decb copy -2 -b -r appleemu.bin apple2coco.dsk,APPLEEMU.BIN
	fi
	echo "Finished"
fi