; ****************************************************************************
; * Video Game Music Player
; * Author Daniel Tremblay
; * Code written for the C256 Foenix retro computer
; * Permission is granted to reuse this code to create your own games
; * for the C256 Foenix.
; * Copyright Daniel Tremblay 2020
; * This code is provided without warranty.
; * Please attribute credits to Daniel Tremblay if you reuse.
; ****************************************************************************
; *   To play VGM files in your games, include this file first.
; *   Next, in your interrupt handler, enable timer0.
; *   In the TIMER0 interrupt handler, call the VGM_WRITE_REGISTER subroutine.
; *   In your game code, set the SONG_START to the beginning of your VGM file.
; *   Call VGM_SET_SONG_POINTERS, this will initialize the other register.
; *   Finally, call VGM_INIT_TIMER0 to initialize TIMER0.
; *   Chips supported at this time are:
; *     - SN76489 (PSG)
; *     - YM2612  (OPN2)
; *     - YM2151  (OPM)
; *     - YM262   (OPL3)
; *     - YM3812  (OPL2)
; ****************************************************************************
; * This version of the application will be bundled into a PGX file.
; * The way to use this application is to put it on the SD Card and run:
; *   BRUN VGMPLAY.PGX "@s:yoursong.vgm"
; ****************************************************************************
.cpu "65816"
.include "macros_inc.asm"
.include "bank_00_inc.asm"
.include "vicky_ii_def.asm"
.include "kernel_inc.asm"
.include "timer_def.asm"
.include "math_def.asm"
.include "interrupt_def.asm"
.include "sdos_inc.asm"

OPM_BASE_ADDRESS  = $AFF000
PSG_BASE_ADDRESS  = $AFF100
OPN2_BASE_ADDRESS = $AFF200
OPL3_BASE_ADRESS  = $AFE600

; Important VGM file offsets
VGM_VERSION       = $8  ; 32-bits
SN_CLOCK          = $C  ; 32-bits
GD3_OFFSET        = $14 ; 32-bits
LOOP_OFFSET       = $1C ; 32-bits
YM_OFFSET         = $2C ; 32-bits
OPM_CLOCK         = $30 ; 32-bits
VGM_OFFSET        = $34 ; 32-bits

; VGM Registers
MIN_VERSION       = $77 ; 1 byte
DISPLAY_OFFSET    = $78 ; 2 bytes
MSG_PTR           = $7A ; 3 bytes
DATA_STREAM_CNT   = $7D ; 2 byte

COMMAND           = $7F ; 1 byte

SONG_START        = $80 ; 4 bytes
CURRENT_POSITION  = $84 ; 4 bytes
WAIT_CNTR         = $88 ; 2 bytes
PCM_OFFSET        = $8A ; 4 bytes
GD3_POSITION      = $8E ; 4 bytes

AY_3_8910_A       = $92 ; 2 bytes
AY_3_8910_B       = $94 ; 2 bytes
AY_3_8910_C       = $96 ; 2 bytes
AY_3_8910_N       = $98 ; 2 bytes
AY_BASE_AMPL      = $9A ; 1 byte

DATA_STREAM_TBL   = $8000 ; each entry is 4 bytes

VGM_FILE          = $170000  ; the address to store the VGM data.

* = $162200

