load_sprite:                    ; (name, dest)
        push bp
        mov bp, sp
.buffer_size equ 16 * 16
        sub sp, .buffer_size + 2
        push ds
        push es
.name equ 4
.dest equ 6
.buffer equ -.buffer_size
.file equ -.buffer_size - 2
.counter equ -.buffer_size - 2

        mov ax, ds              ; Prepare ES for buffer copy
        mov es, ax

        mov ax, 0x3d00          ; Open file - readonly
        mov dx, [bp + .name]    ; filename in DS:DX
        int 0x21
        jc .exit                ; return on error
        mov [bp + .file], ax

        mov bx, ax
        mov ax, 0x4200          ; Seek from beginning of file
        xor cx, cx
        mov dx, 0x0a            ; cx:dx - position of pixel data offset
        int 0x21
        jc .exit

        mov ax, ss
        mov ds, ax
        mov ax, 0x3f00          ; Read from file
        mov bx, [bp + .file]
        mov cx, 4               ; Size of pixel data offset
        lea dx, [bp + .buffer]  ; ds:dx buffer for data read
        int 0x21
        jc .exit

        mov ax, 0x4200          ; Seek from beginning of file
        mov bx, [bp + .file]
        mov dx, [bp + .buffer]  ; cx:dx - pixel data offset
        mov cx, [bp + .buffer + 2]
        int 0x21
        jc .exit

        mov ax, 0x3f00          ; Read from file
        mov bx, [bp + .file]
        mov cx, .buffer_size    ; Number of bytes to read
        lea dx, [bp + .buffer]
        int 0x21
        jc .exit

        lea si, [bp + .buffer + .buffer_size - 16] ; Copy buffer to dest
        mov di, [bp + .dest]
        mov byte [bp + .counter], 16
        cld
.copyloop:
        mov cx, 16 / 4
        rep movsd
        sub si, 32              ; move 2 rows back
        dec byte [bp + .counter]
        jnz .copyloop

.exit:  pop es
        pop ds
        mov sp, bp
        pop bp
        ret
