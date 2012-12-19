cls

..\..\bin\lcc -c -o midi.o midi232.s
..\..\bin\lcc -c -o pushpin.o pushpin.c
..\..\bin\lcc -Wl-m -Wl-yp0x143=0x80 -o pushpin.gb pushpin.o midi.o
@del *.o
@del *.lst
@del *.map
F:\gbdev\xchange\gbt14 -l pushpin.gb
