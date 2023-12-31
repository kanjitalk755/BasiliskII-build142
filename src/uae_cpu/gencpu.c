/*
 * UAE - The Un*x Amiga Emulator
 *
 * MC68000 emulation generator
 *
 * This is a fairly stupid program that generates a lot of case labels that
 * can be #included in a switch statement.
 * As an alternative, it can generate functions that handle specific
 * MC68000 instructions, plus a prototype header file and a function pointer
 * array to look up the function for an opcode.
 * Error checking is bad, an illegal table68k file will cause the program to
 * call abort().
 * The generated code is sometimes sub-optimal, an optimizing compiler should
 * take care of this.
 *
 * Copyright 1995, 1996 Bernd Schmidt
 */

#include <ctype.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "sysdeps.h"
#include "readcpu.h"

#if defined(SPARC_V8_ASSEMBLY) || defined(SPARC_V9_ASSEMBLY)
#define SPARC_ASSEMBLY 0
#endif

#define BOOL_TYPE "int"

static FILE *headerfile;
static FILE *stblfile;

static int using_prefetch;
static int using_exception_3;
static int cpu_level;

/* For the current opcode, the next lower level that will have different code.
 * Initialized to -1 for each opcode. If it remains unchanged, indicates we
 * are done with that opcode.  */
static int next_cpu_level;

static int *opcode_map;
static int *opcode_next_clev;
static int *opcode_last_postfix;
static unsigned long *counts;

static void read_counts (void)
{
    FILE *file;
    unsigned long opcode, count, total;
    char name[20];
    int nr = 0;
    memset (counts, 0, 65536 * sizeof *counts);

    file = fopen ("frequent.68k", "r");
    if (file) {
        fscanf (file, "Total: %lu\r\n", &total);
        while (fscanf (file, "%lx: %lu %s\r\n", &opcode, &count, name) == 3) {
            opcode_next_clev[nr] = 4;
            opcode_last_postfix[nr] = -1;
            opcode_map[nr++] = opcode;
            counts[opcode] = count;
        }
        fclose (file);
    }
    if (nr == nr_cpuop_funcs)
        return;
    for (opcode = 0; opcode < 0x10000; opcode++) {
        if (table68k[opcode].handler == -1 && table68k[opcode].mnemo != i_ILLG
            && counts[opcode] == 0)
        {
            opcode_next_clev[nr] = 4;
            opcode_last_postfix[nr] = -1;
            opcode_map[nr++] = opcode;
            counts[opcode] = count;
        }
    }
    if (nr != nr_cpuop_funcs)
        abort ();
}

static char endlabelstr[80];
static int endlabelno = 0;
static int need_endlabel;

static int n_braces = 0;
static int m68k_pc_offset = 0;
static int insn_n_cycles;

static void start_brace (void)
{
    n_braces++;
    printf ("{");
}

static void close_brace (void)
{
    assert (n_braces > 0);
    n_braces--;
    printf ("}");
}

static void finish_braces (void)
{
    while (n_braces > 0)
        close_brace ();
}

static void pop_braces (int to)
{
    while (n_braces > to)
        close_brace ();
}

static int bit_size (int size)
{
    switch (size) {
     case sz_byte: return 8;
     case sz_word: return 16;
     case sz_long: return 32;
     default: abort ();
    }
    return 0;
}

static const char *bit_mask (int size)
{
    switch (size) {
     case sz_byte: return "0xff";
     case sz_word: return "0xffff";
     case sz_long: return "0xffffffff";
     default: abort ();
    }
    return 0;
}

static const char *gen_nextilong (void)
{
    static char buffer[80];
    int r = m68k_pc_offset;
    m68k_pc_offset += 4;

    insn_n_cycles += 4;

    if (using_prefetch)
        sprintf (buffer, "get_ilong_prefetch(%d)", r);
    else
        sprintf (buffer, "get_ilong(%d)", r);
    return buffer;
}

static const char *gen_nextiword (void)
{
    static char buffer[80];
    int r = m68k_pc_offset;
    m68k_pc_offset += 2;

    insn_n_cycles += 2;

    if (using_prefetch)
        sprintf (buffer, "get_iword_prefetch(%d)", r);
    else
        sprintf (buffer, "get_iword(%d)", r);
    return buffer;
}

static const char *gen_nextibyte (void)
{
    static char buffer[80];
    int r = m68k_pc_offset;
    m68k_pc_offset += 2;

    insn_n_cycles += 2;

    if (using_prefetch)
        sprintf (buffer, "get_ibyte_prefetch(%d)", r);
    else
        sprintf (buffer, "get_ibyte(%d)", r);
    return buffer;
}

static void fill_prefetch_0 (void)
{
    if (using_prefetch)
        printf ("fill_prefetch_0 ();\r\n");
}

static void fill_prefetch_2 (void)
{
    if (using_prefetch)
        printf ("fill_prefetch_2 ();\r\n");
}

static void swap_opcode (void)
{
  printf ("#ifdef HAVE_GET_WORD_UNSWAPPED\r\n");
  printf ("\topcode = ((opcode << 8) & 0xFF00) | ((opcode >> 8) & 0xFF);\r\n");
  printf ("#endif\r\n");
}

static void sync_m68k_pc (void)
{
    if (m68k_pc_offset == 0)
        return;
    printf ("m68k_incpc(%d);\r\n", m68k_pc_offset);
    switch (m68k_pc_offset) {
     case 0:
        /*fprintf (stderr, "refilling prefetch at 0\r\n"); */
        break;
     case 2:
        fill_prefetch_2 ();
        break;
     default:
        fill_prefetch_0 ();
        break;
    }
    m68k_pc_offset = 0;
}

/* getv == 1: fetch data; getv != 0: check for odd address. If movem != 0,
 * the calling routine handles Apdi and Aipi modes. */
static void genamode (amodes mode, char *reg, wordsizes size, char *name, int getv, int movem)
{
    start_brace ();
    switch (mode) {
     case Dreg:
        if (movem)
            abort ();
        if (getv == 1)
            switch (size) {
             case sz_byte:
#ifdef AMIGA
                /* sam: I don't know why gcc.2.7.2.1 produces a code worse */
                /* if it is not done like that: */
                printf ("\tuae_s8 %s = ((uae_u8*)&m68k_dreg(regs, %s))[3];\r\n", name, reg);
#else
                printf ("\tuae_s8 %s = m68k_dreg(regs, %s);\r\n", name, reg);
#endif
                break;
             case sz_word:
#ifdef AMIGA
                printf ("\tuae_s16 %s = ((uae_s16*)&m68k_dreg(regs, %s))[1];\r\n", name, reg);
#else
                printf ("\tuae_s16 %s = m68k_dreg(regs, %s);\r\n", name, reg);
#endif
                break;
             case sz_long:
                printf ("\tuae_s32 %s = m68k_dreg(regs, %s);\r\n", name, reg);
                break;
             default:
                abort ();
            }
        return;
     case Areg:
        if (movem)
            abort ();
        if (getv == 1)
            switch (size) {
             case sz_word:
                printf ("\tuae_s16 %s = m68k_areg(regs, %s);\r\n", name, reg);
                break;
             case sz_long:
                printf ("\tuae_s32 %s = m68k_areg(regs, %s);\r\n", name, reg);
                break;
             default:
                abort ();
            }
        return;
     case Aind:
        printf ("\tuaecptr %sa = m68k_areg(regs, %s);\r\n", name, reg);
        break;
     case Aipi:
        printf ("\tuaecptr %sa = m68k_areg(regs, %s);\r\n", name, reg);
        break;
     case Apdi:
        switch (size) {
         case sz_byte:
            if (movem)
                printf ("\tuaecptr %sa = m68k_areg(regs, %s);\r\n", name, reg);
            else
                printf ("\tuaecptr %sa = m68k_areg(regs, %s) - areg_byteinc[%s];\r\n", name, reg, reg);
            break;
         case sz_word:
            printf ("\tuaecptr %sa = m68k_areg(regs, %s) - %d;\r\n", name, reg, movem ? 0 : 2);
            break;
         case sz_long:
            printf ("\tuaecptr %sa = m68k_areg(regs, %s) - %d;\r\n", name, reg, movem ? 0 : 4);
            break;
         default:
            abort ();
        }
        break;
     case Ad16:
        printf ("\tuaecptr %sa = m68k_areg(regs, %s) + (uae_s32)(uae_s16)%s;\r\n", name, reg, gen_nextiword ());
        break;
     case Ad8r:
        if (cpu_level > 1) {
            if (next_cpu_level < 1)
                next_cpu_level = 1;
            sync_m68k_pc ();
            start_brace ();
            printf ("\tuaecptr %sa = get_disp_ea_020(m68k_areg(regs, %s), next_iword_020());\r\n", name, reg);
        } else
            printf ("\tuaecptr %sa = get_disp_ea_000(m68k_areg(regs, %s), %s);\r\n", name, reg, gen_nextiword ());

        break;
     case PC16:
        printf ("\tuaecptr %sa = m68k_getpc () + %d;\r\n", name, m68k_pc_offset);
        printf ("\t%sa += (uae_s32)(uae_s16)%s;\r\n", name, gen_nextiword ());
        break;
     case PC8r:
        if (cpu_level > 1) {
            if (next_cpu_level < 1)
                next_cpu_level = 1;
            sync_m68k_pc ();
            start_brace ();
            printf ("\tuaecptr tmppc = m68k_getpc();\r\n");
            printf ("\tuaecptr %sa = get_disp_ea_020(tmppc, next_iword_020());\r\n", name);
        } else {
            printf ("\tuaecptr tmppc = m68k_getpc() + %d;\r\n", m68k_pc_offset);
            printf ("\tuaecptr %sa = get_disp_ea_000(tmppc, %s);\r\n", name, gen_nextiword ());
        }

        break;
     case absw:
        printf ("\tuaecptr %sa = (uae_s32)(uae_s16)%s;\r\n", name, gen_nextiword ());
        break;
     case absl:
        printf ("\tuaecptr %sa = %s;\r\n", name, gen_nextilong ());
        break;
     case imm:
        if (getv != 1)
            abort ();
        switch (size) {
         case sz_byte:
            printf ("\tuae_s8 %s = %s;\r\n", name, gen_nextibyte ());
            break;
         case sz_word:
            printf ("\tuae_s16 %s = %s;\r\n", name, gen_nextiword ());
            break;
         case sz_long:
            printf ("\tuae_s32 %s = %s;\r\n", name, gen_nextilong ());
            break;
         default:
            abort ();
        }
        return;
     case imm0:
        if (getv != 1)
            abort ();
        printf ("\tuae_s8 %s = %s;\r\n", name, gen_nextibyte ());
        return;
     case imm1:
        if (getv != 1)
            abort ();
        printf ("\tuae_s16 %s = %s;\r\n", name, gen_nextiword ());
        return;
     case imm2:
        if (getv != 1)
            abort ();
        printf ("\tuae_s32 %s = %s;\r\n", name, gen_nextilong ());
        return;
     case immi:
        if (getv != 1)
            abort ();
        printf ("\tuae_u32 %s = %s;\r\n", name, reg);
        return;
     default:
        abort ();
    }

    /* We get here for all non-reg non-immediate addressing modes to
     * actually fetch the value. */

    if (using_exception_3 && getv != 0 && size != sz_byte) {
        printf ("\tif ((%sa & 1) != 0) {\r\n", name);
        printf ("\t\tlast_fault_for_exception_3 = %sa;\r\n", name);
        printf ("\t\tlast_op_for_exception_3 = opcode;\r\n");
        printf ("\t\tlast_addr_for_exception_3 = m68k_getpc() + %d;\r\n", m68k_pc_offset);
        printf ("\t\tException(3, 0);\r\n");
        printf ("\t\tgoto %s;\r\n", endlabelstr);
        printf ("\t}\r\n");
        need_endlabel = 1;
        start_brace ();
    }

    if (getv == 1) {
        switch (size) {
         case sz_byte: insn_n_cycles += 2; break;
         case sz_word: insn_n_cycles += 2; break;
         case sz_long: insn_n_cycles += 4; break;
         default: abort ();
        }
        start_brace ();
        switch (size) {
         case sz_byte: printf ("\tuae_s8 %s = get_byte(%sa);\r\n", name, name); break;
         case sz_word: printf ("\tuae_s16 %s = get_word(%sa);\r\n", name, name); break;
         case sz_long: printf ("\tuae_s32 %s = get_long(%sa);\r\n", name, name); break;
         default: abort ();
        }
    }

    /* We now might have to fix up the register for pre-dec or post-inc
     * addressing modes. */
    if (!movem)
        switch (mode) {
         case Aipi:
            switch (size) {
             case sz_byte:
                printf ("\tm68k_areg(regs, %s) += areg_byteinc[%s];\r\n", reg, reg);
                break;
             case sz_word:
                printf ("\tm68k_areg(regs, %s) += 2;\r\n", reg);
                break;
             case sz_long:
                printf ("\tm68k_areg(regs, %s) += 4;\r\n", reg);
                break;
             default:
                abort ();
            }
            break;
         case Apdi:
            printf ("\tm68k_areg (regs, %s) = %sa;\r\n", reg, name);
            break;
         default:
            break;
        }
}

static void genastore (char *from, amodes mode, char *reg, wordsizes size, char *to)
{
    switch (mode) {
     case Dreg:
        switch (size) {
         case sz_byte:
#ifdef LITTLE_ENDIAN
            printf ("\t*((uae_u8*)&m68k_dreg(regs, %s)) = (uae_u8)(%s);\r\n", reg, from);
#else
            printf ("\tm68k_dreg(regs, %s) = (m68k_dreg(regs, %s) & ~0xff) | ((%s) & 0xff);\r\n", reg, reg, from);
#endif
            break;
         case sz_word:
#ifdef LITTLE_ENDIAN
            printf ("\t*((uae_u16*)&m68k_dreg(regs, %s)) = (uae_u16)(%s);\r\n", reg, from);
#else
            printf ("\tm68k_dreg(regs, %s) = (m68k_dreg(regs, %s) & ~0xffff) | ((%s) & 0xffff);\r\n", reg, reg, from);
#endif
            break;
         case sz_long:
            printf ("\tm68k_dreg(regs, %s) = (%s);\r\n", reg, from);
            break;
         default:
            abort ();
        }
        break;
     case Areg:
        switch (size) {
         case sz_word:
            fprintf (stderr, "Foo\r\n");
            printf ("\tm68k_areg(regs, %s) = (uae_s32)(uae_s16)(%s);\r\n", reg, from);
            break;
         case sz_long:
            printf ("\tm68k_areg(regs, %s) = (%s);\r\n", reg, from);
            break;
         default:
            abort ();
        }
        break;
     case Aind:
     case Aipi:
     case Apdi:
     case Ad16:
     case Ad8r:
     case absw:
     case absl:
     case PC16:
     case PC8r:
        if (using_prefetch)
            sync_m68k_pc ();
        switch (size) {
         case sz_byte:
            insn_n_cycles += 2;
            printf ("\tput_byte(%sa,%s);\r\n", to, from);
            break;
         case sz_word:
            insn_n_cycles += 2;
            if (cpu_level < 2 && (mode == PC16 || mode == PC8r))
                abort ();
            printf ("\tput_word(%sa,%s);\r\n", to, from);
            break;
         case sz_long:
            insn_n_cycles += 4;
            if (cpu_level < 2 && (mode == PC16 || mode == PC8r))
                abort ();
            printf ("\tput_long(%sa,%s);\r\n", to, from);
            break;
         default:
            abort ();
        }
        break;
     case imm:
     case imm0:
     case imm1:
     case imm2:
     case immi:
        abort ();
        break;
     default:
        abort ();
    }
}

