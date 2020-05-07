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


OPM_BASE_ADDRESS  = $AFF000
PSG_BASE_ADDRESS  = $AFF100
OPN2_BASE_ADDRESS = $AFF200
OPL3_BASE_ADRESS  = $AFE600

; Important offsets
VGM_VERSION       = $8  ; 32-bits
SN_CLOCK          = $C  ; 32-bits
LOOP_OFFSET       = $1C ; 32-bits
YM_OFFSET         = $2C ; 32-bits
OPM_CLOCK         = $30 ; 32-bits
VGM_OFFSET        = $34 ; 32-bits

; Registers
CURRENT_POSITION  = $70 ; 2 bytes
POSITION_HI       = $72 ; 1 byte
WAIT_CNTR         = $74 ; 2 bytes
LOOP_OFFSET_REG   = $76 ; 2 bytes
DISPLAY_OFFSET    = $78 ; 2 bytes
MSG_PTR           = $7A ; 3 bytes
DATA_STREAM_CNT   = $7D ; 2 byte
DATA_STREAM_TBL   = $8000

* = $160000

VGM_START
            .as
            .xs
            setas
            setxl
            
            JSL CLRSCREEN
            
            LDX #0
            STX DATA_STREAM_CNT
            
            LDX #$A000
            STX DISPLAY_OFFSET
            
            LDA #`RESET_MSG
            STA MSG_PTR+2
            
            JSR SET_SONG_POINTERS
            
            JSR INIT_TIMER0
                
            LDA #$FF
            STA @lINT_EDGE_REG0
            STA @lINT_EDGE_REG1
            STA @lINT_EDGE_REG2
            STA @lINT_EDGE_REG3
                
            LDA #~( FNX0_INT02_TMR0 )
            STA @lINT_MASK_REG0
            LDA #$FF
            STA @lINT_MASK_REG1
            STA @lINT_MASK_REG2
            STA @lINT_MASK_REG3
            
            JSR WRITE_REGISTER  ; the initial load of register should set the timerA
            CLI
            ; loop, waiting for interrupts
        LOOP
            BRA LOOP
            
SET_SONG_POINTERS
            .as
            PHB
            
            setal
            LDA #<>RESET_MSG
            STA MSG_PTR
            setas
            JSR DISPLAY_MSG
            
            LDA #`VGM_FILE
            STA POSITION_HI
            PHA
            PLB
            .databank `VGM_FILE
            
            ; add the start offset
            setal
            CLC
            LDY #VGM_OFFSET
            LDA VGM_FILE,Y
            ADC #$34
            STA CURRENT_POSITION
            LDA #0
            STA WAIT_CNTR
            setas
            
            PLB 
            
            RTS
            
SET_LOOP_POINTERS
            .as
            PHB
            
            setal
            LDA #<>LOOPING_MSG
            STA MSG_PTR
            setas
            JSR DISPLAY_MSG
            
            LDA #`VGM_FILE
            STA POSITION_HI
            PHA
            PLB
            .databank `VGM_FILE
            
            ; add the start offset
            setal
            CLC
            LDY #LOOP_OFFSET
            LDA VGM_FILE,Y
            BEQ NO_LOOP_INFO
            
            ADC #$1C
            BRA STORE_PTR
            
    NO_LOOP_INFO
            LDY #VGM_OFFSET
            LDA VGM_FILE,Y
            ADC #$34
    STORE_PTR
            STA CURRENT_POSITION
            LDA #0
            STA WAIT_CNTR
            setas
            
            PLB
            .databank ?
            
            RTS
            
RESET_MSG   .text 'Restarting song',0
LOOPING_MSG .text 'Looping song',0
DATA_BLOCK_MSG .text 'Reading Data Block',0

DISPLAY_MSG
            .as
            PHY
            LDX DISPLAY_OFFSET
            LDY #0
    DISPLAY_NEXT
            LDA #$2D
            STA $AF2000,X
            LDA [MSG_PTR],Y
            STA $AF0000,X
            ; write the color for the characters - green
            
            INX
            INY
            CMP #0
            BNE DISPLAY_NEXT
            
            setal
            LDA DISPLAY_OFFSET
            CLC
            ADC #$80
            STA DISPLAY_OFFSET
            setas
            
            PLY
            RTS
; *******************************************************************
; * Interrupt driven sub-routine.
; *******************************************************************
WRITE_REGISTER
            .as
            LDX WAIT_CNTR
            CPX #0
            BEQ STORE_VALUES
            
            DEX
            STX WAIT_CNTR
            
            RTS
            
            
    STORE_VALUES
            
            PHB
            LDA POSITION_HI
            PHA
            PLB
            .databank `VGM_FILE 
            
            LDY CURRENT_POSITION
            ; first byte is a  command - should be $54 for YM2151
    CHECK_NEXT
            LDA VGM_FILE,Y
            INY
            
        CHK_PSG
            CMP #$50
            BNE CHK_YM2612_P0
            
            LDA VGM_FILE,Y
            STA PSG_BASE_ADDRESS
            INY
            JMP WR_DONE
            
        CHK_YM2612_P0
            CMP #$52
            BNE CHK_YM2612_P1
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA VGM_FILE,Y
            TAX
            INY
            
            ; the third byte is the value to write in the register
            LDA VGM_FILE,Y
            STA @lOPN2_BASE_ADDRESS,X
            INY
            BRA CHECK_NEXT
            
        CHK_YM2612_P1
            CMP #$53
            BNE CHK_YM2151
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA VGM_FILE,Y
            TAX
            INY
            
            ; the third byte is the value to write in the register
            LDA VGM_FILE,Y
            STA @lOPN2_BASE_ADDRESS + $100,X
            INY
            BRA CHECK_NEXT
            
        CHK_YM2151
            CMP #$54
            BNE CHK_YM262_P0
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA VGM_FILE,Y
            TAX
            INY
            
            ; the third byte is the value to write in the register
            LDA VGM_FILE,Y
            STA @lOPM_BASE_ADDRESS,X
            INY
            BRA CHECK_NEXT
        
        CHK_YM262_P0
            CMP #$5E
            BNE CHK_YM262_P1
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA VGM_FILE,Y
            TAX
            INY
            
            ; the third byte is the value to write in the register
            LDA VGM_FILE,Y
            STA @lOPL3_BASE_ADRESS,X
            INY
            BRA WR_DONE
            
        CHK_YM262_P1
            CMP #$5F
            BNE CHK_WAIT_N_SAMPLES
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA VGM_FILE,Y
            TAX
            INY
            
            ; the third byte is the value to write in the register
            LDA VGM_FILE,Y
            STA @lOPL3_BASE_ADRESS+ $100,X
            INY
            BRA WR_DONE
            
        CHK_WAIT_N_SAMPLES
            CMP #$61
            BNE CHK_WAIT_60
            setal
            LDA VGM_FILE,Y
            TAX
            STX WAIT_CNTR
            setas
            INY
            INY
            
            BRA WR_DONE
            
        CHK_WAIT_60
            CMP #$62
            BNE CHK_WAIT_50
            
            LDX #$2df
            STX WAIT_CNTR

            BRA WR_DONE
            
        CHK_WAIT_50
            CMP #$63
            BNE CHK_END_SONG
            
            LDX #$372
            STX WAIT_CNTR

            BRA WR_DONE
            
        CHK_END_SONG
            CMP #$66 ; end of song
            BNE CHK_DATA_BLOCK
            
            JSR SET_LOOP_POINTERS
            PLB
            RTS
            
        CHK_DATA_BLOCK
            CMP #$67
            BNE CHK_WAIT_N
            
            JSR READ_DATA_BLOCK
            
            JMP CHECK_NEXT
            
        CHK_WAIT_N
            BIT #$70
            BEQ CHK_YM2612_DAC
            
            AND #$F
            TAX
            INX ; $7n where we wait n+1
            STX WAIT_CNTR
            BRA WR_DONE
            
        CHK_YM2612_DAC
            BIT #$80
            BEQ CHK_DATA_STREAM
            
            ; write directly to DAC then wait n
            
            ; this is the wait part
            AND #$F
            TAX
            STX WAIT_CNTR
            BRA WR_DONE
            
        CHK_DATA_STREAM
            CMP #$90
            BNE SKIP_CMD
            
    SKIP_CMD
            JSL PRINTAH

    WR_DONE
            setal
            TYA
            SBC CURRENT_POSITION
            setas
            BCS WR_DONE_DONE
            
            INC POSITION_HI
            
    WR_DONE_DONE
            STY CURRENT_POSITION
            PLB
            RTS
            