VGM_START
            .as
            .xs
            PHP
            setas
            setxl
            PHB
            PHD
            
            SEI
            setal
            LDA #0
            STA WAIT_CNTR
            setas
            TCD  ; store 0 in the direct page register
            PHA
            PLB  ; store 0 in the bank register
            
            STA COMMAND
            ; set the base address for messages
            LDA #`RESET_MSG
            STA MSG_PTR+2
            ; set the display offset - reuse the kernels start address
            LDX $17
            STX DISPLAY_OFFSET
            
            ; detect if a file was provided in the BRUN command
            JSR LOAD_VGM_FILE
            LDA COMMAND ; if the command is still 0, it's a vgm file
            BNE VGM_DONE
            
            ; disable the cursor
            LDA #0
            STA VKY_TXT_CURSOR_CTRL_REG
            
            LDX #0
            STX DATA_STREAM_CNT
            
            ; load the music
            LDA #`VGM_FILE
            STA CURRENT_POSITION + 2
            STA SONG_START + 2

            LDX #<>VGM_FILE
            STX SONG_START
            
            LDA #0
            STA COMMAND
            JSR CHECK_VGM_FILE
            LDA COMMAND ; if the command is still 0, it's a vgm file
            BNE INVALID_FILE
            
            JSR VGM_SET_SONG_POINTERS
            
            JSR VGM_DISPLAY_GD3
            
            JSR VGM_INIT_TIMER0

            ; enable timer 0
            LDA INT_MASK_REG0
            AND #~( FNX0_INT02_TMR0 ) ;
            STA INT_MASK_REG0
            
            JSL VGM_WRITE_REGISTER  ; the initial load of register should set the timerA
            CLI

            BRA VGM_DONE
            
        INVALID_FILE
            setal
            LDA #<>INVALID_FILE_MSG
            STA MSG_PTR
            setas
            JSR DISPLAY_MSG
        VGM_DONE
            ; return control to the kernel
            LDY #<>KERNEL_RETURN_MSG
            STY MSG_PTR
            JSR DISPLAY_MSG
            
            PLD
            PLB
            PLP
            RTL
            
RESET_MSG               .text 'Restarting song:',0
LOOPING_MSG             .text 'Looping song:',0
DATA_BLOCK_MSG          .text 'Reading Data Block:',0
INVALID_FILE_MSG        .text 'Invalid file type:', 0
UNK_CMD1_MSG            .text 'Unknown 1-Byte Command:',0
UNK_CMD2_MSG            .text 'Unknown 2-Byte Command:',0
UNK_CMD3_MSG            .text 'Unknown 3-Byte Command:',0
UNK_CMD4_MSG            .text 'Unknown 4-Byte Command:',0
HEX_VALUES              .text '0123456789ABCDEF'
GD3_ERR_MSG             .text 'Couldn''t read Gd3 Info', 0
LOADING_VGM_FILE_MSG    .text 'VGM Player loading file', 0
BRUN_CMD_ERROR_MSG      .text 'BRUN does not have a file to load.', 0
KERNEL_RETURN_MSG       .text 'Returning control to kernel', 0
 
DOS_REC_PTR      .dstruct FILEDESC

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
            
            ; get the file version
            LDY #8
            LDA [SONG_START],Y
            STA MIN_VERSION
            
            RTS
            
    CHECK_FAILED
            LDA #1
            STA COMMAND
            RTS
            
LOAD_VGM_FILE
            .as
            .xl
            
            setdp <>DOS_RUN_PARAM
            .as
            LDY #0
            
    FS_LOOP
            LDA [DOS_RUN_PARAM],Y
            INY
            CPY #$20 ; expect the vgm command to be less than 32 characters
            BGE LF_ERROR
            
            CMP #' '  ; seek the space character in the BRUN command
            BNE FS_LOOP
            PHY
            PHD
            setdp 0
            .as
            ; display a message to the user that we're loading a file
            LDY #<>LOADING_VGM_FILE_MSG
            STY MSG_PTR
            JSR DISPLAY_MSG
            PLD
            PLY
            BRA LF_GOOD
            
    LF_ERROR
            setdp 0
            .as
            LDY #<>BRUN_CMD_ERROR_MSG
            STY MSG_PTR
            JSR DISPLAY_MSG
            LDA #1
            STA COMMAND
            RTS
            
    LF_GOOD
            ; setup the file parameters for the kernel
            setal
            TYA
            CLC
            ADC DOS_RUN_PARAM
            STA DOS_REC_PTR.PATH
            LDA DOS_RUN_PARAM + 2
            STA DOS_REC_PTR.PATH + 2
            LDA #<>VGM_FILE
            STA DOS_DST_PTR
            LDA #`VGM_FILE
            STA DOS_DST_PTR + 2
            
            ; write the address of the file descriptor
            LDA #<>DOS_REC_PTR
            STA DOS_FD_PTR
            LDA #`DOS_REC_PTR
            STA DOS_FD_PTR + 2
            
            ; write the address of our buffer
            LDA #<>VGM_START - 512
            STA DOS_REC_PTR.BUFFER
            LDA #`(VGM_START - 512)
            STA DOS_REC_PTR.BUFFER + 2
            
            setas

            LDA #0
            STA DOS_REC_PTR.STATUS
            LDA #BIOS_DEV_SD
            STA DOS_REC_PTR.DEV
            JSL F_LOAD
            BCC LF_ERROR
            
            setdp 0
            
            RTS
            
