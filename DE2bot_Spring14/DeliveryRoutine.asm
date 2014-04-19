; DeliveryRoutine.asm
; Created by Idan Mintz

	ORG     &H000		;Begin program at x000
Init:
	LOAD    Zero
	OUT     LVELCMD     ; Stop motors
	OUT     RVELCMD
	
	CALL    SetupI2C    ; Configure the I2C
	CALL    BattCheck   ; Get battery voltage (and end if too low).
	OUT     SSEG2       ; Display batt voltage on SS

	LOAD    Zero
	ADDI    &H17        ; arbitrary reminder to toggle SW17
	OUT     SSEG1
WaitForUser:
	IN      XIO         ; contains KEYs and SAFETY
	AND     StartMask   ; mask with 0x10100 : KEY3 and SAFETY
	XOR     Mask4       ; KEY3 is active low; invert SAFETY to match
	JPOS    WaitForUser ; one of those is not ready, so try again

Main: ; "Real" program starts here.
	LOAD	One
	STORE	CurrX
	STORE	CurrY
	LOAD	ClkIn
	OUT		UART
	CALL	WaitForUART
	IN		UART
	CALL	WaitForUART
	IN		UART
	CALL	GetJobs
	CALL	JobSelect	
	
	
	
HERE: JUMP HERE

	
;***** SUBROUTINES

; Subroutine to wait (block) for 1 second
Wait1:
	STORE	WaitTemp
	OUT     TIMER
Wloop: 
	IN      TIMER
	OUT     LEDS
	ADDI    -10
	JNEG    Wloop
	LOAD	WaitTemp
	RETURN
	
Wait3:
	STORE	WaitTemp
	CALL	Wait1
	CALL	Wait1
	CALL	Wait1
	LOAD	WaitTemp
	RETURN
	

GetJobs:
	LOAD	Rqst
	STORE	JobCount
	
	;Put all the job requests into the UART FIFO
	JobAskLoop:
		LOAD	JobCount
		OUT		UART
		ADDI	1
		STORE	JobCount
		CALL	WaitForUART
		CALL	Wait1
		LOAD	JobCount
		ADDI	-40
				
		JNEG	JobAskLoop
		JZERO	JobAskLoop
	
	LOAD	Zero
	STORE	Iterator
	ADD		Jobs_Addr
	STORE	JobCount

	JobRetreiveLoop:
		CALL	WaitForUART
		IN		UART
		AND		MaskL2
		ISTORE	JobCount
		LOAD	JobCount
		ADDI	1
		STORE	JobCount
		
		
		CALL	WaitForUART
		IN		UART
		AND		MaskL2
		ISTORE	JobCount
		LOAD	JobCount
		ADDI	1
		STORE	JobCount
		CALL	WaitForUART
		IN		UART
		AND		MaskL2
		ISTORE	JobCount
		LOAD	JobCount
		ADDI	1
		STORE	JobCount
		CALL	WaitForUART
		IN		UART
		AND		MaskL2
		ISTORE	JobCount
		LOAD	JobCount
		ADDI	1
		STORE	JobCount
		CALL	WaitForUART
		IN		UART
		LOAD	Iterator
		ADDI	1
		STORE	Iterator
		ADDI	-8
		JNEG	JobRetreiveLoop
		
	RETURN
	
GoToLongWall:
		OUT		RESETODO
		LOAD	Zero
		ADDI	6		;creates mask 0000110 to enable sonars 2 and 3
		OUT		SONAREN
KeepTurning: ; Turn until the two sonar values are close enough 
		LOAD	FSlow
		OUT		LVELCMD
		LOAD	RSlow
		OUT		RVELCMD
		IN		DIST2
		STORE	Temp
		IN		DIST3
		SUB		TEMP	; Get difference of Sonar 2 and 3
		JPOS	SkipABS
		MULT	NegOne;
SkipABS:
		ADDI	-5
		JPOS	KeepTurning
		;Now go towards the wall
GoToWall:
		LOAD	FMed
		OUT		RVELCMD
		OUT		LVELCMD
		IN		DIST2
		ADDI	-5
		JPOS	GoToWall
		

