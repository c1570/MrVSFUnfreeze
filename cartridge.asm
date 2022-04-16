; Build customized cartridge (MAGIC DESK 64k = 8 banks, 8k each, visible at $8000-$9FFF).
; 64k are not enough to hold both the uncompressed game and uncompressed splash screen.
; Hold as much data as possible in uncompressed form.
; Splash graphics (bitmap at $4000) are stored without compression.

; Unfortunately, the C64's PLA does not provide a "CART_LOW + RAM" option which would
; be handy for decompressing from ROM directly (as the decompressor needs access to
; decompressed data).
; Consequently, we can only decompress directly to $0000-$9FFF and $C000-$CFFF.
; Other areas can be copied to (without decompressing). Of course decompressing
; to RAM, then copying to, e.g., $A000, is possible. Copying compressed data
; then uncompressing works, too.
; However, be aware that setting the MSB of $DE00 is is sticky for some
; hardware, i.e., once you disable EXROM there, the cartridge ROM is gone for
; good (until reset).

; Magic Desk CRT info
; https://codebase64.org/doku.php?id=base:crt_file_format#magic_desk_domark_hes_australia

; Available PLA configurations
; $01	GAME 	EXROM
; x7	1 	1 	Int. RAM 	Int. RAM 	BASIC ROM 	Int. RAM 	I/O 	Kernal ROM
; x3	1 	1 	Int. RAM 	Int. RAM 	BASIC ROM 	Int. RAM 	Charset ROM 	Kernal ROM
; x6	1 	X 	Int. RAM 	Int. RAM 	Int. RAM 	Int. RAM 	I/O 	Kernal ROM
; x5	1 	X 	Int. RAM 	Int. RAM 	Int. RAM 	Int. RAM 	I/O 	Int. RAM
; x0/x4	1 	X 	Int. RAM 	Int. RAM 	Int. RAM 	Int. RAM 	Int. RAM 	Int. RAM
; x2	1 	X 	Int. RAM 	Int. RAM 	Int. RAM 	Int. RAM 	Charset ROM 	Kernal ROM
; x1	1 	X 	Int. RAM 	Int. RAM 	Int. RAM 	Int. RAM 	Charset ROM 	Int. RAM
; x7	1 	0 	Int. RAM 	Cart. Low 	BASIC ROM 	Int. RAM 	I/O 	Kernal ROM
; x3	1 	0 	Int. RAM 	Cart. Low 	BASIC ROM 	Int. RAM 	Charset ROM 	Kernal ROM

* = $0

; ********************* BANK 0
; * CRT start code and helper, LZSA decompressor,
; * compressed splash gfx screen scrmem and colmem,
; * VSF unfreezer stage 2/3, compressed $4000-$6400 data

