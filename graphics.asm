        Back_buff_seg equ 0xb000
        Front_buff_seg equ 0xa000

        Screen_Width equ 320
        Screen_Height equ 200

wait_for_retrace:               ; ()
        mov dx, 0x03da
.l1:
        in al, dx
        test al, 0x08
        jnz .l1
.l2:
        in al, dx
        test al, 0x08
        jz .l2
        ret

copy_buffer:                    ; ()
        push ds

        mov ax, Back_buff_seg
        mov ds, ax
        mov ax, Front_buff_seg
        mov es, ax

        xor si, si
        xor di, di

        mov cx, Screen_Width * Screen_Height / 4
        cld
        rep movsd

        pop ds
        ret

clear_screen:                   ; ()
        mov ax, Back_buff_seg
        mov es, ax

        xor ax, ax
        mov cx, Screen_Width * Screen_Height / 2
        xor di, di
        cld
        rep stosw
        ret

        tile.passable equ 0
        tile.destructible equ 1
        tile.pixels equ 2

draw_tilemap:
        push bp
        mov bp, sp
        sub sp, 8
.a0:    equ -8
.x      equ -2
.y      equ -4

        mov ax, Back_buff_seg
        mov es, ax

        mov word [bp + .x], 0
        mov word [bp + .y], 0
.loop:  mov ax, [bp + .x]
        mov [bp + .a0], ax
        mov ax, [bp + .y]
        mov [bp + .a0 + 2], ax
        call draw_tile

        inc word [bp + .x]

        cmp word [bp + .x], Level_Width
        jb .loop

        mov word [bp + .x], 0
        inc word [bp + .y]

        cmp word [bp + .y], Level_Height
        jb .loop

        mov sp, bp
        pop bp
        ret

draw_tile:                      ; (x, y)
        push bp
        mov bp, sp
.x      equ 4
.y      equ 6

        ; load pixel pointer of the tile
        mov ax, [bp + .y]
        xor dx, dx
        mov bx, Level_Width
        mul bx
        add ax, [bp + .x]
        mov si, ax
        mov bl, [tile_map + si] ; bl <- tile index
        mov bh, 0
        shl bx, 1
        mov si, [tiles + bx]    ; si <- tile data pointer

        lea si, [si + tile.pixels]

        ; set di to offset in the drawing buffer
        mov ax, [bp + .y]
        xor dx, dx
        mov bx, Screen_Width * Tile_Height
        mul bx
        mov di, ax
        mov ax, [bp + .x]
        xor dx, dx
        mov bx, Tile_Width
        mul bx
        add di, ax

        mov ax, Tile_Height
.loop:  mov cx, Tile_Width / 4
        cld
        rep movsd

        add di, Screen_Width - Tile_Width ; Move to next line

        dec ax
        jnz .loop

        mov sp, bp
        pop bp
        ret

draw_sprite:                    ; (sprite)
.sprite equ 4
.x equ -2
.y equ -4
        push bp
        mov bp, sp
        sub sp, 4

        mov ax, Back_buff_seg
        mov es, ax

        mov bx, [bp + .sprite]

        movzx ax, byte [bx + sprite.x]
        shl ax, 4               ; ASSUMES Tile_Width = 16!
        mov [bp + .x], ax
        movzx ax, byte [bx + sprite.y]
        shl ax, 4               ; ASSUMES Tile_Height = 16!
        mov [bp + .y], ax

        movzx cx, byte [bx + sprite.t]

        movzx si, byte [bx + sprite.dir]
        shl si, 1
        mov ax, [.lut + si]
        jmp ax
.lut:   dw .none, .left, .up, .right, .down
.left:  sub [bp + .x], cx
        jmp .none
.up:    sub [bp + .y], cx
        jmp .none
.right: add [bp + .x], cx
        jmp .none
.down:  add [bp + .y], cx
        jmp .none
.none:
        mov si, [bx + sprite.sprite]

        mov ax, [bp + .y]
        xor dx, dx
        mov bx, Screen_Width
        mul bx
        add ax, [bp + .x]
        mov di, ax

        mov bx, Tile_Height     ; bx <- y counter

.loop:  mov cx, Tile_Width

.rowloop:
        mov al, [si]
        test al, al
        jz .dontwrite
        mov [es:di], al