JobSelect:
	LOAD	One
	STORE	JobCount
	ADD		TwoK
	STORE	BestDist
	LOAD	Jobs_Addr
	STORE	Temp
SelectLoop:
	ILOAD	Temp
	STORE	TempX1	
	OUT		LCD
	CALL	Wait3
	LOAD	Temp
	ADDI	1
	STORE	Temp
	ILOAD	Temp
	STORE	TempY1
	OUT		LCD
	CALL	Wait3
	LOAD	CurrX
	SUB		TempX1
	STORE	TempX2
	LOAD	CurrY
	SUB		TempY1
	STORE	TempY2
	MULT	TempY2
	STORE	TempY2
	LOAD	TempX2
	MULT	TempX2
	ADD		TempY2
	SQRT
	STORE	TempX2
	OUT		LCD
	CALL	Wait3
	
	SUB		BestDist
	OUT		LCD
	CALL	Wait3
	JPOS	SkipSet
	LOAD	TempX2
	STORE	BestDist
	OUT		LCD
	CALL	Wait3
	LOAD	JobCount
	Store	CurrJob
SkipSet:
	LOAD	Temp
	ADDI	3
	STORE	Temp
	LOAD	JobCount
	ADDI	1
	STORE	JobCount
	ADDI	-9
	JNEG	SelectLoop
	RETURN
	

	
	
	
; Loops until the UART output FIFO is not empty
WaitForUART:
	IN UART_CHK
	JZERO	WaitForUART
	RETURN

TabLookUp:
	LOAD	CurrY
	SUB		One
	MULT	Fifty
	STORE	Temp
	LOAD	NEXTX
	SUB		One
	MULT	Ten
	ADD		Temp
	STORE	Temp
	LOAD	NEXTY
	SUB		One
	MULT	Two
	ADD		Temp
	STORE	Temp
	ADDI	600
	STORE	Temp
	ILOAD	Temp
	STORE	Angle
	Load	Temp
	ADDI	1
	STORE	Temp
	ILOAD	Temp
	STORE	Mag
	RETURN
		
		
	

; This subroutine will get the battery voltage,
; and stop program execution if it is too low.
; SetupI2C must be executed prior to this.
BattCheck:
	CALL    GetBattLvl 
	SUB     MinBatt
	JNEG    DeadBatt
	ADD     MinBatt     ; get original value back
	RETURN
; If the battery is too low, we want to make
; sure that the user realizes it...
DeadBatt:
	LOAD    Four
	OUT     BEEP        ; start beep sound
	CALL    GetBattLvl  ; get the battery level
	OUT     SSEG1       ; display it everywhere
	OUT     SSEG2
	OUT     LCD
	LOAD    Zero
	ADDI    -1          ; 0xFFFF
	OUT     LEDS        ; all LEDs on
	OUT     GLEDS
	CALL    Wait1       ; 1 second
	Load    Zero
	OUT     BEEP        ; stop beeping
	LOAD    Zero
	OUT     LEDS        ; LEDs off
	OUT     GLEDS
	CALL    Wait1       ; 1 second
	JUMP    DeadBatt    ; repeat forever
	
; Subroutine to configure the I2C for reading batt voltage
; Only needs to be done once after each reset.
SetupI2C:
	LOAD    I2CWCmd     ; 0x1190 (write 1B, read 1B, addr 0x90)
	OUT     I2C_CMD     ; to I2C_CMD register
	LOAD    Zero        ; 0x0000 (A/D port 0, no increment)
	OUT     I2C_DATA    ; to I2C_DATA register
	OUT     I2C_RDY     ; start the communication
	CALL    BlockI2C    ; wait for it to finish
	RETURN
	
; Subroutine to read the A/D (battery voltage)
; Assumes that SetupI2C has been run
GetBattLvl:
	LOAD    I2CRCmd     ; 0x0190 (write 0B, read 1B, addr 0x90)
	OUT     I2C_CMD     ; to I2C_CMD
	OUT     I2C_RDY     ; start the communication
	CALL    BlockI2C    ; wait for it to finish
	IN      I2C_DATA    ; get the returned data
	RETURN

