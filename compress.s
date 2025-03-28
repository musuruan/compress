; Compress v1.0 for Commodore 64
; Copyright (C) 1996-2025 Andrea Musuruane
; source for ca65
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <http://www.gnu.org/licenses/>.

.include "kernalRoutines.inc"	; commodore kernal routines
.include "macros.inc"		; macro used in this program (different from the GEOS ones)

; constants

MAGIC0		= $1f	; compressed files with header must begin with
MAGIC1		= $9d	; these two bytes
BITMASK		= $1f	; mask used to get the max code size from compr'ed file
BLOCKMASK	= $80	; mask used to know if block compress is on

INIT_BITS 	= 9	; initial code size in bits
MAX_BITS	= 13	; maximum code size in bits, when decoding
BITS		= 12	; maximum code size in bits, when encoding

CLEAR 		= 256	; bump code, when encountered re-initialize the decoder
FIRST 		= 257	; first useful entry of the decoder table

STACK_BASE 	= $1000	; decoder stack size must be 2^MAX_BITS
TABLE_BASE 	= $3000 ; decoder table size must be 3 * 2^MAX_BITS

HASH_BASE	= $1000	; encoder hash table
HASH_SIZE	= 2 * 5 * (1 << BITS)	; encoder hash table must be 2 * 5 * 2^BITS
					; the size is 100% larger to avoid frequent collisions

NOENT		= $ffff	; hash table flag meaning there is no entry

tablep 		= $fc	; pointer to a cell of the table
stackp 		= $fe	; pointer to the top of the decoder stack

; program starts here!

; Commodore Load Address
LOADADDR = $c000

.word LOADADDR
.org LOADADDR

	jmp	Decode	; entry table
	jmp	Encode

; decompress input file to output file

Decode: 
	lda	magic
	beq	InitDecoder

	jsr	CheckMagic
	sta	error
	beq	InitDecoder
	jsr	ClrChn
	rts

InitDecoder: 
	LoadB	n_bits, INIT_BITS
	LoadW	maxcode, (1 << INIT_BITS) - 2
	LoadB	codemask, 1

	LoadW	freecode, FIRST-1
	lda	block_compress 
	bne	NoBlkComp
	LoadW	freecode, 255

NoBlkComp:  
	LoadW	maxmaxcode, 0
	ldx	maxbits
Loop:
	sec
	rol	maxmaxcode
	rol	maxmaxcode+1
	dex
	bne	Loop

	jsr	Get1stCode
	MoveW	code, oldcode
	sta	finchar
	jsr	Chrout

	LoadW	stackp, STACK_BASE

Start:
	jsr	GetCode

	lda	block_compress
	beq	NoClear
	CmpWI	code, CLEAR
	bne	NoClear

	LoadB	n_bits, INIT_BITS
	LoadW	maxcode, (1 << INIT_BITS) - 2
	LoadB	codemask, 1
	LoadW	freecode, (FIRST - 1) - 1
	LoadB	size, 0
	bra	Start

NoClear:
	MoveW	code, incode

; special case for KwKwK string

	CmpW	freecode, code
	bcs	GenOutput	; check code <= freecode

	lda	finchar
	ldy	#0
	sta	(stackp),y
	IncW	stackp
	MoveW	oldcode, code

; generate output characters in reverse order

GenOutput:
	lda	code+1	; check if code >= 256
	beq	WriteOutput

FillStack:
	MoveW	code, index
	jsr	GetLocation

	ldy	#0
	lda	(tablep),y
	sta	(stackp),y
	IncW	stackp

	iny
	lda	(tablep),y
	sta	code
	iny
	lda	(tablep),y
	sta	code+1
	bne	FillStack

; and write them out in the forward order

WriteOutput:
	MoveB	code, finchar
	jsr	Chrout

EmptyStack:
	CmpWI	stackp, STACK_BASE
	beq	NewEntry

	DecW	stackp
	ldy	#0
	lda	(stackp),y
	jsr	Chrout

	bra	EmptyStack

; generate new entry

NewEntry:      
	CmpW	freecode, maxmaxcode
	bcs	Continue	; check freecode >= maxmaxcode

	IncW	freecode	; freecode++

	CmpW	maxcode, freecode
	bcs	StoreEntry	; check freecode <= maxcode

	inc	n_bits
	sec
	rol	maxcode+1	; maxcode is always %1111 1110

	CmpB	n_bits, maxbits	; except when n_bits == maxbits
	bne	NotMax
	inc	maxcode		; maxcode == %1111 1111
NotMax:
	LoadB	size,0
	sec
	rol	codemask

StoreEntry:
	MoveW	freecode, index
	jsr	GetLocation
	ldy	#0
	lda	finchar
	sta	(tablep),y
	iny
	lda	oldcode
	sta	(tablep),y
	iny
	lda	oldcode+1
	sta	(tablep),y

; remember previous code

Continue:      
	MoveW	incode, oldcode
	jmp	Start

