/*

cc65 Abadia del crimen

garacilb@gmail.com 27/09/2016 (Spain)

*/

#include <conio.h>
#include <stdio.h>
#include <stdlib.h>
#include <6502.h>
#include <peekpoke.h>
#include <string.h>

#include "manuscrito.h"
#include "io.h"

int main(void)
{
	FILE* fp;
	unsigned int k;
	unsigned char *buffer;
#if defined(__CBM510__)	
	unsigned int s;
#endif

	bgcolor(0);
	bordercolor(0);
    textcolor(1);
	clrscr();
	puts("Loading");

	fp = fopen("abadia.koa", "rb");
#if defined(__CBM510__)
	fread((unsigned char*) VIC_MEM, 1, 8000, fp);
	fread((unsigned char*) VIC_SCR, 1, 1000, fp);
	buffer = malloc(1000);
	fread((unsigned char*)  buffer, 1, 1000, fp);
	fclose(fp);
	for (s = 0; s < 1000; s++) {
		pokebsys(VIC_COL + s, buffer[s]);
	}
  free(buffer);	
#else
	buffer = malloc(10000);
	fread((unsigned char*) buffer       , 1, 8000, fp);
	fread((unsigned char*) buffer + 8000, 1, 1000, fp);
	fread((unsigned char*) buffer + 9000, 1, 1000, fp);
	fclose(fp);
	SEI();
	POKE(0x0001, 0x32); // Only RAM & KERNAL I/O disabled
	memcpy((unsigned char*) VIC_MEM, (unsigned char*) &buffer[0]   , 8000);
	memcpy((unsigned char*) VIC_SCR, (unsigned char*) &buffer[8000], 1000);
	POKE(0x0001, 0x36); // RAM, KERNAL & I/O
	CLI();
	memcpy((unsigned char*) VIC_COL, (unsigned char*) &buffer[9000], 1000);
	free(buffer);
#endif

	screenbitmapmulticolor();

	while(1) {
		k = (int)cgetc();
		if (k)
			break;
	}

	manusintro();

	while(1) {
		k = (int)cgetc();
		if (k)
			break;
	}
	//screenbitmap();
  return EXIT_SUCCESS;
}
