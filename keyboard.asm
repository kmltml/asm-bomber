Keyboard_port equ 0x60

        SC_A equ 0x9e
        SC_S equ 0x9f
        SC_D equ 0xa0
        SC_W equ 0x91
        SC_SPACE equ 0xb9
        SC_ENT equ 0x9c

        SC_EXT equ 0xe0
        SC_LEFT equ 0xcb
        SC_DOWN equ 0xd0
        SC_RIGHT equ 0xcd
        SC_UP equ 0xc8

        SC_Push_Mask equ 0x80

;; Initialize the keyboard interrupt handler
kb_init:
        xor ax, ax
        mov es, ax

        mov ax, [es:9 * 4]      ; save the original interrupt vector
        mov [original_kbint], ax
        mov ax, [es:9 * 4 + 2]
        mov [original_kbint + 2], ax
        mov word [es:9 * 4], kbint ; install the custom interrupt handler
        mov word [es:9 * 4 + 2], cs

        ret

;; Keyboard interrupt handler routine
kbint:  push ax
        push bx

        in al, Keyboard_port

        mov bx, [cs:.state]
        jmp bx

.state0:                        ; primary state
        cmp al, SC_EXT          ; when extension scancode is received
        jne .s0                 ; go to state 1
        mov word [cs:.state], .state1
        jmp .quit

.s0:    mov ah, al
        or ah, SC_Push_Mask

        cmp ah, SC_A
        je .a
        cmp ah, SC_S
        je .s
        cmp ah, SC_W
        je .w
        cmp ah, SC_D
        je .d
        cmp ah, SC_SPACE
        je .space
        cmp ah, SC_ENT
        je .enter
        jmp .quit

.a:     mov bx, key_a
        jmp .set
.s:     mov bx, key_s
        jmp .set
.w:     mov bx, key_w
        jmp .set
.d:     mov bx, key_d
        jmp .set
.space:
        mov bx, key_space
        jmp .set
.enter:
        mov bx, key_ent
        jmp .set

.state1:                        ; state after receiving extension scancode
        mov word [cs:.state], .state0 ; go back to primary state
        mov ah, al
        or ah, SC_Push_Mask

        cmp ah, SC_LEFT
        je .left
        cmp ah, SC_DOWN
        je .down
        cmp ah, SC_UP
        je .up
        cmp ah, SC_RIGHT
        je .right
        jmp .quit
.left:  mov bx, key_left
        jmp .set
.down:  mov bx, key_down
        jmp .set
.up:    mov bx, key_up
        jmp .set
.right: mov bx, key_right
        jmp .set


.set:   xor ah, ah
        and al, SC_Push_Mask
        test al, al
        jnz .skip
        inc ah                  ; set ah to 1
.skip:  mov [cs:bx], ah
        jmp .quit

.quit:
        mov al, 0x20            ; signal completion of interrupt handling
        out 0x20, al

        pop bx
        pop ax
        iret

.state: dw .state0

key_player1:
key_a:  db 0
key_s:  db 0
key_d:  db 0
key_w:  db 0
key_space: db 0

        key.left equ key_a - key_player1
        key.down equ key_s - key_player1
        key.right equ key_d - key_player1
        key.up equ key_w - key_player1
        key.place equ key_space - key_player1

key_player2:
key_left: db 0
key_down: db 0
key_right: db 0
key_up: db 0
key_ent: db 0

original_kbint: dw 0, 0
