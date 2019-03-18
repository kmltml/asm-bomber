game.com: main.asm graphics.asm keyboard.asm bmp.asm
	nasm -fbin -o"game.com" main.asm

run:	game.com
	dosbox game.com

debug:	game.com
	dosbox-debug game.com