static void genmovemel (uae_u16 opcode)
{
    char getcode[100];
    int size = table68k[opcode].size == sz_long ? 4 : 2;

    if (table68k[opcode].size == sz_long) {
        strcpy (getcode, "get_long(srca)");
    } else {
        strcpy (getcode, "(uae_s32)(uae_s16)get_word(srca)");
    }

    printf ("\tuae_u16 mask = %s;\r\n", gen_nextiword ());
    printf ("\tunsigned int dmask = mask & 0xff, amask = (mask >> 8) & 0xff;\r\n");
    genamode (table68k[opcode].dmode, "dstreg", table68k[opcode].size, "src", 2, 1);
    start_brace ();
    printf ("\twhile (dmask) { m68k_dreg(regs, movem_index1[dmask]) = %s; srca += %d; dmask = movem_next[dmask]; }\r\n",
            getcode, size);
    printf ("\twhile (amask) { m68k_areg(regs, movem_index1[amask]) = %s; srca += %d; amask = movem_next[amask]; }\r\n",
            getcode, size);

    if (table68k[opcode].dmode == Aipi)
        printf ("\tm68k_areg(regs, dstreg) = srca;\r\n");
}

static void genmovemle (uae_u16 opcode)
{
    char putcode[100];
    int size = table68k[opcode].size == sz_long ? 4 : 2;
    if (table68k[opcode].size == sz_long) {
        strcpy (putcode, "put_long(srca,");
    } else {
        strcpy (putcode, "put_word(srca,");
    }

    printf ("\tuae_u16 mask = %s;\r\n", gen_nextiword ());
    genamode (table68k[opcode].dmode, "dstreg", table68k[opcode].size, "src", 2, 1);
    if (using_prefetch)
        sync_m68k_pc ();

    start_brace ();
    if (table68k[opcode].dmode == Apdi) {
        printf ("\tuae_u16 amask = mask & 0xff, dmask = (mask >> 8) & 0xff;\r\n");
        printf ("\twhile (amask) { srca -= %d; %s m68k_areg(regs, movem_index2[amask])); amask = movem_next[amask]; }\r\n",
                size, putcode);
        printf ("\twhile (dmask) { srca -= %d; %s m68k_dreg(regs, movem_index2[dmask])); dmask = movem_next[dmask]; }\r\n",
                size, putcode);
        printf ("\tm68k_areg(regs, dstreg) = srca;\r\n");
    } else {
        printf ("\tuae_u16 dmask = mask & 0xff, amask = (mask >> 8) & 0xff;\r\n");
        printf ("\twhile (dmask) { %s m68k_dreg(regs, movem_index1[dmask])); srca += %d; dmask = movem_next[dmask]; }\r\n",
                putcode, size);
        printf ("\twhile (amask) { %s m68k_areg(regs, movem_index1[amask])); srca += %d; amask = movem_next[amask]; }\r\n",
                putcode, size);
    }
}

static void duplicate_carry (void)
{
    printf ("\tCOPY_CARRY;\r\n");
}

typedef enum {
    flag_logical_noclobber, flag_logical, flag_add, flag_sub, flag_cmp, flag_addx, flag_subx, flag_zn,
    flag_av, flag_sv
} flagtypes;

static void genflags_normal (flagtypes type, wordsizes size, char *value, char *src, char *dst)
{
    char vstr[100], sstr[100], dstr[100];
    char usstr[100], udstr[100];
    char unsstr[100], undstr[100];

    switch (size) {
     case sz_byte:
        strcpy (vstr, "((uae_s8)(");
        strcpy (usstr, "((uae_u8)(");
        break;
     case sz_word:
        strcpy (vstr, "((uae_s16)(");
        strcpy (usstr, "((uae_u16)(");
        break;
     case sz_long:
        strcpy (vstr, "((uae_s32)(");
        strcpy (usstr, "((uae_u32)(");
        break;
     default:
        abort ();
    }
    strcpy (unsstr, usstr);

    strcpy (sstr, vstr);
    strcpy (dstr, vstr);
    strcat (vstr, value);
    strcat (vstr, "))");
    strcat (dstr, dst);
    strcat (dstr, "))");
    strcat (sstr, src);
    strcat (sstr, "))");

    strcpy (udstr, usstr);
    strcat (udstr, dst);
    strcat (udstr, "))");
    strcat (usstr, src);
    strcat (usstr, "))");

    strcpy (undstr, unsstr);
    strcat (unsstr, "-");
    strcat (undstr, "~");
    strcat (undstr, dst);
    strcat (undstr, "))");
    strcat (unsstr, src);
    strcat (unsstr, "))");

    switch (type) {
     case flag_logical_noclobber:
     case flag_logical:
     case flag_zn:
     case flag_av:
     case flag_sv:
     case flag_addx:
     case flag_subx:
        break;

     case flag_add:
        start_brace ();
        printf ("uae_u32 %s = %s + %s;\r\n", value, dstr, sstr);
        break;
     case flag_sub:
     case flag_cmp:
        start_brace ();
        printf ("uae_u32 %s = %s - %s;\r\n", value, dstr, sstr);
        break;
    }

    switch (type) {
     case flag_logical_noclobber:
     case flag_logical:
     case flag_zn:
        break;

     case flag_add:
     case flag_sub:
     case flag_addx:
     case flag_subx:
     case flag_cmp:
     case flag_av:
     case flag_sv:
        start_brace ();
        printf ("\t" BOOL_TYPE " flgs = %s < 0;\r\n", sstr);
        printf ("\t" BOOL_TYPE " flgo = %s < 0;\r\n", dstr);
        printf ("\t" BOOL_TYPE " flgn = %s < 0;\r\n", vstr);
        break;
    }

    switch (type) {
     case flag_logical:
        printf ("\tCLEAR_CZNV;\r\n");
        printf ("\tSET_ZFLG (%s == 0);\r\n", vstr);
        printf ("\tSET_NFLG (%s < 0);\r\n", vstr);
        break;
     case flag_logical_noclobber:
        printf ("\tSET_ZFLG (%s == 0);\r\n", vstr);
        printf ("\tSET_NFLG (%s < 0);\r\n", vstr);
        break;
     case flag_av:
        printf ("\tSET_VFLG ((flgs ^ flgn) & (flgo ^ flgn));\r\n");
        break;
     case flag_sv:
        printf ("\tSET_VFLG ((flgs ^ flgo) & (flgn ^ flgo));\r\n");
        break;
     case flag_zn:
        printf ("\tSET_ZFLG (GET_ZFLG & (%s == 0));\r\n", vstr);
        printf ("\tSET_NFLG (%s < 0);\r\n", vstr);
        break;
     case flag_add:
        printf ("\tSET_ZFLG (%s == 0);\r\n", vstr);
        printf ("\tSET_VFLG ((flgs ^ flgn) & (flgo ^ flgn));\r\n");
        printf ("\tSET_CFLG (%s < %s);\r\n", undstr, usstr);
        duplicate_carry ();
        printf ("\tSET_NFLG (flgn != 0);\r\n");
        break;
     case flag_sub:
        printf ("\tSET_ZFLG (%s == 0);\r\n", vstr);
        printf ("\tSET_VFLG ((flgs ^ flgo) & (flgn ^ flgo));\r\n");
        printf ("\tSET_CFLG (%s > %s);\r\n", usstr, udstr);
        duplicate_carry ();
        printf ("\tSET_NFLG (flgn != 0);\r\n");
        break;
     case flag_addx:
        printf ("\tSET_VFLG ((flgs ^ flgn) & (flgo ^ flgn));\r\n"); /* minterm SON: 0x42 */
        printf ("\tSET_CFLG (flgs ^ ((flgs ^ flgo) & (flgo ^ flgn)));\r\n"); /* minterm SON: 0xD4 */
        duplicate_carry ();
        break;
     case flag_subx:
        printf ("\tSET_VFLG ((flgs ^ flgo) & (flgo ^ flgn));\r\n"); /* minterm SON: 0x24 */
        printf ("\tSET_CFLG (flgs ^ ((flgs ^ flgn) & (flgo ^ flgn)));\r\n"); /* minterm SON: 0xB2 */
        duplicate_carry ();
        break;
     case flag_cmp:
        printf ("\tSET_ZFLG (%s == 0);\r\n", vstr);
        printf ("\tSET_VFLG ((flgs != flgo) && (flgn != flgo));\r\n");
        printf ("\tSET_CFLG (%s > %s);\r\n", usstr, udstr);
        printf ("\tSET_NFLG (flgn != 0);\r\n");
        break;
    }
}

