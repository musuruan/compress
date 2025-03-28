;************************************************************************
;
;	Load Byte:        LoadB    dest,value
;
;	Args:	dest - address of byte to load with value
;		value - byte to load
;
;	Action:	Load a byte with a value
;
;*************************************************************************
.macro LoadB dest,value
	lda #value	;load value
	sta dest	;store it
.endmacro

;************************************************************************
;
;	Load Word:        LoadW    dest,value
;
;	Args:	dest - address of word to load with value
;		value - word to load
;
;	Action:	Load a word with a value
;
;*************************************************************************
.macro LoadW dest,value
	lda #>(value)	;get higher byte of value to load
	sta dest+1	;store it
	lda #<(value)	;get lower byte of value to load
	sta dest+0	;store it
.endmacro
;************************************************************************
;
;	Move Byte:        MoveB    source,dest
;
;	Args:	source - source address
;		dest - destination address
;
;	Action:	Moves byte contents of source to destination.
;
;*************************************************************************
.macro MoveB source,dest
	lda source	;load data from source
	sta dest	;store it in destination
.endmacro

;************************************************************************
;
;	Move Word:        MoveW    source,dest
;
;	Args:	source - source address
;		dest - destination address
;
;	Action:	Moves a word from source address to dest address.
;
;*************************************************************************
.macro MoveW source,dest
	lda source+1	;get high byte
	sta dest+1	;store it
	lda source+0	;get low byte
	sta dest+0	;store it
.endmacro

;************************************************************************
;
;	Add Byte:        add    source
;
;	Args:	source - address of byte to add, or immediate value
;
;	Action:	a = a + source
;
;*************************************************************************
.macro add source
	clc
	adc source
.endmacro
;************************************************************************
;
;	Add Bytes:        AddB    source,dest
;
;	Args:	source - address of byte to add
;		dest - address of byte to add to
;
;	Action:	dest = dest + source
;
;*************************************************************************
.macro AddB source,dest
	clc		;must add with carry
	lda source	;get source byte
	adc dest	;add to destination byte
	sta dest	;store result
.endmacro
;************************************************************************
;
;	Add Words:        AddW    source,dest
;
;	Args:	source - address of word to add
;		dest - address of word to add to
;
;	Action:	dest = dest + source
;	
;*************************************************************************
.macro AddW source,dest
	lda source	;get source low byte
	clc
	adc dest+0	;add to destination low byte
	sta dest+0	;store result, sec carry with overflow
	lda source+1	;get source high byte
	adc dest+1	;add with carry to high byte dest
	sta dest+1	;store result
.endmacro
;************************************************************************
;
;	Add Value To Byte:        AddVB    value,dest
;
;	Args:	value - constant to add to dest
;		dest - address of byte to add to
;
;	Action:	dest = dest + value
;
;*************************************************************************
.macro AddVB value,dest
	lda dest
	clc
	adc #value
	sta dest
.endmacro
;************************************************************************
;
;	Add Value to Word:        AddVW    value,dest
;
;	Args:	value - constant to add to dest
;		dest - address of word to add to
;
;	Action:	dest = dest + value
;
;*************************************************************************
.macro AddVW value,dest
	.local @noInc
	clc		;must add with carry
	lda #<(value)	;get low byte of value
	adc dest+0	;add to low byte of word
	sta dest+0	;store updated value

.if (value >= 0) && (value <= 255)
	bcc @noInc	;carry was set if adc above overflowed.
	inc dest+1	;increment high byte of word
@noInc:
.else
	lda #>(value)	;carry was set if adc above overflowed.
	adc dest+1	;add carry + 0 to high byte of address
	sta dest+1	;store result
.endif

.endmacro

;************************************************************************
;
;	Subtract Byte:        sub    source
;
;	Args:	source - address of byte to subtract, or immediate value
;
;	Action:	a = a - source
;
;*************************************************************************
.macro sub source
	sec
	sbc source
.endmacro
;************************************************************************
;
;	Sub Bytes:        SubB    source,dest
;
;	Args:	source - address of byte to subtract
;		dest - address of byte to subtract from
;
;	Action:	dest = dest - source
;
;*************************************************************************
.macro SubB source,dest
	sec		;must add with carry
	lda dest	;get destination byte
	sbc source	;subtract source byte
	sta dest	;store result
