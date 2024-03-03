INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]

  jp EntryPoint   

; Setup Interrupts
SECTION	"VBLANK interrupt",ROM0[$0040]
    jp _HRAM ; DMA Routine lives in HRAM
SECTION	"LCDC interrupt",ROM0[$0048]
    reti
SECTION	"TIMER Overflow interrupt",ROM0[$0050]
    reti
SECTION	"SERIAL interrupt",ROM0[$0058]
    reti
SECTION	"p1234 interrupt",ROM0[$0060]
    reti

SECTION "main", ROM0[$150]

; DMA routine
DMACopy:
  push af
  ld a, HIGH(oam_buffer)
  ld [rDMA], a  ; start DMA transfer
  ld a, 40       ; do nothing 40 * (1 + 3) cycles = 160
DMAWait:
  dec a          ; 1 cylce
  jr nz, DMAWait ; 3 cycles
  pop af
  reti           ; return with enable interrupts
DMAEnd:

EntryPoint:

  di

  ; Clear oam buffer
  xor a
  ld d, a
  ld hl, oam_buffer
  ld bc, oam_buffer_end - oam_buffer
  call MemSet

  ; Copy DMA routine to HRAM
  ld de, DMACopy
  ld hl, _HRAM
  ld bc, DMAEnd - DMACopy
  call MemCpy

  ; Init Smiley (oam_buffer[0])
  ld hl, oam_buffer

  ld a, 50 + 16
  ld [hli], a
  ld a, 16 + 8
  ld [hli], a
  ld a, $21
  ld [hli], a
  ld [hl], a

WaitVBlank:
  ; VBlank starts at y position 144
  ld a, [rLY]
  cp 144
  jp c, WaitVBlank

  ; Turn off LCD
  xor a
  ld [rLCDC], a

  ld de, FontStart
  ld hl, $8000
  ld bc, FontEnd - FontStart
  call MemCpy

  ld de, FontStart
  ld hl, $9000
  ld bc, FontEnd - FontStart
  call MemCpy

  /*; Copy Smiley Tiles
  ld de, SmileyStart
  ld hl, $8000
  ld bc, SmileyEnd - SmileyStart
  Call MemCpy*/

  /*; Copy Tiles
  ld de, Tiles
  ld hl, $9000
  ld bc, TilesEnd - Tiles
  call MemCpy*/

  /*; Copy TileMap
  ld de, Tilemap
  ld hl, $9800
  ld bc, TilemapEnd - Tilemap
  call MemCpy*/

  ; Clear Tiles
  ld d, $80
  ld bc, 32*32
  ld hl, $9800
  call MemSet

  ld hl, HelloStart
  call PrintText

  ld de, 13
  ld a, 2
  call Mul8

  ; Turn on LCD
  ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
  ld [rLCDC], a

  ; Initialize lcd color palette during first blank
  ; bits 7-6: color 3 -> 11 'black'
  ; bits 5-4: color 2 -> 10 'dark gray'
  ; bits 3-2: color 1 -> 01 'light gray'
  ; bits 1-0: color 0 -> 00 'white'
  ld a, %11100100
  ld [rBGP], a

  ; Same for object color palette
  ld a, %11100100
  ld [rOBP0], a

  ; Enable VBlank interrupt
  ld a, $00000001
  ld [rIE], a

  ei

Loop:
  jp Loop

SECTION "Print", ROM0[$350]
PrintText:
  xor a
  ld d, a ; de = index
  ld e, a
  push hl

begin:
  ; load stack address to hl
  ld hl, sp+0

  ; load low byte (l) from stack
  ld c, [hl]
  inc hl
  ; load high byte (h) from stack
  ld b, [hl]

  ;  Load string address to hl
  ld h, b
  ld l, c

  ; add index
  add hl, de

  ; Load char from string, return if zero
  ld a, [hl]
  or a
  jr nz, convert

  pop hl
  ret

convert:
  ; convert from ascii to tile index
  sub a, $20

  ; load tilemap address and add index
  ld hl, $9800
  add hl, de

  ; Store tile index at tilemap
  ld [hl], a
  
  ; increase index
  inc de
  jp begin

PrintMsg:
  ld hl, $9800
  ld a, $21
  ld [hl+], a
  ld [hl+], a
  ld [hl+], a
  ld [hl+], a
  ld [hl+], a
  ld [hl+], a
  ret

SECTION "Div", ROM0[$400]
;Divide d by e, stores the qotient in d and the remainder in a
Divide:
  xor	a
  ld	b, 8

_loop:
  sla	d
  rla
  cp	e
  jr	c, skip_sub
  sub	e
  inc	d

skip_sub:
  dec b
  jr nz,	_loop
  
  ret

SECTION "Mul", ROM0[$450]
Mul8:                            ; this routine performs the operation HL=DE*A
  ld hl,0                        ; HL is used to accumulate the result
  ld b,8                         ; the multiplier (A) is 8 bits wide
Mul8Loop:
  rrca                           ; putting the next bit into the carry
  jr nc,Mul8Skip                 ; if zero, we skip the addition (jp is used for speed)
  add hl,de                      ; adding to the product if necessary
Mul8Skip:
  sla e                          ; calculating the next auxiliary product by shifting
  rl d                           ; DE one bit leftwards (refer to the shift instructions!)

  dec b
  jr nz, Mul8Loop
  ret

; Utility subroutines

  /*
  @param de: source
  @param hl: destination
  @param bc: number of bytes to copy

  loads bc bytes from address de to hl
  no register values will be retained
  */
MemCpy:
  ld a, [de]
  ld [hl+], a
  inc de
  dec bc
  ld a, b
  ; check if either high or low byte has ones set
  or a, c
  jr nz, MemCpy
  ret

  /*
  @param d:   byte
  @param hl:  address
  @param bc:  number of bytes to set

  sets bc bytes to d starting at address hl
  no register values will be retained
  */
MemSet:
  ld a, d
  ld [hl+], a
  dec bc
  ld a, b
  or c
  jr nz, MemSet
  ret


SECTION "OAM Buffer", WRAM0[$C100]
oam_buffer:
  ds 4 * 40
oam_buffer_end:

SECTION "IBM FONT", ROM0
FontStart:
  INCBIN "font_8x8.chr"
FontEnd:

SECTION "TEXT_SEC", ROM0[$10]
HelloStart:
  db "1.Hello World!", 0
HelloEnd: