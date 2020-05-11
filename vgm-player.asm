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

; VGM Registers
COMMAND           = $80 ; 1 byte
SONG_START        = $84 ; 4 bytes
CURRENT_POSITION  = $88 ; 4 bytes
WAIT_CNTR         = $8C ; 2 bytes
LOOP_OFFSET_REG   = $8E ; 2 bytes


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
            
            ; disable the cursor
            LDA #0
            STA VKY_TXT_CURSOR_CTRL_REG
            
            LDX #0
            STX DATA_STREAM_CNT
            
            LDX #$A000
            STX DISPLAY_OFFSET
            
            LDA #`RESET_MSG
            STA MSG_PTR+2
            
            ; load the music
            LDA #`VGM_FILE
            STA CURRENT_POSITION + 2
            STA SONG_START + 2
            setal
            LDA #<>VGM_FILE
            STA SONG_START
            setas
            
            ; first three bytes should be VGM - if not, maybe it's compressed?
            LDA #0
            STA COMMAND
            JSR CHECK_VGM_FILE
            LDA COMMAND ; if the command is still 0, it's a vgm file
            BNE INVALID_FILE
            
            JSR VGM_SET_SONG_POINTERS
            
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
            
            JSR VGM_WRITE_REGISTER  ; the initial load of register should set the timerA
            CLI
            ; loop, waiting for interrupts
        LOOP
            BRA LOOP
            
        INVALID_FILE
            setal
            LDA #<>INVALID_FILE_MSG
            STA MSG_PTR
            setas
            JSR DISPLAY_MSG
            
            BRA LOOP
            
RESET_MSG        .text 'Restarting song:',0
LOOPING_MSG      .text 'Looping song:',0
DATA_BLOCK_MSG   .text 'Reading Data Block:',0
INVALID_FILE_MSG .text 'Invalid file type:', 0
UNK_CMD1_MSG     .text 'Unknown 1-Byte Command:',0
UNK_CMD2_MSG     .text 'Unknown 2-Byte Command:',0
UNK_CMD3_MSG     .text 'Unknown 3-Byte Command:',0
UNK_CMD4_MSG     .text 'Unknown 4-Byte Command:',0
HEX_VALUES       .text '0123456789ABCDEF'

; *******************************************************************
; * First three bytes of the file must be VGM
; *******************************************************************
CHECK_VGM_FILE
            .as
            LDY #0
            LDA [SONG_START],Y
            INY
            CMP #'V'
            BNE CHECK_FAILED
            
            LDA [SONG_START],Y
            INY
            CMP #'g'
            BNE CHECK_FAILED
            
            LDA [SONG_START],Y
            INY
            CMP #'m'
            BNE CHECK_FAILED
            
            RTS
            
    CHECK_FAILED
            LDA #1
            STA COMMAND
            RTS
            
DISPLAY_MSG
            .as
            PHY
            LDX DISPLAY_OFFSET
            LDY #0
            LDA #0
            XBA
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
            
            LDA #$2D
            STA $AF2000,X
            LDA COMMAND
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
            LDA #$2D
            STA $AF2000,X
            LDA COMMAND
            AND #$F
            TXY
            TAX 
            LDA HEX_VALUES,X
            TYX
            STA $AF0000,X
            
            
            setal
            LDA DISPLAY_OFFSET
            CLC
            ADC #$80
            STA DISPLAY_OFFSET
            setas
            
            XBA
            CMP #$BF
            BLT DISPLAY_DONE
            
            XBA
            BNE FIRST_COL
            LDX #$A020 ; create a second column
            STX DISPLAY_OFFSET
            BRA DISPLAY_DONE
        FIRST_COL
            LDX #$A000 
            STX DISPLAY_OFFSET
            JSL CLRSCREEN
            
    DISPLAY_DONE
            PLY
            RTS

increment_long_addr .macro
            setal
            INC \1
            BNE increment_done
            INC \1 + 2
    increment_done
            setas
                    .endm
; *******************************************************************
; * Interrupt driven sub-routine.
; *******************************************************************
VGM_WRITE_REGISTER
            .as
            LDX WAIT_CNTR
            CPX #0
            BEQ READ_COMMAND
            
            DEX
            STX WAIT_CNTR
            
            RTS
            
    READ_COMMAND
            ; first byte is a  command - should be $54 for YM2151
            LDA #0
            XBA
            LDA [CURRENT_POSITION]
            STA COMMAND
            increment_long_addr CURRENT_POSITION
            
            AND #$F0
            LSR A
            LSR A
            LSR A
            TAX
            JSR (VGM_COMMAND_TABLE,X)
            RTS
            
; *******************************************************************
; * Command Table
; *******************************************************************
VGM_COMMAND_TABLE
            .word <>INVALID_COMMAND ;0
            .word <>INVALID_COMMAND ;1
            .word <>INVALID_COMMAND ;2
            .word <>SKIP_BYTE_CMD   ;3 - reserved - not implemented
            .word <>SKIP_BYTE_CMD   ;4 - not implemented
            .word <>WRITE_YM_CMD    ;5 - YM*
            .word <>WAIT_COMMANDS   ;6
            .word <>WAIT_N_1        ;7
            .word <>YM2612_SAMPLE   ;8
            .word <>DAC_STREAM      ;9
            .word <>SKIP_TWO_BYTES  ;A - AY8910 - not implemented
            .word <>SKIP_TWO_BYTES  ;B - not implemented
            .word <>SKIP_THREE_BYTES;C - not implemented
            .word <>SKIP_THREE_BYTES;D - not implemented
            .word <>SKIP_FOUR_BYTES ;E - not implemented
            .word <>SKIP_FOUR_BYTES ;F - not implemented
            
INVALID_COMMAND
            .as
            RTS
SKIP_BYTE_CMD
            .as
            setal
            LDA #<>UNK_CMD1_MSG
            STA MSG_PTR
            setas
            JSR DISPLAY_MSG
            increment_long_addr CURRENT_POSITION
            RTS
SKIP_TWO_BYTES
            .as
            setal
            LDA #<>UNK_CMD2_MSG
            STA MSG_PTR
            setas
            JSR DISPLAY_MSG
            setal
            INC CURRENT_POSITION
            BNE s2_1
            INC CURRENT_POSITION + 2
    s2_1
            INC CURRENT_POSITION
            BNE s2_2
            INC CURRENT_POSITION + 2
    s2_2
            setas
            RTS
SKIP_THREE_BYTES
            .as
            setal
            LDA #<>UNK_CMD3_MSG
            STA MSG_PTR
            setas
            JSR DISPLAY_MSG
            setal
            INC CURRENT_POSITION
            BNE s3_1
            INC CURRENT_POSITION + 2
    s3_1
            INC CURRENT_POSITION
            BNE s3_2
            INC CURRENT_POSITION + 2
    s3_2
            INC CURRENT_POSITION
            BNE s3_3
            INC CURRENT_POSITION + 2
    s3_3
            setas
            RTS
SKIP_FOUR_BYTES
            .as
            setal
            LDA #<>UNK_CMD4_MSG
            STA MSG_PTR
            setas
            JSR DISPLAY_MSG
            setal
            INC CURRENT_POSITION
            BNE s4_1
            INC CURRENT_POSITION + 2
    s4_1
            INC CURRENT_POSITION
            BNE s4_2
            INC CURRENT_POSITION + 2
    s4_2
            INC CURRENT_POSITION
            BNE s4_3
            INC CURRENT_POSITION + 2
    s4_3
            INC CURRENT_POSITION
            BNE s4_4
            INC CURRENT_POSITION + 2
    s4_4
            setas
            RTS

; *******************************************************************
; * YM Commands
; *******************************************************************
WRITE_YM_CMD
            .as
            LDA COMMAND
            CMP #$50
            BNE CHK_2413
            
            LDA [CURRENT_POSITION]
            STA PSG_BASE_ADDRESS
            increment_long_addr CURRENT_POSITION
            RTS
            
        CHK_2413
            CMP #$51
            BNE CHK_YM2612_P0
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA [CURRENT_POSITION]
            TAX
            increment_long_addr CURRENT_POSITION
            
            ; the third byte is the value to write in the register
            LDA [CURRENT_POSITION]
            ;STA @lOPN2_BASE_ADDRESS,X  ; this probably won't work
            increment_long_addr CURRENT_POSITION
            RTS
            
        CHK_YM2612_P0
            CMP #$52
            BNE CHK_YM2612_P1
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA [CURRENT_POSITION]
            TAX
            increment_long_addr CURRENT_POSITION
            
            ; the third byte is the value to write in the register
            LDA [CURRENT_POSITION]
            STA @lOPN2_BASE_ADDRESS,X
            increment_long_addr CURRENT_POSITION
            RTS
            
        CHK_YM2612_P1
            CMP #$53
            BNE CHK_YM2151
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA [CURRENT_POSITION]
            TAX
            increment_long_addr CURRENT_POSITION
            
            ; the third byte is the value to write in the register
            LDA [CURRENT_POSITION]
            STA @lOPN2_BASE_ADDRESS + $100,X
            increment_long_addr CURRENT_POSITION
            RTS
            
        CHK_YM2151
            CMP #$54
            BNE CHK_YM2203
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA [CURRENT_POSITION]
            TAX
            increment_long_addr CURRENT_POSITION
            
            ; the third byte is the value to write in the register
            LDA [CURRENT_POSITION]
            STA @lOPM_BASE_ADDRESS,X
            increment_long_addr CURRENT_POSITION
            RTS
            
        CHK_YM2203
            CMP #$55
            BNE CHK_YM2608_P0
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA [CURRENT_POSITION]
            TAX
            increment_long_addr CURRENT_POSITION
            
            ; the third byte is the value to write in the register
            LDA [CURRENT_POSITION]
            ;STA @lOPM_BASE_ADDRESS,X
            increment_long_addr CURRENT_POSITION
            RTS
            
        CHK_YM2608_P0
            CMP #$56
            BNE CHK_YM2608_P1
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA [CURRENT_POSITION]
            TAX
            increment_long_addr CURRENT_POSITION
            
            ; the third byte is the value to write in the register
            LDA [CURRENT_POSITION]
            ;STA @lOPM_BASE_ADDRESS,X
            increment_long_addr CURRENT_POSITION
            RTS
            
        CHK_YM2608_P1
            CMP #$57
            BNE CHK_YM2610_P0
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA [CURRENT_POSITION]
            TAX
            increment_long_addr CURRENT_POSITION
            
            ; the third byte is the value to write in the register
            LDA [CURRENT_POSITION]
            ;STA @lOPM_BASE_ADDRESS,X
            increment_long_addr CURRENT_POSITION
            RTS
            
        CHK_YM2610_P0
            CMP #$58
            BNE CHK_YM2610_P1
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA [CURRENT_POSITION]
            TAX
            increment_long_addr CURRENT_POSITION
            
            ; the third byte is the value to write in the register
            LDA [CURRENT_POSITION]
            STA @lOPN2_BASE_ADDRESS,X
            increment_long_addr CURRENT_POSITION
            RTS
            
        CHK_YM2610_P1
            CMP #$59
            BNE CHK_YM_3812
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA [CURRENT_POSITION]
            TAX
            increment_long_addr CURRENT_POSITION
            
            ; the third byte is the value to write in the register
            LDA [CURRENT_POSITION]
            STA @lOPN2_BASE_ADDRESS + $100,X
            increment_long_addr CURRENT_POSITION
            RTS
            
        CHK_YM_3812
            CMP #$5A
            BNE CHK_YM262_P0
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA [CURRENT_POSITION]
            TAX
            increment_long_addr CURRENT_POSITION
            
            ; the third byte is the value to write in the register
            LDA [CURRENT_POSITION]
            STA @lOPL3_BASE_ADRESS,X
            increment_long_addr CURRENT_POSITION
            RTS
        
        CHK_YM262_P0
            CMP #$5E
            BNE CHK_YM262_P1
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA [CURRENT_POSITION]
            TAX
            increment_long_addr CURRENT_POSITION
            
            ; the third byte is the value to write in the register
            LDA [CURRENT_POSITION]
            STA @lOPL3_BASE_ADRESS,X
            increment_long_addr CURRENT_POSITION
            RTS
            
        CHK_YM262_P1
            CMP #$5F
            BNE YM_DONE
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA [CURRENT_POSITION]
            TAX
            increment_long_addr CURRENT_POSITION
            
            ; the third byte is the value to write in the register
            LDA [CURRENT_POSITION]
            STA @lOPL3_BASE_ADRESS+ $100,X
            increment_long_addr CURRENT_POSITION
    YM_DONE
            RTS
            
; *******************************************************************
; * Wait Commands
; *******************************************************************
WAIT_COMMANDS
            .as
            LDA COMMAND
            CMP #$61
            BNE CHK_WAIT_60th
            setal
            LDA [CURRENT_POSITION]
            TAX
            STX WAIT_CNTR
            setas
            increment_long_addr CURRENT_POSITION
            increment_long_addr CURRENT_POSITION
            RTS
            
        CHK_WAIT_60th
            CMP #$62
            BNE CHK_WAIT_50th
            
            LDX #$2df
            STX WAIT_CNTR
            RTS
            
        CHK_WAIT_50th
            CMP #$63
            BNE CHK_END_SONG
            
            LDX #$372
            STX WAIT_CNTR
            RTS

        CHK_END_SONG
            CMP #$66 ; end of song
            BNE CHK_DATA_BLOCK
            
            JSR VGM_SET_LOOP_POINTERS
            RTS
            
        CHK_DATA_BLOCK
            CMP #$67
            BNE DONE_WAIT
            
            JSR READ_DATA_BLOCK
    DONE_WAIT
            RTS
            
; *******************************************************************
; * Wait N+1 Commands
; *******************************************************************
WAIT_N_1
            .as
            LDA COMMAND
            AND #$F
            TAX
            INX ; $7n where we wait n+1
            STX WAIT_CNTR
            RTS
            
; *******************************************************************
; * Play Samples and wait N
; *******************************************************************
YM2612_SAMPLE
            .as
            LDA COMMAND
            
            ; write directly to YM2612 DAC then wait n
            ; load a value from database
            ; STA OPN2_2A_DAC
            
            ; this is the wait part
            AND #$F
            TAX
            STX WAIT_CNTR
            RTS
            
; *******************************************************************
; * Play Samples and wait N
; *******************************************************************
DAC_STREAM
            .as
            LDA COMMAND
            AND #$F
            RTS
            


VGM_SET_SONG_POINTERS
            .as
            setal
            LDA #<>RESET_MSG
            STA MSG_PTR
            setas
            JSR DISPLAY_MSG
            
            ; add the start offset
            setal
            LDA #0
            STA WAIT_CNTR
            LDA SONG_START + 2
            STA CURRENT_POSITION + 2
            CLC
            LDY #VGM_OFFSET
            LDA [SONG_START],Y
            ADC #VGM_OFFSET
            ADC SONG_START
            STA CURRENT_POSITION
            BCC VSP_DONE
            
            INC CURRENT_POSITION + 2
    VSP_DONE
            
            setas
            
            RTS
            
VGM_SET_LOOP_POINTERS
            .as
            
            ; add the start offset
            setal
            LDA #0
            STA WAIT_CNTR
            LDA SONG_START + 2
            STA CURRENT_POSITION + 2
            
            CLC
            LDY #LOOP_OFFSET
            LDA [SONG_START],Y
            BEQ NO_LOOP_INFO
            
            ADC #LOOP_OFFSET
            PHA
            
            LDA #<>LOOPING_MSG
            STA MSG_PTR
            setas
            JSR DISPLAY_MSG
            setal
            PLA
            
            BRA STORE_PTR
            
    NO_LOOP_INFO
            LDY #VGM_OFFSET
            LDA [SONG_START],Y
            ADC #VGM_OFFSET
            PHA
            
            LDA #<>RESET_MSG
            STA MSG_PTR
            setas
            JSR DISPLAY_MSG
            setal
            PLA
    STORE_PTR
            ADC SONG_START
            STA CURRENT_POSITION
            
            BCC VSL_DONE
            INC CURRENT_POSITION + 2
    VSL_DONE
            setas
            
            RTS

VGM_INIT_TIMER0
            .as
            
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
            
            LDA [CURRENT_POSITION] ; should be 66
            ;CMP #$66 ; what happens if it's not 66?
            increment_long_addr CURRENT_POSITION
            LDA  [CURRENT_POSITION] ; should be the type - I expect $C0
            PHA
            increment_long_addr CURRENT_POSITION
            
            ; read the size of the data stream - and compute the end of stream position
            setal
            LDA [CURRENT_POSITION]
            STA ADDER_A
            increment_long_addr CURRENT_POSITION
            increment_long_addr CURRENT_POSITION
            setal
            LDA [CURRENT_POSITION]
            STA ADDER_A + 2
            increment_long_addr CURRENT_POSITION
            increment_long_addr CURRENT_POSITION
            setal
            LDA CURRENT_POSITION
            STA ADDER_B
            LDA CURRENT_POSITION + 2
            STA ADDER_B + 2
            
            ; continue reading the file here
            LDA ADDER_R
            STA CURRENT_POSITION
            LDA ADDER_R + 2
            STA CURRENT_POSITION + 2
            
            setas
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
;.binary "songs/04 Kalinka.vgm"
;.binary "songs/peddler.vgm"
;.binary "songs/05 Troika.vgm"
;.binary "songs/test.vgm"
;.binary "songs/2 Strolling Player.vgm"

; PSG FILES
;.binary "songs/03 Minigame Intro.vgm" ;- this song is so happy!!
;.binary "songs/01 Ghostbusters Main Theme.vgm"

; YM2612
;.binary "songs/09 Skyscrapers.vgm"
;.binary "songs/01 Title-ym2612.vgm"

; YM262
;.binary "songs/02 At Doom's Gate-ym262.vgm"  

; YM3812
;.binary "songs/lemmings/lemming1.vgm"
;.binary "songs/lemmings/tim5.vgm"

; YM262 + DAC
;.binary "songs/02 Character Select.vgm" ; missing DAC stuff

;YM2610 - Foenix play as OPN2
;.binary "songs/SuperDodgeBall-01-Title.vgm" ; - a mix of DAC and YM2612
.binary "songs/Dodge-Ball 02 Team Select.vgm" ; for the 2610; - crashes
;.binary "songs/Figth Fever 04 Character Select.vgm" - not great - crash at the end
