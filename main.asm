org 0x100

[map all game.map]

        Level_Width equ 11
        Level_Height equ 11

        Tile_Width equ 16
        Tile_Height equ 16

        Explosion_Duration equ 30
        Bomb_Ticks equ 90
        Invincibility_Time equ 255

section code

start:                          ; game entry point
        mov bp, sp
        sub sp, 0xa
.a0 equ -0xa

        mov ax, 0x0013          ; switch graphics to 320 x 200 256-color mode
        int 0x10

        call kb_init

        call load_sprites
.loop:
        call wait_for_retrace
        call copy_buffer
        call clear_screen

        call draw_tilemap

        mov word [bp + .a0], player1 ; *player
        mov word [bp + .a0 + 2], key_player1 ; *controls
        call update_player

        mov word [bp + .a0], player2 ; *player
        mov word [bp + .a0 + 2], key_player2 ; *controls
        call update_player

        test byte [player1 + player.invtime], 0x8 ; blink every 8 ticks when invincible
        jnz .p1drawskip
        mov word [bp + .a0], player1 ; sprite
        call draw_sprite
.p1drawskip:

        test byte [player2 + player.invtime], 0x8
        jnz .p2drawskip
        mov word [bp + .a0], player2 ; sprite
        call draw_sprite
.p2drawskip:

        mov word [bp + .a0], player1 ; player
        mov byte [bp + .a0 + 2], 0   ; y
        call draw_player_stats

        mov word [bp + .a0], player2 ; player
        mov byte [bp + .a0 + 2], 4   ; y
        call draw_player_stats

        call draw_explosion_tiles

        call update_explosion_tiles

        call draw_bombs

        call update_bombs

        cmp byte [player1 + player.lives], 0 ; check for victory
        je .player2_won

        cmp byte [player2 + player.lives], 0
        je .player1_won

        jmp .loop

.player1_won:
        mov bx, player1_winmsg
        jmp .show_win_msg
.player2_won:
        mov bx, player2_winmsg
.show_win_msg:

        push bp
        push es
        mov ax, ds
        mov es, ax
        mov bp, bx              ; string pointer
        mov ax, 0x1301          ; write string, move cursor, attribute in bl
        mov bx, 0x000c          ; page 0, light red on black background
        mov cx, winmsg.length
        mov dx, 0x0a05          ; coordinates
        int 0x10
        pop es
        pop bp

.endloop1:
        cmp byte [key_space], 0 ; wait until space is released...
        jne .endloop1
.endloop2:
        cmp byte [key_space], 0 ; ...and then pressed again
        je .endloop2

        mov ax, 0x0003          ; set the video mode back to default text mode
        int 0x10

        xor ax, ax
        mov es, ax

        mov ax, [original_kbint] ; restore the original keyboard interrupt handler
        mov [es:9 * 4], ax
        mov ax, [original_kbint + 2]
        mov [es:9 * 4 + 2], ax

        xor ax, ax              ; Finish program
        int 0x21

player1_winmsg:
        db "Player 1 won!"
        winmsg.length equ $ - player1_winmsg
player2_winmsg:
        db "Player 2 won!"

;; Update the player based on inputs and other game state
update_player:                  ; (*player, *controls)
        push bp
        mov bp, sp
        sub sp, 6
.player equ 4
.controls equ 6
.dir equ -2
.a0 equ -6

        mov bx, [bp + .player]

        cmp byte [bx + sprite.dir], 0 ; accept input only when not moving already
        jnz .controlskip

        xor dx, dx

        mov bx, [bp + .controls]

        cmp byte [bx + key.left], 0
        jz .lskip
        mov dl, Dir_Left
.lskip: cmp byte [bx + key.right], 0
        jz .rskip
        mov dl, Dir_Right
.rskip: cmp byte [bx + key.up], 0
        jz .uskip
        mov dl, Dir_Up
.uskip: cmp byte [bx + key.down], 0
        jz .dskip
        mov dl, Dir_Down
.dskip:
        test dl, dl
        jz .controlskip         ; don't do anything when no control key is pressed

        mov [bp + .dir], dl

        mov bx, [bp + .player]

        mov al, [bx + sprite.x]
        mov [bp + .a0], al      ; x
        mov al, [bx + sprite.y]
        mov [bp + .a0 + 1], al  ; y
        mov [bp + .a0 + 2], dl  ; dir
        call can_enter

        test ax, ax
        jz .controlskip         ; don't do anything, if the destination tile can't be entered

        mov bx, [bp + .player]
        mov dl, [bp + .dir]
        mov [bx + sprite.dir], dl