static void genflags (flagtypes type, wordsizes size, char *value, char *src, char *dst)
{
#ifdef SPARC_V8_ASSEMBLY
        switch(type)
        {
                case flag_add:
                        start_brace();
                        printf("\tuae_u32 %s;\r\n", value);
                        switch(size)
                        {
                                case sz_byte:
                                        printf("\t%s = sparc_v8_flag_add_8(&regflags, (uae_u32)(%s), (uae_u32)(%s));\r\n", value, src, dst);
                                        break;
                                case sz_word:
                                        printf("\t%s = sparc_v8_flag_add_16(&regflags, (uae_u32)(%s), (uae_u32)(%s));\r\n", value, src, dst);
                                        break;
                                case sz_long:
                                        printf("\t%s = sparc_v8_flag_add_32(&regflags, (uae_u32)(%s), (uae_u32)(%s));\r\n", value, src, dst);
                                        break;
                        }
                        return;

                case flag_sub:
                        start_brace();
                        printf("\tuae_u32 %s;\r\n", value);
                        switch(size)
                        {
                                case sz_byte:
                                        printf("\t%s = sparc_v8_flag_sub_8(&regflags, (uae_u32)(%s), (uae_u32)(%s));\r\n", value, src, dst);
                                        break;
                                case sz_word:
                                        printf("\t%s = sparc_v8_flag_sub_16(&regflags, (uae_u32)(%s), (uae_u32)(%s));\r\n", value, src, dst);
                                        break;
                                case sz_long:
                                        printf("\t%s = sparc_v8_flag_sub_32(&regflags, (uae_u32)(%s), (uae_u32)(%s));\r\n", value, src, dst);
                                        break;
                        }
                        return;

                case flag_cmp:
                        switch(size)
                        {
                                case sz_byte:
//                                      printf("\tsparc_v8_flag_cmp_8(&regflags, (uae_u32)(%s), (uae_u32)(%s));\r\n", src, dst);
                                        break;
                                case sz_word:
//                                      printf("\tsparc_v8_flag_cmp_16(&regflags, (uae_u32)(%s), (uae_u32)(%s));\r\n", src, dst);
                                        break;
                                case sz_long:
#if 1
                                        printf("\tsparc_v8_flag_cmp_32(&regflags, (uae_u32)(%s), (uae_u32)(%s));\r\n", src, dst);
                                        return;
#endif
                                        break;
                        }
//                      return;
                        break;
        }
#elif defined(SPARC_V9_ASSEMBLY)
        switch(type)
        {
                case flag_add:
                        start_brace();
                        printf("\tuae_u32 %s;\r\n", value);
                        switch(size)
                        {
                                case sz_byte:
                                        printf("\t%s = sparc_v9_flag_add_8(&regflags, (uae_u32)(%s), (uae_u32)(%s));\r\n", value, src, dst);
                                        break;
                                case sz_word:
                                        printf("\t%s = sparc_v9_flag_add_16(&regflags, (uae_u32)(%s), (uae_u32)(%s));\r\n", value, src, dst);
                                        break;
                                case sz_long:
                                        printf("\t%s = sparc_v9_flag_add_32(&regflags, (uae_u32)(%s), (uae_u32)(%s));\r\n", value, src, dst);
                                        break;
                        }
                        return;

                case flag_sub:
                        start_brace();
                        printf("\tuae_u32 %s;\r\n", value);
                        switch(size)
                        {
                                case sz_byte:
                                        printf("\t%s = sparc_v9_flag_sub_8(&regflags, (uae_u32)(%s), (uae_u32)(%s));\r\n", value, src, dst);
                                        break;
                                case sz_word:
                                        printf("\t%s = sparc_v9_flag_sub_16(&regflags, (uae_u32)(%s), (uae_u32)(%s));\r\n", value, src, dst);
                                        break;
                                case sz_long:
                                        printf("\t%s = sparc_v9_flag_sub_32(&regflags, (uae_u32)(%s), (uae_u32)(%s));\r\n", value, src, dst);
                                        break;
                        }
                        return;

                case flag_cmp:
                        switch(size)
                        {
                                case sz_byte:
                                        printf("\tsparc_v9_flag_cmp_8(&regflags, (uae_u32)(%s), (uae_u32)(%s));\r\n", src, dst);
                                        break;
                                case sz_word:
                                        printf("\tsparc_v9_flag_cmp_16(&regflags, (uae_u32)(%s), (uae_u32)(%s));\r\n", src, dst);
                                        break;
                                case sz_long:
                                        printf("\tsparc_v9_flag_cmp_32(&regflags, (uae_u32)(%s), (uae_u32)(%s));\r\n", src, dst);
                                        break;
                        }
                        return;

                case flag_logical:
                        if (strcmp(value, "0") == 0) {
                                printf("\tregflags.nzvc = 0x04;\r\n");
                        } else {
                                switch(size) {
                                        case sz_byte:
                                                printf("\tsparc_v9_flag_test_8(&regflags, (uae_u32)(%s));\r\n", value);
                                                break;
                                        case sz_word:
                                                printf("\tsparc_v9_flag_test_16(&regflags, (uae_u32)(%s));\r\n", value);
                                                break;
                                        case sz_long:
                                                printf("\tsparc_v9_flag_test_32(&regflags, (uae_u32)(%s));\r\n", value);
                                                break;
                                }
                        }
                        return;

#if 0
                case flag_logical_noclobber:
                        printf("\t{uae_u32 old_flags = regflags.nzvc & ~0x0C;\r\n");
                        if (strcmp(value, "0") == 0) {
                                printf("\tregflags.nzvc = old_flags | 0x04;\r\n");
                        } else {
                                switch(size) {
                                        case sz_byte:
                                                printf("\tsparc_v9_flag_test_8(&regflags, (uae_u32)(%s));\r\n", value);
                                                break;
                                        case sz_word:
                                                printf("\tsparc_v9_flag_test_16(&regflags, (uae_u32)(%s));\r\n", value);
                                                break;
                                        case sz_long:
                                                printf("\tsparc_v9_flag_test_32(&regflags, (uae_u32)(%s));\r\n", value);
                                                break;
                                }
                                printf("\tregflags.nzvc |= old_flags;\r\n");
                        }
                        printf("\t}\r\n");
                        return;
#endif
        }
#elif defined(X86_ASSEMBLY)
    switch (type) {
     case flag_add:
     case flag_sub:
        start_brace ();
        printf ("\tuae_u32 %s;\r\n", value);
        break;

     default:
        break;
    }

    /* At least some of those casts are fairly important! */
    switch (type) {
     case flag_logical_noclobber:
        printf ("\t{uae_u32 oldcznv = regflags.cznv & ~0xC0;\r\n");
        if (strcmp (value, "0") == 0) {
            printf ("\tregflags.cznv = olcznv | 64;\r\n");
        } else {
            switch (size) {
             case sz_byte: printf ("\tx86_flag_testb ((uae_s8)(%s));\r\n", value); break;
             case sz_word: printf ("\tx86_flag_testw ((uae_s16)(%s));\r\n", value); break;
             case sz_long: printf ("\tx86_flag_testl ((uae_s32)(%s));\r\n", value); break;
            }
            printf ("\tregflags.cznv |= oldcznv;\r\n");
        }
        printf ("\t}\r\n");
        return;
     case flag_logical:
        if (strcmp (value, "0") == 0) {
            printf ("\tregflags.cznv = 64;\r\n");
        } else {
            switch (size) {
             case sz_byte: printf ("\tx86_flag_testb ((uae_s8)(%s));\r\n", value); break;
             case sz_word: printf ("\tx86_flag_testw ((uae_s16)(%s));\r\n", value); break;
             case sz_long: printf ("\tx86_flag_testl ((uae_s32)(%s));\r\n", value); break;
            }
        }
        return;

     case flag_add:
        switch (size) {
         case sz_byte: printf ("\t%s = x86_flag_addb ((uae_s8)(%s), (uae_s8)(%s));\r\n", value, src, dst); break;
         case sz_word: printf ("\t%s = x86_flag_addw ((uae_s16)(%s), (uae_s16)(%s));\r\n", value, src, dst); break;
         case sz_long: printf ("\t%s = x86_flag_addl ((uae_s32)(%s), (uae_s32)(%s));\r\n", value, src, dst); break;
        }
        duplicate_carry();
        return;

     case flag_sub:
        switch (size) {
         case sz_byte: printf ("\t%s = x86_flag_subb ((uae_s8)(%s), (uae_s8)(%s));\r\n", value, src, dst); break;
         case sz_word: printf ("\t%s = x86_flag_subw ((uae_s16)(%s), (uae_s16)(%s));\r\n", value, src, dst); break;
         case sz_long: printf ("\t%s = x86_flag_subl ((uae_s32)(%s), (uae_s32)(%s));\r\n", value, src, dst); break;
        }
        duplicate_carry();
        return;

     case flag_cmp:
        switch (size) {
         case sz_byte: printf ("\tx86_flag_cmpb ((uae_s8)(%s), (uae_s8)(%s));\r\n", src, dst); break;
         case sz_word: printf ("\tx86_flag_cmpw ((uae_s16)(%s), (uae_s16)(%s));\r\n", src, dst); break;
         case sz_long: printf ("\tx86_flag_cmpl ((uae_s32)(%s), (uae_s32)(%s));\r\n", src, dst); break;
        }
        return;

     default:
        break;
    }
#elif defined(M68K_FLAG_OPT)
    /* sam: here I'm cloning what X86_ASSEMBLY does */
#define EXT(size)  (size==sz_byte?"b":(size==sz_word?"w":"l"))
#define CAST(size) (size==sz_byte?"uae_s8":(size==sz_word?"uae_s16":"uae_s32"))
    switch (type) {
     case flag_add:
     case flag_sub:
        start_brace ();
        printf ("\tuae_u32 %s;\r\n", value);
        break;

     default:
        break;
    }

    switch (type) {
     case flag_logical:
        if (strcmp (value, "0") == 0) {
            printf ("\t*(uae_u16 *)&regflags = 4;\r\n");        /* Z = 1 */
        } else {
            printf ("\tm68k_flag_tst (%s, (%s)(%s));\r\n",
                    EXT (size), CAST (size), value);
        }
        return;

     case flag_add:
        printf ("\t{uae_u16 ccr;\r\n");
        printf ("\tm68k_flag_add (%s, (%s)%s, (%s)(%s), (%s)(%s));\r\n",
                EXT (size), CAST (size), value, CAST (size), src, CAST (size), dst);
        printf ("\t((uae_u16*)&regflags)[1]=((uae_u16*)&regflags)[0]=ccr;}\r\n");
        return;

     case flag_sub:
        printf ("\t{uae_u16 ccr;\r\n");
        printf ("\tm68k_flag_sub (%s, (%s)%s, (%s)(%s), (%s)(%s));\r\n",
                EXT (size), CAST (size), value, CAST (size), src, CAST (size), dst);
        printf ("\t((uae_u16*)&regflags)[1]=((uae_u16*)&regflags)[0]=ccr;}\r\n");
        return;

     case flag_cmp:
        printf ("\tm68k_flag_cmp (%s, (%s)(%s), (%s)(%s));\r\n",
                EXT (size), CAST (size), src, CAST (size), dst);
        return;

     default:
        break;
    }
#elif defined(ACORN_FLAG_OPT) && defined(__GNUC_MINOR__)
/*
 * This is new. Might be quite buggy.
 */
    switch (type) {
     case flag_av:
     case flag_sv:
     case flag_zn:
     case flag_addx:
     case flag_subx:
        break;

     case flag_logical:
        if (strcmp (value, "0") == 0) {
            /* v=c=n=0 z=1 */
            printf ("\t*(ULONG*)&regflags = 0x40000000;\r\n");
            return;
        } else {
            start_brace ();
            switch (size) {
             case sz_byte:
                printf ("\tUBYTE ccr;\r\n");
                printf ("\tULONG shift;\r\n");
                printf ("\t__asm__(\"mov %%2,%%1,lsl#24\r\n\ttst %%2,%%2\r\n\tmov %%0,r15,lsr#24\r\n\tbic %%0,%%0,#0x30\"\r\n"
                        "\t: \"=r\" (ccr) : \"r\" (%s), \"r\" (shift) : \"cc\" );\r\n", value);
                printf ("\t*((UBYTE*)&regflags+3) = ccr;\r\n");
                return;
             case sz_word:
                printf ("\tUBYTE ccr;\r\n");
                printf ("\tULONG shift;\r\n");
                printf ("\t__asm__(\"mov %%2,%%1,lsl#16\r\n\ttst %%2,%%2\r\n\tmov %%0,r15,lsr#24\r\n\tbic %%0,%%0,#0x30\"\r\n"
                        "\t: \"=r\" (ccr) : \"r\" ((WORD)%s), \"r\" (shift) : \"cc\" );\r\n", value);
                printf ("\t*((UBYTE*)&regflags+3) = ccr;\r\n");
                return;
             case sz_long:
                printf ("\tUBYTE ccr;\r\n");
                printf ("\t__asm__(\"tst %%1,%%1\r\n\tmov %%0,r15,lsr#24\r\n\tbic %%0,%%0,#0x30\"\r\n"
                        "\t: \"=r\" (ccr) : \"r\" ((LONG)%s) : \"cc\" );\r\n", value);
                printf ("\t*((UBYTE*)&regflags+3) = ccr;\r\n");
                return;
            }
        }
        break;
     case flag_add:
        if (strcmp (dst, "0") == 0) {
            printf ("/* Error! Hier muss Peter noch was machen !!! (ADD-Flags) */");
        } else {
            start_brace ();
            switch (size) {
             case sz_byte:
                printf ("\tULONG ccr, shift, %s;\r\n", value);
                printf ("\t__asm__(\"mov %%4,%%3,lsl#24\r\n\tadds %%0,%%4,%%2,lsl#24\r\n\tmov %%0,%%0,asr#24\r\n\tmov %%1,r15\r\n\torr %%1,%%1,%%1,lsr#29\"\r\n"
                        "\t: \"=r\" (%s), \"=r\" (ccr) : \"r\" (%s), \"r\" (%s), \"r\" (shift) : \"cc\" );\r\n", value, src, dst);
                printf ("\t*(ULONG*)&regflags = ccr;\r\n");
                return;
             case sz_word:
                printf ("\tULONG ccr, shift, %s;\r\n", value);
                printf ("\t__asm__(\"mov %%4,%%3,lsl#16\r\n\tadds %%0,%%4,%%2,lsl#16\r\n\tmov %%0,%%0,asr#16\r\n\tmov %%1,r15\r\n\torr %%1,%%1,%%1,lsr#29\"\r\n"
                        "\t: \"=r\" (%s), \"=r\" (ccr) : \"r\" ((WORD)%s), \"r\" ((WORD)%s), \"r\" (shift) : \"cc\" );\r\n", value, src, dst);
                printf ("\t*(ULONG*)&regflags = ccr;\r\n");
                return;
             case sz_long:
                printf ("\tULONG ccr, %s;\r\n", value);
                printf ("\t__asm__(\"adds %%0,%%3,%%2\r\n\tmov %%1,r15\r\n\torr %%1,%%1,%%1,lsr#29\"\r\n"
                        "\t: \"=r\" (%s), \"=r\" (ccr) : \"r\" ((LONG)%s), \"r\" ((LONG)%s) : \"cc\" );\r\n", value, src, dst);
                printf ("\t*(ULONG*)&regflags = ccr;\r\n");
                return;
            }
        }
        break;
     case flag_sub:
        if (strcmp (dst, "0") == 0) {
            printf ("/* Error! Hier muss Peter noch was machen !!! (SUB-Flags) */");
        } else {
            start_brace ();
            switch (size) {
             case sz_byte:
                printf ("\tULONG ccr, shift, %s;\r\n", value);
                printf ("\t__asm__(\"mov %%4,%%3,lsl#24\r\n\tsubs %%0,%%4,%%2,lsl#24\r\n\tmov %%0,%%0,asr#24\r\n\tmov %%1,r15\r\n\teor %%1,%%1,#0x20000000\r\n\torr %%1,%%1,%%1,lsr#29\"\r\n"
                        "\t: \"=r\" (%s), \"=r\" (ccr) : \"r\" (%s), \"r\" (%s), \"r\" (shift) : \"cc\" );\r\n", value, src, dst);
                printf ("\t*(ULONG*)&regflags = ccr;\r\n");
                return;
             case sz_word:
                printf ("\tULONG ccr, shift, %s;\r\n", value);
                printf ("\t__asm__(\"mov %%4,%%3,lsl#16\r\n\tsubs %%0,%%4,%%2,lsl#16\r\n\tmov %%0,%%0,asr#16\r\n\tmov %%1,r15\r\n\teor %%1,%%1,#0x20000000\r\n\torr %%1,%%1,%%1,lsr#29\"\r\n"
                        "\t: \"=r\" (%s), \"=r\" (ccr) : \"r\" ((WORD)%s), \"r\" ((WORD)%s), \"r\" (shift) : \"cc\" );\r\n", value, src, dst);
                printf ("\t*(ULONG*)&regflags = ccr;\r\n");
                return;
             case sz_long:
                printf ("\tULONG ccr, %s;\r\n", value);
                printf ("\t__asm__(\"subs %%0,%%3,%%2\r\n\tmov %%1,r15\r\n\teor %%1,%%1,#0x20000000\r\n\torr %%1,%%1,%%1,lsr#29\"\r\n"
                        "\t: \"=r\" (%s), \"=r\" (ccr) : \"r\" ((LONG)%s), \"r\" ((LONG)%s) : \"cc\" );\r\n", value, src, dst);
                printf ("\t*(ULONG*)&regflags = ccr;\r\n");
                return;
            }
        }
        break;
     case flag_cmp:
        if (strcmp (dst, "0") == 0) {
            printf ("/*Error! Hier muss Peter noch was machen !!! (CMP-Flags)*/");
        } else {
            start_brace ();
            switch (size) {
             case sz_byte:
                printf ("\tULONG shift, ccr;\r\n");
                printf ("\t__asm__(\"mov %%3,%%2,lsl#24\r\n\tcmp %%3,%%1,lsl#24\r\n\tmov %%0,r15,lsr#24\r\n\teor %%0,%%0,#0x20\"\r\n"
                        "\t: \"=r\" (ccr) : \"r\" (%s), \"r\" (%s), \"r\" (shift) : \"cc\" );\r\n", src, dst);
                printf ("\t*((UBYTE*)&regflags+3) = ccr;\r\n");
                return;
             case sz_word:
                printf ("\tULONG shift, ccr;\r\n");
                printf ("\t__asm__(\"mov %%3,%%2,lsl#16\r\n\tcmp %%3,%%1,lsl#16\r\n\tmov %%0,r15,lsr#24\r\n\teor %%0,%%0,#0x20\"\r\n"
                        "\t: \"=r\" (ccr) : \"r\" ((WORD)%s), \"r\" ((WORD)%s), \"r\" (shift) : \"cc\" );\r\n", src, dst);
                printf ("\t*((UBYTE*)&regflags+3) = ccr;\r\n");
                return;
             case sz_long:
                printf ("\tULONG ccr;\r\n");
                printf ("\t__asm__(\"cmp %%2,%%1\r\n\tmov %%0,r15,lsr#24\r\n\teor %%0,%%0,#0x20\"\r\n"
                        "\t: \"=r\" (ccr) : \"r\" ((LONG)%s), \"r\" ((LONG)%s) : \"cc\" );\r\n", src, dst);
                printf ("\t*((UBYTE*)&regflags+3) = ccr;\r\n");
                /*printf ("\tprintf (\"%%08x %%08x %%08x\\r\n\", %s, %s, *((ULONG*)&regflags));\r\n", src, dst); */
                return;
            }
        }
        break;
    }
#endif
    genflags_normal (type, size, value, src, dst);
}

static void force_range_for_rox (const char *var, wordsizes size)
{
    /* Could do a modulo operation here... which one is faster? */
    switch (size) {
     case sz_long:
        printf ("\tif (%s >= 33) %s -= 33;\r\n", var, var);
        break;
     case sz_word:
        printf ("\tif (%s >= 34) %s -= 34;\r\n", var, var);
        printf ("\tif (%s >= 17) %s -= 17;\r\n", var, var);
        break;
     case sz_byte:
        printf ("\tif (%s >= 36) %s -= 36;\r\n", var, var);
        printf ("\tif (%s >= 18) %s -= 18;\r\n", var, var);
        printf ("\tif (%s >= 9) %s -= 9;\r\n", var, var);
        break;
    }
}

static const char *cmask (wordsizes size)
{
    switch (size) {
     case sz_byte: return "0x80";
     case sz_word: return "0x8000";
     case sz_long: return "0x80000000";
     default: abort ();
    }
}

static int source_is_imm1_8 (struct instr *i)
{
    return i->stype == 3;
}

static char *make_cctrue(int cc)
{
	static char cc_str[50];
#ifdef GENASM
	switch(cc) {
		case 0: strcpy( cc_str, "1" );				break;
		case 1: strcpy( cc_str, "0" );				break;
		case 2: strcpy( cc_str, "cc_ja()" );	break;
		case 3: strcpy( cc_str, "cc_jbe()" );	break;
		case 4: strcpy( cc_str, "cc_jae()" );	break;
		case 5: strcpy( cc_str, "cc_jb()" );	break;
		case 6: strcpy( cc_str, "cc_jne()" );	break;
		case 7: strcpy( cc_str, "cc_je()" );	break;
		case 8: strcpy( cc_str, "cc_jno()" );	break;
		case 9: strcpy( cc_str, "cc_jo()" );	break;
		case 10: strcpy( cc_str, "cc_jns()" );break;
		case 11: strcpy( cc_str, "cc_js()" );	break;
		case 12: strcpy( cc_str, "cc_jge()" );break;
		case 13: strcpy( cc_str, "cc_jl()" );	break;
		case 14: strcpy( cc_str, "cc_jg()" );	break;
		case 15: strcpy( cc_str, "cc_jle()" );break;
	}
#else //!GENASM
	sprintf( cc_str, "cctrue(%d)", cc );
#endif //GENASM
	return cc_str;
}

static char *make_ccfalse(int cc)
{
	return make_cctrue(cc^1);
}

