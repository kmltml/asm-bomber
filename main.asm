org 0x100

[map all game.map]

        Level_Width equ 11
        Level_Height equ 11

        Tile_Width equ 16
        Tile_Height equ 16

        Explosion_Duration equ 30
        Bomb_Ticks equ 90

section code

start:
        mov bp, sp
        sub sp, 0xa
.a0 equ -0xa
.x equ 0
.y equ 2
        mov word [bp + .x], 0
        mov word [bp + .y], 0

        mov ax, 0x0013
        int 0x10

        call kb_init

        call load_sprites
.loop:
        call wait_for_retrace
        call copy_buffer
        call clear_screen

        call draw_tilemap

        cmp byte [sprites + sprite.dir], 0
        jnz .controlskip

        xor dx, dx

        cmp byte [key_a], 0
        jz .askip
        mov dl, Dir_Left
.askip: cmp byte [key_d], 0
        jz .dskip
        mov dl, Dir_Right
.dskip: cmp byte [key_w], 0
        jz .wskip
        mov dl, Dir_Up
.wskip: cmp byte [key_s], 0
        jz .sskip
        mov dl, Dir_Down
.sskip:

        test dl, dl
        jz .controlskip

        mov al, [sprites + sprite.x]
        mov [bp + .a0], al
        mov al, [sprites + sprite.y]
        mov [bp + .a0 + 1], al
        mov [bp + .a0 + 2], dl
        call can_enter

        test ax, ax
        jz .controlskip

        mov [sprites + sprite.dir], dl

.controlskip:

        ; update sprite
        cmp byte [sprites + sprite.dir], Dir_None
        je .updateskip

        inc byte [sprites + sprite.t]
        cmp byte [sprites + sprite.t], Tile_Width
        jne .updateskip

        mov byte [sprites + sprite.t], 0
        movzx si, byte [sprites + sprite.dir]
        mov byte [sprites + sprite.dir], 0
        shl si, 1
        mov ax, [.lut + si]
        jmp ax
.lut:   dw .none, .left, .up, .right, .down
.left:  dec byte [sprites + sprite.x]
        jmp .none
.up:    dec byte [sprites + sprite.y]
        jmp .none
.right: inc byte [sprites + sprite.x]
        jmp .none
.down:  inc byte [sprites + sprite.y]
        jmp .none
.none:


.updateskip:
        mov word [bp + .a0], sprites
        call draw_sprite

        call draw_explosion_tiles

        call update_explosion_tiles

        call draw_bombs

        call update_bombs

        cmp byte [key_space], 0
        jz .spaceskip

        mov al, [sprites + sprite.x]
        mov [bp + .a0], al
        mov al, [sprites + sprite.y]
        mov [bp + .a0 + 1], al
        call place_bomb

.spaceskip:

        jmp .loop

can_enter:                      ; (byte x, byte y, dir): bool
.x equ 4
.y equ 5
.dir equ 6
        push bp
        mov bp, sp
        sub sp, 4
.xn equ -1
.yn equ -2
.dx equ -4
        mov [bp + .dx], dx

        mov al, [bp + .x]
        mov [bp + .xn], al
        mov al, [bp + .y]
        mov [bp + .yn], al

        movzx si, [bp + .dir]
        shl si, 1
        mov ax, [.lut + si]
        jmp ax
.lut:   dw .none, .left, .up, .right, .down
.left:  dec byte [bp + .xn]
        jmp .none
.right: inc byte [bp + .xn]
        jmp .none
.up:    dec byte [bp + .yn]
        jmp .none
.down:  inc byte [bp + .yn]
        jmp .none
.none:
        cmp byte [bp + .xn], 0
        jl .no
        cmp byte [bp + .xn], Level_Width
        jge .no
        cmp byte [bp + .yn], 0
        jl .no
        cmp byte [bp + .yn], Level_Height
        jge .no

        movzx ax, byte [bp + .yn]
        xor dx, dx
        mov bx, Level_Width
        mul bx
        mov si, ax
        movzx ax, byte [bp + .xn]
        add si, ax

        movzx bx, byte [tile_map + si]
        shl bx, 1
        mov bx, [tiles + bx]
        mov al, [bx + tile.passable]

        test al, al
        jz .no

        mov ax, 1
        jmp .exit
.no:    xor ax, ax
.exit:  mov dx, [bp + .dx]
        mov sp, bp
        pop bp
        ret

place_bomb:                     ; (x, y)
        push bp
        mov bp, sp
.x equ 4
.y equ 5
        mov bx, bombs
        mov cx, Max_Bomb_Count
.loop:  cmp word [bx + sprite.sprite], 0
        je .found

        add bx, bomb.size
        loop .loop

        mov sp, bp
        pop bp
        ret

.found: mov word [bx + sprite.sprite], sprite_bomb
        mov al, [bp + .x]
        mov [bx + sprite.x], al
        mov al, [bp + .y]
        mov [bx + sprite.y], al
        mov byte [bx + sprite.dir], Dir_None
        mov byte [bx + sprite.t], 0
        mov byte [bx + bomb.ticks], Bomb_Ticks

        mov sp, bp
        pop bp
        ret