; check if input file begins with two MAGIC bytes and get 
; the block_compress option and the maximum bits used in the
; compressed file

CheckMagic:
	ldx	#2
	jsr	Chkin

	jsr	Chrin
	cmp	#MAGIC0
	bne	Err2
	jsr	Chrin
	cmp	#MAGIC1
	bne	Err2

	jsr	Chrin
	tax
	and	#BLOCKMASK
	sta	block_compress
	txa
	and	#BITMASK
	sta	maxbits

	lda	#MAX_BITS
	cmp	maxbits
	bcc	Err3	; check maxbits > #MAX_BITS
	lda	#0
	rts
Err2:           
	lda	#2
	rts
Err3:           
	lda	#3
	rts

; get the next code from the input file

GetCode: 
	lda	bitoff
	cmp	size
	bcc	NextCode	; check bitoff < size

	lda	eof
	beq	Get1stCode
	pla
	pla
	jsr	ClrChn
	rts

Get1stCode:
	ldx	#2
	jsr	Chkin

	ldy	#0
ReadLoop:
	jsr	Chrin
	sta	bitbuf, y
	iny

	jsr	Readst
	and	#64
	sta	eof
	bne	NoData

	cpy	n_bits
	bne	ReadLoop

NoData:
	tya
	asl	a
	asl	a
	asl	a
	sub	n_bits
	sta	size
	inc	size
	lda	#0
	sta	bitoff

NextCode: 
	tax		; the accumulator still contains bitoff
	lsr	a
	lsr	a
	lsr	a
	tay
	lda	bitbuf, y
	sta	code
	iny
	lda	bitbuf, y
	sta	code+1
	iny
	lda	bitbuf, y
	sta	code+2

	txa		; the accumulator still contains bitoff
	and	#7
	tax
	beq	Masking
Shifting:
	lsr	code+2
	ror	code+1
	ror	code
	dex
	bne	Shifting

Masking:
	lda	code+1
	and	codemask
	sta	code+1

	AddB	n_bits, bitoff

	ldx	#3
	jsr	Chkout

	rts

; take the index to evaluate the table location 

GetLocation:
	MoveW	index, tablep	; tablep = TABLE_BASE + index * 3
	asl	tablep
	rol	tablep+1
	clc
	lda	tablep
	adc	index
	sta	tablep
	lda	tablep+1
	adc	index+1
	adc	#>TABLE_BASE	; #<TABLE_BASE == 0
	sta	tablep+1
	rts

; compress input file to output file

Encode:
	lda	$01	; use RAM under BASIC ROM
	and	#$fe
	sta	$01

	lda	maxbits
	cmp	#INIT_BITS
	bcs	NextCheck
	LoadB	maxbits, INIT_BITS

NextCheck:
	lda	#BITS
	cmp	maxbits
	bcs	WriteHeader	
	LoadB	maxbits, BITS

WriteHeader:
	lda	magic
	beq	Init
	ldx	#3
	jsr	Chkout
	lda	#MAGIC0
	jsr	Chrout
	lda	#MAGIC1
	jsr	Chrout
	lda	maxbits
	ora	block_compress
	jsr	Chrout

Init:
	LoadB	bitoff, 0
	LoadB	bitbuf, 0

	LoadB	n_bits, INIT_BITS
	LoadW	maxcode, (1 << INIT_BITS) - 1

	LoadW	maxmaxcode, 0
	ldx	maxbits
LoopE:
	sec
	rol	maxmaxcode
	rol	maxmaxcode+1
	dex
	bne	LoopE

	LoadW	freecode, FIRST
	lda	block_compress
	bne	NoBlkE
	LoadW	freecode, 256
	
NoBlkE:
	jsr	ClearHash
	ldx	#2
	jsr	Chkin
	jsr	Chrin
	sta	ent
	LoadB	ent + 1, 0

GetNextChar:
	jsr	Readst
	and	#64
	beq	KeepReading
	jmp	Quit

KeepReading:
	jsr	Chrin
	sta	c

	jsr	LookUp
	bcc	GetNextChar

	MoveW	ent, code
	jsr	PutCode

	CmpW	maxmaxcode, freecode
	bcc	ClearTable

; add the new entry

	ldy	#0
	lda	ent
	sta	(tablep), y
	iny
	lda	ent + 1
	sta	(tablep), y
	iny
	lda	c
	sta	(tablep), y
	iny
	lda	freecode
	sta	(tablep), y
	iny
	lda	freecode + 1
	sta	(tablep), y

; if the next entry is going to be too big for the code size, then increase it, if possible

	CmpW	maxcode, freecode
	bcs	PointNextCode

	jsr	Padding

	inc	n_bits

	sec
	rol	maxcode + 1

PointNextCode:
	IncW	freecode

	bra	NextEntry

ClearTable:
	lda	block_compress
	beq	NextEntry

	LoadW	code, CLEAR
	jsr	PutCode
	jsr	Padding
	jsr	ClearHash
	LoadW	freecode, FIRST
	LoadW	maxcode, (1 << INIT_BITS) - 1
	LoadB	n_bits, INIT_BITS