.controlskip:

        mov bx, [bp + .player]

        cmp byte [bx + sprite.dir], Dir_None
        je .none

        inc byte [bx + sprite.t] ; update move animation
        cmp byte [bx + sprite.t], Tile_Width
        jne .none

        ; animation done, update position
        mov byte [bx + sprite.t], 0
        movzx si, byte [bx + sprite.dir]
        mov byte [bx + sprite.dir], 0
        shl si, 1
        mov ax, [.lut + si]
        jmp ax
.lut:   dw .none, .left, .up, .right, .down
.left:  dec byte [bx + sprite.x]
        jmp .none
.up:    dec byte [bx + sprite.y]
        jmp .none
.right: inc byte [bx + sprite.x]
        jmp .none
.down:  inc byte [bx + sprite.y]
        jmp .none
.none:

        mov bx, [bp + .controls]
        cmp byte [bx + key.place], 0 ; place bomb if the key is pressed...
        jz .bombskip

        mov bx, [bp + .player]
        cmp byte [bx + player.bombsrem], 0 ; ...and the player has a bomb to place
        je .bombskip

        dec byte [bx + player.bombsrem]

        mov al, [bx + sprite.x]
        mov [bp + .a0], al      ; x
        mov al, [bx + sprite.y]
        mov [bp + .a0 + 1], al  ; y
        mov [bp + .a0 + 2], bx  ; player pointer
        call place_bomb

.bombskip:

        mov bx, [bp + .player]
        mov al, [bx + sprite.x]
        mov [bp + .a0], al      ; x
        mov al, [bx + sprite.y]
        mov [bp + .a0 + 1], al  ; y
        call is_explosion_tile

        mov bx, [bp + .player]
        test ax, ax
        jz .hurtskip

        cmp byte [bx + player.lives], 0
        je .hurtskip
        cmp byte [bx + player.invtime], 0
        jne .hurtskip

        dec byte [bx + player.lives]
        mov byte [bx + player.invtime], Invincibility_Time

.hurtskip:
        cmp byte [bx + player.invtime], 0
        je .invskip

        dec byte [bx + player.invtime] ; update player invincibility state
.invskip:

        mov sp, bp
        pop bp
        ret

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

        ; find coordinates after move
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
        ; test for going out of the level
        cmp byte [bp + .xn], 0
        jl .no
        cmp byte [bp + .xn], Level_Width
        jge .no
        cmp byte [bp + .yn], 0
        jl .no
        cmp byte [bp + .yn], Level_Height
        jge .no

        ; find the address of the destination tile
        movzx ax, byte [bp + .yn]
        xor dx, dx
        mov bx, Level_Width
        mul bx
        mov si, ax
        movzx ax, byte [bp + .xn]
        add si, ax

        ; check if it's passable
        movzx bx, byte [tile_map + si]
        shl bx, 1
        mov bx, [tiles + bx]
        mov al, [bx + tile.passable]

        test al, al
        jz .no

        ; check if there's a bomb placed there
        mov al, [bp + .xn]
        mov ah, [bp + .yn]

        mov bx, bombs
        mov cx, Max_Bomb_Count
.bombloop:
        cmp word [bx + sprite.sprite], 0
        je .bombcont

        cmp [bx + sprite.x], al
        jne .bombcont

        cmp [bx + sprite.y], ah
        je .no

.bombcont:
        add bx, bomb.size
        loop .bombloop

        mov ax, 1
        jmp .exit
.no:    xor ax, ax
.exit:  mov dx, [bp + .dx]
        mov sp, bp
        pop bp
        ret

;; Place a bomb at given position
place_bomb:                     ; (x, y, player)
        push bp
        mov bp, sp
.x equ 4
.y equ 5
.player equ 6
        mov bx, bombs
        mov cx, Max_Bomb_Count
.loop:  cmp word [bx + sprite.sprite], 0
        je .found

        add bx, bomb.size
        loop .loop

        mov sp, bp
        pop bp
        ret

        ; a free slot in bombs array found
.found: mov word [bx + sprite.sprite], sprite_bomb
        mov al, [bp + .x]
        mov [bx + sprite.x], al
        mov al, [bp + .y]
        mov [bx + sprite.y], al
        mov byte [bx + sprite.dir], Dir_None
        mov byte [bx + sprite.t], 0
        mov byte [bx + bomb.ticks], Bomb_Ticks
        mov di, [bp + .player]
        mov [bx + bomb.player], di
        mov al, [di + player.range]
        mov [bx + bomb.range], al

        mov sp, bp
        pop bp
        ret

;; Draw information about player (at the moment just health)
draw_player_stats:              ; (*player, y)
        push bp
        mov bp, sp
        sub sp, sprite.size + 6
