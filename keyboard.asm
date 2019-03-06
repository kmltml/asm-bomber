Keyboard_port equ 0x60

        SC_P_A equ 0x1e
        SC_P_S equ 0x1f
        SC_P_D equ 0x20
        SC_P_W equ 0x11

        SC_R_A equ 0x9e
        SC_R_S equ 0x9f
        SC_R_D equ 0xa0
        SC_R_W equ 0x91

kb_init:
        xor ax, ax
        mov es, ax

        mov word [es:9 * 4], kbint
        mov word [es:9 * 4 + 2], cs

        ret

kbint:  push ax
        push ds

        mov ax, cs
        mov ds, ax

        in al, Keyboard_port

        cmp al, SC_P_A
        je .ap
        cmp al, SC_R_A
        je .ar
        cmp al, SC_P_S
        je .sp
        cmp al, SC_R_S
        je .sr
        cmp al, SC_P_W
        je .wp
        cmp al, SC_R_W
        je .wr
        cmp al, SC_P_D
        je .dp
        cmp al, SC_R_D
        je .dr
        jmp .quit

.ap:    mov byte [key_a], 1
        jmp .quit
.ar:    mov byte [key_a], 0
        jmp .quit
.sp:    mov byte [key_s], 1
        jmp .quit
.sr:    mov byte [key_s], 0
        jmp .quit
.wp:    mov byte [key_w], 1
        jmp .quit
.wr:    mov byte [key_w], 0
        jmp .quit
.dp:    mov byte [key_d], 1
        jmp .quit
.dr:    mov byte [key_d], 0
        jmp .quit
.quit:
        mov al, 0x20
        out 0x20, al

        pop ds
        pop ax
        iret

key_a:  db 0
key_s:  db 0
key_d:  db 0
key_w:  db 0