; Subroutine to block until I2C device is idle
BlockI2C:
	IN      I2C_RDY;   ; Read busy signal
	JPOS    BlockI2C    ; If not 0, try again
	RETURN              ; Else return

	
; Variables
Temp:     DW 0 ; "Temp" is not a great name, but can be helpful
WaitTemp: DW 0
TempX1:	  DW 0
TempY1:	  DW 0
TempX2:	  DW 0
TempY2:	  DW 0
JobsComp: DW 0 ; Number of jobs that have  been completed
JobCount: DW &H21 ; Variable used for getting jobs
CurrJob:  DW 0
BestDist: DW 0
CurrX:	  DW &H00
CurrY:	  DW &H00
NextX:    DW &H0000 ; Target X Position in grid space
;NextX_A: DW &H0000 ; Target X position in absolute location (measured/odometry)
NextY:    DW &H0000 ; Target Y Position in grid space
Angle:	  DW 0
Mag:	  DW 0
;NextY_A: DW &H0000 ; Target Y position in absolute location (measured/odometry)
Iterator: DW &H0000 ; Used for loops as counter

; Constants
NegOne:   DW -1
Zero:     DW 0
One:      DW 1
Two:      DW 2
Three:    DW 3
Four:     DW 4
Five:     DW 5
Six:      DW 6
Seven:    DW 7
Eight:    DW 8
Nine:     DW 9
Ten:      DW 10
Fifty:	  DW 50
TwoK:	  DW 2000
FSlow:    DW 100       ; 100 is about the lowest value that will move at all
RSlow:    DW -100
FFast:    DW 500       ; 500 is a fair clip (511 is max)
RFast:    DW -500
FMed:	  DW 300
RMed:	  DW -300
; Masks of multiple bits can be constructed by, for example,
; LOAD Mask0; OR Mask2; OR Mask4, etc.
Mask0:    	DW &B00000001
Mask1:    	DW &B00000010
Mask2:    	DW &B00000100
Mask3:    	DW &B00001000
Mask4:    	DW &B00010000
Mask5:    	DW &B00100000
Mask6:  	DW &B01000000
Mask7:	    DW &B10000000
MaskL2:		DW &H0F
StartMask: 	DW &B10100
AllSonar: 	DW &B11111111
OneMeter: 	DW 476        ; one meter in 2.1mm units
HalfMeter: 	DW 238       ; half meter in 2.1mm units
TwoFeet:  	DW 290        ; ~2ft in 2.1mm units
MinBatt:  	DW 110        ; 11V - minimum safe battery voltage
I2CWCmd:  	DW &H1190     ; write one byte, read one byte, addr 0x90
I2CRCmd:  	DW &H0190     ; write nothing, read one byte, addr 0x90

;Constants
ClkIn: 	  	DW &H10
Rqst:		DW &H21
PkUp:		DW &H30
DrpOff:		DW &H40
TmLft:		DW &H50
ClkOut:		DW &H60
Done:		DW &H90

Table_Addr:	DW 600
Jobs_Addr:	DW 900

		  
		  ORG 600
Tab1S1Ang:	DW 0
Tab1S1Dst:	DW 0
Tab1S2Ang:	DW 0
Tab1S2Dst:	DW 290
Tab1S3Ang:	DW 0
Tab1S3Dst:	DW 581
Tab1S4Ang:	DW 0
Tab1S4Dst:	DW 871
Tab1S5Ang:	DW 0
Tab1S5Dst:	DW 1161
Tab1S6Ang:	DW 526
Tab1S6Dst:	DW 290
Tab1S7Ang:	DW 613
Tab1S7Dst:	DW 411
Tab1S8Ang:	DW 649
Tab1S8Dst:	DW 649
Tab1S9Ang:	DW 665
Tab1S9Dst:	DW 918
Tab1S10Ang:	DW 674
Tab1S10Dst:	DW 1197
Tab1S11Ang:	DW 526
Tab1S11Dst:	DW 581
Tab1S12Ang:	DW 577
Tab1S12Dst:	DW 649
Tab1S13Ang:	DW 613
Tab1S13Dst:	DW 821
Tab1S14Ang:	DW 635
Tab1S14Dst:	DW 1047
Tab1S15Ang:	DW 649
Tab1S15Dst:	DW 1298
Tab1S16Ang:	DW 526
Tab1S16Dst:	DW 871
Tab1S17Ang:	DW 562
Tab1S17Dst:	DW 918
Tab1S18Ang:	DW 591
Tab1S18Dst:	DW 1047
Tab1S19Ang:	DW 613
Tab1S19Dst:	DW 1232
Tab1S20Ang:	DW 692
Tab1S20Dst:	DW 1451
Tab1S21Ang:	DW 526
Tab1S21Dst:	DW 1161
Tab1S22Ang:	DW 553
Tab1S22Dst:	DW 1197
Tab1S23Ang:	DW 577
Tab1S23Dst:	DW 1298
Tab1S24Ang:	DW 598
Tab1S24Dst:	DW 1451
Tab1S25Ang:	DW 613
Tab1S25Dst:	DW 1642

Tab2S1Ang:	DW 0
Tab2S1Dst:	DW 0
Tab2S2Ang:	DW 0
Tab2S2Dst:	DW 0
Tab2S3Ang:	DW 0
Tab2S3Dst:	DW 0
Tab2S4Ang:	DW 0
Tab2S4Dst:	DW 0
Tab2S5Ang:	DW 0
Tab2S5Dst:	DW 0
Tab2S6Ang:	DW 0
Tab2S6Dst:	DW 0
Tab2S7Ang:	DW 0
Tab2S7Dst:	DW 0
Tab2S8Ang:	DW 0
Tab2S8Dst:	DW 0
Tab2S9Ang:	DW 0
Tab2S9Dst:	DW 0
Tab2S10Ang:	DW 0
Tab2S10Dst:	DW 0
Tab2S11Ang:	DW 0
Tab2S11Dst:	DW 0
Tab2S12Ang:	DW 0
Tab2S12Dst:	DW 0
Tab2S13Ang:	DW 0
Tab2S13Dst:	DW 0
Tab2S14Ang:	DW 0
Tab2S14Dst:	DW 0
Tab2S15Ang:	DW 0
Tab2S15Dst:	DW 0
Tab2S16Ang:	DW 0
Tab2S16Dst:	DW 0
Tab2S17Ang:	DW 0
Tab2S17Dst:	DW 0
Tab2S18Ang:	DW 0
Tab2S18Dst:	DW 0
Tab2S19Ang:	DW 0
Tab2S19Dst:	DW 0
Tab2S20Ang:	DW 0
Tab2S20Dst:	DW 0
Tab2S21Ang:	DW 0
Tab2S21Dst:	DW 0
Tab2S22Ang:	DW 0
Tab2S22Dst:	DW 0
Tab2S23Ang:	DW 0
Tab2S23Dst:	DW 0
Tab2S24Ang:	DW 0
Tab2S24Dst:	DW 0
Tab2S25Ang:	DW 0
Tab2S25Dst:	DW 0

Tab3S1Ang:	DW 0
Tab3S1Dst:	DW 0
Tab3S2Ang:	DW 0
Tab3S2Dst:	DW 0
Tab3S3Ang:	DW 0
Tab3S3Dst:	DW 0
Tab3S4Ang:	DW 0
Tab3S4Dst:	DW 0
Tab3S5Ang:	DW 0
Tab3S5Dst:	DW 0
Tab3S6Ang:	DW 0
Tab3S6Dst:	DW 0
Tab3S7Ang:	DW 0
Tab3S7Dst:	DW 0
Tab3S8Ang:	DW 0
Tab3S8Dst:	DW 0
Tab3S9Ang:	DW 0
Tab3S9Dst:	DW 0
Tab3S10Ang:	DW 0
Tab3S10Dst:	DW 0
Tab3S11Ang:	DW 0
Tab3S11Dst:	DW 0
Tab3S12Ang:	DW 0
Tab3S12Dst:	DW 0
Tab3S13Ang:	DW 0
Tab3S13Dst:	DW 0
Tab3S14Ang:	DW 0
Tab3S14Dst:	DW 0
Tab3S15Ang:	DW 0
Tab3S15Dst:	DW 0
Tab3S16Ang:	DW 0
Tab3S16Dst:	DW 0
Tab3S17Ang:	DW 0
Tab3S17Dst:	DW 0
Tab3S18Ang:	DW 0
Tab3S18Dst:	DW 0
Tab3S19Ang:	DW 0
Tab3S19Dst:	DW 0
Tab3S20Ang:	DW 0
Tab3S20Dst:	DW 0
Tab3S21Ang:	DW 0
Tab3S21Dst:	DW 0
Tab3S22Ang:	DW 0
Tab3S22Dst:	DW 0
Tab3S23Ang:	DW 0
Tab3S23Dst:	DW 0
Tab3S24Ang:	DW 0
Tab3S24Dst:	DW 0
Tab3S25Ang:	DW 0
Tab3S25Dst:	DW 0