.dontwrite:
        inc si
        inc di
        dec cx
        jnz .rowloop

        add di, Screen_Width - Tile_Width

        dec bx
        jnz .loop

        mov sp, bp
        pop bp
        ret

draw_explosion_tiles:
        push bp
        mov bp, sp
        sub sp, 4
.x equ -1
.y equ -2
.a0 equ -4

        mov byte [bp + .y], Level_Width - 1

.loopy: mov byte [bp + .x], Level_Width - 1
.loopx: mov al, [bp + .x]
        mov [bp + .a0], al
        mov al, [bp + .y]
        mov [bp + .a0 + 1], al
        call draw_explosion_tile
        dec byte [bp + .x]
        jns .loopx

        dec byte [bp + .y]
        jns .loopy

        mov sp, bp
        pop bp
        ret

draw_explosion_tile:            ; (x, y)
        push bp
        mov bp, sp
        sub sp, 3
.x equ 4
.y equ 5
.bf equ -1
.a0 equ -3
        mov al, [bp + .x]
        mov [bp + .a0], al
        mov al, [bp + .y]
        mov [bp + .a0 + 1], al
        call is_explosion_tile
        test ax, ax
        jz .exit

        mov byte [bp + .bf], 0

        mov al, [bp + .x]
        dec al
        mov [bp + .a0], al
        mov al, [bp + .y]
        mov [bp + .a0 + 1], al
        call is_explosion_tile
        or [bp + .bf], al

        mov al, [bp + .x]
        mov [bp + .a0], al
        mov al, [bp + .y]
        dec al
        mov [bp + .a0 + 1], al
        call is_explosion_tile
        shl al, 1
        or [bp + .bf], al

        mov al, [bp + .x]
        inc al
        mov [bp + .a0], al
        mov al, [bp + .y]
        mov [bp + .a0 + 1], al
        call is_explosion_tile
        shl al, 2
        or [bp + .bf], al

        mov al, [bp + .x]
        mov [bp + .a0], al
        mov al, [bp + .y]
        inc al
        mov [bp + .a0 + 1], al
        call is_explosion_tile
        shl al, 3
        or [bp + .bf], al

        movzx bx, byte [bp + .bf]
        shl bx, 1
        mov si, [cs:.lut + bx]

        movzx ax, byte [bp + .y]
        xor dx, dx
        mov bx, Screen_Width * Tile_Height
        mul bx
        mov di, ax
        movzx ax, byte [bp + .x]
        shl ax, 4
        add di, ax

        mov bx, Tile_Height     ; bx <- y counter

.loop:  mov cx, Tile_Width

.rowloop:
        mov al, [si]
        test al, al
        jz .dontwrite
        mov [es:di], al
.dontwrite:
        inc si
        inc di
        dec cx
        jnz .rowloop

        add di, Screen_Width - Tile_Width

        dec bx
        jnz .loop

.exit:  mov sp, bp
        pop bp
        ret

.lut:   dw expl_c, expl_r, expl_b, expl_c, expl_l, expl_h, expl_c, expl_c
        dw expl_u, expl_c, expl_v, expl_c, expl_c, expl_c, expl_c, expl_c




is_explosion_tile:              ; (x, y)
        push bp
        mov bp, sp
.x equ 4
.y equ 5
        cmp byte [bp + .x], 0
        jl .no
        cmp byte [bp + .x], Level_Width
        jge .no
        cmp byte [bp + .y], 0
        jl .no
        cmp byte [bp + .y], Level_Height
        jge .no

        movzx ax, byte [bp + .y]
        mov bl, Level_Width
        mul bl
        movzx bx, byte [bp + .x]
        add bx, ax

        cmp byte [explosion_tiles + bx], 0
        je .no

        mov ax, 1
        mov sp, bp
        pop bp
        ret

.no:
        xor ax, ax
        mov sp, bp
        pop bp
        ret

expl_c: times Tile_Width * Tile_Height db 0
expl_h: times Tile_Width * Tile_Height db 0
expl_v: times Tile_Width * Tile_Height db 0
expl_u: times Tile_Width * Tile_Height db 0
expl_b: times Tile_Width * Tile_Height db 0
expl_l: times Tile_Width * Tile_Height db 0
expl_r: times Tile_Width * Tile_Height db 0
