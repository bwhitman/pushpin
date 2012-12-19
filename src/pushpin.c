#include <gb.h>
#include <cgb.h>
#include "dsperado.c"
#include "dsperado.h"
#include "pp2frontmap.c"
#include "pp2front.c"
#include "pp2front.h"

#define OFF	0
#define ON  1

extern unsigned char channel;
extern unsigned char offset;
extern unsigned char program;


//extern unsigned char selchannel;
unsigned char programs[4];

UBYTE key_flag;

UWORD dsppalette[] = {
				tileDataS0P0C0,tileDataS0P0C1,tileDataS0P0C2,tileDataS0P0C3,
			    tileDataS0P1C0,tileDataS0P1C1,tileDataS0P1C2,tileDataS0P1C3,
			    tileDataS0P2C0,tileDataS0P2C1,tileDataS0P2C2,tileDataS0P2C3,
                      tileDataS0P3C0,tileDataS0P3C1,tileDataS0P3C2,tileDataS0P3C3,
                      tileDataS0P4C0,tileDataS0P4C1,tileDataS0P4C2,tileDataS0P4C3,
                      tileDataS0P5C0,tileDataS0P5C1,tileDataS0P5C2,tileDataS0P5C3,
                      tileDataS0P6C0,tileDataS0P6C1,tileDataS0P6C2,tileDataS0P6C3,
                      tileDataS0P7C0,tileDataS0P7C1,tileDataS0P7C2,tileDataS0P7C3};




unsigned char msg_clear[] = {212,212,212,212,212,212,212,212,212,212,212,212,212,212,212,212,212};
unsigned char clear_pal[] = {6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6,  6  };

unsigned char hardmap[] = {211};
unsigned char hardoffmap[] = {212};


void draw_number(UBYTE number, UBYTE x, UBYTE y) {
	UBYTE temp;
	unsigned char nummap[3];

	nummap[0]=(number / 100) + 201;
	temp = number / 10;
	if(temp>9) temp = temp  % 10;
	nummap[1]=temp+201;
	if(number>9) { nummap[2]=(number % 10)+201; } else { nummap[2]=number+201; }

	set_bkg_tiles( x, y, 3, 1, nummap);
}


UBYTE getkey()
{

	UBYTE inkey;
	inkey = joypad();
	if( key_flag == OFF ) {
		if( inkey ) {
      		key_flag = ON;
		}
	} else {
		if( !inkey ) {
			key_flag = OFF;
		}
	inkey = 0;
	}
	return( inkey );
}

void cls()
{
	UBYTE y;
	for( y=0; y<18; y++ ) {
	//	set_bkg_tiles( 0, y, 20, 1, msg_clear );
	}
}

void set_program0() {
	set_bkg_tiles(16,14+0,1,1,hardoffmap);
	draw_number(program, 17, 14+0);
	//if(program<32) set_bkg_tiles(16,14+1,1,1,hardmap);
}


void set_program1() {
	set_bkg_tiles(16,14+1,1,1,hardoffmap);
	draw_number(program, 17, 14+1);
	//if(program<32) set_bkg_tiles(16,14+1,1,1,hardmap);
}


void set_program2() {
	set_bkg_tiles(16,14+2,1,1,hardoffmap);
	draw_number(program, 17, 14+2);
	//if(program<32) set_bkg_tiles(16,14+2,1,1,hardmap);
}


void set_program3() {
	set_bkg_tiles(16,14+3,1,1,hardoffmap);
	draw_number(program, 17, 14+3);
	//if(program<32) set_bkg_tiles(16,14+2,1,1,hardmap);
}


main()
{
	UBYTE key;
//	selchannel=0;
	programs[0]=0;programs[1]=0;programs[2]=0;programs[3]=0;

	offset=0;

	// load palette sets
	set_bkg_palette( 0, 7, &dsppalette[0] );

	// load in tiles
	set_bkg_data(0,214,tileData);
	SHOW_BKG;
	DISPLAY_ON;

	VBK_REG = 1;

	// set palettes per tile
	set_bkg_tiles( 0,0,   20,18, mapAttr);
	VBK_REG = 0;

	// set actual tiles
	set_bkg_tiles( 0,0, 20,18, mapData);


	key = 0;
      while(key != J_START) {
      	key = getkey();
	      if ( (key & J_DOWN)&&(offset >  0) ) offset --;
      	if ( (key & J_UP)&&(offset < 12) ) offset ++;
		draw_number(offset+1,17,14);
		draw_number(offset+2,17,15);
		draw_number(offset+3,17,16);
		draw_number(offset+4,17,17);
      }

	VBK_REG = 1;



	VBK_REG=1;
	set_bkg_tiles(0,14,17,1,clear_pal);
	set_bkg_tiles(0,15,17,1,clear_pal);
	set_bkg_tiles(0,16,17,1,clear_pal);
	set_bkg_tiles(0,17,17,1,clear_pal);
	VBK_REG=0;
	set_bkg_tiles(0,14,17,1,msg_clear);
	set_bkg_tiles(0,15,17,1,msg_clear);
	set_bkg_tiles(0,16,17,1,msg_clear);
	set_bkg_tiles(0,17,17,1,msg_clear);

	draw_number(0,17,14);
	draw_number(0,17,15);
	draw_number(0,17,16);
	draw_number(0,17,17);

	set_bkg_tiles(16,14,1,1,hardmap);
	set_bkg_tiles(16,15,1,1,hardmap);
	set_bkg_tiles(16,16,1,1,hardmap);
	set_bkg_tiles(16,17,1,1,hardmap);

	// Go onto pushpin proper
	midi_server();

	return(0);
}