Tab4S1Ang:	DW 0
Tab4S1Dst:	DW 0
Tab4S2Ang:	DW 0
Tab4S2Dst:	DW 0
Tab4S3Ang:	DW 0
Tab4S3Dst:	DW 0
Tab4S4Ang:	DW 0
Tab4S4Dst:	DW 0
Tab4S5Ang:	DW 0
Tab4S5Dst:	DW 0
Tab4S6Ang:	DW 0
Tab4S6Dst:	DW 0
Tab4S7Ang:	DW 0
Tab4S7Dst:	DW 0
Tab4S8Ang:	DW 0
Tab4S8Dst:	DW 0
Tab4S9Ang:	DW 0
Tab4S9Dst:	DW 0
Tab4S10Ang:	DW 0
Tab4S10Dst:	DW 0
Tab4S11Ang:	DW 0
Tab4S11Dst:	DW 0
Tab4S12Ang:	DW 0
Tab4S12Dst:	DW 0
Tab4S13Ang:	DW 0
Tab4S13Dst:	DW 0
Tab4S14Ang:	DW 0
Tab4S14Dst:	DW 0
Tab4S15Ang:	DW 0
Tab4S15Dst:	DW 0
Tab4S16Ang:	DW 0
Tab4S16Dst:	DW 0
Tab4S17Ang:	DW 0
Tab4S17Dst:	DW 0
Tab4S18Ang:	DW 0
Tab4S18Dst:	DW 0
Tab4S19Ang:	DW 0
Tab4S19Dst:	DW 0
Tab4S20Ang:	DW 0
Tab4S20Dst:	DW 0
Tab4S21Ang:	DW 0
Tab4S21Dst:	DW 0
Tab4S22Ang:	DW 0
Tab4S22Dst:	DW 0
Tab4S23Ang:	DW 0
Tab4S23Dst:	DW 0
Tab4S24Ang:	DW 0
Tab4S24Dst:	DW 0
Tab4S25Ang:	DW 0
Tab4S25Dst:	DW 0

Tab5S1Ang:	DW 0
Tab5S1Dst:	DW 0
Tab5S2Ang:	DW 0
Tab5S2Dst:	DW 0
Tab5S3Ang:	DW 0
Tab5S3Dst:	DW 0
Tab5S4Ang:	DW 0
Tab5S4Dst:	DW 0
Tab5S5Ang:	DW 0
Tab5S5Dst:	DW 0
Tab5S6Ang:	DW 0
Tab5S6Dst:	DW 0
Tab5S7Ang:	DW 0
Tab5S7Dst:	DW 0
Tab5S8Ang:	DW 0
Tab5S8Dst:	DW 0
Tab5S9Ang:	DW 0
Tab5S9Dst:	DW 0
Tab5S10Ang:	DW 0
Tab5S10Dst:	DW 0
Tab5S11Ang:	DW 0
Tab5S11Dst:	DW 0
Tab5S12Ang:	DW 0
Tab5S12Dst:	DW 0
Tab5S13Ang:	DW 0
Tab5S13Dst:	DW 0
Tab5S14Ang:	DW 0
Tab5S14Dst:	DW 0
Tab5S15Ang:	DW 0
Tab5S15Dst:	DW 0
Tab5S16Ang:	DW 0
Tab5S16Dst:	DW 0
Tab5S17Ang:	DW 0
Tab5S17Dst:	DW 0
Tab5S18Ang:	DW 0
Tab5S18Dst:	DW 0
Tab5S19Ang:	DW 0
Tab5S19Dst:	DW 0
Tab5S20Ang:	DW 0
Tab5S20Dst:	DW 0
Tab5S21Ang:	DW 0
Tab5S21Dst:	DW 0
Tab5S22Ang:	DW 0
Tab5S22Dst:	DW 0
Tab5S23Ang:	DW 0
Tab5S23Dst:	DW 0
Tab5S24Ang:	DW 0
Tab5S24Dst:	DW 0
Tab5S25Ang:	DW 0
Tab5S25Dst:	DW 0
	  

		  ORG 900