NextEntry:
	MoveB	c, ent
	LoadB	ent + 1, 0

	jmp	GetNextChar

; put out the final code

Quit:
	MoveW	ent, code
	jsr	PutCode

; at EOF, write the rest of the buffer

	lda	bitoff
	beq	RestoreRAM

	lda	bitoff
	clc
	adc	#7
	lsr	a
	lsr	a
	lsr	a
	sta	bitoff

	ldx	#3
	jsr	Chkout

	ldy	#0
Flushing:
	lda	bitbuf, y
	jsr	Chrout
	iny
	cpy	bitoff
	bne	Flushing
	
; restore original RAM configuration	

RestoreRAM:
	lda	$01
	ora	#1
	sta	$01

	jsr	ClrChn

	rts

; clear out the hash table

ClearHash:
	LoadW	tablep, HASH_BASE

ClearLoop:
	ldy	#0
	lda	#<NOENT
	sta	(tablep), y
	iny
	lda	#>NOENT
	sta	(tablep), y

	AddVW	5, tablep	; each entry takes 5 bytes

	CmpWI	tablep, HASH_BASE + HASH_SIZE
	bne	ClearLoop
	rts

; pad buffer with zeros

Padding:
	lda	bitoff
	beq	PadDone
PadLoop:
	LoadW	code, 0
	jsr	PutCode
	lda	bitoff
	bne	PadLoop
PadDone:
	rts


; search through the hash table

LookUp:

; the hash function is (c << 5) ^ ent

	MoveB	c, index
	LoadB	index + 1, 0

	ldx	#5
DoShift:
	asl	index
	rol	index + 1
	dex
	bne	DoShift

	lda	index
	eor	ent
	sta	index
	lda	index + 1
	eor	ent + 1
	sta	index + 1

Search:
	MoveW	index, tablep	; tablep = HASH_BASE + index * 5
	asl	tablep
	rol	tablep + 1
	asl	tablep
	rol	tablep + 1
	clc
	lda	tablep
	adc	index
	sta	tablep
	lda	tablep+1
	adc	index+1
	adc	#>HASH_BASE	; #<HASH_BASE == 0
	sta	tablep+1

	ldy	#0
	lda	(tablep), y
	cmp	ent
	bne	NotFound
	iny
	lda	(tablep), y
	cmp	ent + 1
	bne	NotFound
	iny
	lda	(tablep), y
	cmp	c
	bne	NotFound

	iny
	lda	(tablep), y
	sta	ent
	iny
	lda	(tablep), y
	sta	ent + 1
	clc
	rts

NotFound:
	ldy	#0
	lda	(tablep), y
	cmp	#<NOENT
	bne	Collision
	iny
	lda	(tablep), y
	cmp	#>NOENT
	bne	Collision

	sec
	rts

; we solve the collisions looking into the next slot of the hash table

Collision:
	inc	index
	bne	Search
	inc	index + 1
	
	lda	index + 1
	and	#> (HASH_SIZE - 1)
	sta	index + 1
	bra	Search

; output the given code. "n_bits" output bytes (containing 8 codes) 
; are assembled in "bitbuf", and then written out.

PutCode:
	lda	bitoff
	lsr	a
	lsr	a
	lsr	a
	tay

	lda	bitoff
	and	#7
	beq	Store
	tax

ShiftLoop:
	asl	code
	rol	code + 1
	rol	code + 2
	dex
	bne	ShiftLoop

Store:
	lda	code
	ora	bitbuf, y
	sta	bitbuf, y
	iny
	lda	code + 1
	sta	bitbuf, y
	iny
	lda	code + 2
	sta	bitbuf, y

	AddB	n_bits, bitoff

	lda	n_bits
	asl	a
	asl	a
	asl	a
	cmp	bitoff
	bne	RtsPutCode

	ldx	#3
	jsr	Chkout

	ldy	#0
WriteBuffer:
	lda	bitbuf, y
	jsr	Chrout
	iny
	cpy	n_bits
	bne	WriteBuffer

	ldx	#2
	jsr	Chkin

	LoadB	bitoff, 0
	LoadB	bitbuf, 0

RtsPutCode:
	rts

.bss
.org $CF00

error:  
	.RES 1
maxbits: 
	.RES 1
magic:
	.RES 1	
block_compress:  
	.RES 1

n_bits: 
	.RES 1
maxcode: 
	.RES 2
codemask:
	.RES 1
freecode: 
	.RES 2
maxmaxcode: 
	.RES 2

size:   
	.RES 1
bitoff: 
	.RES 1
bitbuf: 
	.RES MAX_BITS + 2 
code:   
	.RES 3	; we must have 3 bytes to read the code!
oldcode:
	.RES 2
incode: 
	.RES 2
finchar:
	.RES 1

c:
	.RES 1
ent:
	.RES 2

index:  
	.RES 2

eof:
	.RES 1