static void gen_opcode (unsigned long int opcode)
{
    struct instr *curi = table68k + opcode;
    insn_n_cycles = 2;

    start_brace ();
#if 0
    printf ("uae_u8 *m68k_pc = regs.pc_p;\r\n");
#endif
    m68k_pc_offset = 2;
    switch (curi->plev) {
     case 0: /* not privileged */
        break;
     case 1: /* unprivileged only on 68000 */
        if (cpu_level == 0)
            break;
        if (next_cpu_level < 0)
            next_cpu_level = 0;

        /* fall through */
     case 2: /* priviledged */
        printf ("if (!regs.s) { Exception(8,0); goto %s; }\r\n", endlabelstr);
        need_endlabel = 1;
        start_brace ();
        break;
     case 3: /* privileged if size == word */
        if (curi->size == sz_byte)
            break;
        printf ("if (!regs.s) { Exception(8,0); goto %s; }\r\n", endlabelstr);
        need_endlabel = 1;
        start_brace ();
        break;
    }
    switch (curi->mnemo) {
     case i_OR:
     case i_AND:
     case i_EOR:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 1, 0);
        printf ("\tsrc %c= dst;\r\n", curi->mnemo == i_OR ? '|' : curi->mnemo == i_AND ? '&' : '^');
        genflags (flag_logical, curi->size, "src", "", "");
        genastore ("src", curi->dmode, "dstreg", curi->size, "dst");
        break;
     case i_ORSR:
     case i_EORSR:
        printf ("\tMakeSR();\r\n");
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        if (curi->size == sz_byte) {
            printf ("\tsrc &= 0xFF;\r\n");
        }
        printf ("\tregs.sr %c= src;\r\n", curi->mnemo == i_EORSR ? '^' : '|');
        printf ("\tMakeFromSR();\r\n");
        break;
     case i_ANDSR:
        printf ("\tMakeSR();\r\n");
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        if (curi->size == sz_byte) {
            printf ("\tsrc |= 0xFF00;\r\n");
        }
        printf ("\tregs.sr &= src;\r\n");
        printf ("\tMakeFromSR();\r\n");
        break;
     case i_SUB:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 1, 0);
        start_brace ();
        genflags (flag_sub, curi->size, "newv", "src", "dst");
        genastore ("newv", curi->dmode, "dstreg", curi->size, "dst");
        break;
     case i_SUBA:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", sz_long, "dst", 1, 0);
        start_brace ();
        printf ("\tuae_u32 newv = dst - src;\r\n");
        genastore ("newv", curi->dmode, "dstreg", sz_long, "dst");
        break;
     case i_SUBX:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 1, 0);
        start_brace ();
        printf ("\tuae_u32 newv = dst - src - (GET_XFLG ? 1 : 0);\r\n");
        genflags (flag_subx, curi->size, "newv", "src", "dst");
        genflags (flag_zn, curi->size, "newv", "", "");
        genastore ("newv", curi->dmode, "dstreg", curi->size, "dst");
        break;
     case i_SBCD:
        /* Let's hope this works... */
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 1, 0);
        start_brace ();
        printf ("\tuae_u16 newv_lo = (dst & 0xF) - (src & 0xF) - (GET_XFLG ? 1 : 0);\r\n");
        printf ("\tuae_u16 newv_hi = (dst & 0xF0) - (src & 0xF0);\r\n");
        printf ("\tuae_u16 newv;\r\n");
        printf ("\tint cflg;\r\n");
        printf ("\tif (newv_lo > 9) { newv_lo-=6; newv_hi-=0x10; }\r\n");
        printf ("\tnewv = newv_hi + (newv_lo & 0xF);");
        printf ("\tSET_CFLG (cflg = (newv_hi & 0x1F0) > 0x90);\r\n");
        duplicate_carry ();
        printf ("\tif (cflg) newv -= 0x60;\r\n");
        genflags (flag_zn, curi->size, "newv", "", "");
        genflags (flag_sv, curi->size, "newv", "src", "dst");
        genastore ("newv", curi->dmode, "dstreg", curi->size, "dst");
        break;
     case i_ADD:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 1, 0);
        start_brace ();
        genflags (flag_add, curi->size, "newv", "src", "dst");
        genastore ("newv", curi->dmode, "dstreg", curi->size, "dst");
        break;
     case i_ADDA:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", sz_long, "dst", 1, 0);
        start_brace ();
        printf ("\tuae_u32 newv = dst + src;\r\n");
        genastore ("newv", curi->dmode, "dstreg", sz_long, "dst");
        break;
     case i_ADDX:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 1, 0);
        start_brace ();
        printf ("\tuae_u32 newv = dst + src + (GET_XFLG ? 1 : 0);\r\n");
        genflags (flag_addx, curi->size, "newv", "src", "dst");
        genflags (flag_zn, curi->size, "newv", "", "");
        genastore ("newv", curi->dmode, "dstreg", curi->size, "dst");
        break;
     case i_ABCD:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 1, 0);
        start_brace ();
        printf ("\tuae_u16 newv_lo = (src & 0xF) + (dst & 0xF) + (GET_XFLG ? 1 : 0);\r\n");
        printf ("\tuae_u16 newv_hi = (src & 0xF0) + (dst & 0xF0);\r\n");
        printf ("\tuae_u16 newv;\r\n");
        printf ("\tint cflg;\r\n");
        printf ("\tif (newv_lo > 9) { newv_lo +=6; }\r\n");
        printf ("\tnewv = newv_hi + newv_lo;");
        printf ("\tSET_CFLG (cflg = (newv & 0x1F0) > 0x90);\r\n");
        duplicate_carry ();
        printf ("\tif (cflg) newv += 0x60;\r\n");
        genflags (flag_zn, curi->size, "newv", "", "");
        genflags (flag_sv, curi->size, "newv", "src", "dst");
        genastore ("newv", curi->dmode, "dstreg", curi->size, "dst");
        break;
     case i_NEG:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        start_brace ();
        genflags (flag_sub, curi->size, "dst", "src", "0");
        genastore ("dst", curi->smode, "srcreg", curi->size, "src");
        break;
     case i_NEGX:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        start_brace ();
        printf ("\tuae_u32 newv = 0 - src - (GET_XFLG ? 1 : 0);\r\n");
        genflags (flag_subx, curi->size, "newv", "src", "0");
        genflags (flag_zn, curi->size, "newv", "", "");
        genastore ("newv", curi->smode, "srcreg", curi->size, "src");
        break;
     case i_NBCD:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        start_brace ();
        printf ("\tuae_u16 newv_lo = - (src & 0xF) - (GET_XFLG ? 1 : 0);\r\n");
        printf ("\tuae_u16 newv_hi = - (src & 0xF0);\r\n");
        printf ("\tuae_u16 newv;\r\n");
        printf ("\tint cflg;\r\n");
        printf ("\tif (newv_lo > 9) { newv_lo-=6; newv_hi-=0x10; }\r\n");
        printf ("\tnewv = newv_hi + (newv_lo & 0xF);");
        printf ("\tSET_CFLG (cflg = (newv_hi & 0x1F0) > 0x90);\r\n");
        duplicate_carry();
        printf ("\tif (cflg) newv -= 0x60;\r\n");
        genflags (flag_zn, curi->size, "newv", "", "");
        genastore ("newv", curi->smode, "srcreg", curi->size, "src");
        break;
     case i_CLR:
        genamode (curi->smode, "srcreg", curi->size, "src", 2, 0);
        genflags (flag_logical, curi->size, "0", "", "");
        genastore ("0", curi->smode, "srcreg", curi->size, "src");
        break;
     case i_NOT:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        start_brace ();
        printf ("\tuae_u32 dst = ~src;\r\n");
        genflags (flag_logical, curi->size, "dst", "", "");
        genastore ("dst", curi->smode, "srcreg", curi->size, "src");
        break;
     case i_TST:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genflags (flag_logical, curi->size, "src", "", "");
        break;
     case i_BTST:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 1, 0);
        if (curi->size == sz_byte)
            printf ("\tsrc &= 7;\r\n");
        else
            printf ("\tsrc &= 31;\r\n");
        printf ("\tSET_ZFLG (1 ^ ((dst >> src) & 1));\r\n");
        break;
     case i_BCHG:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 1, 0);
        if (curi->size == sz_byte)
            printf ("\tsrc &= 7;\r\n");
        else
            printf ("\tsrc &= 31;\r\n");
        printf ("\tdst ^= (1 << src);\r\n");
        printf ("\tSET_ZFLG ((dst & (1 << src)) >> src);\r\n");
        genastore ("dst", curi->dmode, "dstreg", curi->size, "dst");
        break;
     case i_BCLR:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 1, 0);
        if (curi->size == sz_byte)
            printf ("\tsrc &= 7;\r\n");
        else
            printf ("\tsrc &= 31;\r\n");
        printf ("\tSET_ZFLG (1 ^ ((dst >> src) & 1));\r\n");
        printf ("\tdst &= ~(1 << src);\r\n");
        genastore ("dst", curi->dmode, "dstreg", curi->size, "dst");
        break;
     case i_BSET:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 1, 0);
        if (curi->size == sz_byte)
            printf ("\tsrc &= 7;\r\n");
        else
            printf ("\tsrc &= 31;\r\n");
        printf ("\tSET_ZFLG (1 ^ ((dst >> src) & 1));\r\n");
        printf ("\tdst |= (1 << src);\r\n");
        genastore ("dst", curi->dmode, "dstreg", curi->size, "dst");
        break;
     case i_CMPM:
     case i_CMP:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 1, 0);
        start_brace ();
        genflags (flag_cmp, curi->size, "newv", "src", "dst");
        break;
     case i_CMPA:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", sz_long, "dst", 1, 0);
        start_brace ();
        genflags (flag_cmp, sz_long, "newv", "src", "dst");
        break;
        /* The next two are coded a little unconventional, but they are doing
         * weird things... */
     case i_MVPRM:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);

        printf ("\tuaecptr memp = m68k_areg(regs, dstreg) + (uae_s32)(uae_s16)%s;\r\n", gen_nextiword ());
        if (curi->size == sz_word) {
            printf ("\tput_byte(memp, src >> 8); put_byte(memp + 2, src);\r\n");
        } else {
            printf ("\tput_byte(memp, src >> 24); put_byte(memp + 2, src >> 16);\r\n");
            printf ("\tput_byte(memp + 4, src >> 8); put_byte(memp + 6, src);\r\n");
        }
        break;
     case i_MVPMR:
        printf ("\tuaecptr memp = m68k_areg(regs, srcreg) + (uae_s32)(uae_s16)%s;\r\n", gen_nextiword ());
        genamode (curi->dmode, "dstreg", curi->size, "dst", 2, 0);
        if (curi->size == sz_word) {
            printf ("\tuae_u16 val = (get_byte(memp) << 8) + get_byte(memp + 2);\r\n");
        } else {
            printf ("\tuae_u32 val = (get_byte(memp) << 24) + (get_byte(memp + 2) << 16)\r\n");
            printf ("              + (get_byte(memp + 4) << 8) + get_byte(memp + 6);\r\n");
        }
        genastore ("val", curi->dmode, "dstreg", curi->size, "dst");
        break;
     case i_MOVE:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 2, 0);
        genflags (flag_logical, curi->size, "src", "", "");
        genastore ("src", curi->dmode, "dstreg", curi->size, "dst");
        break;
     case i_MOVEA:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 2, 0);
        if (curi->size == sz_word) {
            printf ("\tuae_u32 val = (uae_s32)(uae_s16)src;\r\n");
        } else {
            printf ("\tuae_u32 val = src;\r\n");
        }
        genastore ("val", curi->dmode, "dstreg", sz_long, "dst");
        break;
     case i_MVSR2:
        genamode (curi->smode, "srcreg", sz_word, "src", 2, 0);
        printf ("\tMakeSR();\r\n");
        if (curi->size == sz_byte)
            genastore ("regs.sr & 0xff", curi->smode, "srcreg", sz_word, "src");
        else
            genastore ("regs.sr", curi->smode, "srcreg", sz_word, "src");
        break;
     case i_MV2SR:
        genamode (curi->smode, "srcreg", sz_word, "src", 1, 0);
        if (curi->size == sz_byte)
            printf ("\tMakeSR();\r\n\tregs.sr &= 0xFF00;\r\n\tregs.sr |= src & 0xFF;\r\n");
        else {
            printf ("\tregs.sr = src;\r\n");
        }
        printf ("\tMakeFromSR();\r\n");
        break;
     case i_SWAP:
        genamode (curi->smode, "srcreg", sz_long, "src", 1, 0);
        start_brace ();
        printf ("\tuae_u32 dst = ((src >> 16)&0xFFFF) | ((src&0xFFFF)<<16);\r\n");
        genflags (flag_logical, sz_long, "dst", "", "");
        genastore ("dst", curi->smode, "srcreg", sz_long, "src");
        break;
     case i_EXG:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 1, 0);
        genastore ("dst", curi->smode, "srcreg", curi->size, "src");
        genastore ("src", curi->dmode, "dstreg", curi->size, "dst");
        break;
     case i_EXT:
        genamode (curi->smode, "srcreg", sz_long, "src", 1, 0);
        start_brace ();
        switch (curi->size) {
         case sz_byte: printf ("\tuae_u32 dst = (uae_s32)(uae_s8)src;\r\n"); break;
         case sz_word: printf ("\tuae_u16 dst = (uae_s16)(uae_s8)src;\r\n"); break;
         case sz_long: printf ("\tuae_u32 dst = (uae_s32)(uae_s16)src;\r\n"); break;
         default: abort ();
        }
        genflags (flag_logical,
                  curi->size == sz_word ? sz_word : sz_long, "dst", "", "");
        genastore ("dst", curi->smode, "srcreg",
                   curi->size == sz_word ? sz_word : sz_long, "src");
        break;
     case i_MVMEL:
        genmovemel (opcode);
        break;
     case i_MVMLE:
        genmovemle (opcode);
        break;
     case i_TRAP:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        sync_m68k_pc ();
        printf ("\tException(src+32,0);\r\n");
        m68k_pc_offset = 0;
        break;
     case i_MVR2USP:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        printf ("\tregs.usp = src;\r\n");
        break;
     case i_MVUSP2R:
        genamode (curi->smode, "srcreg", curi->size, "src", 2, 0);
        genastore ("regs.usp", curi->smode, "srcreg", curi->size, "src");
        break;
     case i_RESET:
        break;
     case i_NOP:
        break;
     case i_STOP:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        printf ("\tregs.sr = src;\r\n");
        printf ("\tMakeFromSR();\r\n");
        printf ("\tm68k_setstopped(1);\r\n");
        break;
     case i_RTE:
        if (cpu_level == 0) {
            genamode (Aipi, "7", sz_word, "sr", 1, 0);
            genamode (Aipi, "7", sz_long, "pc", 1, 0);
            printf ("\tregs.sr = sr; m68k_setpc_rte(pc);\r\n");
            fill_prefetch_0 ();
            printf ("\tMakeFromSR();\r\n");
        } else {
            int old_brace_level = n_braces;
            if (next_cpu_level < 0)
                next_cpu_level = 0;
            printf ("\tuae_u16 newsr; uae_u32 newpc; for (;;) {\r\n");
            genamode (Aipi, "7", sz_word, "sr", 1, 0);
            genamode (Aipi, "7", sz_long, "pc", 1, 0);
            genamode (Aipi, "7", sz_word, "format", 1, 0);
            printf ("\tnewsr = sr; newpc = pc;\r\n");
            printf ("\tif ((format & 0xF000) == 0x0000) { break; }\r\n");
            printf ("\telse if ((format & 0xF000) == 0x1000) { ; }\r\n");
            printf ("\telse if ((format & 0xF000) == 0x2000) { m68k_areg(regs, 7) += 4; break; }\r\n");
            printf ("\telse if ((format & 0xF000) == 0x3000) { m68k_areg(regs, 7) += 4; break; }\r\n");
            printf ("\telse if ((format & 0xF000) == 0x7000) { m68k_areg(regs, 7) += 52; break; }\r\n");
            printf ("\telse if ((format & 0xF000) == 0x8000) { m68k_areg(regs, 7) += 50; break; }\r\n");
            printf ("\telse if ((format & 0xF000) == 0x9000) { m68k_areg(regs, 7) += 12; break; }\r\n");
            printf ("\telse if ((format & 0xF000) == 0xa000) { m68k_areg(regs, 7) += 24; break; }\r\n");
            printf ("\telse if ((format & 0xF000) == 0xb000) { m68k_areg(regs, 7) += 84; break; }\r\n");
            printf ("\telse { Exception(14,0); goto %s; }\r\n", endlabelstr);
            printf ("\tregs.sr = newsr; MakeFromSR();\r\n}\r\n");
            pop_braces (old_brace_level);
            printf ("\tregs.sr = newsr; MakeFromSR();\r\n");
            printf ("\tm68k_setpc_rte(newpc);\r\n");
            fill_prefetch_0 ();
            need_endlabel = 1;
        }
        /* PC is set and prefetch filled. */
        m68k_pc_offset = 0;
        break;
     case i_RTD:
        printf ("\tcompiler_flush_jsr_stack();\r\n");
        genamode (Aipi, "7", sz_long, "pc", 1, 0);
        genamode (curi->smode, "srcreg", curi->size, "offs", 1, 0);
        printf ("\tm68k_areg(regs, 7) += offs;\r\n");
        printf ("\tm68k_setpc_rte(pc);\r\n");
        fill_prefetch_0 ();
        /* PC is set and prefetch filled. */
        m68k_pc_offset = 0;
        break;
     case i_LINK:
        genamode (Apdi, "7", sz_long, "old", 2, 0);
        genamode (curi->smode, "srcreg", sz_long, "src", 1, 0);
        genastore ("src", Apdi, "7", sz_long, "old");
        genastore ("m68k_areg(regs, 7)", curi->smode, "srcreg", sz_long, "src");
        genamode (curi->dmode, "dstreg", curi->size, "offs", 1, 0);
        printf ("\tm68k_areg(regs, 7) += offs;\r\n");
        break;
     case i_UNLK:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        printf ("\tm68k_areg(regs, 7) = src;\r\n");
        genamode (Aipi, "7", sz_long, "old", 1, 0);
        genastore ("old", curi->smode, "srcreg", curi->size, "src");
        break;
     case i_RTS:
        printf ("\tm68k_do_rts();\r\n");
        fill_prefetch_0 ();
        m68k_pc_offset = 0;
        break;
     case i_TRAPV:
        sync_m68k_pc ();
        printf ("\tif (GET_VFLG) { Exception(7,m68k_getpc()); goto %s; }\r\n", endlabelstr);
        need_endlabel = 1;
        break;
     case i_RTR:
        printf ("\tcompiler_flush_jsr_stack();\r\n");
        printf ("\tMakeSR();\r\n");
        genamode (Aipi, "7", sz_word, "sr", 1, 0);
        genamode (Aipi, "7", sz_long, "pc", 1, 0);
        printf ("\tregs.sr &= 0xFF00; sr &= 0xFF;\r\n");
        printf ("\tregs.sr |= sr; m68k_setpc(pc);\r\n");
        fill_prefetch_0 ();
        printf ("\tMakeFromSR();\r\n");
        m68k_pc_offset = 0;
        break;
     case i_JSR:
        genamode (curi->smode, "srcreg", curi->size, "src", 0, 0);
        printf ("\tm68k_do_jsr(m68k_getpc() + %d, srca);\r\n", m68k_pc_offset);
        fill_prefetch_0 ();
        m68k_pc_offset = 0;
        break;
     case i_JMP:
        genamode (curi->smode, "srcreg", curi->size, "src", 0, 0);
        printf ("\tm68k_setpc(srca);\r\n");
        fill_prefetch_0 ();
        m68k_pc_offset = 0;
        break;
     case i_BSR:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        printf ("\tuae_s32 s = (uae_s32)src + 2;\r\n");
        if (using_exception_3) {
            printf ("\tif (src & 1) {\r\n");
            printf ("\tlast_addr_for_exception_3 = m68k_getpc() + 2;\r\n");
            printf ("\t\tlast_fault_for_exception_3 = m68k_getpc() + s;\r\n");
            printf ("\t\tlast_op_for_exception_3 = opcode; Exception(3,0); goto %s;\r\n", endlabelstr);
            printf ("\t}\r\n");
            need_endlabel = 1;
        }
        printf ("\tm68k_do_bsr(m68k_getpc() + %d, s);\r\n", m68k_pc_offset);
        fill_prefetch_0 ();
        m68k_pc_offset = 0;
        break;
     case i_Bcc:
        if (curi->size == sz_long) {
            if (cpu_level < 2) {
                printf ("\tm68k_incpc(2);\r\n");
                printf ("\tif (%s) goto %s;\r\n", make_ccfalse(curi->cc), endlabelstr);
                printf ("\t\tlast_addr_for_exception_3 = m68k_getpc() + 2;\r\n");
                printf ("\t\tlast_fault_for_exception_3 = m68k_getpc() + 1;\r\n");
                printf ("\t\tlast_op_for_exception_3 = opcode; Exception(3,0); goto %s;\r\n", endlabelstr);
                need_endlabel = 1;
            } else {
                if (next_cpu_level < 1)
                    next_cpu_level = 1;
            }
        }
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        printf ("\tif (%s) goto didnt_jump;\r\n", make_ccfalse(curi->cc));
        if (using_exception_3) {
            printf ("\tif (src & 1) {\r\n");
            printf ("\t\tlast_addr_for_exception_3 = m68k_getpc() + 2;\r\n");
            printf ("\t\tlast_fault_for_exception_3 = m68k_getpc() + 2 + (uae_s32)src;\r\n");
            printf ("\t\tlast_op_for_exception_3 = opcode; Exception(3,0); goto %s;\r\n", endlabelstr);
            printf ("\t}\r\n");
            need_endlabel = 1;
        }
#ifdef USE_COMPILER
        printf ("\tm68k_setpc_bcc(m68k_getpc() + 2 + (uae_s32)src);\r\n");
#else
        printf ("\tm68k_incpc ((uae_s32)src + 2);\r\n");
#endif
        fill_prefetch_0 ();
        printf ("\tgoto %s;\r\n", endlabelstr);
        printf ("didnt_jump:;\r\n");
        need_endlabel = 1;
        break;
     case i_LEA:
        genamode (curi->smode, "srcreg", curi->size, "src", 0, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 2, 0);
        genastore ("srca", curi->dmode, "dstreg", curi->size, "dst");
        break;
     case i_PEA:
        genamode (curi->smode, "srcreg", curi->size, "src", 0, 0);
        genamode (Apdi, "7", sz_long, "dst", 2, 0);
        genastore ("srca", Apdi, "7", sz_long, "dst");
        break;
     case i_DBcc:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "offs", 1, 0);

        printf ("\tif (%s) {\r\n", make_ccfalse(curi->cc));
        genastore ("(src-1)", curi->smode, "srcreg", curi->size, "src");

        printf ("\t\tif (src) {\r\n");
        if (using_exception_3) {
            printf ("\t\t\tif (offs & 1) {\r\n");
            printf ("\t\t\tlast_addr_for_exception_3 = m68k_getpc() + 2;\r\n");
            printf ("\t\t\tlast_fault_for_exception_3 = m68k_getpc() + 2 + (uae_s32)offs + 2;\r\n");
            printf ("\t\t\tlast_op_for_exception_3 = opcode; Exception(3,0); goto %s;\r\n", endlabelstr);
            printf ("\t\t}\r\n");
            need_endlabel = 1;
        }
#ifdef USE_COMPILER
        printf ("\t\t\tm68k_setpc_bcc(m68k_getpc() + (uae_s32)offs + 2);\r\n");
#else
        printf ("\t\t\tm68k_incpc((uae_s32)offs + 2);\r\n");
