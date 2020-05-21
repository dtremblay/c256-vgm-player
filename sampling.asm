; ****************************************************************************
; * Video Game Music Player
; * Author Daniel Tremblay
; * Code written for the C256 Foenix retro computer
; * Permission is granted to reuse this code to create your own games
; * for the C256 Foenix.
; * Copyright Daniel Tremblay 2020
; * This code is provided without warranty.
; * Please attribute credits to Daniel Tremblay is you reuse.
; ****************************************************************************
; *   To play VGM files in your games, include this file first.
; *   Next, in your interrupt handler, enable timer0.
; *   In the TIMER0 interrupt handler, call the VGM_WRITE_REGISTER subroutine.
; *   In your game code, set the SONG_START to the beginning of your VGM file.
; *   Call VGM_SET_SONG_POINTERS, this will initialize the other register.
; *   Finally, call VGM_INIT_TIMER0 to initialize TIMER0.
; *   Chips supported at this time are:
; *     - SN76489 (PSG)
; *     - YM2612 (OPN2)
; *     - YM2151 (OPM)
; *     - YM262 (OPL3)
; *     - YM3812 (OPL2)
; ****************************************************************************
.cpu "65816"
.include "macros_inc.asm"
.include "base.asm"
.include "bank_00_inc.asm"
.include "interrupt_def.asm"
.include "keyboard_def.asm"
.include "vicky_def.asm"
.include "kernel_inc.asm"
.include "timer_def.asm"
.include "math_def.asm"

PSG_BASE_ADDRESS  = $AFF100
OPN2_BASE_ADDRESS = $AFF200

WAIT_CNTR         = $76 ; 2 bytes
DISPLAY_OFFSET    = $78 ; 2 bytes
MSG_PTR           = $7A ; 3 bytes
SAMPLE_START      = $80 ; 3 bytes
SAMPLE_PTR        = $83 ; 3 bytes

* = $160000

VGM_START
            .as
            .xs
            setas
            setxl
            
            JSL CLRSCREEN
            
            ; disable the cursor
            LDA #0
            STA VKY_TXT_CURSOR_CTRL_REG
            
            ; initialize the sample and pointer
            LDA #`SAMPLE_FILE
            STA SAMPLE_START + 2
            
            LDX #<>SAMPLE_FILE + $2D
            STX SAMPLE_START
            LDX #0
            STX SAMPLE_PTR
            
            LDX #0
            STX WAIT_CNTR
            
            LDX #$A000
            STX DISPLAY_OFFSET
            
            LDA #`STARTING_MSG
            STA MSG_PTR+2
            LDX #<>STARTING_MSG
            STX MSG_PTR
            JSR DISPLAY_MSG
            
            JSR VGM_INIT_TIMER0
                
            LDA #$FF
            STA @lINT_EDGE_REG0
            STA @lINT_EDGE_REG1
            STA @lINT_EDGE_REG2
            STA @lINT_EDGE_REG3

            LDA #~( FNX0_INT02_TMR0 | FNX0_INT00_SOF)
            STA @lINT_MASK_REG0
            LDA #$FF
            STA @lINT_MASK_REG1
            STA @lINT_MASK_REG2
            STA @lINT_MASK_REG3
            
            ; enable the DAC
            LDA #$80
            STA OPN2_BASE_ADDRESS + $2B
            
            CLI
            ; loop, waiting for interrupts
        LOOP
            BRA LOOP
            
HEX_VALUES       .text '0123456789ABCDEF'
STARTING_MSG     .text 'Starting Sample Wave: Hello Foenix',0

; *******************************************************************
; * Interrupt driven sub-routine.
; *******************************************************************
VGM_WRITE_REGISTER
            .as
            
            LDX WAIT_CNTR
            CPX #0
            BEQ PLAY_SAMPLE
            
            DEX
            STX WAIT_CNTR
            
            RTS
            
    PLAY_SAMPLE
            LDX #0
            STX WAIT_CNTR
            LDY SAMPLE_PTR
            LDA [SAMPLE_START],Y
            CLC 
            ADC #127
            STA OPN2_BASE_ADDRESS + $2A
            INY
            INY 
            ;CPY #$5dc0
            CPY #$49b6
            ;CPY #$FFFE
            BNE PLAY_SAMPLE_DONE
            LDY #0
            LDX #$4000
            STX WAIT_CNTR
            
    PLAY_SAMPLE_DONE
            STY SAMPLE_PTR
            RTS

            
DISPLAY_MSG
            .as
            PHY
            LDX DISPLAY_OFFSET
            LDY #0
            LDA #0
            XBA
    DISPLAY_NEXT
            ; write the color for the characters - green
            LDA #$2D ; charachter fg/bg color
            STA $AF2000,X
            LDA [MSG_PTR],Y
            STA $AF0000,X
            
            INX
            INY
            CMP #0 ; a null indicates the end of the string
            BNE DISPLAY_NEXT
            
            ; move the display pointer to the next line
            setal
            LDA DISPLAY_OFFSET
            CLC
            ADC #$80
            STA DISPLAY_OFFSET
            setas
            
            XBA
            CMP #$BF ; are we at the bottom of the screen?
            BLT DISPLAY_DONE
            
            XBA
            BNE FIRST_COL
            LDX #$A020 ; create a second column
            STX DISPLAY_OFFSET
            BRA DISPLAY_DONE
        FIRST_COL
            ; reset to the top of screen
            LDX #$A000 
            STX DISPLAY_OFFSET
            JSL CLRSCREEN
            
    DISPLAY_DONE
            PLY
            RTS

; Display Hex value of A
DISPLAY_HEX
            .as
            PHA
            PHA
            ; colour first
            LDA #$2D
            STA $AF2000,X
            
            PLA
            AND #$F0
            LSR A
            LSR A
            LSR A
            LSR A
            TXY
            TAX 
            LDA HEX_VALUES,X
            TYX
            STA $AF0000,X
            INX
            ; display the second digit
            LDA #$2D
            STA $AF2000,X
            PLA
            AND #$F
            TXY
            TAX 
            LDA HEX_VALUES,X
            TYX
            STA $AF0000,X
            RTS
            
VGM_INIT_TIMER0
            .as
            
            LDA #$FD
            STA TIMER0_CMP_L
            LDA #6
            STA TIMER0_CMP_M
            
            LDA #0
            STA TIMER0_CMP_H
            
            
            LDA #0    ; set timer0 charge to 0
            STA TIMER0_CHARGE_L
            STA TIMER0_CHARGE_M
            STA TIMER0_CHARGE_H
            
            LDA #TMR0_CMP_RECLR  ; count up from "CHARGE" value to TIMER_CMP
            STA TIMER0_CMP_REG
            
            LDA #(TMR0_EN | TMR0_UPDWN | TMR0_SCLR)
            STA TIMER0_CTRL_REG

            RTS
            
.include "interrupt_handler.asm"
        
SAMPLE_FILE
.binary "samples/hello-foenix.wav"
;.binary "samples/hello-foenix-48k.wav"
;.binary "samples/nes-12-12.wav"


;            .text 0,10,20,30,40,50,60,70,80,90,100,110,120,130,140,150,160,170,180,190,200,210,220,230,240,250 ; triangular wave
;            .text 240,230,220,210,200,190,180,170,160,150,140,130,120,110,100,90,80,70,60,50,40,30,20,10