DISPLAY_MSG
            .as
            PHY
            LDX DISPLAY_OFFSET
            LDY #0
            LDA #0
            XBA
    DISPLAY_NEXT
            LDA #$2D   ; Text color
            STA $AF2000,X  ; offset to Text LUT $AF:C000
            LDA [MSG_PTR],Y
            STA $AF0000,X  ; offset to Text $AF:A000
            ; write the color for the characters - green
            
            INX
            INY
            CMP #0
            BNE DISPLAY_NEXT
            
            ; display the command hex
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
            ADC #80 ; 80 columns in 640x480 mode
            STA DISPLAY_OFFSET
            setas
            
            XBA
            CMP #$B1 ; 80 COLS * 56 ROWS = $1180  - SO $11 + A0 = $B1
            BLT DISPLAY_DONE
            
            XBA
            BNE FIRST_COL
            LDX #$A000 + 40 ; create a second column
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
            PHD
            setdp 0
            .as
     
            LDX WAIT_CNTR
            CPX #0
            BEQ READ_COMMAND
            
            DEX
            STX WAIT_CNTR
            
            PLD
            RTL
            
    READ_COMMAND
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
            JMP (VGM_COMMAND_TABLE,X)
            
    VGM_LOOP_DONE
            PLD
            RTL
            
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
            .word <>AY8910          ;A - AY8910
            .word <>SKIP_TWO_BYTES  ;B - not implemented
            .word <>SKIP_THREE_BYTES;C - not implemented
            .word <>SKIP_THREE_BYTES;D - not implemented
            .word <>SEEK_OFFSET     ;E - not implemented
            .word <>SKIP_FOUR_BYTES ;F - not implemented
            
INVALID_COMMAND
            .as
            JMP READ_COMMAND

SKIP_BYTE_CMD
            .as
            setal
            LDA #<>UNK_CMD1_MSG
            STA MSG_PTR
            setas
            JSR DISPLAY_MSG
            increment_long_addr CURRENT_POSITION
            JMP READ_COMMAND

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
            JMP READ_COMMAND

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
            JMP READ_COMMAND

SEEK_OFFSET
            .as
            LDA COMMAND
            CMP #$E0
            BNE SKIP_FOUR_BYTES
            
            ; read 4 bytes, add them to the databank 0 offset
            ; and store in the PCM_OFFSET
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
            LDA DATA_STREAM_TBL
            STA ADDER_B
            LDA DATA_STREAM_TBL + 2
            STA ADDER_B + 2
            
            LDA ADDER_R
            STA PCM_OFFSET
            LDA ADDER_R + 2
            STA PCM_OFFSET + 2
            setas
            
            JMP VGM_LOOP_DONE
            
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
            JMP READ_COMMAND

