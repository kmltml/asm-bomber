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

        in al, Keyboard_port

        cmp al, SC_P_A
        jne .ap
        mov byte [key_a], 1
.ap:    cmp al, SC_R_A
        jne .ar
        mov byte [key_a], 0
.ar:    cmp al, SC_P_S
        jne .sp
        mov byte [key_s], 1
.sp:    cmp al, SC_R_S
        jne .sr
        mov byte [key_s], 0
.sr:    cmp al, SC_P_W
        jne .wp
        mov byte [key_w], 1
.wp:    cmp al, SC_R_W
        jne .wr
        mov byte [key_w], 0
.wr:    cmp al, SC_P_D
        jne .dp
        mov byte [key_d], 1
.dp:    cmp al, SC_R_D
        jne .dr
        mov byte [key_d], 0
.dr:

        mov al, 0x20
        out 0x20, al

        pop ax
        iret

key_a:  db 0
key_s:  db 0
key_d:  db 0
key_w:  db 0

        