#endif
        fill_prefetch_0 ();
        printf ("\t\tgoto %s;\r\n", endlabelstr);
        printf ("\t\t}\r\n");
        printf ("\t}\r\n");
        need_endlabel = 1;
        break;
     case i_Scc:
        genamode (curi->smode, "srcreg", curi->size, "src", 2, 0);
        start_brace ();
        printf ("\tint val = %s ? 0xff : 0;\r\n", make_cctrue(curi->cc));
        genastore ("val", curi->smode, "srcreg", curi->size, "src");
        break;
     case i_DIVU:
        printf ("\tuaecptr oldpc = m68k_getpc();\r\n");
        genamode (curi->smode, "srcreg", sz_word, "src", 1, 0);
        genamode (curi->dmode, "dstreg", sz_long, "dst", 1, 0);
        printf ("\tif(src == 0) { Exception(5,oldpc); goto %s; } else {\r\n", endlabelstr);
        printf ("\tuae_u32 newv = (uae_u32)dst / (uae_u32)(uae_u16)src;\r\n");
        printf ("\tuae_u32 rem = (uae_u32)dst %% (uae_u32)(uae_u16)src;\r\n");
        /* The N flag appears to be set each time there is an overflow.
         * Weird. */
        printf ("\tif (newv > 0xffff) { SET_VFLG (1); SET_NFLG (1); SET_CFLG (0); } else\r\n\t{\r\n");
        genflags (flag_logical, sz_word, "newv", "", "");
        printf ("\tnewv = (newv & 0xffff) | ((uae_u32)rem << 16);\r\n");
        genastore ("newv", curi->dmode, "dstreg", sz_long, "dst");
        printf ("\t}\r\n");
        printf ("\t}\r\n");
        insn_n_cycles += 68;
        need_endlabel = 1;
        break;
     case i_DIVS:
        printf ("\tuaecptr oldpc = m68k_getpc();\r\n");
        genamode (curi->smode, "srcreg", sz_word, "src", 1, 0);
        genamode (curi->dmode, "dstreg", sz_long, "dst", 1, 0);
        printf ("\tif(src == 0) { Exception(5,oldpc); goto %s; } else {\r\n", endlabelstr);
        printf ("\tuae_s32 newv = (uae_s32)dst / (uae_s32)(uae_s16)src;\r\n");
        printf ("\tuae_u16 rem = (uae_s32)dst %% (uae_s32)(uae_s16)src;\r\n");
        printf ("\tif ((newv & 0xffff8000) != 0 && (newv & 0xffff8000) != 0xffff8000) { SET_VFLG (1); SET_NFLG (1); SET_CFLG (0); } else\r\n\t{\r\n");
        printf ("\tif (((uae_s16)rem < 0) != ((uae_s32)dst < 0)) rem = -rem;\r\n");
        genflags (flag_logical, sz_word, "newv", "", "");
        printf ("\tnewv = (newv & 0xffff) | ((uae_u32)rem << 16);\r\n");
        genastore ("newv", curi->dmode, "dstreg", sz_long, "dst");
        printf ("\t}\r\n");
        printf ("\t}\r\n");
        insn_n_cycles += 72;
        need_endlabel = 1;
        break;
     case i_MULU:
        genamode (curi->smode, "srcreg", sz_word, "src", 1, 0);
        genamode (curi->dmode, "dstreg", sz_word, "dst", 1, 0);
        start_brace ();
        printf ("\tuae_u32 newv = (uae_u32)(uae_u16)dst * (uae_u32)(uae_u16)src;\r\n");
        genflags (flag_logical, sz_long, "newv", "", "");
        genastore ("newv", curi->dmode, "dstreg", sz_long, "dst");
        insn_n_cycles += 32;
        break;
     case i_MULS:
        genamode (curi->smode, "srcreg", sz_word, "src", 1, 0);
        genamode (curi->dmode, "dstreg", sz_word, "dst", 1, 0);
        start_brace ();
        printf ("\tuae_u32 newv = (uae_s32)(uae_s16)dst * (uae_s32)(uae_s16)src;\r\n");
        genflags (flag_logical, sz_long, "newv", "", "");
        genastore ("newv", curi->dmode, "dstreg", sz_long, "dst");
        insn_n_cycles += 32;
        break;
     case i_CHK:
        printf ("\tuaecptr oldpc = m68k_getpc();\r\n");
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 1, 0);
        printf ("\tif ((uae_s32)dst < 0) { SET_NFLG (1); Exception(6,oldpc); goto %s; }\r\n", endlabelstr);
        printf ("\telse if (dst > src) { SET_NFLG (0); Exception(6,oldpc); goto %s; }\r\n", endlabelstr);
        need_endlabel = 1;
        break;

     case i_CHK2:
        printf ("\tuaecptr oldpc = m68k_getpc();\r\n");
        genamode (curi->smode, "srcreg", curi->size, "extra", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 2, 0);
        printf ("\t{uae_s32 upper,lower,reg = regs.regs[(extra >> 12) & 15];\r\n");
        switch (curi->size) {
         case sz_byte:
            printf ("\tlower=(uae_s32)(uae_s8)get_byte(dsta); upper = (uae_s32)(uae_s8)get_byte(dsta+1);\r\n");
            printf ("\tif ((extra & 0x8000) == 0) reg = (uae_s32)(uae_s8)reg;\r\n");
            break;
         case sz_word:
            printf ("\tlower=(uae_s32)(uae_s16)get_word(dsta); upper = (uae_s32)(uae_s16)get_word(dsta+2);\r\n");
            printf ("\tif ((extra & 0x8000) == 0) reg = (uae_s32)(uae_s16)reg;\r\n");
            break;
         case sz_long:
            printf ("\tlower=get_long(dsta); upper = get_long(dsta+4);\r\n");
            break;
         default:
            abort ();
        }
        printf ("\tSET_ZFLG (upper == reg || lower == reg);\r\n");
        printf ("\tSET_CFLG (lower <= upper ? reg < lower || reg > upper : reg > upper || reg < lower);\r\n");
        printf ("\tif ((extra & 0x800) && GET_CFLG) { Exception(6,oldpc); goto %s; }\r\n}\r\n", endlabelstr);
        need_endlabel = 1;
        break;

     case i_ASR:
        genamode (curi->smode, "srcreg", curi->size, "cnt", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "data", 1, 0);
        start_brace ();
        switch (curi->size) {
         case sz_byte: printf ("\tuae_u32 val = (uae_u8)data;\r\n"); break;
         case sz_word: printf ("\tuae_u32 val = (uae_u16)data;\r\n"); break;
         case sz_long: printf ("\tuae_u32 val = data;\r\n"); break;
         default: abort ();
        }
        printf ("\tuae_u32 sign = (%s & val) >> %d;\r\n", cmask (curi->size), bit_size (curi->size) - 1);
        printf ("\tcnt &= 63;\r\n");
        printf ("\tCLEAR_CZNV;\r\n");
        printf ("\tif (cnt >= %d) {\r\n", bit_size (curi->size));
        printf ("\t\tval = %s & (uae_u32)-sign;\r\n", bit_mask (curi->size));
        printf ("\t\tSET_CFLG (sign);\r\n");
        duplicate_carry ();
        if (source_is_imm1_8 (curi))
            printf ("\t} else {\r\n");
        else
            printf ("\t} else if (cnt > 0) {\r\n");
        printf ("\t\tval >>= cnt - 1;\r\n");
        printf ("\t\tSET_CFLG (val & 1);\r\n");
        duplicate_carry ();
        printf ("\t\tval >>= 1;\r\n");
        printf ("\t\tval |= (%s << (%d - cnt)) & (uae_u32)-sign;\r\n",
                bit_mask (curi->size),
                bit_size (curi->size));
        printf ("\t\tval &= %s;\r\n", bit_mask (curi->size));
        printf ("\t}\r\n");
        genflags (flag_logical_noclobber, curi->size, "val", "", "");
        genastore ("val", curi->dmode, "dstreg", curi->size, "data");
        break;
     case i_ASL:
        genamode (curi->smode, "srcreg", curi->size, "cnt", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "data", 1, 0);
        start_brace ();
        switch (curi->size) {
         case sz_byte: printf ("\tuae_u32 val = (uae_u8)data;\r\n"); break;
         case sz_word: printf ("\tuae_u32 val = (uae_u16)data;\r\n"); break;
         case sz_long: printf ("\tuae_u32 val = data;\r\n"); break;
         default: abort ();
        }
        printf ("\tcnt &= 63;\r\n");
        printf ("\tCLEAR_CZNV;\r\n");
        printf ("\tif (cnt >= %d) {\r\n", bit_size (curi->size));
        printf ("\t\tSET_VFLG (val != 0);\r\n");
        printf ("\t\tSET_CFLG (cnt == %d ? val & 1 : 0);\r\n",
                bit_size (curi->size));
        duplicate_carry ();
        printf ("\t\tval = 0;\r\n");
        if (source_is_imm1_8 (curi))
            printf ("\t} else {\r\n");
        else
            printf ("\t} else if (cnt > 0) {\r\n");
        printf ("\t\tuae_u32 mask = (%s << (%d - cnt)) & %s;\r\n",
                bit_mask (curi->size),
                bit_size (curi->size) - 1,
                bit_mask (curi->size));
        printf ("\t\tSET_VFLG ((val & mask) != mask && (val & mask) != 0);\r\n");
        printf ("\t\tval <<= cnt - 1;\r\n");
        printf ("\t\tSET_CFLG ((val & %s) >> %d);\r\n", cmask (curi->size), bit_size (curi->size) - 1);
        duplicate_carry ();
        printf ("\t\tval <<= 1;\r\n");
        printf ("\t\tval &= %s;\r\n", bit_mask (curi->size));
        printf ("\t}\r\n");
        genflags (flag_logical_noclobber, curi->size, "val", "", "");
        genastore ("val", curi->dmode, "dstreg", curi->size, "data");
        break;
     case i_LSR:
        genamode (curi->smode, "srcreg", curi->size, "cnt", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "data", 1, 0);
        start_brace ();
        switch (curi->size) {
         case sz_byte: printf ("\tuae_u32 val = (uae_u8)data;\r\n"); break;
         case sz_word: printf ("\tuae_u32 val = (uae_u16)data;\r\n"); break;
         case sz_long: printf ("\tuae_u32 val = data;\r\n"); break;
         default: abort ();
        }
        printf ("\tcnt &= 63;\r\n");
        printf ("\tCLEAR_CZNV;\r\n");
        printf ("\tif (cnt >= %d) {\r\n", bit_size (curi->size));
        printf ("\t\tSET_CFLG ((cnt == %d) & (val >> %d));\r\n",
                bit_size (curi->size), bit_size (curi->size) - 1);
        duplicate_carry ();
        printf ("\t\tval = 0;\r\n");
        if (source_is_imm1_8 (curi))
            printf ("\t} else {\r\n");
        else
            printf ("\t} else if (cnt > 0) {\r\n");
        printf ("\t\tval >>= cnt - 1;\r\n");
        printf ("\t\tSET_CFLG (val & 1);\r\n");
        duplicate_carry ();
        printf ("\t\tval >>= 1;\r\n");
        printf ("\t}\r\n");
        genflags (flag_logical_noclobber, curi->size, "val", "", "");
        genastore ("val", curi->dmode, "dstreg", curi->size, "data");
        break;
     case i_LSL:
        genamode (curi->smode, "srcreg", curi->size, "cnt", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "data", 1, 0);
        start_brace ();
        switch (curi->size) {
         case sz_byte: printf ("\tuae_u32 val = (uae_u8)data;\r\n"); break;
         case sz_word: printf ("\tuae_u32 val = (uae_u16)data;\r\n"); break;
         case sz_long: printf ("\tuae_u32 val = data;\r\n"); break;
         default: abort ();
        }
        printf ("\tcnt &= 63;\r\n");
        printf ("\tCLEAR_CZNV;\r\n");
        printf ("\tif (cnt >= %d) {\r\n", bit_size (curi->size));
        printf ("\t\tSET_CFLG (cnt == %d ? val & 1 : 0);\r\n",
                bit_size (curi->size));
        duplicate_carry ();
        printf ("\t\tval = 0;\r\n");
        if (source_is_imm1_8 (curi))
            printf ("\t} else {\r\n");
        else
            printf ("\t} else if (cnt > 0) {\r\n");
        printf ("\t\tval <<= (cnt - 1);\r\n");
        printf ("\t\tSET_CFLG ((val & %s) >> %d);\r\n", cmask (curi->size), bit_size (curi->size) - 1);
        duplicate_carry ();
        printf ("\t\tval <<= 1;\r\n");
        printf ("\tval &= %s;\r\n", bit_mask (curi->size));
        printf ("\t}\r\n");
        genflags (flag_logical_noclobber, curi->size, "val", "", "");
        genastore ("val", curi->dmode, "dstreg", curi->size, "data");
        break;
     case i_ROL:
        genamode (curi->smode, "srcreg", curi->size, "cnt", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "data", 1, 0);
        start_brace ();
        switch (curi->size) {
         case sz_byte: printf ("\tuae_u32 val = (uae_u8)data;\r\n"); break;
         case sz_word: printf ("\tuae_u32 val = (uae_u16)data;\r\n"); break;
         case sz_long: printf ("\tuae_u32 val = data;\r\n"); break;
         default: abort ();
        }
        printf ("\tcnt &= 63;\r\n");
        printf ("\tCLEAR_CZNV;\r\n");
        if (source_is_imm1_8 (curi))
            printf ("{");
        else
            printf ("\tif (cnt > 0) {\r\n");
        printf ("\tuae_u32 loval;\r\n");
        printf ("\tcnt &= %d;\r\n", bit_size (curi->size) - 1);
        printf ("\tloval = val >> (%d - cnt);\r\n", bit_size (curi->size));
        printf ("\tval <<= cnt;\r\n");
        printf ("\tval |= loval;\r\n");
        printf ("\tval &= %s;\r\n", bit_mask (curi->size));
        printf ("\tSET_CFLG (val & 1);\r\n");
        printf ("}\r\n");
        genflags (flag_logical_noclobber, curi->size, "val", "", "");
        genastore ("val", curi->dmode, "dstreg", curi->size, "data");
        break;
     case i_ROR:
        genamode (curi->smode, "srcreg", curi->size, "cnt", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "data", 1, 0);
        start_brace ();
        switch (curi->size) {
         case sz_byte: printf ("\tuae_u32 val = (uae_u8)data;\r\n"); break;
         case sz_word: printf ("\tuae_u32 val = (uae_u16)data;\r\n"); break;
         case sz_long: printf ("\tuae_u32 val = data;\r\n"); break;
         default: abort ();
        }
        printf ("\tcnt &= 63;\r\n");
        printf ("\tCLEAR_CZNV;\r\n");
        if (source_is_imm1_8 (curi))
            printf ("{");
        else
            printf ("\tif (cnt > 0) {");
        printf ("\tuae_u32 hival;\r\n");
        printf ("\tcnt &= %d;\r\n", bit_size (curi->size) - 1);
        printf ("\thival = val << (%d - cnt);\r\n", bit_size (curi->size));
        printf ("\tval >>= cnt;\r\n");
        printf ("\tval |= hival;\r\n");
        printf ("\tval &= %s;\r\n", bit_mask (curi->size));
        printf ("\tSET_CFLG ((val & %s) >> %d);\r\n", cmask (curi->size), bit_size (curi->size) - 1);
        printf ("\t}\r\n");
        genflags (flag_logical_noclobber, curi->size, "val", "", "");
        genastore ("val", curi->dmode, "dstreg", curi->size, "data");
        break;
     case i_ROXL:
        genamode (curi->smode, "srcreg", curi->size, "cnt", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "data", 1, 0);
        start_brace ();
        switch (curi->size) {
         case sz_byte: printf ("\tuae_u32 val = (uae_u8)data;\r\n"); break;
         case sz_word: printf ("\tuae_u32 val = (uae_u16)data;\r\n"); break;
         case sz_long: printf ("\tuae_u32 val = data;\r\n"); break;
         default: abort ();
        }
        printf ("\tcnt &= 63;\r\n");
        printf ("\tCLEAR_CZNV;\r\n");
        if (! source_is_imm1_8 (curi))
            force_range_for_rox ("cnt", curi->size);
        if (source_is_imm1_8 (curi))
            printf ("{");
        else
            printf ("\tif (cnt > 0) {\r\n");
        printf ("\tcnt--;\r\n");
        printf ("\t{\r\n\tuae_u32 carry;\r\n");
        printf ("\tuae_u32 loval = val >> (%d - cnt);\r\n", bit_size (curi->size) - 1);
        printf ("\tcarry = loval & 1;\r\n");
        printf ("\tval = (((val << 1) | GET_XFLG) << cnt) | (loval >> 1);\r\n");
        printf ("\tSET_XFLG (carry);\r\n");
        printf ("\tval &= %s;\r\n", bit_mask (curi->size));
        printf ("\t} }\r\n");
        printf ("\tSET_CFLG (GET_XFLG);\r\n");
        genflags (flag_logical_noclobber, curi->size, "val", "", "");
        genastore ("val", curi->dmode, "dstreg", curi->size, "data");
        break;
     case i_ROXR:
        genamode (curi->smode, "srcreg", curi->size, "cnt", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "data", 1, 0);
        start_brace ();
        switch (curi->size) {
         case sz_byte: printf ("\tuae_u32 val = (uae_u8)data;\r\n"); break;
         case sz_word: printf ("\tuae_u32 val = (uae_u16)data;\r\n"); break;
         case sz_long: printf ("\tuae_u32 val = data;\r\n"); break;
         default: abort ();
        }
        printf ("\tcnt &= 63;\r\n");
        printf ("\tCLEAR_CZNV;\r\n");
        if (! source_is_imm1_8 (curi))
            force_range_for_rox ("cnt", curi->size);
        if (source_is_imm1_8 (curi))
            printf ("{");
        else
            printf ("\tif (cnt > 0) {\r\n");
        printf ("\tcnt--;\r\n");
        printf ("\t{\r\n\tuae_u32 carry;\r\n");
        printf ("\tuae_u32 hival = (val << 1) | GET_XFLG;\r\n");
        printf ("\thival <<= (%d - cnt);\r\n", bit_size (curi->size) - 1);
        printf ("\tval >>= cnt;\r\n");
        printf ("\tcarry = val & 1;\r\n");
        printf ("\tval >>= 1;\r\n");
        printf ("\tval |= hival;\r\n");
        printf ("\tSET_XFLG (carry);\r\n");
        printf ("\tval &= %s;\r\n", bit_mask (curi->size));
        printf ("\t} }\r\n");
        printf ("\tSET_CFLG (GET_XFLG);\r\n");
        genflags (flag_logical_noclobber, curi->size, "val", "", "");
        genastore ("val", curi->dmode, "dstreg", curi->size, "data");
        break;
     case i_ASRW:
        genamode (curi->smode, "srcreg", curi->size, "data", 1, 0);
        start_brace ();
        switch (curi->size) {
         case sz_byte: printf ("\tuae_u32 val = (uae_u8)data;\r\n"); break;
         case sz_word: printf ("\tuae_u32 val = (uae_u16)data;\r\n"); break;
         case sz_long: printf ("\tuae_u32 val = data;\r\n"); break;
         default: abort ();
        }
        printf ("\tuae_u32 sign = %s & val;\r\n", cmask (curi->size));
        printf ("\tuae_u32 cflg = val & 1;\r\n");
        printf ("\tval = (val >> 1) | sign;\r\n");
        genflags (flag_logical, curi->size, "val", "", "");
        printf ("\tSET_CFLG (cflg);\r\n");
        duplicate_carry ();
        genastore ("val", curi->smode, "srcreg", curi->size, "data");
        break;
     case i_ASLW:
        genamode (curi->smode, "srcreg", curi->size, "data", 1, 0);
        start_brace ();
        switch (curi->size) {
         case sz_byte: printf ("\tuae_u32 val = (uae_u8)data;\r\n"); break;
         case sz_word: printf ("\tuae_u32 val = (uae_u16)data;\r\n"); break;
         case sz_long: printf ("\tuae_u32 val = data;\r\n"); break;
         default: abort ();
        }
        printf ("\tuae_u32 sign = %s & val;\r\n", cmask (curi->size));
        printf ("\tuae_u32 sign2;\r\n");
        printf ("\tval <<= 1;\r\n");
        genflags (flag_logical, curi->size, "val", "", "");
        printf ("\tsign2 = %s & val;\r\n", cmask (curi->size));
        printf ("\tSET_CFLG (sign != 0);\r\n");
        duplicate_carry ();

        printf ("\tSET_VFLG (GET_VFLG | (sign2 != sign));\r\n");
        genastore ("val", curi->smode, "srcreg", curi->size, "data");
        break;
     case i_LSRW:
        genamode (curi->smode, "srcreg", curi->size, "data", 1, 0);
        start_brace ();
        switch (curi->size) {
         case sz_byte: printf ("\tuae_u32 val = (uae_u8)data;\r\n"); break;
         case sz_word: printf ("\tuae_u32 val = (uae_u16)data;\r\n"); break;
         case sz_long: printf ("\tuae_u32 val = data;\r\n"); break;
         default: abort ();
        }
        printf ("\tuae_u32 carry = val & 1;\r\n");
        printf ("\tval >>= 1;\r\n");
        genflags (flag_logical, curi->size, "val", "", "");
        printf ("SET_CFLG (carry);\r\n");
        duplicate_carry ();
        genastore ("val", curi->smode, "srcreg", curi->size, "data");
        break;
     case i_LSLW:
        genamode (curi->smode, "srcreg", curi->size, "data", 1, 0);
        start_brace ();
        switch (curi->size) {
         case sz_byte: printf ("\tuae_u8 val = data;\r\n"); break;
         case sz_word: printf ("\tuae_u16 val = data;\r\n"); break;
         case sz_long: printf ("\tuae_u32 val = data;\r\n"); break;
         default: abort ();
        }
        printf ("\tuae_u32 carry = val & %s;\r\n", cmask (curi->size));
        printf ("\tval <<= 1;\r\n");
        genflags (flag_logical, curi->size, "val", "", "");
        printf ("SET_CFLG (carry >> %d);\r\n", bit_size (curi->size) - 1);
        duplicate_carry ();
        genastore ("val", curi->smode, "srcreg", curi->size, "data");
        break;
     case i_ROLW:
        genamode (curi->smode, "srcreg", curi->size, "data", 1, 0);
        start_brace ();
        switch (curi->size) {
         case sz_byte: printf ("\tuae_u8 val = data;\r\n"); break;
         case sz_word: printf ("\tuae_u16 val = data;\r\n"); break;
         case sz_long: printf ("\tuae_u32 val = data;\r\n"); break;
         default: abort ();
        }
        printf ("\tuae_u32 carry = val & %s;\r\n", cmask (curi->size));
        printf ("\tval <<= 1;\r\n");
        printf ("\tif (carry)  val |= 1;\r\n");
        genflags (flag_logical, curi->size, "val", "", "");
        printf ("SET_CFLG (carry >> %d);\r\n", bit_size (curi->size) - 1);
        genastore ("val", curi->smode, "srcreg", curi->size, "data");
        break;
     case i_RORW:
        genamode (curi->smode, "srcreg", curi->size, "data", 1, 0);
        start_brace ();
        switch (curi->size) {
         case sz_byte: printf ("\tuae_u8 val = data;\r\n"); break;
         case sz_word: printf ("\tuae_u16 val = data;\r\n"); break;
         case sz_long: printf ("\tuae_u32 val = data;\r\n"); break;
         default: abort ();
        }
        printf ("\tuae_u32 carry = val & 1;\r\n");
        printf ("\tval >>= 1;\r\n");
        printf ("\tif (carry) val |= %s;\r\n", cmask (curi->size));
        genflags (flag_logical, curi->size, "val", "", "");
        printf ("SET_CFLG (carry);\r\n");
        genastore ("val", curi->smode, "srcreg", curi->size, "data");
        break;
     case i_ROXLW:
        genamode (curi->smode, "srcreg", curi->size, "data", 1, 0);
        start_brace ();
        switch (curi->size) {
         case sz_byte: printf ("\tuae_u8 val = data;\r\n"); break;
         case sz_word: printf ("\tuae_u16 val = data;\r\n"); break;
         case sz_long: printf ("\tuae_u32 val = data;\r\n"); break;
         default: abort ();
        }
        printf ("\tuae_u32 carry = val & %s;\r\n", cmask (curi->size));
        printf ("\tval <<= 1;\r\n");
        printf ("\tif (GET_XFLG) val |= 1;\r\n");
        genflags (flag_logical, curi->size, "val", "", "");
        printf ("SET_CFLG (carry >> %d);\r\n", bit_size (curi->size) - 1);
        duplicate_carry ();
        genastore ("val", curi->smode, "srcreg", curi->size, "data");
        break;
     case i_ROXRW:
        genamode (curi->smode, "srcreg", curi->size, "data", 1, 0);
        start_brace ();
        switch (curi->size) {
         case sz_byte: printf ("\tuae_u8 val = data;\r\n"); break;
         case sz_word: printf ("\tuae_u16 val = data;\r\n"); break;
         case sz_long: printf ("\tuae_u32 val = data;\r\n"); break;
         default: abort ();
        }
        printf ("\tuae_u32 carry = val & 1;\r\n");
        printf ("\tval >>= 1;\r\n");
        printf ("\tif (GET_XFLG) val |= %s;\r\n", cmask (curi->size));
        genflags (flag_logical, curi->size, "val", "", "");
        printf ("SET_CFLG (carry);\r\n");
        duplicate_carry ();
        genastore ("val", curi->smode, "srcreg", curi->size, "data");
        break;
     case i_MOVEC2:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        start_brace ();
        printf ("\tint regno = (src >> 12) & 15;\r\n");
        printf ("\tuae_u32 *regp = regs.regs + regno;\r\n");
        printf ("\tm68k_movec2(src & 0xFFF, regp);\r\n");
        break;
     case i_MOVE2C:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        start_brace ();
        printf ("\tint regno = (src >> 12) & 15;\r\n");
        printf ("\tuae_u32 *regp = regs.regs + regno;\r\n");
        printf ("\tm68k_move2c(src & 0xFFF, regp);\r\n");
        break;
     case i_CAS:
        {
            int old_brace_level;
            genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
            genamode (curi->dmode, "dstreg", curi->size, "dst", 1, 0);
            start_brace ();
            printf ("\tint ru = (src >> 6) & 7;\r\n");
            printf ("\tint rc = src & 7;\r\n");
            genflags (flag_cmp, curi->size, "newv", "m68k_dreg(regs, rc)", "dst");
            printf ("\tif (GET_ZFLG)");
            old_brace_level = n_braces;
            start_brace ();
            genastore ("(m68k_dreg(regs, ru))", curi->dmode, "dstreg", curi->size, "dst");
            pop_braces (old_brace_level);
            printf ("else");
            start_brace ();
            printf ("m68k_dreg(regs, rc) = dst;\r\n");
            pop_braces (old_brace_level);
        }
        break;
     case i_CAS2:
        genamode (curi->smode, "srcreg", curi->size, "extra", 1, 0);
        printf ("\tuae_u32 rn1 = regs.regs[(extra >> 28) & 15];\r\n");
        printf ("\tuae_u32 rn2 = regs.regs[(extra >> 12) & 15];\r\n");
        if (curi->size == sz_word) {
            int old_brace_level = n_braces;
            printf ("\tuae_u16 dst1 = get_word(rn1), dst2 = get_word(rn2);\r\n");
            genflags (flag_cmp, curi->size, "newv", "m68k_dreg(regs, (extra >> 16) & 7)", "dst1");
            printf ("\tif (GET_ZFLG) {\r\n");
            genflags (flag_cmp, curi->size, "newv", "m68k_dreg(regs, extra & 7)", "dst2");
            printf ("\tif (GET_ZFLG) {\r\n");
            printf ("\tput_word(rn1, m68k_dreg(regs, (extra >> 22) & 7));\r\n");
            printf ("\tput_word(rn1, m68k_dreg(regs, (extra >> 6) & 7));\r\n");
            printf ("\t}}\r\n");
            pop_braces (old_brace_level);
            printf ("\tif (! GET_ZFLG) {\r\n");
            printf ("\tm68k_dreg(regs, (extra >> 22) & 7) = (m68k_dreg(regs, (extra >> 22) & 7) & ~0xffff) | (dst1 & 0xffff);\r\n");
            printf ("\tm68k_dreg(regs, (extra >> 6) & 7) = (m68k_dreg(regs, (extra >> 6) & 7) & ~0xffff) | (dst2 & 0xffff);\r\n");
            printf ("\t}\r\n");
        } else {
            int old_brace_level = n_braces;
            printf ("\tuae_u32 dst1 = get_long(rn1), dst2 = get_long(rn2);\r\n");
            genflags (flag_cmp, curi->size, "newv", "m68k_dreg(regs, (extra >> 16) & 7)", "dst1");
            printf ("\tif (GET_ZFLG) {\r\n");
            genflags (flag_cmp, curi->size, "newv", "m68k_dreg(regs, extra & 7)", "dst2");
            printf ("\tif (GET_ZFLG) {\r\n");
            printf ("\tput_long(rn1, m68k_dreg(regs, (extra >> 22) & 7));\r\n");
            printf ("\tput_long(rn1, m68k_dreg(regs, (extra >> 6) & 7));\r\n");
            printf ("\t}}\r\n");
            pop_braces (old_brace_level);
            printf ("\tif (! GET_ZFLG) {\r\n");
            printf ("\tm68k_dreg(regs, (extra >> 22) & 7) = dst1;\r\n");
            printf ("\tm68k_dreg(regs, (extra >> 6) & 7) = dst2;\r\n");
            printf ("\t}\r\n");
        }
        break;
     case i_MOVES:              /* ignore DFC and SFC because we have no MMU */
        {
            int old_brace_level;
            genamode (curi->smode, "srcreg", curi->size, "extra", 1, 0);
            printf ("\tif (extra & 0x800)\r\n");
            old_brace_level = n_braces;
            start_brace ();
            printf ("\tuae_u32 src = regs.regs[(extra >> 12) & 15];\r\n");
            genamode (curi->dmode, "dstreg", curi->size, "dst", 2, 0);
            genastore ("src", curi->dmode, "dstreg", curi->size, "dst");
            pop_braces (old_brace_level);
            printf ("else");
            start_brace ();
            genamode (curi->dmode, "dstreg", curi->size, "src", 1, 0);
            printf ("\tif (extra & 0x8000) {\r\n");
            switch (curi->size) {
             case sz_byte: printf ("\tm68k_areg(regs, (extra >> 12) & 7) = (uae_s32)(uae_s8)src;\r\n"); break;
             case sz_word: printf ("\tm68k_areg(regs, (extra >> 12) & 7) = (uae_s32)(uae_s16)src;\r\n"); break;
             case sz_long: printf ("\tm68k_areg(regs, (extra >> 12) & 7) = src;\r\n"); break;
             default: abort ();
            }
            printf ("\t} else {\r\n");
            genastore ("src", Dreg, "(extra >> 12) & 7", curi->size, "");
            printf ("\t}\r\n");
            pop_braces (old_brace_level);
        }
        break;
     case i_BKPT:               /* only needed for hardware emulators */
        sync_m68k_pc ();
        printf ("\top_illg(opcode);\r\n");
        break;
     case i_CALLM:              /* not present in 68030 */
        sync_m68k_pc ();
        printf ("\top_illg(opcode);\r\n");
        break;
     case i_RTM:                /* not present in 68030 */
        sync_m68k_pc ();
        printf ("\top_illg(opcode);\r\n");
        break;
     case i_TRAPcc:
        if (curi->smode != am_unknown && curi->smode != am_illg)
            genamode (curi->smode, "srcreg", curi->size, "dummy", 1, 0);
        printf ("\tif (%s) { Exception(7,m68k_getpc()); goto %s; }\r\n", make_cctrue(curi->cc), endlabelstr);
        need_endlabel = 1;
        break;
     case i_DIVL:
        sync_m68k_pc ();
        start_brace ();
        printf ("\tuaecptr oldpc = m68k_getpc();\r\n");
        genamode (curi->smode, "srcreg", curi->size, "extra", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 1, 0);
        sync_m68k_pc ();
        printf ("\tm68k_divl(opcode, dst, extra, oldpc);\r\n");
        break;
     case i_MULL:
        genamode (curi->smode, "srcreg", curi->size, "extra", 1, 0);
        genamode (curi->dmode, "dstreg", curi->size, "dst", 1, 0);
        sync_m68k_pc ();
        printf ("\tm68k_mull(opcode, dst, extra);\r\n");
        break;
     case i_BFTST:
     case i_BFEXTU:
     case i_BFCHG:
     case i_BFEXTS:
     case i_BFCLR:
     case i_BFFFO:
     case i_BFSET:
     case i_BFINS:
        genamode (curi->smode, "srcreg", curi->size, "extra", 1, 0);
        genamode (curi->dmode, "dstreg", sz_long, "dst", 2, 0);
        start_brace ();
        printf ("\tuae_s32 offset = extra & 0x800 ? m68k_dreg(regs, (extra >> 6) & 7) : (extra >> 6) & 0x1f;\r\n");
        printf ("\tint width = (((extra & 0x20 ? m68k_dreg(regs, extra & 7) : extra) -1) & 0x1f) +1;\r\n");
        if (curi->dmode == Dreg) {
            printf ("\tuae_u32 tmp = m68k_dreg(regs, dstreg) << (offset & 0x1f);\r\n");
        } else {
            printf ("\tuae_u32 tmp,bf0,bf1;\r\n");
            printf ("\tdsta += (offset >> 3) | (offset & 0x80000000 ? ~0x1fffffff : 0);\r\n");
            printf ("\tbf0 = get_long(dsta);bf1 = get_byte(dsta+4) & 0xff;\r\n");
            printf ("\ttmp = (bf0 << (offset & 7)) | (bf1 >> (8 - (offset & 7)));\r\n");
        }
        printf ("\ttmp >>= (32 - width);\r\n");
        printf ("\tSET_NFLG (tmp & (1 << (width-1)) ? 1 : 0);\r\n");
        printf ("\tSET_ZFLG (tmp == 0); SET_VFLG (0); SET_CFLG (0);\r\n");
        switch (curi->mnemo) {
         case i_BFTST:
            break;
         case i_BFEXTU:
            printf ("\tm68k_dreg(regs, (extra >> 12) & 7) = tmp;\r\n");
            break;
         case i_BFCHG:
            printf ("\ttmp = ~tmp;\r\n");
            break;
         case i_BFEXTS:
            printf ("\tif (GET_NFLG) tmp |= width == 32 ? 0 : (-1 << width);\r\n");
            printf ("\tm68k_dreg(regs, (extra >> 12) & 7) = tmp;\r\n");
            break;
         case i_BFCLR:
            printf ("\ttmp = 0;\r\n");
            break;
         case i_BFFFO:
            printf ("\t{ uae_u32 mask = 1 << (width-1);\r\n");
            printf ("\twhile (mask) { if (tmp & mask) break; mask >>= 1; offset++; }}\r\n");
            printf ("\tm68k_dreg(regs, (extra >> 12) & 7) = offset;\r\n");
            break;
         case i_BFSET:
            printf ("\ttmp = 0xffffffff;\r\n");
            break;
         case i_BFINS:
            printf ("\ttmp = m68k_dreg(regs, (extra >> 12) & 7);\r\n");
            break;
         default:
            break;
        }
        if (curi->mnemo == i_BFCHG
            || curi->mnemo == i_BFCLR
            || curi->mnemo == i_BFSET
            || curi->mnemo == i_BFINS)
        {
            printf ("\ttmp <<= (32 - width);\r\n");
            if (curi->dmode == Dreg) {
                printf ("\tm68k_dreg(regs, dstreg) = (m68k_dreg(regs, dstreg) & ((offset & 0x1f) == 0 ? 0 :\r\n");
                printf ("\t\t(0xffffffff << (32 - (offset & 0x1f))))) |\r\n");
                printf ("\t\t(tmp >> (offset & 0x1f)) |\r\n");
                printf ("\t\t(((offset & 0x1f) + width) >= 32 ? 0 :\r\n");
                printf (" (m68k_dreg(regs, dstreg) & ((uae_u32)0xffffffff >> ((offset & 0x1f) + width))));\r\n");
            } else {
                printf ("\tbf0 = (bf0 & (0xff000000 << (8 - (offset & 7)))) |\r\n");
                printf ("\t\t(tmp >> (offset & 7)) |\r\n");
                printf ("\t\t(((offset & 7) + width) >= 32 ? 0 :\r\n");
                printf ("\t\t (bf0 & ((uae_u32)0xffffffff >> ((offset & 7) + width))));\r\n");
                printf ("\tput_long(dsta,bf0 );\r\n");
                printf ("\tif (((offset & 7) + width) > 32) {\r\n");
                printf ("\t\tbf1 = (bf1 & (0xff >> (width - 32 + (offset & 7)))) |\r\n");
                printf ("\t\t\t(tmp << (8 - (offset & 7)));\r\n");
                printf ("\t\tput_byte(dsta+4,bf1);\r\n");
                printf ("\t}\r\n");
            }
        }
        break;
     case i_PACK:
        if (curi->smode == Dreg) {
            printf ("\tuae_u16 val = m68k_dreg(regs, srcreg) + %s;\r\n", gen_nextiword ());
            printf ("\tm68k_dreg(regs, dstreg) = (m68k_dreg(regs, dstreg) & 0xffffff00) | ((val >> 4) & 0xf0) | (val & 0xf);\r\n");
        } else {
            printf ("\tuae_u16 val;\r\n");
            printf ("\tm68k_areg(regs, srcreg) -= areg_byteinc[srcreg];\r\n");
            printf ("\tval = (uae_u16)get_byte(m68k_areg(regs, srcreg));\r\n");
            printf ("\tm68k_areg(regs, srcreg) -= areg_byteinc[srcreg];\r\n");
            printf ("\tval = (val | ((uae_u16)get_byte(m68k_areg(regs, srcreg)) << 8)) + %s;\r\n", gen_nextiword ());
            printf ("\tm68k_areg(regs, dstreg) -= areg_byteinc[dstreg];\r\n");
            printf ("\tput_byte(m68k_areg(regs, dstreg),((val >> 4) & 0xf0) | (val & 0xf));\r\n");
        }
        break;
     case i_UNPK:
        if (curi->smode == Dreg) {
            printf ("\tuae_u16 val = m68k_dreg(regs, srcreg);\r\n");
            printf ("\tval = (((val << 4) & 0xf00) | (val & 0xf)) + %s;\r\n", gen_nextiword ());
            printf ("\tm68k_dreg(regs, dstreg) = (m68k_dreg(regs, dstreg) & 0xffff0000) | (val & 0xffff);\r\n");
        } else {
            printf ("\tuae_u16 val;\r\n");
            printf ("\tm68k_areg(regs, srcreg) -= areg_byteinc[srcreg];\r\n");
            printf ("\tval = (uae_u16)get_byte(m68k_areg(regs, srcreg));\r\n");
            printf ("\tval = (((val << 4) & 0xf00) | (val & 0xf)) + %s;\r\n", gen_nextiword ());
            printf ("\tm68k_areg(regs, dstreg) -= areg_byteinc[dstreg];\r\n");
            printf ("\tput_byte(m68k_areg(regs, dstreg),val);\r\n");
            printf ("\tm68k_areg(regs, dstreg) -= areg_byteinc[dstreg];\r\n");
            printf ("\tput_byte(m68k_areg(regs, dstreg),val >> 8);\r\n");
        }
        break;
     case i_TAS:
        genamode (curi->smode, "srcreg", curi->size, "src", 1, 0);
        genflags (flag_logical, curi->size, "src", "", "");
        printf ("\tsrc |= 0x80;\r\n");
        genastore ("src", curi->smode, "srcreg", curi->size, "src");
        break;
     case i_FPP:
        genamode (curi->smode, "srcreg", curi->size, "extra", 1, 0);
        sync_m68k_pc ();
        swap_opcode ();
        printf ("\tfpp_opp(opcode,extra);\r\n");
        break;
     case i_FDBcc:
        genamode (curi->smode, "srcreg", curi->size, "extra", 1, 0);
        sync_m68k_pc ();
        swap_opcode ();
        printf ("\tfdbcc_opp(opcode,extra);\r\n");
        break;
     case i_FScc:
        genamode (curi->smode, "srcreg", curi->size, "extra", 1, 0);
        sync_m68k_pc ();
        swap_opcode ();
        printf ("\tfscc_opp(opcode,extra);\r\n");
        break;
     case i_FTRAPcc:
        sync_m68k_pc ();
        start_brace ();
        printf ("\tuaecptr oldpc = m68k_getpc();\r\n");
        if (curi->smode != am_unknown && curi->smode != am_illg)
            genamode (curi->smode, "srcreg", curi->size, "dummy", 1, 0);
        sync_m68k_pc ();
        swap_opcode ();
        printf ("\tftrapcc_opp(opcode,oldpc);\r\n");
        break;
     case i_FBcc:
        sync_m68k_pc ();
        start_brace ();
        printf ("\tuaecptr pc = m68k_getpc();\r\n");
        genamode (curi->dmode, "srcreg", curi->size, "extra", 1, 0);
        sync_m68k_pc ();
        swap_opcode ();
        printf ("\tfbcc_opp(opcode,pc,extra);\r\n");
        break;
     case i_FSAVE:
        sync_m68k_pc ();
        swap_opcode ();
        printf ("\tfsave_opp(opcode);\r\n");
        break;
     case i_FRESTORE:
        sync_m68k_pc ();
        swap_opcode ();
        printf ("\tfrestore_opp(opcode);\r\n");
        break;
     case i_CINVL:
     case i_CINVP:
     case i_CINVA:
        sync_m68k_pc ();
        // insn_n_cycles += ??; // don't know how many cycles.
        break;
     case i_CPUSHL:
     case i_CPUSHP:
     case i_CPUSHA:
        sync_m68k_pc ();
        // insn_n_cycles += ??; // don't know how many cycles.
        break;
     case i_MOVE16:
        if ((opcode & 0xFFF8) == 0xF620) {
                printf ("\tm68k_incpc(2);\r\n");
                printf ("\tuae_u32 dstreg = (next_iword() >> 12) & 7;\r\n");
                printf ("#ifdef OPTIMIZED_8BIT_MEMORY_ACCESS\r\n");
                printf ("\tuae_u32 srcptr = ((uae_u32)get_real_address(m68k_areg(regs, srcreg) & 0xFFFFFFF0));\r\n");
                printf ("\tuae_u32 dstptr = ((uae_u32)get_real_address(m68k_areg(regs, dstreg) & 0xFFFFFFF0));\r\n");
                printf ("\tmemcpy( (void *)dstptr, (void *)srcptr, 16 );\r\n");
                printf ("#else\r\n");
                printf ("\tuae_u32 mems = (m68k_areg(regs, srcreg) & 0xFFFFFFF0);\r\n");
                printf ("\tuae_u32 memd = (m68k_areg(regs, dstreg) & 0xFFFFFFF0);\r\n");
                printf ("\tput_long(memd, get_long(mems));\r\n");
                printf ("\tput_long(memd+4, get_long(mems+4));\r\n");
                printf ("\tput_long(memd+8, get_long(mems+8));\r\n");
                printf ("\tput_long(memd+12, get_long(mems+12));\r\n");
                printf ("#endif\r\n");
                printf ("\tm68k_areg(regs, srcreg) += 16;\r\n");
                printf ("\tif(srcreg != dstreg)\r\n");
				                printf ("\t\tm68k_areg(regs, dstreg) += 16;\r\n");
        } else {
                printf ("\tm68k_incpc(2);\r\n");
                printf ("\tuae_u32 regptr = m68k_areg(regs, srcreg) & 0xFFFFFFF0;\r\n");
                printf ("\tuae_u32 address = next_ilong() & 0xFFFFFFF0;\r\n");
                printf ("\tswitch((opcode >> 3) & 3) {\r\n");
                        printf ("\t\tcase 0:\r\n");
                                printf ("\t\t\tput_long(address, get_long(regptr));\r\n");
                                printf ("\t\t\tput_long(address+4, get_long(regptr+4));\r\n");
                                printf ("\t\t\tput_long(address+8, get_long(regptr+8));\r\n");
                                printf ("\t\t\tput_long(address+12, get_long(regptr+12));\r\n");
                                printf ("\t\t\tm68k_areg(regs, srcreg) += 16;\r\n");
                                printf ("\t\t\tbreak;\r\n");
                        printf ("\t\tcase 1:\r\n");
                                printf ("\t\t\tput_long(regptr, get_long(address));\r\n");
                                printf ("\t\t\tput_long(regptr+4, get_long(address+4));\r\n");
                                printf ("\t\t\tput_long(regptr+8, get_long(address+8));\r\n");
                                printf ("\t\t\tput_long(regptr+12, get_long(address+12));\r\n");
                                printf ("\t\t\tm68k_areg(regs, srcreg) += 16;\r\n");
                                printf ("\t\t\tbreak;\r\n");
                        printf ("\t\tcase 2:\r\n");
                                printf ("\t\t\tput_long(address, get_long(regptr));\r\n");
                                printf ("\t\t\tput_long(address+4, get_long(regptr+4));\r\n");
                                printf ("\t\t\tput_long(address+8, get_long(regptr+8));\r\n");
                                printf ("\t\t\tput_long(address+12, get_long(regptr+12));\r\n");
                                printf ("\t\t\tbreak;\r\n");
                        printf ("\t\tcase 3:\r\n");
                                printf ("\t\t\tput_long(regptr, get_long(address));\r\n");
                                printf ("\t\t\tput_long(regptr+4, get_long(address+4));\r\n");
                                printf ("\t\t\tput_long(regptr+8, get_long(address+8));\r\n");
                                printf ("\t\t\tput_long(regptr+12, get_long(address+12));\r\n");
                                printf ("\t\t\tbreak;\r\n");
                printf ("\t}\r\n");
        }
        // insn_n_cycles += ??; // don't know how many cycles.
        m68k_pc_offset = 0;
        break;
     case i_MMUOP:
        genamode (curi->smode, "srcreg", curi->size, "extra", 1, 0);
        sync_m68k_pc ();
        swap_opcode ();
        printf ("\tmmu_op(opcode,extra);\r\n");
        break;
     default:
        abort ();
        break;
    }
    finish_braces ();
    sync_m68k_pc ();
}