; we need to combine R1 and R0 together before we send
; the data to the SN76489
AY8910 
            .as
            LDA #$F
            STA AY_BASE_AMPL
            LDA COMMAND
            CMP #$A0
            BEQ AY_COMMAND
            
            JMP SKIP_TWO_BYTES ; when mixing with the YM2612, the SN76489 is just too load.
            
    AY_COMMAND
            ; the second byte is the register
            LDA [CURRENT_POSITION]
            increment_long_addr CURRENT_POSITION
            CMP #0 ; Register 0 fine
            BNE AY_R1
            
            LDA AY_3_8910_A
            CMP #8
            BLT R0_FINE
            
            LDA #$87
            STA PSG_BASE_ADDRESS
            LDA #$3F
            STA PSG_BASE_ADDRESS
            increment_long_addr CURRENT_POSITION
            JMP READ_COMMAND
            
        R0_FINE
            XBA
            LDA [CURRENT_POSITION]
            increment_long_addr CURRENT_POSITION
            
            setal
            LSR A ; drop the LSB
            setas
            PHA
            AND #$F
            ORA #$80
            STA PSG_BASE_ADDRESS
            
            PLA
            setal
            LSR A
            LSR A
            LSR A
            LSR A
            setas
            
            AND #$3F ; 6 bits

            STA PSG_BASE_ADDRESS
            JMP READ_COMMAND
            
            
    AY_R1   CMP #1
            BNE AY_R2
            
            LDA [CURRENT_POSITION]
            increment_long_addr CURRENT_POSITION
            AND #$F
            STA AY_3_8910_A
            
            JMP READ_COMMAND
            
    AY_R2   CMP #2
            BNE AY_R3
            
            LDA AY_3_8910_B
            CMP #8
            BLT R1_FINE
            
            LDA #$A7
            STA PSG_BASE_ADDRESS
            LDA #$3F
            STA PSG_BASE_ADDRESS
            increment_long_addr CURRENT_POSITION
            JMP READ_COMMAND
            
        R1_FINE
            XBA
            LDA [CURRENT_POSITION]
            increment_long_addr CURRENT_POSITION
            
            setal
            LSR A ; drop the LSB
            setas
            
            PHA
            AND #$F
            ORA #$A0
            STA PSG_BASE_ADDRESS
            
            PLA
            setal
            LSR A
            LSR A
            LSR A
            LSR A
            setas
            AND #$3F ; 6 bits

            STA PSG_BASE_ADDRESS
            JMP READ_COMMAND
            
    AY_R3   CMP #3
            BNE AY_R4
            
            LDA [CURRENT_POSITION]
            increment_long_addr CURRENT_POSITION
            AND #$F
            STA AY_3_8910_B
            
            JMP READ_COMMAND
            
    AY_R4   CMP #4
            BNE AY_R5
            
            LDA AY_3_8910_C
            CMP #8
            BLT R2_FINE
            
            LDA #$C7
            STA PSG_BASE_ADDRESS
            LDA #$3F
            STA PSG_BASE_ADDRESS
            increment_long_addr CURRENT_POSITION
            JMP READ_COMMAND
            
        R2_FINE
            XBA
            LDA [CURRENT_POSITION]
            increment_long_addr CURRENT_POSITION
            
            setal
            LSR A ; drop the LSB
            setas
            
            PHA
            AND #$F
            ORA #$C0
            STA PSG_BASE_ADDRESS
            
            PLA
            setal
            LSR A
            LSR A
            LSR A
            LSR A
            setas
            AND #$3F ; 6 bits

            STA PSG_BASE_ADDRESS
            JMP READ_COMMAND
            
    AY_R5   CMP #5
            BNE AY_R10
            
            LDA [CURRENT_POSITION]
            increment_long_addr CURRENT_POSITION
            AND #$F
            STA AY_3_8910_C
            
            JMP READ_COMMAND
    
    AY_R10
            CMP #8
            BNE AY_R11
            
            LDA [CURRENT_POSITION]
            increment_long_addr CURRENT_POSITION
            EOR AY_BASE_AMPL
            AND #$F
            ORA #$90
            STA PSG_BASE_ADDRESS
            JMP READ_COMMAND
            
    AY_R11
            CMP #9
            BNE AY_R12
            
            LDA [CURRENT_POSITION]
            increment_long_addr CURRENT_POSITION
            EOR AY_BASE_AMPL
            AND #$F
            ORA #$B0
            STA PSG_BASE_ADDRESS
            JMP READ_COMMAND
            
    AY_R12
            CMP #10
            BNE AY_R15
            
            LDA [CURRENT_POSITION]
            increment_long_addr CURRENT_POSITION
            EOR AY_BASE_AMPL
            AND #$F
            ORA #$D0
            STA PSG_BASE_ADDRESS
            JMP READ_COMMAND
            
    AY_R15
            increment_long_addr CURRENT_POSITION
            JMP READ_COMMAND
