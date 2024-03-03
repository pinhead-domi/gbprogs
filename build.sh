mkdir -p build

rgbasm main.gameboy.asm -o ./build/main.asm.o -Wall -l
rgblink -o output.gb --map ./build/output.map ./build/main.asm.o
rgbfix -v output.gb -p 0xff