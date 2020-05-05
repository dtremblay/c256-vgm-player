;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
; Interrupt Handler
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////
;////////////////////////////////////////////////////////////////////////////

check_irq_bit  .macro
                LDA \1
                AND #\2
                CMP #\2
                BNE END_CHECK
                STA \1
                JSR \3
                
END_CHECK
                .endm
                
IRQ_HANDLER
; First Block of 8 Interrupts
                .as
                setdp 0
                
                .as
                LDA #0  ; set the data bank register to 0
                PHA
                PLB
                setas
                LDA INT_PENDING_REG0
                BEQ CHECK_PENDING_REG1

; Start of Frame (display), timer 0 (music), mouse (ignored)
                ;check_irq_bit INT_PENDING_REG0, FNX0_INT00_SOF, SOF_INTERRUPT
                check_irq_bit INT_PENDING_REG0, FNX0_INT02_TMR0, TIMER0_INTERRUPT
                ;check_irq_bit INT_PENDING_REG0, FNX0_INT07_MOUSE, MOUSE_INTERRUPT


; Second Block of 8 Interrupts
CHECK_PENDING_REG1
                setas
                LDA INT_PENDING_REG1
                BEQ CHECK_PENDING_REG2
; Keyboard Interrupt
                ;check_irq_bit INT_PENDING_REG1, FNX1_INT00_KBD, KEYBOARD_INTERRUPT

; Third Block of 8 Interrupts
CHECK_PENDING_REG2
                setas
                LDA INT_PENDING_REG2
                BEQ CHECK_PENDING_REG3
                
; Fourth Block of 8 Interrupts
CHECK_PENDING_REG3
                setas
                LDA INT_PENDING_REG3
                BEQ EXIT_IRQ_HANDLE
                check_irq_bit INT_PENDING_REG3, FNX3_INT01_OPM, OPM_INTERRUPT
                
EXIT_IRQ_HANDLE
                ; Exit Interrupt Handler

                RTL

; ****************************************************************
; ****************************************************************
;
;  KEYBOARD_INTERRUPT
;
; ****************************************************************
; ****************************************************************
; * The only keys accepted are Left Arrow, Right Arrow, Down Arrow and Space (to rotate)
; * Alias ASD keys to arrows?
KEYBOARD_INTERRUPT
                .as
                LDA #0  ; clear B
                XBA
                
                LDA KBD_INPT_BUF        ; Get Scan Code from KeyBoard
                STA KEYBOARD_SC_TMP     ; Save Code Immediately
                
                TAX
                LDA ScanCode_Press_Set1,X
                
    DONT_REACT
                RTS

OPM_INTERRUPT
                .as
                JSR WRITE_REGISTER
                RTS
                

; ****************************************************************
; ****************************************************************
; * Start of Frame Interrupt
; * 60Hz, 16ms Cyclical Interrupt
; ****************************************************************
; ****************************************************************
SOF_INTERRUPT
                .as
                ;JSR WRITE_REGISTER
                RTS


; ****************************************************************
; ****************************************************************
; * Play notes
; ****************************************************************
; ****************************************************************
TIMER0_INTERRUPT
                .as
                JSR WRITE_REGISTER
                RTS
                
; ****************************************************************
; ****************************************************************
; * Mouse Interrupt
; * We still need to service the mouse interrupts, even 
; * though we don't use it.
; ****************************************************************
; ****************************************************************
MOUSE_INTERRUPT .as
                setas
                LDA @lINT_PENDING_REG0
                AND #FNX0_INT07_MOUSE
                STA @lINT_PENDING_REG0
                LDA KBD_INPT_BUF
                LDX #$0000
                setxs
                LDX MOUSE_PTR
                STA @lMOUSE_PTR_BYTE0, X
                INX
                CPX #$03
                BNE EXIT_FOR_NEXT_VALUE
                ; Create Absolute Count from Relative Input
                LDA @lMOUSE_PTR_X_POS_L
                STA MOUSE_POS_X_LO
                LDA @lMOUSE_PTR_X_POS_H
                STA MOUSE_POS_X_HI

                LDA @lMOUSE_PTR_Y_POS_L
                STA MOUSE_POS_Y_LO
                LDA @lMOUSE_PTR_Y_POS_H
                STA MOUSE_POS_Y_HI

                setas
                LDX #$00
EXIT_FOR_NEXT_VALUE
                STX MOUSE_PTR

                setxl
                RTS