; *******************************************************************
; * YM Commands
; *******************************************************************
WRITE_YM_CMD
            .as
            LDA COMMAND
            CMP #$50
            BNE CHK_YM2413
            
            LDA [CURRENT_POSITION]
            STA PSG_BASE_ADDRESS
            increment_long_addr CURRENT_POSITION
            JMP VGM_LOOP_DONE ; for some reason, this chip needs more time between writes
            
        CHK_YM2413
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
            STA @lOPL3_BASE_ADRESS,X
            ;STA @lOPN2_BASE_ADDRESS,X  ; this probably won't work
            increment_long_addr CURRENT_POSITION
            JMP READ_COMMAND
            
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
            JMP VGM_LOOP_DONE ; for some reason, this chip needs more time between writes
            
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
            JMP VGM_LOOP_DONE ; for some reason, this chip needs more time between writes
            
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
            JMP READ_COMMAND
            
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
            JMP READ_COMMAND
            
        CHK_YM2608_P0
            CMP #$56
            BNE CHK_YM2608_P1
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA [CURRENT_POSITION]
            CMP #$10  ; if the register is 0 to $1F, process as SSG
            BGE YM2608_FM
            JMP AY8910

        YM2608_FM
            TAX
            increment_long_addr CURRENT_POSITION
            
            ; the third byte is the value to write in the register
            LDA [CURRENT_POSITION]
            STA @lOPN2_BASE_ADDRESS,X
            increment_long_addr CURRENT_POSITION
            JMP READ_COMMAND
            
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
            STA @lOPN2_BASE_ADDRESS,X
            increment_long_addr CURRENT_POSITION
            JMP READ_COMMAND
            
        CHK_YM2610_P0
            CMP #$58
            BNE CHK_YM2610_P1
            
            ; the second byte is the register
            LDA #0
            XBA
            LDA [CURRENT_POSITION]
            CMP #$10  ; if the register is 0 to $1F, process as SSG
            BGE YM2610_FM
            JMP AY8910
            
        YM2610_FM
            TAX
            increment_long_addr CURRENT_POSITION
            
            ; the third byte is the value to write in the register
            LDA [CURRENT_POSITION]
            STA @lOPN2_BASE_ADDRESS,X
            increment_long_addr CURRENT_POSITION
            JMP READ_COMMAND
            
        CHK_YM2610_P1
            CMP #$59
            BNE CHK_YM3812
            
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
            JMP READ_COMMAND
            
        CHK_YM3812
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
            JMP READ_COMMAND
        
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
            JMP READ_COMMAND
            
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
            JMP READ_COMMAND
            
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
            JMP VGM_LOOP_DONE
            
        CHK_WAIT_60th
            CMP #$62
            BNE CHK_WAIT_50th
            
            LDX #$2df
            STX WAIT_CNTR
            JMP VGM_LOOP_DONE
            
        CHK_WAIT_50th
            CMP #$63
            BNE CHK_END_SONG
            
            LDX #$372
            STX WAIT_CNTR
            JMP VGM_LOOP_DONE

        CHK_END_SONG
            CMP #$66 ; end of song
            BNE CHK_DATA_BLOCK
            
            JSR VGM_SET_LOOP_POINTERS
            JMP VGM_LOOP_DONE
            
        CHK_DATA_BLOCK
            CMP #$67
            BNE DONE_WAIT
            
            JSR READ_DATA_BLOCK
    DONE_WAIT
            JMP VGM_LOOP_DONE
            
