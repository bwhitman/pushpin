;***********************************
;MIDI synth server for Gameboy Color
;Brian Whitman 8/00

;Timing:
;after last bit, we've gone 80 once we get back to read_byte
;each bit takes 268 cycles @ 31250bps, double speed
;sooo......  last bit... 268... stop bit ... ~268 .. should be back testing
;	       last bit... 80 .. we have *at most* 188+268=456 cycles
;			             to be safe, we should do 188 + (268/2=134) = 322
;					 but *at least* 188 to get past the last bit
; 
; The GB can reproduce notes at midi 36-107 


; Globals
;	.include	"../../lib/global.s"

;	.globl	.init_vram
;	.globl	.copy_vram
;	.globl	.init_wtt
;	.globl	.init_btt
;	.globl	.set_xy_wtt

	.globl	_cls
;	.globl	_green_on
;	.globl	_green_off
	.globl	_set_program0
	.globl	_set_program1
	.globl	_set_program2
	.globl	_set_program3


	.area	_BSS
_offset::				; midi channel offset
	.ds	1			
_channel::				; Global channel
	.ds	1
_program::
	.ds	1			; Global for Program Changes
.mode:
	.ds	1			; mode pointer
.con_reg:
	.ds	1			; Storage for the controller lookup tables
.con_len:
	.ds	1
.con_shf:
	.ds	1
.con_pos:
	.ds	1
.cha_lo:				; Given channel, knows which reg to change
	.ds	1
.cha_hi:
	.ds	1
.cha_env:
	.ds	1
.cha_pbhi:
	.ds	2
.cha_pblo:
	.ds	1
.last_freq1:
	.ds	2
.last_freq2:
	.ds	2
.last_freq3:
	.ds	2
.last_midi1q:
	.ds	1
.last_midi2q:
	.ds	1
.last_midi3q:
	.ds	1
.last_midi4q:
	.ds	1
.pb1_val:
	.ds	1
.pb2_val:
	.ds	1
.pb3_val:
	.ds	1
.pb4_val:
	.ds	1
.cur_play1:
	.ds	1
.cur_play2:
	.ds	1
.cur_play3:
	.ds	1
.cur_play4:
	.ds	1
 	



	.area	_CODE
_midi_server::
	call	toggle_speed
	call	ser_init

	ld	a,#0x0c		; init pitch bend to center
	ld	(.pb1_val),a
	ld	a,#0x0c		; init pitch bend to center
	ld	(.pb2_val),a
	ld	a,#0x0c		; init pitch bend to center
	ld	(.pb3_val),a
	ld	a,#0x0c		; init pitch bend to center
	ld	(.pb4_val),a
	
	di
	jp	midi_modewait	; we need to start with a mode, so wait for a high bit
midi_top:	
	call	read_byte
	bit	7,a
	jp	nz,midi_changemode	 ; check to see if it's a MIDI mode change
; Given mode, determines where to handle the next byte
midi_where:
;	ld	b,a			; already a=b
	ld	a,(.mode)
	bit	0,a
	jp	nz,midi_noteon
	bit	1,a
	jp	nz,midi_noteoff
	bit	2,a
	jp	nz,midi_cont		
	bit	3,a
	jp	nz,midi_prog
	bit	4,a
	jp	nz,midi_pitch
	;or else something bad happened:
	jp	midi_modewait

;Given a read byte, change the mode
midi_changemode:
;	ld 	b,a			; b already is a
	and 	#0xF0			;isolate the left half
	ld	d,a

	cp	#0x90			;note on
	jp	nz,next1
	ld	a,#1
	ld	(.mode),a
	jp	outmoded
next1:
	ld	a,d
	cp	#0x80 		;note off
	jp	nz,next2
	ld	a,#2
	ld	(.mode),a
	jp	outmoded
next2:
	ld	a,d
	cp	#0xB0			;controller
	jp	nz,next3
	ld	a,#4
	ld	(.mode),a
	jp	outmoded
next3:
	ld	a,d
	cp	#0xC0			;program change
	jp	nz,next4
	ld	a,#8
	ld	(.mode),a
	jp	outmoded
	
next4:
	ld	a,d
	cp	#0xE0			;pitchbend
	jp	nz,midi_modewait
	ld	a,#16
	ld	(.mode),a
	

outmoded:
	ld	a,(_offset)
	ld	c,a
	
	ld	a,b		
	and	#0x0F		; mask off channel
	
	sub	c		; sub off base channel(offset)

	ld	(_channel),a	;figure out the channel
	cp	#0
	jp	z,channel_1		; and set the registers
	cp	#1
	jp	z,channel_2
	cp	#2
	jp	z,channel_3
	cp	#3
	jp	z,channel_4
	jp	midi_modewait	;not 1-4, we better wait for a new message then


; Sound 1 - square with freq sweep and envelope
channel_1:
	ld	a,#0x13
	ld	(.cha_lo),a
	ld	a,#0x14
	ld	(.cha_hi),a
	ld	a,#0x12
	ld	(.cha_env),a
	call	read_byte
	jp	midi_where
; Sound 2- square with envelope
channel_2:
	ld	a,#0x18
	ld	(.cha_lo),a
	ld	a,#0x19
	ld	(.cha_hi),a
	ld	a,#0x17
	ld	(.cha_env),a
	call	read_byte
	jp	midi_where
; Sound 3- wave pattern RAM
channel_3:
	ld	a,#0x1D
	ld	(.cha_lo),a
	ld	a,#0x1E
	ld	(.cha_hi),a
	ld	a,#0x1C
	ld	(.cha_env),a
	call	read_byte
	jp	midi_where