Job1X1:	  DW &H0000
Job1Y1:	  DW &H0000
Job1X2:   DW &H0000
Job1Y2:   DW &H0000
Job2X1:	  DW &H0000
Job2Y1:	  DW &H0000
Job2X2:   DW &H0000
Job2Y2:   DW &H0000
Job3X1:	  DW &H0000
Job3Y1:	  DW &H0000
Job3X2:   DW &H0000
Job3Y2:   DW &H0000
Job4X1:	  DW &H0000
Job4Y1:	  DW &H0000
Job4X2:   DW &H0000
Job4Y2:   DW &H0000
Job5X1:	  DW &H0000
Job5Y1:	  DW &H0000
Job5X2:   DW &H0000
Job5Y2:   DW &H0000
Job6X1:	  DW &H0000
Job6Y1:	  DW &H0000
Job6X2:   DW &H0000
Job6Y2:   DW &H0000
Job7X1:	  DW &H0000
Job7Y1:	  DW &H0000
Job7X2:   DW &H0000
Job7Y2:   DW &H0000
Job8X1:	  DW &H0000
Job8Y1:	  DW &H0000
Job8X2:   DW &H0000
Job8Y2:   DW &H0000



; IO address space map
SWITCHES: EQU &H00  ; slide switches
LEDS:     EQU &H01  ; red LEDs
TIMER:    EQU &H02  ; timer, usually running at 10 Hz
XIO:      EQU &H03  ; pushbuttons and some misc. inputs
SSEG1:    EQU &H04  ; seven-segment display (4-digits only)
SSEG2:    EQU &H05  ; seven-segment display (4-digits only)
LCD:      EQU &H06  ; primitive 4-digit LCD display
GLEDS:    EQU &H07  ; Green LEDs (and Red LED16+17)
BEEP:     EQU &H0A  ; Control the beep
LPOS:     EQU &H80  ; left wheel encoder position (read only)
LVEL:     EQU &H82  ; current left wheel velocity (read only)
LVELCMD:  EQU &H83  ; left wheel velocity command (write only)
RPOS:     EQU &H88  ; same values for right wheel...
RVEL:     EQU &H8A  ; ...
RVELCMD:  EQU &H8B  ; ...
I2C_CMD:  EQU &H90  ; I2C module's CMD register,
I2C_DATA: EQU &H91  ; ... DATA register,
I2C_RDY:  EQU &H92  ; ... and BUSY register
UART:     EQU &H98  ; The basic UART interface provided
UART_CHK: EQU &H99
; 0x98-0x9F are reserved for any additional UART functions you create
SONAR:    EQU &HA0  ; base address for more than 16 registers....
DIST0:    EQU &HA8  ; the eight sonar distance readings
DIST1:    EQU &HA9  ; ...
DIST2:    EQU &HAA  ; ...
DIST3:    EQU &HAB  ; ...
DIST4:    EQU &HAC  ; ...
DIST5:    EQU &HAD  ; ...
DIST6:    EQU &HAE  ; ...
DIST7:    EQU &HAF  ; ...
SONAREN:  EQU &HB2  ; register to control which sonars are enabled
XPOS:     EQU &HC0  ; Current X-position (read only)
YPOS:     EQU &HC1  ; Y-position
THETA:    EQU &HC2  ; Current rotational position of robot (0-701)
RESETODO: EQU &HC3  ; reset odometry to 0