; *******************************************************************
; * Wait N+1 Commands
; *******************************************************************
WAIT_N_1
            .as
            LDA #0
            XBA
            LDA COMMAND
            AND #$F
            TAX
            INX ; $7n where we wait n+1
            STX WAIT_CNTR
            JMP VGM_LOOP_DONE
            
; *******************************************************************
; * Play Samples and wait N
; *******************************************************************
YM2612_SAMPLE
            .as
            ; write directly to YM2612 DAC then wait n
            ; load a value from database
            LDA [PCM_OFFSET]
            STA OPN2_BASE_ADDRESS + $2A
            
            ; increment PCM_OFFSET
            setal
            LDA PCM_OFFSET
            INC A
            STA PCM_OFFSET
            BCC YMS_WAIT
            LDA PCM_OFFSET + 2
            INC A
            STA PCM_OFFSET + 2
            
    YMS_WAIT
            setas
            LDA #0
            XBA
            LDA COMMAND
            ; this is the wait part
            AND #$F
            TAX
            STX WAIT_CNTR
            ;CPX #0
            ;BNE YMS_NOT_ZERO
            
            ;RTS
            
    YMS_NOT_ZERO
            JMP READ_COMMAND
            
; *******************************************************************
; * Don't know yet
; *******************************************************************
DAC_STREAM
            .as

            ;JMP VGM_LOOP_DONE
            JMP READ_COMMAND
            

VGM_SET_SONG_POINTERS
            .as
            setal
            LDA #<>RESET_MSG
            STA MSG_PTR
            setas
            JSR DISPLAY_MSG
            
            setal
            LDA #0
            STA WAIT_CNTR
            LDA SONG_START + 2
            STA CURRENT_POSITION + 2
            setas
            
            LDA MIN_VERSION
            CMP #$50
            BLT OLD_VERSION
            
            ; add the start offset
            setal
            CLC
            LDY #VGM_OFFSET
            LDA [SONG_START],Y
            ADC #VGM_OFFSET
            ADC SONG_START
            STA CURRENT_POSITION
            BCC VSP_DONE
            
            INC CURRENT_POSITION + 2
    VSP_DONE
            
            ; compute the GD3 information position
            CLC
            LDY #GD3_OFFSET
            LDA [SONG_START],Y
            ADC #GD3_OFFSET
            ADC SONG_START
            STA GD3_POSITION
            
            INY
            INY
            LDA [SONG_START],Y
            ADC SONG_START + 2
            STA GD3_POSITION + 2
            
            setas
            RTS
            
    OLD_VERSION
            setal
            CLC
            LDA #$40
            ADC SONG_START
            STA CURRENT_POSITION
            BCC VSP_OLD_DONE
            
            INC CURRENT_POSITION + 2
    VSP_OLD_DONE
            setas
            RTS
            
VGM_SET_LOOP_POINTERS
            .as
            PHD
            PHB
            LDA #0
            PHA
            PLB
            
            ; add the start offset
            setal
            LDA #0
            TCD  ; reset the direct page.
            STA WAIT_CNTR
            
            
            CLC
            LDY #LOOP_OFFSET
            LDA [SONG_START],Y
            BEQ NO_LOOP_INFO ; if this is zero, assume that the upper word is also 0
            
            ADC #LOOP_OFFSET ; add the current position
            STA ADDER_A
            INY
            INY
            LDA [SONG_START],Y
            STA ADDER_A + 2
            
            LDA #<>LOOPING_MSG
            STA MSG_PTR
            setas
            JSR DISPLAY_MSG
            setal
            
            LDA SONG_START
            STA ADDER_B
            LDA SONG_START + 2
            STA ADDER_B + 2
            LDA ADDER_R
            STA CURRENT_POSITION
            LDA ADDER_R + 2
            STA CURRENT_POSITION + 2
            
            BRA VSL_DONE
            
    NO_LOOP_INFO
            LDA #<>RESET_MSG
            STA MSG_PTR
            setas
            JSR DISPLAY_MSG
            setal
            
            LDY #VGM_OFFSET
            LDA [SONG_START],Y
            ADC #VGM_OFFSET

            ADC SONG_START
            STA CURRENT_POSITION
            LDA SONG_START + 2
            STA CURRENT_POSITION + 2
            
            BCC VSL_DONE
            INC CURRENT_POSITION + 2
    VSL_DONE
            setas
            PLB
            PLD
            RTS

