/*	Copyright (C) 2002 Paul Pratt	You can redistribute this file and/or modify it under the terms	of version 2 of the GNU General Public License as published by	the Free Software Foundation.  You should have received a copy	of the license along with with this file; see the file COPYING.	This file is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the	license for more details.*/#include "MYMACAPI.i"#define WantOptMoveBytes 1#include "COREDEFS.i"#include "POW2UTIL.i"#include "STRUTILS.i"#include "SAVEDERR.i"#include "MACENVRN.i"#include "MACINITS.i"#include "FILEUTIL.i"#if 0#include "DEBUGLOG.i"#endif#include "MYMEMORY.i"#include "CMDARGW1.i"#if 0#define MyAlertFromCStr(s) fprintf(stdout, "%s\n", s);#endif#define MyAlertFromCStr DisplayRunErr#define MyAlertFromPStr AlertUserFromPStr#include "HEXCONVR.i"#include "STRMOUTT.i"#include "STREAMIN.i"#include "TOKENIZR.i"#include "BINPRGIN.i"#include "BINPRMAP.i"#include "PRIQUEUE.i"#include "REFERMAX.i"enum {	sym_kTableRel,	sym_NTables};LOCALFUNC ps3p sym_TableName(ui4r table){	ps3p p = NULL;	switch (table) {		case sym_kTableRel:			p = (StringPtr)"\pbin_names";			break;	}	return p;}#include "SYMTABLS.i"/* -- numconv -- */#define extb(x) ((simr)(si3r)(x))#define extw(x) ((simr)(si4r)(x))/* -- dumbhacks.h -- *//* for using maptype unit */#define binmap_kIsCode 2#define binmap_kIsNotCode 3/* addressing reference type */#define ref_kData 1#define ref_kAlter 2#define ref_kBranch 4#define ref_kSub 5#define ref_kExt 6/* -- makesym -- */LOCALVAR simr nd;LOCALVAR simr nl;LOCALVAR simr np;LOCALVAR simr ne;LOCALPROC GetNextAvailSymbolIndices(void){	Str255 s;	MyCharR *p;	MyCharR c;	si4r n;	simr *v;	simr x;	uimr where = sym_B[sym_kTableRel];	uimr stop = sym_E[sym_kTableRel];	nd = -1;	nl = -1;	np = -1;	ne = -1;	while (where < stop) {		sym_get(where, s);		++where;		v = nullpr;		n = PStrLength(s);		if (n > 0) {			p = PStrToMyCharPtr(s);			switch (*p++) {				case 'E':					if ('_' == *p++) {						n -= 2;						v = &ne;					} else {						goto label_nextsym;					}					break;				case 'P':					--n;					v = &np;					break;				case 'L':					--n;					v = &nl;					break;				case 'D':					if ('T' == *p++) {						n -= 2;						v = &nd;					} else {						goto label_nextsym;					}					break;				default:					goto label_nextsym;					break;			}		}		x = 0;		while (n != 0) {			c = *p++;			--n;			if ((c >= '0') && (c <= '9')) {				x = (x * 10) + (c - '0');			} else {				goto label_nextsym;			}		}		if (x > *v) {			*v = x;		}label_nextsym:		;	}	nd += 1;	nl += 1;	np += 1;	ne += 1;}LOCALPROC domakesym_writeln(uimr address, ps3p s){	strmo_Uimr2Hex(address);	strmo_writeSpace();	strmo_writeChar('"');	strmo_writePStr(s);	strmo_writeChar('"');	strmo_writeReturn();}LOCALPROC process_cur_sym(void){	Str255 s;	sym_get(sym_iterS, s);	domakesym_writeln(sym_iterAddr, s);	sym_iterNext();}LOCALPROC NewSymbolName(uimr addr, ui4r what){	Str255 Temp_Str255_1;	Str255 sym;	ps3p p;	long i;	switch (what) {		case ref_kData:		case ref_kAlter:			i = nd;			p = (StringPtr)"\pDT";			nd++;			break;		case ref_kBranch:			i = nl;			p = (StringPtr)"\pL";			nl++;			break;		case ref_kSub:			i = np;			p = (StringPtr)"\pP";			np++;			break;		case ref_kExt:			i = ne;			p = (StringPtr)"\pE_";			ne++;			break;	}	PStrCopy(sym, p);	NumToString(i, Temp_Str255_1);	PStrAppend(sym, Temp_Str255_1);	domakesym_writeln(addr, sym);}LOCALFUNC blnr domakesym(MyDir_R *d){	uimr x;	uimr addr;	ui4r what;	uimr lref;	blnr IsOk = falseblnr;	GetNextAvailSymbolIndices();	if (CheckSysErr(strmo_open_v2(d, (StringPtr)"\pbin_names"))) {		sym_iterBegin(sym_kTableRel);		lref = -1;		for (x = 0; x < ref_n; ++x) {			addr = (*ref_addr)[x];			what = (*ref_kind)[x];			if (addr != lref) { /* skip duplicates */				lref = addr;				while ((! sym_iterDone) && (sym_iterAddr < addr)) {					process_cur_sym();				}				if ((! sym_iterDone) && (sym_iterAddr == addr)) {					process_cur_sym(); /* keep old name */				} else {					NewSymbolName(addr, what);				}			}		}		while (! sym_iterDone) {			process_cur_sym();		}		IsOk = (noErr == SavedSysErr);		(void) CheckSysErr(strmo_close_v2());	}	return IsOk;}LOCALPROC writeref(uimr addr, ui4r what){	/* writeln('writing ref from ', ' to ref ', addr, ' what ', what); */	if (what >= 4 && what <= 6) {		(void) CheckSysErr(prq_insert_v2(addr));	}	(void) CheckSysErr(ref_add_v2(addr, what));}/* -- tracer -- */LOCALVAR long tce_size;LOCALVAR blnr tce_stop;LOCALVAR Boolean tce_error;LOCALVAR Boolean tce_unhandled;LOCALVAR Boolean tce_any_unhandled;LOCALPROC tr_disp_ea(void){	ui4b dp = prgin_readWord();	if (dp & 0x0100) {		switch ((dp >> 4) & 0x03) {			case 2:				(void) prgin_readWord();				break;			case 3:				(void) prgin_readLong();				break;			default:				break;		}		if ((dp & 0x03) != 0) {			switch (dp & 0x03) {				case 2:					(void) prgin_readWord();					break;				case 3:					(void) prgin_readLong();					break;				default:					break;			}		}	}}LOCALPROC tr_pcdisp_ea(void){	simr offset = 0;	simr ci = prgin_i;	ui4b dp = prgin_readWord();	if (dp & 0x0100) {		switch ((dp >> 4) & 0x03) {			case 2:				offset = (si5b)(si4b)prgin_readWord();				break;			case 3:				offset = prgin_readLong();				break;			default:				break;		}		if ((dp & 0x80) != 0) {			offset = 0; /* suppress */		}		if ((dp & 0x03) != 0) {			switch (dp & 0x03) {				case 2:					(void) prgin_readWord();					break;				case 3:					(void) prgin_readLong();					break;				default:					break;			}		}	} else {		offset = (si3b)(dp);	}	if (offset != 0) {		writeref(ci + offset, ref_kData /* 0 - adtype */);	}}LOCALPROC tr_adec(long mode, long reg, ui4r adtype){	/* decodes the addressing modes, and calls absref to record referencing statistics */	simr offset;	simr ci;	switch (mode) {		case 5:			(void) prgin_readWord();			break;		case 6:			tr_disp_ea();			break;		case 7:			switch (reg) {				case 0:					(void) prgin_readWord();					break;				case 1:					(void) prgin_readLong();					break;				case 2:					ci = prgin_i;					offset = extw(prgin_readWord());					writeref(offset + ci, adtype);					break;				case 3:					tr_pcdisp_ea();					break;				case 4:					switch (tce_size) {						case 1:							(void) prgin_readWord();							break;						case 2:							(void) prgin_readWord();							break;						case 4:							(void) prgin_readLong();							break;					}					break;			}			break;		case 9:			ci = prgin_i;			if (reg == 0) {				offset = extw(prgin_readWord());			} else if (reg == 255) {				offset = (simr) prgin_readLong();			} else {				offset = extb(reg);			}			writeref(offset + ci, adtype);			break;	}}LOCALPROC tr_aline(long by1, long by2){#pragma unused(by2)	tce_size = 0;	if (AndBits(by1, 12) == 12) {		tce_stop = trueblnr;	}}LOCALPROC tr_invalidopcode(void){	tce_stop = trueblnr;	tce_error = true;		/* at prgin_i */}LOCALPROC tr_unhandledopcode(void){	tce_stop = trueblnr;	tce_unhandled = true;		/* at prgin_i */}LOCALVAR long tce_mode;LOCALVAR long tce_reg;LOCALVAR long tce_rg9;LOCALVAR long tce_b76;LOCALPROC tr_findsize(void){	switch (tce_b76) {		case 0:			tce_size = 1;			break;		case 1:			tce_size = 2;			break;		case 2:			tce_size = 4;			break;	}}LOCALPROC tr_decodeone(void){	ui4r opcode;	long by1;	long by2;	long b8;	long cond;	long nib1;	opcode = prgin_readWord();	by1 = (opcode >> 8) & 255;            /* bits 8 ..15 */	by2 = opcode & 255;                   /* bits 0 .. 7 */	tce_reg = AndBits(by2, 7);             /* bits 0 .. 2 */	tce_mode = AndBits(by2, 56) / 8;       /* bits 3 .. 5 */	tce_b76 = AndBits(by2, 192) / 64;      /* bits 6 .. 7 */	b8 = AndBits(by1, 1);                  /* bit  8      */	cond = AndBits(by1, 15);               /* bits 8 ..11 */	tce_rg9 = AndBits(by1, 14) / 2;        /* bits 9 ..11 */	nib1 = AndBits(by1, 240) / 16;         /* bits 12..15 */	switch (nib1) {		case 0:			if (b8 == 1) {				if (tce_mode == 1) {					/* MoveP Opcode = 0000ddd1mm001aaa */					tce_size = AndBits(tce_b76, 1) * 2 + 2;					if (tce_b76 < 2) {						tr_adec(5, tce_reg, ref_kData);						tr_adec(0, tce_reg, ref_kAlter);					} else {						tr_adec(0, tce_reg, ref_kData);						tr_adec(5, tce_reg, ref_kAlter);					}				} else {					/* bitop; dynamic bit, Opcode = 0000ddd1ttmmmrrr */					tce_size = 1;					tr_adec(0, tce_rg9, ref_kData);					tr_adec(tce_mode, tce_reg, ref_kData);				}			} else {				if (tce_rg9 == 4) {					/* bitop; static bit, Opcode = 00001010ssmmmrrr */					tce_size = 1;					tr_adec(7, 4, ref_kData);					tr_adec(tce_mode, tce_reg, ref_kData);				} else {					tr_findsize();					tr_adec(7, 4, ref_kData);					if (AndBits(by1, 4) == 0 && tce_mode == 7 && tce_reg == 4) {#if 0						if (tce_b76 == 0) {							tr_adec(10, 0, ref_kData);						} else {							tr_adec(10, 1, ref_kData);						}#endif					} else {						tr_adec(tce_mode, tce_reg, ref_kAlter);					}				}			}			break;		case 1:		case 2:		case 3:			/* Move */			switch (nib1) {				case 1:					tce_size = 1;					break;				case 2:					tce_size = 4;					break;				case 3:					tce_size = 2;					break;			}			tr_adec(tce_mode, tce_reg, ref_kData);			tr_adec(b8 * 4 + tce_b76, tce_rg9, ref_kAlter);			break;		case 4:			/* Opcode = 4xxx */			if (b8 == 1) {				switch (tce_b76) {					case 1:						tr_invalidopcode();						break;					case 0:					case 2:						/* op := 'Chk';  Opcode = 0100ddd1s0mmmrrr */						tce_size = 4 - tce_b76;						tr_adec(tce_mode, tce_reg, ref_kData);						tr_adec(0, tce_rg9, ref_kData);						break;					case 3:						/* op := 'Lea';  Opcode = 0100aaa111mmmrrr */						tce_size = 4;						tr_adec(tce_mode, tce_reg, ref_kData);						tr_adec(1, tce_rg9, ref_kAlter);						break;				}			} else {				switch (tce_rg9) {					case 0:						if (tce_b76 != 3) {							/* op := 'NegX';  Opcode = 01000000ssmmmrrr */							tr_findsize();							tr_adec(tce_mode, tce_reg, ref_kAlter);						} else {							/* op := 'Move';  Opcode = 0100000011mmmrrr */							tce_size = 2;							/* tr_adec(10, am10_SR, ref_kData); */							tr_adec(tce_mode, tce_reg, ref_kAlter);						}						break;					case 1:						if (tce_b76 != 3) {							/* op := 'Clr';  Opcode = 01000010ssmmmrrr */							tr_findsize();							tr_adec(tce_mode, tce_reg, ref_kAlter);						} else {							/* op := 'Move';  Opcode = 0100001011mmmrrr */							tce_size = 2;							/* tr_adec(10, am10_CCR, ref_kData); */							tr_adec(tce_mode, tce_reg, ref_kAlter);						}						break;					case 2:						if (tce_b76 != 3) {							/* op := 'Neg'; Opcode = 01000100ssmmmrrr */							tr_findsize();							tr_adec(tce_mode, tce_reg, ref_kAlter);						} else {							/* op := 'Move';  Opcode = 0100010011mmmrrr */							tce_size = 2;							tr_adec(tce_mode, tce_reg, ref_kData);							/* tr_adec(10, am10_CCR, ref_kAlter); */						}						break;					case 3:						if (tce_b76 != 3) {							/* op := 'Not'; Opcode = 01000110ssmmmrrr */							tr_findsize();							tr_adec(tce_mode, tce_reg, ref_kAlter);						} else {							/* op := 'Move';  Opcode = 0100011011mmmrrr */							tce_size = 2;							tr_adec(tce_mode, tce_reg, ref_kAlter);							/* tr_adec(10, 1, ref_kData); */						}						break;					case 4:						switch (tce_b76) {							case 0:								/* op := 'Nbcd';  Opcode = 0100100000mmmrrr */								tce_size = 1;								tr_adec(tce_mode, tce_reg, ref_kAlter);								break;							case 1:								if (tce_mode == 0) {									/* op := 'Swap';  Opcode = 0100100001000rrr */									tce_size = 2;									tr_adec(0, tce_reg, ref_kAlter);								} else {									/* op := 'Pea';  Opcode = 0100100001mmmrrr */									tce_size = 4;									tr_adec(tce_mode, tce_reg, ref_kData);								}								break;							case 2:							case 3:								if (tce_mode == 0) {									/* op := 'Ext';  Opcode = 010010001s000ddd */									tce_size = 2 * tce_b76 - 2;									tr_adec(tce_mode, tce_reg, ref_kAlter);								} else {									/* op := 'MoveM';  Opcode = 010010001smmmrrr */									tce_size = 2 * tce_b76 - 2;#if 0									if (tce_mode == 4) {										tr_adec(10, am10_pre, ref_kData);									} else {										tr_adec(10, am10_post, ref_kData);									}#endif									(void) prgin_readWord();									tr_adec(tce_mode, tce_reg, ref_kAlter);								}								break;						}						break;					case 5:						if (tce_b76 != 3) {							/* op := 'Tst'; Opcode = 01001010ssmmmrrr */							tr_findsize();							tr_adec(tce_mode, tce_reg, ref_kData);						} else {							/* op := 'Tas';  Opcode = 0100101011mmmrrr */							tce_size = 1;							tr_adec(tce_mode, tce_reg, ref_kData);						}						break;					case 6:						/* op := 'MoveM';  Opcode = 010011001smmmrrr */						tce_size = 2 * tce_b76 - 2;#if 0						tr_adec(10, am10_post, ref_kAlter);#endif						(void) prgin_readWord();						tr_adec(tce_mode, tce_reg, ref_kData);						break;					case 7:						switch (tce_b76) {							case 0:								tr_invalidopcode();								break;							case 1:								switch (tce_mode) {									case 0:									case 1:										/* op := 'Trap';  Opcode = 010011100100vvvv */										/* tce_size = 0; */										/* tr_adec(8, AndBits(by2, 15), ref_kData); */										break;									case 2:										/* op := 'Link';  Opcode = 0100111001010aaa */										tce_size = 2;										tr_adec(1, tce_reg, ref_kAlter);										tr_adec(7, 4, ref_kData);										break;									case 3:										/* op := 'Unlk';  Opcode = 0100111001011aaa */										tce_size = 0;										tr_adec(1, tce_reg, ref_kAlter);										break;									case 4:										/* op := 'Move';  Opcode = 0100111001100aaa */										tce_size = 4;										tr_adec(1, tce_reg, ref_kData);										/* tr_adec(10, am10_USP, ref_kAlter); */										break;									case 5:										/* op := 'Move';  Opcode = 0100111001101aaa */										tce_size = 4;										/* tr_adec(10, am10_USP, ref_kData); */										tr_adec(1, tce_reg, ref_kAlter);										break;									case 6:										tce_size = 0;										if (tce_reg > 1) {											tce_stop = trueblnr;										}										switch (tce_reg) {											case 2: /* Stop, Opcode = 0100111001110010 */											case 4: /* Rtd, Opcode = 0100111001110100 */												tce_size = 2;												tr_adec(7, 4, ref_kData);												break;											case 0: /* Reset, Opcode = 0100111001100000 */											case 1: /* Nop,  0100111001110001 */											case 3: /* Rte, Opcode = 0100111001110011 */											case 5: /* Rts, Opcode = 0100111001110101 */											case 6: /* TrapV, Opcode = 0100111001110110 */											case 7: /* Rtr, Opcode = 0100111001110111 */												break;										}										break;									case 7:										if (AndBits(tce_reg, 6) == 2) {											/* op := 'MOVEC'; */											/* not correct, but will do */											tce_size = 2;											tr_adec(7, 4, ref_kData);										} else {											tr_invalidopcode();										}										break;								}								break;							case 2:								/* op := 'Jsr';  Opcode = 0100111010mmmrrr */								tce_size = 0;								tr_adec(tce_mode, tce_reg, ref_kSub);								break;							case 3:								/* op := 'Jmp';  Opcode = 0100111011mmmrrr */								tce_size = 0;								tr_adec(tce_mode, tce_reg, ref_kBranch);								tce_stop = trueblnr;								break;						}						break;				}			}			break;		case 5:			/* Opcode = 5xxx */			if (tce_b76 == 3) {				if (tce_mode == 1) {					/* concod('DB');  Opcode = 0101cccc11001ddd */					tce_size = 2;					tr_adec(0, tce_reg, ref_kAlter);					tr_adec(7, 2, ref_kBranch);				} else {					/* concod('S');   Opcode = 0101cccc11mmmrrr */					tce_size = 1;					tr_adec(tce_mode, tce_reg, ref_kAlter);				}			} else {				/* AddQ,SubQ Opcode = 0101nnntssmmmrrr */				/* tr_adec(8, tr_octdat(tce_rg9), ref_kData); */				tr_adec(tce_mode, tce_reg, ref_kAlter);			}			break;		case 6:			/* Opcode = 6xxx */			if (cond == 1) {				/* op := 'Bsr';  Opcode = 01100001nnnnnnnn */				tce_size = 0;				tr_adec(9, by2, ref_kSub);			} else {				if (cond == 0) {                          /* op := 'Bra'; Opcode = 01100000nnnnnnnn */					tce_stop = trueblnr;				}				tce_size = 0;				tr_adec(9, by2, ref_kBranch);    /* also Bcc Opcode = 0110ccccnnnnnnnn */			}			break;		case 7:			/* op := 'MoveQ';  Opcode = 0111ddd0nnnnnnnn */			/* tce_size = 4; */			/* tr_adec(8, extb(by2), ref_kData); */			/* tr_adec(0, tce_rg9, ref_kAlter); */			break;		case 8:			/* Opcode = 8xxx */			if (tce_b76 == 3) {				/* DivU/S Opcode = 1000dddt11mmmrrr */				tce_size = 2;				tr_adec(tce_mode, tce_reg, ref_kData);				tr_adec(0, tce_rg9, ref_kAlter);			} else if (b8 == 1 && tce_mode < 2) {				/* op := 'Sbcd';   Opcode = 1000xxx10000mxxx */				/* tce_size = 1; */				/* tr_blahcode(); */			} else {				/* op := 'Or';    Opcode = 1000dddmssmmmrrr */				tr_findsize();				if (b8 == 1) {					tr_adec(0, tce_rg9, ref_kData);					tr_adec(tce_mode, tce_reg, ref_kAlter);				} else {					tr_adec(tce_mode, tce_reg, ref_kData);					tr_adec(0, tce_rg9, ref_kAlter);				}			}			break;		case 9:		case 13:			tr_findsize();			/* ADD/Sub Opcode = 1t01dddmssmmmrrr */			if (tce_b76 == 3) {				/* op := concat(op,'A');  Opcode = 1t01dddm11mmmrrr */				tce_size = b8 * 2 + 2;				tr_adec(tce_mode, tce_reg, ref_kData);				tr_adec(1, tce_rg9, ref_kAlter);			} else if (b8 == 0) {				tr_adec(tce_mode, tce_reg, ref_kData);				tr_adec(0, tce_rg9, ref_kAlter);			} else if (tce_mode < 2) {				/* tr_blahcode(); */			} else {				tr_adec(0, tce_rg9, ref_kData);				tr_adec(tce_mode, tce_reg, ref_kAlter);			}			break;		case 10:			/* Opcode = Axxx */			tr_aline(by1, by2);			break;		case 11:			/* Opcode = Bxxx */			if (tce_b76 == 3) {				/* op := 'CmpA';  Opcode = 1011ddds11mmmrrr */				tce_size = b8 * 2 + 2;				tr_adec(tce_mode, tce_reg, ref_kData);				tr_adec(1, tce_rg9, ref_kData);			} else if (b8 == 1 && tce_mode == 1) {				/* op := 'CmpM';  Opcode = 1011ddd1ss001rrr */				tr_findsize();				tr_adec(3, tce_reg, ref_kData);				tr_adec(3, tce_rg9, ref_kData);			} else if (b8 == 1) {				/* op := 'Eor';  Opcode = 1011ddd1ssmmmrrr */				tr_findsize();				tr_adec(0, tce_rg9, ref_kData);				tr_adec(tce_mode, tce_reg, ref_kAlter);			} else {				/* op := 'Cmp';  Opcode = 1011ddd0ssmmmrrr */				tr_findsize();				tr_adec(tce_mode, tce_reg, ref_kData);				tr_adec(0, tce_rg9, ref_kData);			}			break;		case 12:			/* Opcode = Cxxx */			if (tce_b76 == 3) {				/* MulU/MulW Opcode = 1100dddt11mmmrrr */				tce_size = 2;				tr_adec(tce_mode, tce_reg, ref_kData);				tr_adec(0, tce_rg9, ref_kAlter);			} else if (tce_mode < 2) {				switch (tce_b76) {					case 0:						/* op := 'Abcd';  Opcode = 1100ddd10000mrrr */						/* tce_size = 1; */						/* tr_blahcode(); */						break;					case 1:						/* op := 'Exg';   Opcode = 1100ddd10100trrr */						tce_size = 4;						tr_adec(tce_mode, tce_rg9, ref_kAlter);						tr_adec(tce_mode, tce_reg, ref_kAlter);						break;					case 2:						/* op := 'Exg';   Opcode = 1100ddd110001rrr */						tce_size = 4;						tr_adec(0, tce_rg9, ref_kAlter);						tr_adec(1, tce_reg, ref_kAlter);						break;				}			} else {				/* op := 'And';    Opcode = 1100dddmssmmmrrr */				tr_findsize();				if (b8 == 1) {					tr_adec(0, tce_rg9, ref_kData);					tr_adec(tce_mode, tce_reg, ref_kAlter);				} else {					tr_adec(tce_mode, tce_reg, ref_kData);					tr_adec(0, tce_rg9, ref_kAlter);				}			}			break;		case 14:			/* Opcode = Exxx */			if (tce_b76 == 3) {				if ((opcode & 0x0800) != 0) {					/* bit fields */					(void) prgin_readWord();					tce_size = 0;					tr_adec(tce_mode, tce_reg, ref_kData);				} else {					/* rolops(rg9);  Opcode = 11100tt111mmmrrr */					tce_size = 2;					tr_adec(tce_mode, tce_reg, ref_kAlter);				}			} else {				/* rolops(AndBits(mode, 3)); */				tr_findsize();				if (tce_mode < 4) {             /* Opcode = 1110cccdss0ttddd */					/* tr_adec(8, tr_octdat(tce_rg9), ref_kData); */				} else {                                  /* Opcode = 1110rrrdss1ttddd */					tr_adec(0, tce_rg9, ref_kData);				}				tr_adec(0, tce_reg, ref_kAlter);			}			break;		case 15:			/* Opcode = Fxxx */			/* tr_invalidopcode(); */			tr_unhandledopcode();			break;	}}LOCALVAR uimr problem_address;LOCALPROC doreporttracererr(void){	MyPStr t;	MyPStr Temp_Str255_1;	PStrFromCStr(t, "reached unrecognized instruction at ");	Uimr2Hex(problem_address, Temp_Str255_1);	PStrAppend(t, Temp_Str255_1);	AlertUserFromPStr(t);#if 0	MyAlertFromCStr("reached unrecognized instruction");#endif}LOCALPROC doreporttracerwarning(void){	MyPStr t;	MyPStr Temp_Str255_1;	PStrFromCStr(t, "reached instruction not yet supported at ");	Uimr2Hex(problem_address, Temp_Str255_1);	PStrAppend(t, Temp_Str255_1);	AlertUserFromPStr(t);#if 0	MyAlertFromCStr("reached unrecognized instruction");#endif}LOCALPROC dotracer(void){	rngtp r;	uimr start;	uimr i_start;	while (prq_deletemin(&start)) {		binmap_find(start, &r);		if (binmap_kUnexplored == r.kind) {			prgin_seek(start);			tce_stop = falseblnr;			do {#if 0				strmo_writeCStr("Instruction at ");				strmo_Uimr2Hex(prgin_i);				strmo_writeReturn();#endif				i_start = prgin_i;				tr_decodeone();			} while ((! tce_stop) && (prgin_i < r.top));			if (tce_error) {				problem_address = i_start;				return;			} else if (tce_unhandled) {				tce_unhandled = falseblnr;				if (! tce_any_unhandled) {					problem_address = i_start;					tce_any_unhandled = trueblnr;				}				CheckSysErr(binmap_set_v2(start, i_start, binmap_kIsCode));				CheckSysErr(binmap_set_v2(i_start, prgin_i, 4));			} else {				CheckSysErr(binmap_set_v2(start, prgin_i, binmap_kIsCode));			}		} else if (binmap_kIsCode != r.kind) {			tce_error = true;			MyAlertFromCStr("reached non code");			return;		}	}}/* -- DisemSet -- */LOCALPROC ListInputUtil(void){	MyPStr s;	uimr address;	while (! The_arg_end) {		GetCurArgAsPStr(s);		if (PStrIsHexNumber(s)) {			address = Hex2Uimr(s);			writeref(address, ref_kExt);			AdvanceTheArg();		} else {			ReportParseFailure("I was expecting an address in hexadecimal");			return;		}	}}/* ****************************************************************** */LOCALVAR MyDir_R BaseDirR;enum {	gestaltOSAttr                 = FOUR_CHAR_CODE('os  '),	gestaltSysZoneGrowable        = 0,	gestaltLaunchCanReturn        = 1,	gestaltLaunchFullFileSpec     = 2,	gestaltLaunchControl          = 3,	gestaltTempMemSupport         = 4,	gestaltRealTempMemory         = 5,	gestaltTempMemTracked         = 6,	gestaltIPCSupport             = 7,	gestaltSysDebuggerSupport     = 8};LOCALPROC LaunchTheSubApp(void){	HParamBlockRec infor;	LaunchParamBlockRec r;	FSSpec theSpec;	OSErr err;	theSpec.vRefNum = BaseDirR.VRefNum;	theSpec.parID = BaseDirR.DirId;	PStrFromCStr(theSpec.name, "FDisasm");	err = MyFileGetInfo_v2(&BaseDirR, theSpec.name, &infor);	if ((noErr == err) && (infor.fileParam.ioFlFndrInfo.fdType == 'APPL'))	/* if (MyResolveAliasNoUI(&theSpec)) */	{		long reply;		if (HaveGestaltAvail()			&& (noErr == Gestalt(gestaltOSAttr, &reply))			&& TestBit(reply, gestaltLaunchFullFileSpec))		{			r.reserved1 = 0;			r.reserved2 = 0;			r.launchBlockID = extendedBlock;			r.launchEPBLength = extendedBlockLen;			r.launchFileFlags = 0;			r.launchControlFlags = launchContinue				| launchNoFileFlags;			r.launchAppSpec = &theSpec;			r.launchAppParameters = NULL;		} else {			r.reserved1 = (long)theSpec.name;			r.reserved2 = 0;		}		err = LaunchApplication((LaunchPBPtr)&r);		if (fnfErr == err) {			/* ok */		} else if (CheckSysErr(err)) {			/* SubAppPsn = r.launchProcessSN; */		}	}}LOCALVAR WantLaunchFDisasm = falseblnr;LOCALPROC DoTheCommand(void){	if (CheckSysErr(prgin_open_v2(&BaseDirR, (StringPtr)"\pbin")))	if (CheckSysErr(binmap_load_v2(&BaseDirR, (StringPtr)"\pbin_map")))	if (CheckSysErr(sym_load_v2(&BaseDirR)))	{		ListInputUtil();		tce_unhandled = falseblnr;		tce_any_unhandled = falseblnr;		tce_error = false;		dotracer();#if 0		if (CheckSysErr(strmo_open_v2(&BaseDirR, (StringPtr)"\pdebug"))) {			(void) CheckSysErr(strmi_close_v2());		}#endif		if (tce_error) {			doreporttracererr();		} else {			if (tce_any_unhandled) {				doreporttracerwarning();			}			if (noErr == SavedSysErr)			if (domakesym(&BaseDirR))			{				(void) CheckSysErr(binmap_save_v2(&BaseDirR, (StringPtr)"\pbin_map"));				WantLaunchFDisasm = trueblnr;			}		}	}	ref_dispose();	prq_dispose();	sym_dispose();	binmap_dispose();	(void) CheckSysErr(prgin_close_v2());}LOCALPROC ProgramZapVars(void){}LOCALPROC ProgramPreInit(void){	OneWindAppPreInit();}LOCALFUNC blnr ProgramInit(void){#ifdef Have_DEBUGLOG	if (CheckSysErr(dbglog_open()))#endif	if (CheckSysErr(MyHGetDir_v2(&BaseDirR)))	if (CheckSysErr(OneWindAppInit_v2()))	{		return trueblnr;	}	return falseblnr;}LOCALPROC ProgramUnInit(void){	OneWindAppUnInit();#ifdef Have_DEBUGLOG	(void) dbglog_close();#endif}LOCALPROC ProgramMain(void){	do {		WaitForInput();		if (GoRequested) {			BeginParseFromTE();			DoTheCommand();			EndParseFromTE();			GoRequested = falseblnr;			if (WantLaunchFDisasm) {				LaunchTheSubApp(); /* may not come back */				WantLaunchFDisasm = falseblnr;			}		}	} while ((! ProgramDone) && (! GoRequested));}int main(void){	ProgramZapVars();	ProgramPreInit();	if (ProgramInit()) {		ProgramMain();	}	ProgramUnInit();	return 0;}