org 0x100

        Back_buff_seg equ 0xb000
        Front_buff_seg equ 0xa000

        Screen_Width equ 320
        Screen_Height equ 200

        Level_Width equ 12
        Level_Height equ 12

        Tile_Width equ 16
        Tile_Height equ 16

section code

start:
        mov bp, sp

        mov ax, cs
        mov ds, ax

        mov ax, 0x0013
        int 0x10
.loop:
        call wait_for_retrace
        call copy_buffer
        call clear_screen

        call draw_tilemap
        jmp .loop


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

copy_buffer:                    ;()
        push ds

        mov ax, Back_buff_seg
        mov ds, ax
        mov ax, Front_buff_seg
        mov es, ax

        xor si, si
        xor di, di

        mov cx, Screen_Width * Screen_Height / 4
        rep movsd

        pop ds
        ret

clear_screen:                   ; ()
        mov ax, Back_buff_seg
        mov es, ax

        xor ax, ax
        mov cx, Screen_Width * Screen_Height / 2
        xor di, di
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
        rep movsd

        add di, Screen_Width - Tile_Width ; Move to next line

        dec ax
        jnz .loop

        mov sp, bp
        pop bp
        ret

tile_block:
        db 0                    ; passable
        db 0                    ; destructible
        db 19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19
        db 19,22,25,25,25,25,25,25,25,25,25,25,25,25,25,19
        db 19,22,23,23,23,23,23,23,23,23,23,23,23,23,25,19
        db 19,22,23,23,23,23,23,26,25,23,23,23,23,23,25,19
        db 19,22,23,23,23,23,26,25,23,23,23,23,23,23,25,19
        db 19,22,23,23,23,23,26,25,23,23,23,23,23,23,25,19
        db 19,22,23,23,23,23,26,25,23,23,23,23,23,23,25,19
        db 19,22,23,23,23,23,23,23,23,23,23,23,23,23,25,19
        db 19,22,23,23,23,26,25,23,23,23,23,26,25,23,25,19
        db 19,22,23,23,26,25,23,23,23,23,26,25,23,23,25,19
        db 19,22,23,23,26,25,23,23,23,23,26,25,23,23,25,19
        db 19,22,23,23,26,25,23,23,23,23,26,25,23,23,25,19
        db 19,22,23,23,23,23,23,23,23,23,23,23,23,23,25,19
        db 19,22,23,23,23,23,23,23,23,23,23,23,23,23,25,19
        db 19,22,22,22,22,22,22,22,22,22,22,22,22,22,22,19
        db 19,19,19,19,19,19,19,19,19,19,19,19,19,19,19,19

tile_brick:
        db 0, 1                   ; passable, destructible
        db 17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17
        db 17,22,22,22,19,22,22,22,22,22,22,19,22,22,22,17
        db 17,21,113,113,19,113,113,113,113,113,113,19,113,113,22,17
        db 17,21,113,113,19,113,113,113,113,113,113,19,113,113,22,17
        db 17,21,113,113,19,113,113,113,113,113,113,19,113,113,22,17
        db 17,19,19,19,19,19,19,19,19,19,19,19,19,19,19,17
        db 17,21,22,22,22,22,22,19,22,22,22,22,22,22,19,17
        db 17,21,113,113,113,113,22,19,113,113,113,113,113,22,19,17
        db 17,21,113,113,113,113,22,19,113,113,113,113,113,22,19,17
        db 17,21,113,113,113,113,22,19,113,113,113,113,113,22,19,17
        db 17,19,19,19,19,19,19,19,19,19,19,19,19,19,19,17
        db 17,21,22,22,19,22,22,22,22,22,22,19,22,22,22,17
        db 17,21,113,22,19,113,113,113,113,113,22,19,113,113,22,17
        db 17,21,113,22,19,113,113,113,113,113,22,19,113,113,22,17
        db 17,21,21,21,19,21,21,21,21,21,21,19,21,21,22,17
        db 17,17,17,17,17,17,17,17,17,17,17,17,17,17,17,17

tile_ground:
        db 1, 0                 ; passable, destructible
        db 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
        db 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
        db 255,255,185,255,255,255,185,255,255,255,185,255,255,255,185,255
        db 255,255,185,255,255,255,185,255,255,255,185,255,255,255,185,255
        db 255,255,185,255,255,255,185,255,255,255,185,255,255,255,185,255
        db 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
        db 255,255,255,255,185,255,255,255,185,255,255,255,185,255,255,255
        db 255,255,255,255,185,255,255,255,185,255,255,255,185,255,255,255
        db 255,255,255,255,185,255,255,255,185,255,255,255,185,255,255,255
        db 255,255,255,255,185,255,255,255,185,255,255,255,185,255,255,255
        db 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
        db 255,255,185,255,255,255,185,255,255,255,185,255,255,255,185,255
        db 255,255,185,255,255,255,185,255,255,255,185,255,255,255,185,255
        db 255,255,185,255,255,255,185,255,255,255,185,255,255,255,185,255
        db 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255
        db 255,255,255,255,255,255,255,255,255,255,255,255,255,255,255,255

tiles:
        dw tile_ground, tile_block, tile_brick

tile_map:
        db 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2
        db 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1
        db 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2
        db 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1
        db 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2
        db 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1
        db 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2
        db 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1
        db 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2
        db 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1
        db 0, 2, 0, 2, 0, 2, 0, 2, 0, 2, 0, 2
        db 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2, 1