.player equ 4
.y equ 6
.i equ -2
.ds equ -4
.sprite equ -sprite.size - 4
.a0 equ -sprite.size - 6

        mov ax, ds
        mov es, ax
        mov [bp + .ds], ax      ; save ds
        mov ax, ss
        mov ds, ax

        ; initialize the sprite struct allocated on stack
        mov word [bp + .sprite + sprite.sprite], heart
        mov byte [bp + .sprite + sprite.dir], 0
        mov al, [bp + .y]
        mov [bp + .sprite + sprite.y], al
        mov byte [bp + .sprite + sprite.x], Level_Width + 2

        mov bx, [bp + .player]
        mov al, [es:bx + player.lives]
        mov [bp + .i], al

.loop:  cmp byte [bp + .i], 0
        je .exit

        dec byte [bp + .i]
        lea ax, [bp + .sprite]
        mov [bp + .a0], ax      ; sprite
        call draw_sprite

        inc byte [bp + .sprite + sprite.x]
        jmp .loop

.exit:  mov ax, [bp + .ds]
        mov ds, ax              ; restore ds

        mov sp, bp
        pop bp
        ret

;; Update all bombs
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
        jz .continue            ; don't do anything if there's no bomb stored there

        dec byte [bx + bomb.ticks]
        jnz .continue           ; if the timer hasn't reached 0, we're done

        mov si, [bx + bomb.player]
        inc byte [si + player.bombsrem] ; let the player place bombs again

        mov word [bx + sprite.sprite], 0 ; mark the spot as unused
        mov al, [bx + sprite.x]
        mov [bp + .a0], al      ; x
        mov al, [bx + sprite.y]
        mov [bp + .a0 + 1], al  ; y
        mov al, [bx + bomb.range]
        mov [bp + .a0 + 2], al  ; range
        call explode

.continue:
        add word [bp + .ptr], bomb.size
        dec byte [bp + .i]
        jnz .loop

        mov sp, bp
        pop bp
        ret

;; Make an explosion at the given point with given range
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

        ; cast an explosion ray in each of four directions
.loop:  mov al, [bp + .x]
        mov [bp + .a0], al      ; x
        mov al, [bp + .y]
        mov [bp + .a0 + 1], al  ; y
        mov al, [bp + .range]
        mov [bp + .a0 + 2], al  ; range
        mov al, [bp + .d]
        mov [bp + .a0 + 3], al  ; dir
        call explode_ray

        inc byte [bp + .d]
        cmp byte [bp + .d], 4
        jbe .loop

        mov sp, bp
        pop bp
        ret

;; Cast a straight ray of explosion in given direction
explode_ray:                    ; (x, y, range, dir)
        push bp
        mov bp, sp
        sub sp, 4
.x equ 4
.y equ 5
.range equ 6
.dir equ 7

        movzx cx, byte [bp + .range]

.loop:
        ; step in given direction and check for level boundary
        movzx bx, byte [bp + .dir]
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
        ; calculate map tile address
        movzx ax, byte [bp + .y]
        mov bl, Level_Width
        mul bl
        add al, [bp + .x]
        movzx bx, al

        ; check if tile is destructible
        movzx si, byte [tile_map + bx]
        shl si, 1
        mov si, [tiles + si]
        mov al, [si + tile.destructible]

        test al, al
        jz .break

        mov byte [tile_map + bx], 0 ; destroy tile
        mov byte [explosion_tiles + bx], Explosion_Duration ; set the tile on fire

        loop .loop
.break:
        mov sp, bp
        pop bp
        ret

;; Update explosion timers
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

        player.bombsrem equ 6
        player.range equ 7
        player.lives equ 8
        player.invtime equ 9
        player.size equ 10

player1:
        dw player1_sprite
        db 0, 0                 ; x, y
        db 0, 0                 ; dir, t
        db 1, 1, 3, 0           ; bombsrem, range, lives, invtime

player2:
        dw player2_sprite
        db Level_Width - 1      ; x
        db Level_Height - 1     ; y
        db 0, 0                 ; dir, t
        db 1, 1, 3, 0           ; bombsrem, range, lives, invtime

        bomb.ticks equ 6
        bomb.range equ 7
        bomb.player equ 8
        bomb.size equ 10

        Max_Bomb_Count equ 16

bombs:  times Max_Bomb_Count * bomb.size db 0


tile_block:
        db 0                    ; passable
        db 0                    ; destructible
        times Tile_Width * Tile_Height db 0

tile_brick:
        db 0, 1                 ; passable, destructible
        times Tile_Width * Tile_Height db 0

tile_ground:
        db 1, 1                 ; passable, destructible
        times Tile_Width * Tile_Height db 0

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