static void generate_includes (FILE * f)
{
    fprintf (f, "#include \"sysdeps.h\"\r\n");
    fprintf (f, "#include \"m68k.h\"\r\n");
    fprintf (f, "#include \"memory.h\"\r\n");
    fprintf (f, "#include \"readcpu.h\"\r\n");
    fprintf (f, "#include \"newcpu.h\"\r\n");
    fprintf (f, "#include \"compiler.h\"\r\n");
    fprintf (f, "#include \"cputbl.h\"\r\n");
}

static int postfix;

static void generate_one_opcode (int rp)
{
    int i;
    uae_u16 smsk, dmsk;
    long int opcode = opcode_map[rp];

    if (table68k[opcode].mnemo == i_ILLG
        || table68k[opcode].clev > cpu_level)
        return;

    for (i = 0; lookuptab[i].name[0]; i++) {
        if (table68k[opcode].mnemo == lookuptab[i].mnemo)
            break;
    }

    if (table68k[opcode].handler != -1)
        return;

    if (opcode_next_clev[rp] != cpu_level) {
        fprintf (stblfile, "{ op_%lx_%d, 0, %ld }, /* %s */\r\n", opcode, opcode_last_postfix[rp],
                 opcode, lookuptab[i].name);
        return;
    }
    fprintf (stblfile, "{ op_%lx_%d, 0, %ld }, /* %s */\r\n", opcode, postfix, opcode, lookuptab[i].name);
    fprintf (headerfile, "extern cpuop_func op_%lx_%d;\r\n", opcode, postfix);
#if HAVE_VOID_CPU_FUNCS
    printf ("void REGPARAM2 op_%lx_%d(uae_u32 opcode) /* %s */\r\n{\r\n", opcode, postfix, lookuptab[i].name);
#else
    printf ("unsigned long REGPARAM2 op_%lx_%d(uae_u32 opcode) /* %s */\r\n{\r\n", opcode, postfix, lookuptab[i].name);
#endif
    printf ("CPUOP_PREFIX(opcode);\r\n");

    switch (table68k[opcode].stype) {
     case 0: smsk = 7; break;
     case 1: smsk = 255; break;
     case 2: smsk = 15; break;
     case 3: smsk = 7; break;
     case 4: smsk = 7; break;
     case 5: smsk = 63; break;
     default: abort ();
    }
    dmsk = 7;

    next_cpu_level = -1;
    if (table68k[opcode].suse
        && table68k[opcode].smode != imm && table68k[opcode].smode != imm0
        && table68k[opcode].smode != imm1 && table68k[opcode].smode != imm2
        && table68k[opcode].smode != absw && table68k[opcode].smode != absl
        && table68k[opcode].smode != PC8r && table68k[opcode].smode != PC16)
    {
        if (table68k[opcode].spos == -1) {
            if (((int) table68k[opcode].sreg) >= 128)
                printf ("\tuae_u32 srcreg = (uae_s32)(uae_s8)%d;\r\n", (int) table68k[opcode].sreg);
            else
                printf ("\tuae_u32 srcreg = %d;\r\n", (int) table68k[opcode].sreg);
        } else {
            char source[100];
            int pos = table68k[opcode].spos;

#if 0
            /* Check that we can do the little endian optimization safely.  */
            if (pos < 8 && (smsk >> (8 - pos)) != 0)
                abort ();
#endif
            printf ("#ifdef HAVE_GET_WORD_UNSWAPPED\r\n");

            if (pos < 8 && (smsk >> (8 - pos)) != 0)
                sprintf (source, "(((opcode >> %d) | (opcode << %d)) & %d)",
                        pos ^ 8, 8 - pos, dmsk);
            else if (pos != 8)
                sprintf (source, "((opcode >> %d) & %d)", pos ^ 8, smsk);
            else
                sprintf (source, "(opcode & %d)", smsk);

            if (table68k[opcode].stype == 3)
                printf ("\tuae_u32 srcreg = imm8_table[%s];\r\n", source);
            else if (table68k[opcode].stype == 1)
                printf ("\tuae_u32 srcreg = (uae_s32)(uae_s8)%s;\r\n", source);
            else
                printf ("\tuae_u32 srcreg = %s;\r\n", source);

            printf ("#else\r\n");

            if (pos)
                sprintf (source, "((opcode >> %d) & %d)", pos, smsk);
            else
                sprintf (source, "(opcode & %d)", smsk);

            if (table68k[opcode].stype == 3)
                printf ("\tuae_u32 srcreg = imm8_table[%s];\r\n", source);
            else if (table68k[opcode].stype == 1)
                printf ("\tuae_u32 srcreg = (uae_s32)(uae_s8)%s;\r\n", source);
            else
                printf ("\tuae_u32 srcreg = %s;\r\n", source);

            printf ("#endif\r\n");
        }
    }
    if (table68k[opcode].duse
        /* Yes, the dmode can be imm, in case of LINK or DBcc */
        && table68k[opcode].dmode != imm && table68k[opcode].dmode != imm0
        && table68k[opcode].dmode != imm1 && table68k[opcode].dmode != imm2
        && table68k[opcode].dmode != absw && table68k[opcode].dmode != absl)
    {
        if (table68k[opcode].dpos == -1) {
            if (((int) table68k[opcode].dreg) >= 128)
                printf ("\tuae_u32 dstreg = (uae_s32)(uae_s8)%d;\r\n", (int) table68k[opcode].dreg);
            else
                printf ("\tuae_u32 dstreg = %d;\r\n", (int) table68k[opcode].dreg);
        } else {
            int pos = table68k[opcode].dpos;
#if 0
            /* Check that we can do the little endian optimization safely.  */
            if (pos < 8 && (dmsk >> (8 - pos)) != 0)
                abort ();
#endif
            printf ("#ifdef HAVE_GET_WORD_UNSWAPPED\r\n");

            if (pos < 8 && (dmsk >> (8 - pos)) != 0)
                printf ("\tuae_u32 dstreg = ((opcode >> %d) | (opcode << %d)) & %d;\r\n",
                        pos ^ 8, 8 - pos, dmsk);
            else if (pos != 8)
                printf ("\tuae_u32 dstreg = (opcode >> %d) & %d;\r\n",
                        pos ^ 8, dmsk);
            else
                printf ("\tuae_u32 dstreg = opcode & %d;\r\n", dmsk);

            printf ("#else\r\n");

            if (pos)
                printf ("\tuae_u32 dstreg = (opcode >> %d) & %d;\r\n",
                        pos, dmsk);
            else
                printf ("\tuae_u32 dstreg = opcode & %d;\r\n", dmsk);

            printf ("#endif\r\n");
        }
    }
    need_endlabel = 0;
    endlabelno++;
    sprintf (endlabelstr, "endlabel%d", endlabelno);
    gen_opcode (opcode);
    if (need_endlabel)
        printf ("%s: ;\r\n", endlabelstr);

#if !HAVE_VOID_CPU_FUNCS
    // I want to keep the return value, but a nonsense value! :)
    insn_n_cycles = 100;
    printf ("return %d;\r\n", insn_n_cycles);
#endif

    printf ("}\r\n");
    opcode_next_clev[rp] = next_cpu_level;
    opcode_last_postfix[rp] = postfix;
}