!pseudopc $8000 {
!word cold_start
!word warm_start
!byte $c3,$c2,$cd,$38,$30

cold_start:
sei
lda #$00
sta $d020
sta $d021
lda #$0b   ; disable screen
sta $d011

waitclr:
lda $d012
bne waitclr
lda $d011
bmi waitclr

ldy #0
cpy_helper:
lda start_helper+$0000,y
sta $0400,y
lda start_helper+$0100,y
sta $0500,y
lda start_helper+$0200,y
sta $0600,y
lda start_helper+$0300,y
sta $0700,y
iny
bne cpy_helper

jmp helper_entry

start_helper:
!pseudopc $0400 {

!src "decompress_faster_v1.asm"

helper_entry:
lda #<cmpr_scrmem_colmem
sta LZSA_SRC_LO
lda #>cmpr_scrmem_colmem
sta LZSA_SRC_HI
lda #0
sta LZSA_DST_LO
lda #$60
sta LZSA_DST_HI
jsr DECOMPRESS_LZSA1_FAST  ; screen mem

lda #0
sta LZSA_DST_LO
lda #$d8
sta LZSA_DST_HI
jsr DECOMPRESS_LZSA1_FAST  ; col mem

lda #1
sta $de00 ; switch to ROM bank 1
lda #0
sta LZSA_SRC_LO
sta LZSA_DST_LO
lda #$80
sta LZSA_SRC_HI
lda #$40
sta LZSA_DST_HI
ldx #$20
jsr justcopy

lda #$03
sta $dd02  ; enable CIA2 port A output
lda #$c2
sta $dd00  ; select VIC bank 1 ($4000-$7FFF)
lda #$80
sta $d018  ; bitmap at $4000, screen mem at $6000
lda #$18
sta $d016  ; enable multicolor mode
lda #$3b
sta $d011  ; enable graphics, enable screen

; splash is visible now - unpack (most) of GQ6 already
nop

; bank 0: $0002-$00F8, $0100-$01A0, $0200-$03FF
lda #0
sta $de00
lda #<cmpr_00_01_02
sta LZSA_SRC_LO
lda #>cmpr_00_01_02
sta LZSA_SRC_HI
lda #$02
sta LZSA_DST_LO
lda #$00
sta LZSA_DST_HI
jsr DECOMPRESS_LZSA1_FAST
lda #$00
sta LZSA_DST_LO
lda #$01
sta LZSA_DST_HI
jsr DECOMPRESS_LZSA1_FAST
lda #$00
sta LZSA_DST_LO
lda #$02
sta LZSA_DST_HI
jsr DECOMPRESS_LZSA1_FAST

skip:
; bank 2: $0801-$2FFF
lda #2
sta $de00
lda #$00
sta LZSA_SRC_LO
lda #$80
sta LZSA_SRC_HI
lda #01
sta LZSA_DST_LO
lda #$08
sta LZSA_DST_HI
jsr DECOMPRESS_LZSA1_FAST

; bank 3: $3000-$3FFF, $6400-$7FFF
lda #3
sta $de00
lda #$00
sta LZSA_SRC_LO
lda #$80
sta LZSA_SRC_HI
lda #$00
sta LZSA_DST_LO
lda #$30
sta LZSA_DST_HI
jsr DECOMPRESS_LZSA1_FAST
lda #$00
sta LZSA_DST_LO
lda #$64
sta LZSA_DST_HI
jsr DECOMPRESS_LZSA1_FAST

; bank 7: $8000-$9FFF
lda #7
sta $de00
lda #$00
sta LZSA_SRC_LO
sta LZSA_DST_LO
lda #$80
sta LZSA_SRC_HI
lda #$80
sta LZSA_DST_HI
ldx #$20
jsr justcopy

; bank 4: $A000-$BFFF
lda #4
sta $de00
lda #$00
sta LZSA_SRC_LO
sta LZSA_DST_LO
lda #$80
sta LZSA_SRC_HI
lda #$A0
sta LZSA_DST_HI
ldx #$20
jsr justcopy

; bank 5: $C000-$DFFF
lda #5
sta $de00
lda #$33
sta $01  ; disable I/O
lda #$2f
sta $00  ; set cpu port to output
lda #$00
sta LZSA_SRC_LO
sta LZSA_DST_LO
lda #$80
sta LZSA_SRC_HI
lda #$C0
sta LZSA_DST_HI
ldx #$20
jsr justcopy
lda #$37
sta $01  ; re-enable I/O

; bank 6: $E000-$FFFF
lda #6
sta $de00
lda #$00
sta LZSA_SRC_LO
sta LZSA_DST_LO
lda #$80
sta LZSA_SRC_HI
lda #$E0
sta LZSA_DST_HI
ldx #$20
jsr justcopy

; splash screen is visible, wait for key/joy2

lda #$ff
sta $dc03
lda #$00
sta $dc02
sta $dc01
waitkey:
ldx $dc00
cpx $dc00
bne waitkey
inx
beq waitkey
waitkey2:
ldx $dc00
cpx $dc00
bne waitkey2
inx
bne waitkey2

; unpack last bits and start

lda #$2b   ; disable screen
sta $d011
waitclr2:
lda $d012
bne waitclr2
lda $d011
bmi waitclr2

; bank 0: $4000-$6400
lda #0
sta $de00
lda #$00
sta LZSA_DST_LO
lda #$40
sta LZSA_DST_HI
lda #<cmpr_40
sta LZSA_SRC_LO
lda #>cmpr_40
sta LZSA_SRC_HI
jsr DECOMPRESS_LZSA1_FAST

; jump to stage 2 (in bank 0)
lda #0
sta $de00
jmp stage2

warm_start:
loop:
lda #$01
sta $d020
sta $d021
jmp loop



; copy X times 256 bytes from LZSA_SRC to LZSA_DST
justcopy:
ldy #0
jcloop:
lda (lzsa_srcptr),y
sta (lzsa_dstptr),y
iny
bne jcloop
inc <lzsa_srcptr + 1
inc <lzsa_dstptr + 1
dex
bne jcloop
rts
}

cmpr_scrmem_colmem:
!binary "build/cmpr_koala_scrcol.bin"
cmpr_00_01_02:
!binary "build/cmpr_00.bin"
!binary "build/cmpr_01.bin"
!binary "build/cmpr_02.bin"

!align $ffff, $8900
stage2:
!binary "build/stage2.prg",,2

cmpr_40:
!binary "build/cmpr_40.bin"
}

; ********************* BANK 1

!align $ffff, $2000

!pseudopc $8000 {
!binary "build/koa_bitmap.bin"
}

; ********************* BANK 2

!align $ffff, $4000

!pseudopc $8000 {
!binary "build/cmpr_08.bin"
}

; ********************* BANK 3

!align $ffff, $6000

!pseudopc $8000 {
!binary "build/cmpr_30.bin"
!binary "build/cmpr_64.bin"
}

; ********************* BANK 4

!align $ffff, $8000

!pseudopc $8000 {
!binary "build/mem_a0.bin"
}

; ********************* BANK 5

!align $ffff, $A000

!pseudopc $8000 {
!binary "build/mem_c0.bin"
}

; ********************* BANK 6

!align $ffff, $C000

!pseudopc $8000 {
!binary "build/mem_e0.bin"
}

; ********************* BANK 7

!align $ffff, $E000

!pseudopc $8000 {
!binary "build/mem_80.bin"
}
