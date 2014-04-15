; asmTest.asm
; Created by Idan Mintz
	ORG		0
	LOAD	Input
	OUT		LEDS
	SQRT
	STORE	Input
	OUT		TIMER
Wait:	IN Timer
	SUB		WaitT
	JPOS	Wait
	LOAD	Input
	OUT		LEDS
HERE: JUMP HERE
	
	
Input:	DW	&H100
WaitT:	DW	20
LEDS:     EQU &H01  ; red LEDs
TIMER:    EQU &H02  ; timer, usually running at 10 Hz