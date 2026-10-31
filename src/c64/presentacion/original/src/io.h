/*

cc65 Abadia del crimen

garacilb@gmain.com 27/09/2016 (Spain)

*/

#if defined(__CBM510__)
#define VIC_MEM 0xc000
#define VIC_COL 0xd400
#define VIC_SCR 0xe000
#else
#define VIC_MEM 0xC000
#define VIC_COL 0xd800
#define VIC_SCR 0xe000
#endif

unsigned char __fastcall__ bytemirror(unsigned char c);
void __fastcall__ screenoff(void);
void __fastcall__ screenon(void);
void __fastcall__ screenbitmap(void);
void __fastcall__ screenbitmapmulticolor(void);
void screenclean(unsigned char b, unsigned char s, unsigned char c);
unsigned int xytoscreen(unsigned int x, unsigned int y);