VGM_INIT_TIMER0
            .as
            
            ; set the timer 0 interrupt to the VGM_WRITE_REGISTER address
            setal
            LDA #<>VGM_WRITE_REGISTER
            STA VEC_INT02_TMR0 + 1
            setas
            
            ; don't write double-bytes, as it will overwrite the JUMP command
            LDA #`VGM_WRITE_REGISTER
            STA VEC_INT02_TMR0 + 3
            
            LDA #$44
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
            PHD
            PHB
            LDA #0
            PHA
            PLB  ; reset bank
            
            setal
            LDA #0
            TCD  ; reset direct reg
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
            BEQ UNCOMPRESSED
            CMP #$C0
            BNE UNKNOWN_DATA_BLOCK
            
    UNCOMPRESSED
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
            PLB
            PLD
            RTS
            
VGM_DISPLAY_GD3
            .as
            ; ensure the Gd3 data is correct, otherwise return
            LDY #0
            LDA [GD3_POSITION],Y
            CMP #'G'
            BNE GD3_ERROR
            INY
            LDA [GD3_POSITION],Y
            CMP #'d'
            BNE GD3_ERROR
            INY
            LDA [GD3_POSITION],Y
            CMP #'3'
            BNE GD3_ERROR
            INY
            LDA [GD3_POSITION],Y
            CMP #' '
            BNE GD3_ERROR
            INY
            setal
            LDA [GD3_POSITION],Y
            CMP #$100
            BNE GD3_ERROR
            INY
            INY
            LDA [GD3_POSITION],Y
            BNE GD3_ERROR
    
            setas
            INY
            INY
            
            INY  ; skip the length
            INY
            INY
            INY
            
            ; header is OK.
            JSR DISPLAY_MSG_16  ; display the track name in English
            JSR DISCARD_16      ; discard the track name in Japanese
            JSR DISCARD_16      ; discard the game name in English
            JSR DISCARD_16      ; discard the game name in Japanese
            JSR DISCARD_16      ; discard the system name in English
            JSR DISCARD_16      ; discard the system name in Japanese
            JSR DISPLAY_MSG_16  ; display the author's name in English
            
            RTS
            
GD3_ERROR   
            setas
            LDX #<>GD3_ERR_MSG
            STX MSG_PTR
            JSR DISPLAY_MSG
            RTS

; read 16 bit character data.  English is still ASCII
; when a 16-bit 0 is found, return
; Y countains an offset from GD3_POSITION
DISPLAY_MSG_16
            .as
            LDX DISPLAY_OFFSET
            
    DM16_LOOP
            setas
            LDA #$2D   ; Text color
            STA $AF2000,X  ; offset to Text LUT $AF:C000
            setal
            LDA [GD3_POSITION],Y
            
            setas
            STA $AF0000,X  ; offset to Text LUT $AF:C000
            
            INY
            INY
            INX
            setal
            CMP #0
            BNE DM16_LOOP
            
            LDA DISPLAY_OFFSET
            CLC
            ADC #80 ; 80 columns in 640x480 mode
            STA DISPLAY_OFFSET
            setas
            RTS
    
; read all characters until a 16 bit 0 is found
DISCARD_16
            setal
    DIS_LOOP
            LDA [GD3_POSITION],Y
            INY
            INY
            CMP #0
            BNE DIS_LOOP
            setas
            RTS
