/*
*/

#include <stdio.h>
#include <stdarg.h>

FILE *outfile;

static void inline _cdecl OUT( char *s, ...)
{
	va_list vargs;

	va_start( vargs, s );
	vfprintf( outfile, s, vargs );
	va_end( vargs );
}


void genea020(void)
{
	unsigned int dp;

	OUT("    switch( (uae_u8)dp ) {\n" );

	for( dp=0; dp<256; dp++ ) {
		if( dp & 8 ) continue;

		OUT("      case 0x%02x:\n", dp );
		OUT("      case 0x%02x:\n", dp | 8 );

		if (dp & 0x80) OUT("        base = 0;\n");
		if (dp & 0x40) OUT("        regd = 0;\n");

		if ((dp & 0x30) == 0x20) OUT("        base += (uae_s32)(uae_s16)next_iword();\n");
		else if ((dp & 0x30) == 0x30) OUT("        base += next_ilong();\n");

		if ((dp & 0x3) == 0x2) OUT("        outer = (uae_s32)(uae_s16)next_iword();\n");
		else if ((dp & 0x3) == 0x3) OUT("        outer = next_ilong();\n");
		else OUT("        outer = 0;\n");

		if (dp & 0x4) {
			if (dp & 0x3) OUT("        base = get_long (base);\n");
			OUT("        return base + regd + outer;\n");
		} else {
			OUT("        base += regd;\n");
			if (dp & 0x3) OUT("        base = get_long (base);\n");
			OUT("        return base + outer;\n");
		}
	}

	OUT("      default: return 0; // just to avoid compiler warnings\n", dp );

	OUT("    }\n" );
}

int main()
{
	outfile = fopen( "ea020.cpp", "w" );
	if(outfile) {
		genea020();
		fclose(outfile);
	}
	return 0;
}