.endmacro

;************************************************************************
;
;	Sub Words:        SubW    source,dest
;
;	Args:	source - address of byte to subtract
;		dest - address of byte to subtract from
;
;	Action:	dest = dest - source
;
;*************************************************************************
.macro SubW source,dest
	lda dest+0	;get source low byte
	sec
	sbc source+0	;subtract from destination low byte
	sta dest+0	;store result, clc carry with overflow
	lda dest+1	;get source high byte
	sbc source+1	;sub with carry from destination high byte
	sta dest+1	;store result
.endmacro

;************************************************************************
;
;	Compare Bytes:        CmpB    source,dest
;
;	Args:	source - address of first byte
;		dest - address of second byte
;
;	Action:	compare contents of source byte to contents of dest. byte
;
;************************************************************************
.macro CmpB source,dest
	lda source	;get source byte
	cmp dest	;compare source to dest
.endmacro
;************************************************************************
;
;	Compare Byte To Value:        CmpBI    source,immed
;
;	Args:	source - address of first byte
;	 	immed - value to compare to
;
;	Action:	compares contents of source to value
;
;************************************************************************
.macro CmpBI source,immed
	lda source	;get source byte
	cmp #immed	;compare source to immediate value
.endmacro

;************************************************************************
;
;	Compare Words:        CmpW    source,dest
;
;	Args:	source - address of first word
;		dest - address of second word
;
;	Action:	compare contents of source word to contents of dest. word
;
;************************************************************************
.macro CmpW source,dest
	lda source
	cmp dest
	lda source+1
	sbc dest+1
.endmacro

;************************************************************************
;
;	Compare Word To Value:        CmpWI    source,immed
;
;	Args:	source - address of first word
;		immed - value to compare to
;
;	Action:	compares contents of source to value
;
;************************************************************************
.macro CmpWI source,immed
	.local @done
	lda source+0	;get low byte
.if ( <immed = 0 )
	cmp #<(immed)	;test low byte of immediate value
.endif
	bne @done	;don't need to do high byte
	lda source+1	;test high byte
	cmp #>(immed)
@done:
.endmacro
;************************************************************************
;
;	Push Byte:        PushB    source
;
;	Args:	source - address of the byte to push
;
;	Action:	Pushes the byte at source onto the stack
;
;*************************************************************************
.macro PushB source
	lda source	;get byte
	pha		;and push it
.endmacro

;************************************************************************
;
;	Push Word:        PushW    source
;
;	Args:	source - address of the word to push
;
;	Action:	Pushes the word at source onto the stack
;
;*************************************************************************
.macro PushW source
	lda source+1	;get high byte of word
	pha		;and push it
	lda source+0	;get low byte of word
	pha		;and push it
.endmacro

;************************************************************************
;
;	Pop Byte:        PopB    dest
;
;	Args:	dest - where to store byte value
;
;	Action:	Pops a byte from the stack
;
;*************************************************************************
.macro PopB dest
	pla		;get byte
	sta dest	;and save it
.endmacro
;************************************************************************
;
;	Pop Word:        PopW    dest
;
;	Args:	dest - where to store word value
;
;	Action:	Pops a word from the stack
;
;*************************************************************************
.macro PopW dest
	pla		;get low byte of word
	sta dest+0	;and save it
	pla		;get high byte of word
	sta dest+1	;and save it
.endmacro

;*************************************************************************
;
;	Branch Relative Always:        bra    addr
;
;	Args:	addr - where to branch to
;
;	Action:	unconditional relative branch
;
;************************************************************************
.macro bra addr
	clv
	bvc addr
.endmacro
;************************************************************************
;
;	DecW:	DecW dest
;
;	Args:	dest - address of word which will be decremented
;
;	Action:	decrements a word
;
;************************************************************************

.macro DecW addr
	.local @j
	lda addr
	bne @j
	dec addr+1
@j:
	dec addr
.endmacro

;************************************************************************
;
;	IncW:	IncW dest
;
;	Args:	dest - address of word which will be incremented
;
;	Action:	increments a word
;
;************************************************************************

.macro IncW addr
	.local @done
	inc addr
	bne @done
	inc addr+1
@done:
.endmacro