INIT_TIMER0
            .as
            PHB
            
            LDA #0
            PHA
            PLB ; set databank to 0
            
            LDA #64
            STA TIMER0_CMP_L
            LDA #1
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
            
            LDA #~( FNX0_INT02_TMR0 )
            STA @lINT_MASK_REG0
            
            PLB
            RTS
            
; *******************************************************************************
; * Read a data block   - 67 66 tt ss ss ss ss
; *******************************************************************************
READ_DATA_BLOCK
            .as
            setal
            LDA #<>DATA_BLOCK_MSG
            STA MSG_PTR
            setas
            JSR DISPLAY_MSG
            
            LDA VGM_FILE,Y ; should be 66
            ;CMP #$66 ; what happens if it's not 66?
            INY
            LDA  VGM_FILE,Y ; should be the type - I expect $C0
            PHA
            INY
            
            ; read the size of the data stream - and compute the end of stream position
            setal
            LDA VGM_FILE,Y
            STA ADDER_A
            INY
            INY
            
            LDA VGM_FILE,Y
            STA ADDER_A + 2
            INY
            INY
            
            TYA
            STA ADDER_B
            setas
            LDA POSITION_HI
            STA ADDER_B + 2
            LDA #0
            STA ADDER_B + 3
            
            ; continue reading the file here
            setal
            LDA ADDER_R
            STA CURRENT_POSITION
            TAY
            setas
            LDA ADDER_R + 2
            STA POSITION_HI
            ; changet the bank
            PHA
            PLB
            
            PLA
            CMP #$C0
            BNE UNKNOWN_DATA_BLOCK
            
            setal
            LDA DATA_STREAM_CNT ; multiply by 4
            ASL A
            ASL A
            TAX
            
            LDA ADDER_B
            STA DATA_STREAM_TBL,X
            LDA ADDER_B + 2
            STA DATA_STREAM_TBL,X + 2

            INC DATA_STREAM_CNT
            setas
            
    UNKNOWN_DATA_BLOCK
            RTS

.include "interrupt_handler.asm"
        
VGM_FILE
;.binary "04 Kalinka.vgm"
;.binary "peddler.vgm"
;.binary "05 Troika.vgm"
;.binary "test.vgm"
;.binary "02 Strolling Player.vgm"

; PSG FILES
;.binary "03 Minigame Intro.vgm"
;.binary "01 Ghostbusters Main Theme.vgm"

; YM2612
;.binary "09 Skyscrapers.vgm"
;.binary "01 Title-ym2612.vgm"

; YM262
.binary "02 At Doom's Gate-ym262.vgm"  ;- this song is so happy!!
;.binary "02 Character Select.vgm"
