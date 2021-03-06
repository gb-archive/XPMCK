.memorymap
        defaultslot 0
        slotsize $2000
        slot 0 $0000
        slot 1 $2000
        slot 2 $4000
        slot 3 $6000
        slot 4 $8000
        slot 5 $A000
        slot 6 $C000
        slot 7 $E000
.endme

.rombankmap
        bankstotal 8
        banksize $2000
        banks 8
.endro

.DEFINE TIMER_COUNTER		$0C00
.DEFINE TIMER_CTRL			$0C01

.DEFINE INTERRUPT_CTRL		$1402
.DEFINE INTERRUPT_STATUS	$1403


.macro INCW
	inc	<\1
	bne	+
	inc	<\1+1
	+:
.endm


.bank 0 slot 7
; Interrupt vectors
.org $1FF6

 .dw vdc_irq                    
 .dw vdc_irq                   
 .dw timer_irq               
 .dw vdc_irq               
 .dw start     


 
.bank 0 slot 7
.org $0000
start:								; HES will not execute this vector
    sei                               
    csh  							; switch the CPU to high speed mode
    cld
    ldx    #$FF
    txs
;------paging-------
    lda    #$FF
    tam    #1      ; page0 - IO
    lda    #$F8    ; page1 - RAM
    tam    #2
    lda    #$01    ; page2 - PRGBANK1 (XPMP)
    tam    #4
    ina
    tam    #$40    ; page6 - PRGBANK2 (PCM)
;-------------------
    stz    $2000   ; clear all the RAM
    tii    $2000,$2001,$1FFF
    cla            ; load song 0
    jmp    choose_song
.include "..\..\lib\pce\xpmp_pce.asm"


.bank 1 slot 2
.org $0000
preplay:	; HES start vector
    sei
    csh
    cld
    ldx    #$FF
    txs
    sta    $2000                    ; store song# (HES player provides it)
    stz    $2001                    ; clear all the RAM
    tii    $2001,$2002,$1FFE
    
    lda    $2000                    ; load song# (count from 0)
choose_song:
	ina                             ; XPMP API expects songs to start from 1
	sta		<xpmp_songNum
	lda		#<xpmp_song_tbl
	sta		xpmp_songTblLo
	lda		#>xpmp_song_tbl
	sta		xpmp_songTblHi
	jsr		xpmp_init

	lda		#139
	sta		xpmp_frameCnt
	
	stz		TIMER_COUNTER
	
	lda		#$FB
	sta		INTERRUPT_CTRL	

	lda		#1
	sta		TIMER_CTRL
	
	cli
play:
	lda		xpmp_frameCnt
	bne		play
	lda		#116		; ~60 Hz
	sta		xpmp_frameCnt
	jsr		xpmp_update
	bra		play
	

timer_irq:
	pha
	phx
	phy
	
	jsr		xpmp_update_dda
	lda		xpmp_channel
	sta.w	$0800				; set channel select back to what it was
	
	stz		INTERRUPT_STATUS	; acknowledge interrupt
	stz		TIMER_CTRL
	stz		TIMER_COUNTER
	lda		#1
	sta		TIMER_CTRL

	dec		xpmp_frameCnt
	
	ply
	plx
	pla
	rti
	
	
vdc_irq:
	rti	
    

; Include the music data 
.include "pcemusic.asm"




