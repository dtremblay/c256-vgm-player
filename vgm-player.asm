.cpu "65816"
.include "macros_inc.asm"
.include "base.asm"
.include "bank_00_inc.asm"
.include "interrupt_def.asm"
.include "keyboard_def.asm"
.include "vicky_def.asm"
.include "kernel_inc.asm"
.include "timer_def.asm"


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
WAIT_CNTR         = $72 ; 2 bytes
LOOP_OFFSET_REG   = $74 ; 2 bytes

* = $160000

VGM_START
            .as
            .xs
            setas
            setxl
            
            PHB
            LDA #`VGM_FILE
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
            LDA #`VGM_FILE
            PHA
            PLB
            .databank `VGM_FILE
            
            ; first byte is a  command - should be $54 for YM2151
            LDY CURRENT_POSITION
    CHECK_NEXT
            LDA VGM_FILE,Y
            INY
            CMP #$50
            BNE NOT_PSG
            
            LDA VGM_FILE,Y
            STA PSG_BASE_ADDRESS
            INY
            JMP WR_DONE
            
    NOT_PSG
            CMP #$52
            BNE NOT_YM2612_P0
            
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
            
    NOT_YM2612_P0
            CMP #$53
            BNE NOT_YM2612_P1
            
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
            
    NOT_YM2612_P1
            CMP #$54
            BNE NOT_YM2151
            
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
        
    NOT_YM2151
            CMP #$5E
            BNE NOT_YM262_P0
            
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
            
    NOT_YM262_P0
            CMP #$5F
            BNE NOT_YM262_P1
            
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
            
    NOT_YM262_P1
            CMP #$61
            BNE NOT_WAIT
            setal
            LDA VGM_FILE,Y
            TAX
            STX WAIT_CNTR
            setas
            ;JSR DISPLAY_X
            INY
            INY
            ;JSR WAIT
            ;BRA LOAD_CMD
            BRA WR_DONE
            
    NOT_WAIT
            CMP #$62
            BNE NOT_WAIT_60TH
            
            LDX #$2df
            STX WAIT_CNTR

            BRA WR_DONE
            
    NOT_WAIT_60TH
            CMP #$63
            BNE NOT_WAIT_50TH
            
            LDX #$372
            STX WAIT_CNTR

            BRA WR_DONE
            
    NOT_WAIT_50TH
            CMP #$66 ; end of song
            BNE NOT_SONG_END
            
            setal
            CLC
            LDY #VGM_OFFSET
            LDA VGM_FILE,Y
            ADC #$34
            TAY
            LDA #0
            STA WAIT_CNTR
            setas
            
            BRA WR_DONE 
            
    NOT_SONG_END
            BIT #$70
            BEQ SKIP_CMD
            
            AND #$F
            TAX
            STX WAIT_CNTR
            BRA WR_DONE
            
    SKIP_CMD
            JSL PRINTAH
            ;INY
            ;INY
    WR_DONE
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

.include "interrupt_handler.asm"
        
VGM_FILE
;.binary "04 Kalinka.vgm"
;.binary "peddler.vgm"
;.binary "troika.vgm"
;.binary "test.vgm"

; PSG FILES
;.binary "03 Minigame Intro.vgm"
;.binary "01 Ghostbusters Main Theme.vgm"

; YM2612
;.binary "09 Skyscrapers.vgm"

; YM262
.binary "02 At Doom's Gate-ym262.vgm"