; Sound 4- noise with polynomial frequency shift
channel_4:
	ld	a,#0x00		; no lo or hi freq settings
	ld	(.cha_lo),a
	ld	a,#0x23		; but the init stuff is in hi, so we need it
	ld	(.cha_hi),a
	ld	a,#0x21
	ld	(.cha_env),a
	call	read_byte
	jp	midi_where

; Wait until we get a mode change. In case we get strange messages.
midi_modewait:
;	ld	a,#0x00
;	ld	(.mode),a
;	ld	(_channel),a
	call	read_byte
	bit	7,a
	jp	nz,midi_changemode
	jp	midi_modewait




;----------------------------------------------------------------------
;MIDI Handlers
;----------------------------------------------------------------------
; Note On
; Note Off
; Controller
; {Program Change} 
; Pitch Bend
; {Sysex}
; {future}


; Noteon handler. All handlers past and future have the form:
;do stuff with first byte (it's already been read)
;read second byte
;do stuff with second byte
;jp to midi_top





; handle midi offs
midi_noteoff:
;	call	_green_off
;	ld	a,(.last_midi1)
	
;	push	bc
;	ld	(_program),a
;	call	_set_program0
;	pop	bc
	
;	push	bc
;	ld	a,b
;	ld	(_program),a
;	call	_set_program1
;	pop	bc
	
;	ld	c,a
		
;	cp	b
;	jp	nz,nonoteoff
	
	call	read_byte
	
	
	ld	a,(.cha_env)
	ld	c,a
	ldh	a,(c)	
	and	#0x0F
	ldh	(c),a				; initial envelope = 0
	
;nonoteoff:
	;noteoff does nothing to byte 1 or 2 really...
	

	
	jp	midi_top

; program changes
midi_prog:
	ld	a,b
	ld	(_program),a
	; call	_set_program
	; and change the program!


	jp	midi_top


; pitch bend
midi_pitch:
	call read_byte			; get the actually only most interesting byte

	ld	c,a			
	srl c				; we only look at lower 5 bits of pitch bend
	srl c
	
	ld	hl,#pbmidi		; pitch bend lookup table (midi notes)
      	ld	b,#0
      	add	hl,bc			; hl now contains addr of pm lookup table
      	ld	a,(hl)			; get pbmidi lookup table val
	ld	b,a			; keep it safe
	
	ld	a,(_channel)
	cp	#0
	jp	z,stashpb1
	cp	#1
	jp	z,stashpb2
	cp	#2
	jp	z,stashpb3

stashpb4:
	ld	a,b				; retrieve pitch bend
	ld	(.pb4_val),a			; stash it
	ld	a,(.cur_play4)			; recall last midi val for channel
	jp	donestashing
stashpb1:	
	ld	a,b
	ld	(.pb1_val),a
	ld	a,(.cur_play1)			; recall last midi val for channel
	jp	donestashing
stashpb2:	
	ld	a,b
	ld	(.pb2_val),a
	ld	a,(.cur_play2)			; recall last midi val for channel
	jp	donestashing

stashpb3:	
	ld	a,b
	ld	(.pb3_val),a
	ld	a,(.cur_play3)			; recall last midi val for channel

donestashing:

	
	add	b		; combine note number, plus pitch bend offset ( a contains note number )
	sub #48				

; given pitch bend and note number, lookup freq in table
	
	sla a			; indexed in pairs (a=a*2)
      	ld	b,#0
	ld	c,a		; bc now contains offset into freq look up table

	ld	hl,#divval		; freq lookup table
      	add	hl,bc			; hl now contains addr of low 8-bit divider val.
      	ld	a,(hl)			; get freq. divider val
   	
      	ld	b,a			; keep it safe
      	inc hl
      	ld	a,(hl)			
      	ld	c,a			; now bc contains divider val

	ld	h,b
	ld	l,c			; now hl contains it.
      	
      	
	ld	a,(.cha_lo)		; a contains the low-half register assoc by channel/voice
	cp	#0x1D			; if 3 do special stuff
	jp	z,pbhandle_sound3 ;what a pain!
	
	ld	c,a			; store low-freq regist addr here
	ld	a,l			; move least-significant data into a
	ldh	(c),a			; store LS data in the lo freq register
	
	
	ld	a,h			; recall MS freq reg data
	ld	b,#0b10000000		; consec on, initial on
	
	or	b			; or it with freq hi info
	ld	d,a			; now the freq hi / consec data is in d (same register)


; write velocity


; write frequency MS register

	ld	a,(.cha_hi)
	ld	c,a
	ld	a,d			; our freq data back in a
	ldh	(c),a			; put it in



	jp	midi_top






midi_realcont:
	ld	(_contnum), a
	call read_byte
	ld	(_contval), a
	
	; lookup table with those two
	
	




; handle MIDI cc's from 0-53
midi_cont:
	ld	a,b
	cp	#53			; A - 53
	jp	nc,wavepattern	; if a>53, go to wavepattern handler

      ; in a we have the controller #... let's get the info
	ld	hl,#controllers
	sla	a		; mult by 4 for the lookup table
	sla	a		; but we're going to have to check for overflow
      add   a,l		; (later)
      ld    l,a
	jr	nc,.skip1_c
	inc	h
.skip1_c:
	ld	a,(hl+)		; get the 4 values out of the lookup table
	ld	(.con_reg),a
	ld	a,(hl+)
	ld	(.con_len),a
	ld	a,(hl+)
	ld	(.con_shf),a
	ld	a,(hl+)
	ld	(.con_pos),a
	
	call	read_byte

	sla	a				; 7-bit to 8-bit
	ld	b,a
	ld	a,(.con_len)
	and	b				; now a is 'scaled' to the parameter length
	ld	b,a
	ld	a,(.con_shf)
	ld	c,a				; now c has the shift count and a the scaled value

	cp	#0				; no shift?
	jp	z, shift_noneed
						; otherwise do the normal shift
	ld	a,b
		
cont_shifting:
	srl	a		
	dec	c		
	jp	nz,cont_shifting		; shift c places to the right
shift_done:
	ld	e,a
	ld	a,(.con_pos)	; loads the position mask: 00011100
	cpl				; complements it:          11100011
	ld	b,a			
	ld	a,(.con_reg)
	ld	c,a		
	ldh	a,(c)			; gets the old register out into a
	and	b			; ands it with the cpl:    10100011
	or	e			; ors in our value:	   10101011
	ldh	(c),a			; loads it back into the register
	jp	midi_top		; I think this takes too long, will check
					; we might need to swap out the delay below (see XXX)
shift_noneed:
	ld	a,b
	jp	shift_done

wavepattern: 
	cp	#85			; make sure we have a valid cont #
	jp	nc,pan
	sub	a,#54
	bit	0,a			; are we left side or right? bit 0 set means right
	jp	nz,rightside
leftside:
	srl	a			; divide by two
	add	a,#0x30			; wave pattern RAM offset
	ld	d,a			; save it
	call read_byte		; get the value
	sla	a			; over 1 bit
	and	#0xF0			; get rid of the right side
	ld	b,a
	ld	c,d
	ldh	a,(c)			; load in the old wave register
	and	#0x0F			; get rid of old data
	or	b			; stick in the new data
	ldh	(c),a			; put it back!
	jp	midi_top
rightside:
	srl	a			; divide by two
	add	a,#0x30			; wave pattern RAM offset
	ld	d,a			; save it
	call read_byte		; get the value
	sla	a			; over 1 bit
	swap	a			; swap it
	and	#0x0F			; get rid of the left side
	ld	b,a
	ld	c,d
	ldh	a,(c)			; load in the old wave register
	and	#0xF0			; get rid of old data
	or	b			; stick in the new data
	ldh	(c),a			; put it back!
	jp	midi_top

pan:
	cp	#86			; make sure we have a valid cont #
	jp	z,pan_1
	cp	#87
	jp	z,pan_2
	cp	#88
	jp	z,pan_3
	cp	#89
	jp	z,pan_4	

toohigh:
	call  read_byte		; skip over the next byte, see what's next
	jp	midi_top

pan_1:
	call	read_byte
	cp	#32
	jp	c,pan_1_left	; less than 32
	cp	#96			
	jp	c,pan_1_center	; less than 96
	jp	pan_1_right		; >= 96
pan_1_left:
	ldh	a,(#0x25)
	set	4,a
	res	0,a
	ldh	(#0x25),a
	jp	midi_top
pan_1_right:
	ldh	a,(#0x25)
	set	0,a
	res	4,a
	ldh	(#0x25),a
	jp	midi_top
pan_1_center:
	ldh	a,(#0x25)
	set	0,a
	set	4,a
	ldh	(#0x25),a
	jp	midi_top

pan_2:
	call	read_byte
	cp	#32
	jp	c,pan_2_left	; less than 32
	cp	#96			
	jp	c,pan_2_center	; less than 96
	jp	pan_2_right		; >= 96
pan_2_left:
	ldh	a,(#0x25)
	set	5,a
	res	1,a
	ldh	(#0x25),a
	jp	midi_top
pan_2_right:
	ldh	a,(#0x25)
	set	1,a
	res	5,a
	ldh	(#0x25),a
	jp	midi_top
pan_2_center:
	ldh	a,(#0x25)
	set	1,a
	set	5,a
	ldh	(#0x25),a
	jp	midi_top
pan_3:
	call	read_byte
	cp	#32
	jp	c,pan_3_left	; less than 32
	cp	#96			
	jp	c,pan_3_center	; less than 96
	jp	pan_3_right		; >= 96
pan_3_left:
	ldh	a,(#0x25)
	set	6,a
	res	2,a
	ldh	(#0x25),a
	jp	midi_top
pan_3_right:
	ldh	a,(#0x25)
	set	2,a
	res	6,a
	ldh	(#0x25),a
	jp	midi_top
pan_3_center:
	ldh	a,(#0x25)
	set	2,a
	set	6,a
	ldh	(#0x25),a
	jp	midi_top
pan_4:
	call	read_byte
	cp	#32
	jp	c,pan_4_left	; less than 32
	cp	#96			
	jp	c,pan_4_center	; less than 96
	jp	pan_4_right		; >= 96
pan_4_left:
	ldh	a,(#0x25)
	set	7,a
	res	3,a
	ldh	(#0x25),a
	jp	midi_top
pan_4_right:
	ldh	a,(#0x25)
	set	3,a
	res	7,a
	ldh	(#0x25),a
	jp	midi_top
pan_4_center:
	ldh	a,(#0x25)
	set	3,a
	set	7,a
	ldh	(#0x25),a
	jp	midi_top
		



;----------------------------------------------------------------------
;Helper Functions
;----------------------------------------------------------------------

; read_byte:
; destroys a,b,c, carry, zero flags
; returns byte in a
; reads a byte at 31250 bps, 8-n-(1/0/1.5)

read_byte:
	ld	b,#0x80		; bit pos

wait_for_start_bit:

	ldh	a,(#0x56)
	bit	4,a
	jp	nz,wait_for_start_bit	; oh 12

	call	delay_startbit		; oh 12 + 24 = 36

read_next_bit:
	ldh	a,(#0x56)						;12
	swap	a							;8
	rr	a	;put pin 4 into carry			;8
	rr	b							;8

	; XXX SWAP THESE TWO INSTRUCTIONS IF NEEDED (skip delay on last bit!)
	; ok done itz
	jp	c,byte_done						;12/16
	call	delay_interbit					;24  at delay oh = 72 +16 for jump=88

									; fallthrough = 48
	jp	read_next_bit					;16

byte_done:
	
	; does MSN=F?
	;ld	a,#0xF0
;	and	b
;	cp	#0xF0
;	jp	nz, no_f_message
	
	; if so:
	;	if LSN = 0
;	ld	a,b
;	cp	#0xF0
;	jp	nz, not_sysex
	
		
;sysex_loop:
;	call read_byte
;	cp	#0xF7
;	jp	nz, sysex_loop
	
;not_sysex:
;	call read_byte
	
;no_f_message:
	ld	a,b	;4
	ret


; Delays
; After start bit:
delay_startbit:
	ld	c,#14	; was 23			;8
dstart:
	dec	c					;4
	jp	nz,dstart				;12/16
	ret						;16
; needs to wait 268-36 + a little to get inthe middle = 232 + (.25*268=67) 300
;13*20 + 16ext + 0nop + 16ret + 8ld = 300

; Interbit
delay_interbit:
	ld	c,#8	; was 23			;8
dinter:
	dec	c					;4
	jp	nz,dinter				;12/16
	ret						;16
; 7*20 + 16 ext + 0 nops +8 ld + 16 ret = 180
; needs to wait 268-88 = 180 



;----------------------------------------------------------------------
;Initialization Functions
;----------------------------------------------------------------------

ser_init:
	ld	a,#0b11000000
	ldh	(#0x56),a	; read enable

	ld	a,#0xFF		;send stop bit
	ldh	(#0x01),a
	ld	a,#0x83
	ldh	(#0x02),a

	; Turn on Sound!

	ld	a,#0b10001111
	ldh	(#0x26),a		; NR52
	ld	a,#0b01110111
	ldh	(#0x24),a     	; NR50
	ld	a,#0b11111111
	ldh	(#0x25),a		; NR51

	ld	a,#0b10000000	; NR30 (sound 3 on)
	ldh	(#0x1A),a

	; Wave RAM
	ld	a,#0x01
	ldh	(#0x30),a
	ld	a,#0x23
	ldh	(#0x31),a
	ld	a,#0x45
	ldh	(#0x32),a
	ld	a,#0x67
	ldh	(#0x33),a
	ld	a,#0x89
	ldh	(#0x34),a
	ld	a,#0xab
	ldh	(#0x35),a
	ld	a,#0xcd
	ldh	(#0x36),a
	ld	a,#0xef
	ldh	(#0x37),a
	ld	a,#0xed
	ldh	(#0x38),a
	ld	a,#0xcb
	ldh	(#0x39),a
	ld	a,#0xa9
	ldh	(#0x3a),a
	ld	a,#0x87
	ldh	(#0x3b),a
	ld	a,#0x65
	ldh	(#0x3c),a
	ld	a,#0x43
	ldh	(#0x3d),a
	ld	a,#0x21
	ldh	(#0x3e),a
	ld	a,#0x00
	ldh	(#0x3f),a



	ret


;Sets GBC into 2x Speed
toggle_speed:
        di

        ld      hl,#0xffff
        ld      a,(hl)
        push    af

        xor     a
        ld      (hl),a         ;disable interrupts
        ldh     (#0x0F),a

        ld      a,#0x30
        ldh     (#0x00),a

        ld      a,#<1
        ldh     (#0x4d),a

        stop

        pop     af
        ld      (hl),a

        ei
        ret



;----------------------------------------------------------------------
; Lookup Tables
;----------------------------------------------------------------------

; MIDI note (36 base) to hi-frequency 3-bit
divval:
	.byte #0b00000000  ;0
	.byte #0b00101100
	.byte #0b00000000  ;1
	.byte #0b10011100
	.byte #0b00000001  ;2 
	.byte #0b00000110
	.byte #0b00000001  ;3 
	.byte #0b01101011
	.byte #0b00000001  ;4  (1,0x6b)
	.byte #0b11001001
	.byte #0b00000010  ;5  (2,0x23)
	.byte #0b00100011
	.byte #0b00000010  ;6
	.byte #0b01110111
	.byte #0b00000010  ;7
	.byte #0b11000110
	.byte #0b00000011  ;8
	.byte #0b00010010
	.byte #0b00000011
	.byte #0b01010110
	.byte #0b00000011
	.byte #0b10011011
	.byte #0b00000011
	.byte #0b11011010
	.byte #0b00000100
	.byte #0b00010110
	.byte #0b00000100
	.byte #0b01001110
	.byte #0b00000100
	.byte #0b10000011
	.byte #0b00000100
	.byte #0b10110101
	.byte #0b00000100
	.byte #0b11100101
	.byte #0b00000101
	.byte #0b00010001
	.byte #0b00000101
	.byte #0b00111011
	.byte #0b00000101
	.byte #0b01100011
	.byte #0b00000101
	.byte #0b10001001
	.byte #0b00000101
	.byte #0b10101100
	.byte #0b00000101  ;22=0x16 (0x05,0xce)
	.byte #0b11001110
	.byte #0b00000101
	.byte #0b11101101
	.byte #0b00000110
	.byte #0b00001010
	.byte #0b00000110
	.byte #0b00100111
	.byte #0b00000110
	.byte #0b01000010
	.byte #0b00000110
	.byte #0b01011011
	.byte #0b00000110
	.byte #0b01110010
	.byte #0b00000110
	.byte #0b10001001
	.byte #0b00000110
	.byte #0b10011110
	.byte #0b00000110
	.byte #0b10110010
	.byte #0b00000110
	.byte #0b11000100
	.byte #0b00000110
	.byte #0b11010110
	.byte #0b00000110
	.byte #0b11100111
	.byte #0b00000110
	.byte #0b11110111
	.byte #0b00000111
	.byte #0b00000110
	.byte #0b00000111
	.byte #0b00010100
	.byte #0b00000111
	.byte #0b00100001
	.byte #0b00000111
	.byte #0b00101101
	.byte #0b00000111
	.byte #0b00111001
	.byte #0b00000111
	.byte #0b01000100
	.byte #0b00000111
	.byte #0b01001111
	.byte #0b00000111
	.byte #0b01011001
	.byte #0b00000111
	.byte #0b01100010
	.byte #0b00000111
	.byte #0b01101011
	.byte #0b00000111
	.byte #0b01110011
	.byte #0b00000111
	.byte #0b01111011
	.byte #0b00000111
	.byte #0b10000011
	.byte #0b00000111
	.byte #0b10001010
	.byte #0b00000111
	.byte #0b10010000
	.byte #0b00000111
	.byte #0b10010111
	.byte #0b00000111
	.byte #0b10011101
	.byte #0b00000111
	.byte #0b10100010
	.byte #0b00000111
	.byte #0b10100111
	.byte #0b00000111
	.byte #0b10101100
	.byte #0b00000111
	.byte #0b10110001
	.byte #0b00000111
	.byte #0b10110110
	.byte #0b00000111
	.byte #0b10111010
	.byte #0b00000111
	.byte #0b10111110
	.byte #0b00000111
	.byte #0b11000001
	.byte #0b00000111
	.byte #0b11000100
	.byte #0b00000111
	.byte #0b11001000
	.byte #0b00000111
	.byte #0b11001011
	.byte #0b00000111
	.byte #0b11001110
	.byte #0b00000111
	.byte #0b11010001
	.byte #0b00000111
	.byte #0b11010100
	.byte #0b00000111
	.byte #0b11010110
	.byte #0b00000111
	.byte #0b11011001
	.byte #0b00000111
	.byte #0b11011011
	.byte #0b00000111
	.byte #0b11011101
	.byte #0b00000111
	.byte #0b11011111

pbmidi:
	.byte #0b00000000
	.byte #0b00000000
	.byte #0b00000001
	.byte #0b00000010
	.byte #0b00000011
	.byte #0b00000011
	.byte #0b00000100
	.byte #0b00000101
	.byte #0b00000110
	.byte #0b00000110
	.byte #0b00000111
	.byte #0b00001000
	.byte #0b00001001
	.byte #0b00001001
	.byte #0b00001010
	.byte #0b00001011
	.byte #0b00001100
	.byte #0b00001100
	.byte #0b00001101
	.byte #0b00001110
	.byte #0b00001111
	.byte #0b00001111
	.byte #0b00010000
	.byte #0b00010001
	.byte #0b00010010
	.byte #0b00010010
	.byte #0b00010011
	.byte #0b00010100
	.byte #0b00010101
	.byte #0b00010101
	.byte #0b00010110
	.byte #0b00011000
	
;Data for parameters, in groups of 4
controllers:
	;Register
	;Lengthmask
	;Shift right count
	;Position Mask

	;FF10 (NR10)
	.byte	#0x10
	.byte	#0b11100000	; 1 sweep time						0
	.byte	#1
	.byte	#0b01110000
	.byte	#0x10
	.byte	#0b10000000 ; 1 sweep increase / decrease				1
	.byte	#4
	.byte	#0b00001000
	.byte	#0x10
	.byte	#0b11100000 ; 1 # of sweep shifts					2
	.byte	#5
	.byte	#0b00000111

	;FF11 (NR11)
	.byte	#0x11
	.byte	#0b11000000	; 1 wave pattern duty					3
	.byte	#0
	.byte	#0b11000000
	.byte	#0x11
	.byte	#0b11111100 ; 1 sound length data					4
	.byte	#2
	.byte	#0b00111111

	;FF12 (NR12)
	.byte	#0x12
	.byte	#0b11110000	; 1 initial value of envelope (volume)		5
	.byte	#0
	.byte	#0b11110000
	.byte	#0x12
	.byte	#0b10000000 ; 1 envelope up down					6
	.byte	#4
	.byte	#0b00001000
	.byte	#0x12
	.byte	#0b11100000 ; 1 # of envelope sweep					7
	.byte	#5
	.byte	#0b00000111

	;FF13 (NR13)
	.byte	#0x13
	.byte	#0b11111111 ; 1 frequency data low					8
	.byte	#0
	.byte	#0b11111111

	;FF14 (NR14)
	.byte	#0x14
	.byte	#0b10000000	; 1 initial							9
	.byte	#0
	.byte	#0b10000000
	.byte	#0x14
	.byte	#0b10000000 ; 1 counter / consecutive				10
	.byte	#1
	.byte	#0b01000000
	.byte	#0x14
	.byte	#0b11100000 ; 1 frequency data high					11
	.byte	#5
	.byte	#0b00000111

	;FF16 (NR21)
	.byte	#0x16
	.byte	#0b11000000	; 2 wave pattern duty					12
	.byte	#0
	.byte	#0b11000000
	.byte	#0x16
	.byte	#0b11111100 ; 2 sound length data					13
	.byte	#2
	.byte	#0b00111111

	;FF17 (NR22)
	.byte	#0x17
	.byte	#0b11110000 ; 2 initial value of envelope				14
	.byte	#0
	.byte	#0b11110000
	.byte	#0x17
	.byte	#0b10000000 ; 2 envelope up down					15
	.byte	#4
	.byte	#0b00001000
	.byte	#0x17
	.byte	#0b11100000 ; 2 # of envelope sweeps				16
	.byte	#5
	.byte	#0b00000111

	;FF18 (NR23)
	.byte	#0x18
	.byte	#0b11111111 ; 2 frequency data low					17
	.byte	#0
	.byte	#0b11111111

	;FF19 (NR24)
	.byte	#0x19
	.byte	#0b10000000	; 2 initial							18
	.byte	#0
	.byte	#0b10000000
	.byte	#0x19
	.byte	#0b10000000 ; 2 counter / consecutive				19
	.byte	#1
	.byte	#0b01000000
	.byte	#0x19
	.byte	#0b11100000 ; 2 frequency data high					20
	.byte	#5
	.byte	#0b00000111

	; Sound 3- Wave Pattern
	;FF1A (NR30)
	.byte	#0x1A
	.byte	#0b10000000 ; 3 sound off/on						21
	.byte	#0
	.byte	#0b10000000

	;FF1B (NR31)
	.byte	#0x1B
	.byte	#0b11111111 ; 3 sound length data					22
	.byte	#0
	.byte	#0b11111111

	;FF1C (NR32)
	.byte	#0x1C
	.byte	#0b11000000 ; 3 select output level for wave pattern		23
	.byte	#1
	.byte	#0b01100000

	;FF1D (NR33)
	.byte	#0x1D
	.byte	#0b11111111 ; 3 frequency data low					24
	.byte	#0
	.byte	#0b11111111

	;FF1E (NR34)
	.byte	#0x1E
	.byte	#0b10000000	; 3 initial							25
	.byte	#0
	.byte	#0b10000000
	.byte	#0x1E
	.byte	#0b10000000 ; 3 counter / consecutive				26
	.byte	#1
	.byte	#0b01000000
	.byte	#0x1E
	.byte	#0b11100000 ; 3 frequency data high					27
	.byte	#5
	.byte	#0b00000111

	;FF20 (NR41)
	.byte	#0x20
	.byte	#0b11111100 ; 4 sound length data					28
	.byte	#2
	.byte	#0b00111111

	;FF21 (NR42)
	.byte	#0x21
	.byte	#0b11110000 ; 4 initial value of envelope				29
	.byte	#0
	.byte	#0b11110000
	.byte	#0x21
	.byte	#0b10000000 ; 4 envelope up down					30
	.byte	#4
	.byte	#0b00001000
	.byte	#0x21
	.byte	#0b11100000 ; 4 # of envelope sweeps				31
	.byte	#5
	.byte	#0b00000111

	;FF22 (NR43)
	.byte	#0x22
	.byte	#0b11110000 ; 4 shift clock freq for polynomial			32
	.byte	#0
	.byte	#0b11110000
	.byte	#0x22
	.byte	#0b10000000 ; 4 polynomial's counter step				33
	.byte	#4
	.byte	#0b00001000
	.byte	#0x22
	.byte	#0b11100000 ; 4 polynomial's counter ratio			34
	.byte	#5
	.byte	#0b00000111

	;FF23 (NR44)
	.byte	#0x23
	.byte	#0b10000000 ; 4 initial							35
	.byte	#0
	.byte	#0b10000000
	.byte	#0x23
	.byte	#0b10000000 ; 4 counter / consecutive				36
	.byte	#1
	.byte	#0b01000000

	;FF24 (NR50)
	.byte	#0x24
	.byte	#0b10000000 ; - vin->s02 on off					37
	.byte	#0
	.byte	#0b10000000
	.byte	#0x24
	.byte	#0b11100000 ; - s02 output level					38
	.byte	#1
	.byte	#0b01110000
	.byte	#0x24
	.byte	#0b10000000 ; - vin->s01 on off					39
	.byte	#4
	.byte	#0b00001000
	.byte	#0x24
	.byte	#0b11100000 ; - s01 output level					40
	.byte	#5
	.byte	#0b00000111

	;FF25 (NR51)
	.byte	#0x25
	.byte	#0b10000000 ; - sound 4 -> so2					41
	.byte	#0
	.byte	#0b10000000
	.byte	#0x25
	.byte	#0b10000000 ; - sound 3 -> so2					42
	.byte	#1
	.byte	#0b01000000
	.byte	#0x25
	.byte	#0b10000000 ; - sound 2 -> so2					43
	.byte	#2
	.byte	#0b00100000
	.byte	#0x25
	.byte	#0b10000000 ; - sound 1 -> so2					44
	.byte	#3
	.byte	#0b00010000
	.byte	#0x25
	.byte	#0b10000000 ; - sound 4 -> so1					45
	.byte	#4
	.byte	#0b00001000
	.byte	#0x25
	.byte	#0b10000000 ; - sound 3 -> so1					46
	.byte	#5
	.byte	#0b00000100
	.byte	#0x25
	.byte	#0b10000000 ; - sound 2 -> so1					47
	.byte	#6
	.byte	#0b00000010
	.byte	#0x25
	.byte	#0b10000000 ; - sound 1 -> so1					48
	.byte	#7
	.byte	#0b00000001

	;FF26 (NR52)
	.byte	#0x26
	.byte	#0b10000000 ; - all sound on off					49
	.byte	#0
	.byte	#0b10000000
	.byte	#0x26
	.byte	#0b10000000 ; - sound 4 on off					50
	.byte	#4
	.byte	#0b00001000
	.byte	#0x26
	.byte	#0b10000000 ; - sound 3 on off					51
	.byte	#5
	.byte	#0b00000100
	.byte	#0x26
	.byte	#0b10000000 ; - sound 2 on off					52
	.byte	#6
	.byte	#0b00000010
	.byte	#0x26
	.byte	#0b10000000 ; - sound 1 on off					53
	.byte	#7
	.byte	#0b00000001


; use me for debugging
;	ld	a,(.pb_save)
;	ld	(_program),a
;	call	_set_program0


midi_noteon:
	ld	a,(_channel)
	cp	#0
	jp	z,midi_noteon1
	cp	#1
	jp	z,midi_noteon2
	cp	#2
	jp	z,midi_noteon3
	cp	#3
	jp	z,midi_noteon4
	

midi_noteon1:
	ld	a,b		;a now contains note number
	cp	#36
	jp	c, note_range
	cp	#108
	jp	nc, note_range
	ld	b,a		; keep unsubtracted note number safe

recallpb1:
	ld	a,b				; retrive safe note number
	ld	(.last_midi1q),a		; stash midi val ; possible cur_play
	ld	a,(.pb1_val)			; recall pitch bend
	
				; pitch bend is in a, note number is in b

	add b			; add note number to pitch bend
	sub	#48		; gameboy starts at MIDI note 36, so 48w/ PB gives 36+/-12


; refined less-twisted, less-complicated note on way w/ PB

				; a contains note number 
	sla a			; indexed in pairs (a=a*2)
	ld	c,a		; b now contains offset into freq look up table
     


	ld	hl,#divval		; freq lookup table
      	ld	b,#0
      	add	hl,bc			; hl now contains addr of low 8-bit divider val.
      	ld	a,(hl)			; get freq. divider val
   	
      	ld	b,a			; keep it safe
      	inc hl
      	ld	a,(hl)			
      	ld	c,a			; now bc contains divider val
	ld	h,b
	ld	l,c			; now hl contains it.
      	

; write the low part, then the velocity, then the high part,
; because you HAVE to do it in that order.

	

; do consec 

	ld	a,h			; recall MS freq reg data
	ld	b,#0b10000000		; consec on, initial on
	or	b			; or it with freq hi info
	ld	d,a			; now the freq hi + consec bitis in d 


; get velocity, write velocity

	call	read_byte		; let's get the velocity!

	cp	#0			; is velocity 0?
	jp	nz, normal1		; if not, it's a normal note on
	
	ld	a,(.cur_play1)		; get currently playing note
	ld	b,a			; move it here
	ld	a,(.last_midi1q)	; get possible math
	cp	b			; do the notes match?
	jp	z,shadynoteoff		; if so, kill it!
	jp 	midi_top		; otherwise book out of here
	
shadynoteoff:
	ld	a,(.cha_env)
	ld	c,a
	ldh	a,(c)	
	and	#0x0F
	ldh	(c),a				; initial envelope = 0
	jp midi_top
	
normal1:	
	
	
; write lo freq register

	ld	a,(.cha_lo)		; a contains the low-half register assoc by channel/voice
	ld	c,a			; store low-freq regist addr here
	ld	a,l			; move least-significant data into a
	ldh	(c),a			; store LS data in the lo freq register

; write sound1 env reg

;	ld	b,a
					; b should still contain velocity

	ld	a,(.cha_env)	; and we'll change the envelope accordingly
	ld	c,a
	ld	a,b
	sla	a			; velocity from 7 bits to 8
	and	#0xF0			; trim it to 4 leftmost bits
	ld	b,a			; pop it in b
	ldh	a,(c)			; now get current envelope
	and	#0x0F			; delete the initial data
	or	b			; or in our scaled data
	ldh	(c),a			; put it back!

; write hi frequency register

	ld	a,(.cha_hi)
	ld	c,a
	ld	a,d			; recall the hi freq register 
	ldh	(c),a			; put it in

; store current playing note
	ld	a,(.last_midi1q)		; get the possible one
	ld	(.cur_play1),a			; remember it

	jp	midi_top


; ------------------------------------------------------------------------------------------------------------------------


midi_noteon2:
	ld	a,b		;a now contains note number
	cp	#36
	jp	c, note_range
	cp	#108
	jp	nc, note_range
	ld	b,a		; keep unsubtracted note number safe
	
	
	ld	a,b				; retrive safe note number
	ld	(.last_midi2q),a			; stash midi val for channel
	ld	a,(.pb2_val)			; recall pitch bend
		
					; pitch bend is in a, note number is in b
	
	add b			; add note number to pitch bend
	sub	#48		; gameboy starts at MIDI note 36, so 48w/ PB gives 36+/-12
	
	
	; refined less-twisted, less-complicated note on way w/ PB
	
					; a contains note number 
	sla a			; indexed in pairs (a=a*2)
	ld	c,a		; b now contains offset into freq look up table
	     
	
	
	ld	hl,#divval		; freq lookup table
	ld	b,#0
	add	hl,bc			; hl now contains addr of low 8-bit divider val.
	ld	a,(hl)			; get freq. divider val
	   	
	ld	b,a			; keep it safe
	inc hl
	ld	a,(hl)			
	ld	c,a			; now bc contains divider val
	ld	h,b
	ld	l,c			; now hl contains it.
	      	
	
	; write the low part, then the velocity, then the high part,
	; because you HAVE to do it in that order.
	
	
	; do consec 
	
	ld	a,h			; recall MS freq reg data
	ld	b,#0b10000000		; consec on, initial on
	or	b			; or it with freq hi info
	ld	d,a			; now the freq hi + consec bitis in d 
	
	
	; get velocity, write velocity
	
	call	read_byte		; let's get the velocity!

	cp	#0			; is velocity 0?
	jp	nz, normal2		; if not, it's a normal note on
	
	ld	a,(.cur_play2)		; get currently playing note
	ld	b,a			; move it here
	ld	a,(.last_midi2q)	; get possible math
	cp	b			; do the notes match?
	jp	z,shadynoteoff		; if so, kill it!
	jp 	midi_top		; otherwise book out of here


normal2:

	; write lo freq register
	ld	a,(.cha_lo)		; a contains the low-half register assoc by channel/voice
	ld	c,a			; store low-freq regist addr here
	ld	a,l			; move least-significant data into a
	ldh	(c),a			; store LS data in the lo freq register

					; b should still contain the velocity
	ld	a,(.cha_env)	; and we'll change the envelope accordingly
	ld	c,a
	ld	a,b
	sla	a			; velocity from 7 bits to 8
	and	#0xF0			; trim it to 4 leftmost bits
	ld	b,a			; pop it in b
	ldh	a,(c)			; now get current envelope
	and	#0x0F			; delete the initial data
	or	b			; or in our scaled data
	ldh	(c),a			; put it back!
	
	; write hi frequency register
	
	ld	a,(.cha_hi)
	ld	c,a
	ld	a,d			; recall the hi freq register 
	ldh	(c),a			; put it in

; store current playing note

	ld	a,(.last_midi2q)		; get the possible one
	ld	(.cur_play2),a			; remember it

	jp	midi_top


; ------------------------------------------------------------------------------------------------------------



midi_noteon3:

	ld	a,b		;a now contains note number
	cp	#36
	jp	c, note_range
	cp	#108
	jp	nc, note_range

	ld	b,a		; keep unsubtracted note number safe
	
	
	ld	a,b				; retrive safe note number
	ld	(.last_midi3q),a		; stash midi val for channel
	ld	a,(.pb3_val)			; recall pitch bend
				; pitch bend is in a, note number is in b

	add b			; add note number to pitch bend
	sub	#48		; gameboy starts at MIDI note 36, so 48w/ PB gives 36+/-12


; refined less-twisted, less-complicated note on way w/ PB

				; a contains note number 
	sla a			; indexed in pairs (a=a*2)
	ld	c,a		; b now contains offset into freq look up table


	ld	hl,#divval		; freq lookup table
      	ld	b,#0
      	add	hl,bc			; hl now contains addr of low 8-bit divider val.
      	ld	a,(hl)			; get freq. divider val
   	
      	ld	b,a			; keep it safe
      	inc hl
      	ld	a,(hl)			
      	ld	c,a			; now bc contains divider val
	ld	h,b
	ld	l,c			; now hl contains it.
      	

; write the low part, then the velocity, then the high part,
; because you HAVE to do it in that order.


sound3_velo:
	call	read_byte		; let's get the velocity!
	ld	e,a			; save velo here
	
	cp	#0			; is velocity 0?
	jp	nz, normal3		; if not, it's a normal note on
	
	ld	a,(.cur_play3)		; get currently playing note
	ld	b,a			; move it here
	ld	a,(.last_midi3q)	; get possible match
	cp	b			; do the notes match?
	jp	z,shadynoteoff		; if so, kill it!
	jp 	midi_top		; otherwise book out of here


normal3:

; write sound3 lo freq register

	ld	a,#0x1d			; sound3 lo freq reg?
	ld	c,a
	ld	a,l			; get lo freq part of "divider" val
	ldh	(c),a			; write it to the data in the lo freq register

; write sound3 hi freq register

	ld	a,(.cha_hi)		
	ld	c,a

	ld	a,h			; recall the hi freq register 
	ld	b,#0b10000000		; consec on, initial on
	or	b			; or it with freq hi info
	ldh	(c),a			; put it in

					
	ld	b,e			; b should already still contain velocity, but doesnt HA, so recall it from e

	ld	a,(.cha_env)	; and we'll change his envelope accordingly
	ld	c,a
	ld	a,b
	srl	a			; move it over 1
	and	#0xF0			; trim it to 2 leftmost bits 00110000
	ld	b,a			; pop it in b
	cp	#0x00
	jp	z,make_11		; mute
	cp	#0x10
	jp	z,make_11		; 1/4
	cp	#0x20
	jp	z,make_10		; 1/2
	cp	#0x30
	jp	z,make_01		; full
make_00:
	ld	a,#0b00000000		; mute
	jp	make_done
make_01:
	ld	a,#0b00100000		; 1/1
	jp	make_done
make_10:
	ld	a,#0b01000000		; 1/2
	jp	make_done
make_11:
	ld	a,#0b01100000		; 1/4
make_done:

	
	ldh	(c),a			; put it back!  waaah!


; store current playing note
	ld	a,(.last_midi3q)		; get the possible one
	ld	(.cur_play3),a			; remember it

	jp midi_top


; this is like handle_sound, but doesn't do the velocity part of it,
; it's meant for use with the pitch bend handler

pbhandle_sound3:			; sound3 is its own monster
				; coming into this routine, hl contains "divider" value

; write sound3 lo freq register

	ld	a,#0x1d			; sound3 lo freq reg?
	ld	c,a
	ld	a,l			; get lo freq part of "divider" val
	ldh	(c),a			; write it to the data in the lo freq register

; write sound3 hi freq register

	ld	a,(.cha_hi)		
	ld	c,a
	ld	a,h			; recall the hi freq register 
	ldh	(c),a			; put it in

	jp midi_top




;------------------------------------------------------------------------------------------------------------------

midi_noteon4:
	
	call	read_byte		; let's get the velocity!
	ld	b,a
	ld	a,(.cha_env)	; and we'll change the envelope accordingly
	ld	c,a
	ld	a,b
	sla	a			; velocity from 7 bits to 8
	and	#0xF0			; trim it to 4 leftmost bits
	ld	b,a			; pop it in b
	ldh	a,(c)			; now get current envelope
	and	#0x0F			; delete the initial data
	or	b			; or in our scaled data
	ldh	(c),a			; put it back!

; write hi frequency register

	ld	a,(.cha_hi)
	ld	c,a
	ld	a,d			; recall the hi freq register 
	ldh	(c),a			; put it in


; store current playing note
	ld	a,(.last_midi4q)		; get the possible one
	ld	(.cur_play4),a			; remember it



	jp	midi_top








;---------------------------------------------------------------------------------------------------------------------
note_range:
	call	read_byte
	jp	midi_top 