static void generate_func (void)
{
    int i, j, rp;

    using_prefetch = 0;
    using_exception_3 = 0;
    for (i = 0; i < 5/*6*/; i++) {
        cpu_level = 4 - i;
        if (i == 5) {
            cpu_level = 0;
            using_prefetch = 1;
            using_exception_3 = 1;
            for (rp = 0; rp < nr_cpuop_funcs; rp++)
                opcode_next_clev[rp] = 0;
        }
        postfix = i;
        fprintf (stblfile, "struct cputbl op_smalltbl_%d[] = {\r\n", postfix);

        /* sam: this is for people with low memory (eg. me :)) */
        /*
        printf ("\r\n"
                "#if !defined(PART_1) && !defined(PART_2) && "
                    "!defined(PART_3) && !defined(PART_4) && "
                    "!defined(PART_5) && !defined(PART_6) && "
                    "!defined(PART_7) && !defined(PART_8)"
                "\r\n"
                "#define PART_1 1\r\n"
                "#define PART_2 1\r\n"
                "#define PART_3 1\r\n"
                "#define PART_4 1\r\n"
                "#define PART_5 1\r\n"
                "#define PART_6 1\r\n"
                "#define PART_7 1\r\n"
                "#define PART_8 1\r\n"
                "#endif\r\n\r\n");
        */
        printf ("\r\n");

        rp = 0;
        for(j=1;j<=8;++j) {
                int k = (j*nr_cpuop_funcs)/8;
                // printf ("#ifdef PART_%d\r\n",j);
                for (; rp < k; rp++)
                   generate_one_opcode (rp);
                // printf ("#endif\r\n\r\n");
                printf ("\r\n");
        }

        fprintf (stblfile, "{ 0, 0, 0 }};\r\n");
    }
}

int main (int argc, char **argv)
{
    read_table68k ();
    do_merges ();

    opcode_map = (int *) malloc (sizeof (int) * nr_cpuop_funcs);
    opcode_last_postfix = (int *) malloc (sizeof (int) * nr_cpuop_funcs);
    opcode_next_clev = (int *) malloc (sizeof (int) * nr_cpuop_funcs);
    counts = (unsigned long *) malloc (65536 * sizeof (unsigned long));
    read_counts ();

    /* It would be a lot nicer to put all in one file (we'd also get rid of
     * cputbl.h that way), but cpuopti can't cope.  That could be fixed, but
     * I don't dare to touch the 68k version.  */

    headerfile = fopen ("cputbl.h", "wb");
    stblfile = fopen ("cpustbl.cpp", "wb");
    freopen ("cpuemu.cpp", "wb", stdout);

    generate_includes (stdout);
    generate_includes (stblfile);

    fprintf (stdout, "#include \"cpuemu.h\"\r\n");
    fprintf (stdout, "#include \"counter.h\"\r\n");
    fprintf (stdout, "extern \"C\" {\r\n");

    fprintf (headerfile, "extern \"C\" {\r\n");

    generate_func ();

    fprintf (stdout, "}\r\n");
    fprintf (headerfile, "}\r\n");

    free (table68k);
    return 0;
}