update_bombs:                   ; ()
        push bp
        mov bp, sp
        sub sp, 6
.i equ -1
.ptr equ -3
.a0 equ -6

        mov byte [bp + .i], Max_Bomb_Count
        mov word [bp + .ptr], bombs

.loop:  mov bx, [bp + .ptr]
        cmp word [bx], 0
        jz .continue

        dec word [bx + bomb.ticks]
        jnz .continue

        mov word [bx + sprite.sprite], 0
        mov al, [bx + sprite.x]
        mov [bp + .a0], al
        mov al, [bx + sprite.y]
        mov [bp + .a0 + 1], al
        mov byte [bp + .a0 + 2], 1
        call explode

.continue:
        add word [bp + .ptr], bomb.size
        dec byte [bp + .i]
        jnz .loop

        mov sp, bp
        pop bp
        ret

explode:                        ; (x, y, range)
        push bp
        mov bp, sp
        sub sp, 5
.x equ 4
.y equ 5
.range equ 6
.d equ -1
.a0 equ -5

        mov byte [bp + .d], 1

        mov al, [bp + .y]
        mov bl, Level_Width
        mul bl
        add al, [bp + .x]
        mov bx, ax
        mov byte [explosion_tiles + bx], Explosion_Duration

.loop:  mov al, [bp + .x]
        mov [bp + .a0], al
        mov al, [bp + .y]
        mov [bp + .a0 + 1], al
        mov al, [bp + .range]
        mov [bp + .a0 + 2], al
        mov al, [bp + .d]
        mov [bp + .a0 + 3], al
        call explode_ray

        inc byte [bp + .d]
        cmp byte [bp + .d], 4
        jbe .loop

        mov sp, bp
        pop bp
        ret

explode_ray:                    ; (x, y, range, dir)
        push bp
        mov bp, sp
        sub sp, 4
.x equ 4
.y equ 5
.range equ 6
.dir equ 7

        movzx cx, byte [bp + .range]

.loop:  movzx bx, byte [bp + .dir]
        shl bx, 1
        mov ax, [cs:.lut + bx]
        jmp ax
.lut:   dw .none, .left, .up, .right, .down
.left:  dec byte [bp + .x]
        js .break
        jmp .none
.right: inc byte [bp + .x]
        cmp byte [bp + .x], Level_Width
        jae .break
        jmp .none
.up:    dec byte [bp + .y]
        js .break
        jmp .none
.down:  inc byte [bp + .y]
        cmp byte [bp + .y], Level_Height
        jae .break
        jmp .none
.none:
        movzx ax, byte [bp + .y]
        mov bl, Level_Width
        mul bl
        add al, [bp + .x]
        movzx bx, al

        movzx si, byte [tile_map + bx]
        shl si, 1
        mov si, [tiles + si]
        mov al, [si + tile.destructible]

        test al, al
        jz .break

        mov byte [tile_map + bx], 0
        mov byte [explosion_tiles + bx], Explosion_Duration

        loop .loop
.break:
        mov sp, bp
        pop bp
        ret

update_explosion_tiles:         ; ()
        mov cx, Level_Width * Level_Height
.loop:  mov bx, cx
        cmp byte [explosion_tiles + bx - 1], 0
        je .skip

        dec byte [explosion_tiles + bx - 1]

.skip:  loop .loop

        ret

%include "graphics.asm"
%include "keyboard.asm"
%include "bmp.asm"

        sprite.sprite equ 0
        sprite.x equ 2
        sprite.y equ 3
        sprite.dir equ 4
        sprite.t equ 5
        sprite.size equ 6

        Dir_None equ 0
        Dir_Left equ 1
        Dir_Up equ 2
        Dir_Right equ 3
        Dir_Down equ 4

sprites:
        dw sprite_bomb
        db 0, 0                 ; x, y
        db 0, 0                 ; dir, t

        bomb.ticks equ 6
        bomb.size equ 8

        Max_Bomb_Count equ 16

bombs:  times Max_Bomb_Count * bomb.size db 0


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
        db 1, 1                 ; passable, destructible
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

sprite_bomb: times 16 * 16 db 0

tiles:
        dw tile_ground, tile_block, tile_brick

tile_map:
        db 0, 0, 0, 2, 1, 2, 1, 2, 0, 0, 0
        db 0, 1, 2, 1, 2, 1, 2, 1, 2, 1, 0
        db 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0
        db 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2
        db 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1
        db 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2
        db 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1
        db 2, 1, 2, 1, 2, 1, 2, 1, 2, 1, 2
        db 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0
        db 0, 1, 2, 1, 2, 1, 2, 1, 2, 1, 0
        db 0, 0, 0, 2, 1, 2, 1, 2, 0, 0, 0

explosion_tiles:
        times Level_Width * Level_Height db 0
