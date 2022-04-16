#!/bin/bash
set -o errexit

# Build customized cartridge (MAGIC DESK 64k = 8 banks, 8k each, visible at $8000-$9FFF).
# 64k are not enough to hold both the uncompressed game and uncompressed splash screen.
# So hold as much data as possible in uncompressed form.
# Compress a few bits (game $0801-$2FFF, $D000-) using fast LZSA1.
# Splash graphics ($1C00-$2FFF plus colmem) are stored uncompressed in bank 0.

# Unfortunately, the C64's PLA does not provide a "CART_LOW + RAM" option which would
# be handy for decompressing from ROM directly (as the decompressor needs access to
# decompressed data).
# Consequently, we can only decompress directly to $0000-$9FFF and $C000-$CFFF.
# To other areas, we can only copy.

# Koala pic: 0x00 0x60, 8000 bytes bitmap, 1000 bytes screen mem, 1000 bytes col mem, 1 byte bkgcol

mkdir -p build
DBUILD=$(pwd)/build
DCWD=$(pwd)

cd "$DBUILD"

dd if="$DCWD/freeze.vsf" of=mem_complete.bin bs=1 skip=153 count=65536
let OSTART=0x0002 ; let OLEN=0x00F7; dd if=mem_complete.bin of=mem_00.bin bs=1 skip=$OSTART count=$OLEN
let OSTART=0x0100 ; let OLEN=0x00A0; dd if=mem_complete.bin of=mem_01.bin bs=1 skip=$OSTART count=$OLEN
let OSTART=0x0200 ; let OLEN=0x0200; dd if=mem_complete.bin of=mem_02.bin bs=1 skip=$OSTART count=$OLEN
let OSTART=0x0801 ; let OLEN=0x2800; dd if=mem_complete.bin of=mem_08.bin bs=1 skip=$OSTART count=$OLEN
let OSTART=0x3000 ; let OLEN=0x1000; dd if=mem_complete.bin of=mem_30.bin bs=1 skip=$OSTART count=$OLEN
let OSTART=0x4000 ; let OLEN=0x2400; dd if=mem_complete.bin of=mem_40.bin bs=1 skip=$OSTART count=$OLEN
let OSTART=0x6400 ; let OLEN=0x1C00; dd if=mem_complete.bin of=mem_64.bin bs=1 skip=$OSTART count=$OLEN
let OSTART=0x8000 ; let OLEN=0x2000; dd if=mem_complete.bin of=mem_80.bin bs=1 skip=$OSTART count=$OLEN
let OSTART=0xA000 ; let OLEN=0x2000; dd if=mem_complete.bin of=mem_a0.bin bs=1 skip=$OSTART count=$OLEN
let OSTART=0xC000 ; let OLEN=0x2000; dd if=mem_complete.bin of=mem_c0.bin bs=1 skip=$OSTART count=$OLEN
let OSTART=0xE000 ; let OLEN=0x2000; dd if=mem_complete.bin of=mem_e0.bin bs=1 skip=$OSTART count=$OLEN

dd conv=notrunc if="$DCWD/koala_pic.bin" of=koa_bitmap.bin bs=1 skip=2 count=8000
dd conv=notrunc if="$DCWD/koala_pic.bin" of=koa_screen.bin bs=1 skip=8002 count=1000
dd conv=notrunc if="$DCWD/koala_pic.bin" of=koa_colmem.bin bs=1 skip=9002 count=1000

echo "*** Run LZSA compressor"
# LZSA compressor: https://github.com/emmanuel-marty/lzsa
rm -f cmpr_*.bin
"$DCWD/lzsa" -stats -f 1 -m 5 -r mem_00.bin cmpr_00.bin
"$DCWD/lzsa" -stats -f 1 -m 5 -r mem_01.bin cmpr_01.bin
"$DCWD/lzsa" -stats -f 1 -m 5 -r mem_02.bin cmpr_02.bin
"$DCWD/lzsa" -stats -f 1 -m 5 -r mem_08.bin cmpr_08.bin
"$DCWD/lzsa" -stats -f 1 -m 5 -r mem_30.bin cmpr_30.bin
"$DCWD/lzsa" -stats -f 1 -m 5 -r mem_40.bin cmpr_40.bin
"$DCWD/lzsa" -stats -f 1 -m 5 -r mem_64.bin cmpr_64.bin
"$DCWD/lzsa" -stats -f 1 -m 5 -r mem_80.bin cmpr_80.bin
"$DCWD/lzsa" -stats -f 1 -m 5 -r koa_screen.bin cmpr_screen.bin
"$DCWD/lzsa" -stats -f 1 -m 5 -r koa_colmem.bin cmpr_colmem.bin
cat cmpr_screen.bin cmpr_colmem.bin > cmpr_koala_scrcol.bin
ls -la cmpr_*.bin

echo "*** generate stage 2"
cd "$DCWD"
php vsfReanimator.php freeze.vsf > "$DBUILD/stage2.prg"
echo "Stage 2 has $(cat "$DBUILD/stage2.prg" | wc -c) bytes"

echo "*** Assemble cartridge BIN file"
acme -o build/cartridge.bin -f plain cartridge.asm
cartconv -t md -i build/cartridge.bin -o build/cartridge.crt
echo "# x64 -cartcrt build/cartridge.crt"
