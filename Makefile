all: TstMem

TstMem: TstMem.asm
	nasm TstMem.asm -o TstMem.vfd
