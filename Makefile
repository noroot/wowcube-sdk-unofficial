
CUBES=8

build:
	pawncc pipes.pwn -ogame


amx:
	for i in 0 1 2 3 4 5 6 7 8 ; do \
		pawnrun game.amx $$i &; \
	done		

emu:
	processing-java --sketch=./wowcube --run 

