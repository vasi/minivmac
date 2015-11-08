/*	SYMTABLS.i	Copyright (C) 2008 Paul C. Pratt	You can redistribute this file and/or modify it under the terms	of version 2 of the GNU General Public License as published by	the Free Software Foundation.  You should have received a copy	of the license along with this file; see the file COPYING.	This file is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the	license for more details.*//*	SYMbol TABLeS*/LOCALVAR uimr sym_Calloc = 0;LOCALVAR uimr sym_Talloc = 0;LOCALVAR ui3h sym_C = nullpr;LOCALVAR ui5h sym_A = nullpr;LOCALVAR ui5h sym_T = nullpr;LOCALVAR uimr sym_B[sym_NTables];LOCALVAR uimr sym_E[sym_NTables];LOCALVAR uimr sym_Tn = 0;LOCALVAR uimr sym_Cn = 0;LOCALPROC sym_dispose(void){	MyNHandleClear((Handle *)&sym_C);	MyNHandleClear((Handle *)&sym_A);	MyNHandleClear((Handle *)&sym_T);	sym_Calloc = 0;	sym_Talloc = 0;	sym_Tn = 0;	sym_Cn = 0;}LOCALFUNC tMyErr sym_openTable_v2(MyDir_R *d, ui4r table){	return token_open_v2(d, sym_TableName(table), nullpr);}LOCALFUNC tMyErr sym_countTable_v2(MyDir_R *d, ui4r table){	/*		figure out how big it is, if		in valid format.	*/	tMyErr err;	if (noErr == (err = sym_openTable_v2(d, table))) {		while (token_kEof != token_kind) {			token_advance();			sym_Calloc += PStrLength(token_peek);			++sym_Talloc;			token_advance();		}		err = CombineErr(err, token_close_v2());	}	return err;}LOCALFUNC tMyErr sym_loadone_v2(uimr address, ps3p gsymbol){	tMyErr err;	uimr NewTlast = sym_Tn + 1;	uimr NewClast = sym_Cn + PStrLength(gsymbol);	if (NewClast > sym_Calloc) {		MyAlertFromCStr("NewClast full");		err = kMyErrReported;	} else if (NewTlast > sym_Talloc) {		MyAlertFromCStr("NewTlast full");		err = kMyErrReported;	} else {		MyMoveBytes(PStrToPtr(gsymbol),			&(*sym_C)[sym_Cn], PStrToSize(gsymbol));		(*sym_A)[sym_Tn] = address;		(*sym_T)[sym_Tn] = NewClast;		sym_Cn = NewClast;		sym_Tn = NewTlast;		err = noErr;	}	return err;}#ifndef sym_sorted#define sym_sorted 1#endifLOCALFUNC tMyErr sym_loadTable_v2(MyDir_R *d, ui4r table){	tMyErr err;	uimr address;	uimr lastaddress;	if (noErr == (err = sym_openTable_v2(d, table))) {		if (token_kEof == token_kind) {			/* ok */		} else {			address = token_getHex2Uimr();			if (noErr == (err = sym_loadone_v2(address, token_peek))) {				token_advance();label_retry:				ProgressBarVal = sym_Cn;				if (token_kEof == token_kind) {					/* ok */				} else if (noErr != (err = CheckAbortRequested())) {				} else {					lastaddress = address;					address = token_getHex2Uimr();#if sym_sorted					if (address <= lastaddress) {						MyPStr s;						PStrFromCStr(s,							"error : loadTable - must be sorted ");						PStrApndUimr2Hex(s, lastaddress);						MyAlertFromPStr(s);						err = kMyErrReported;					} else#endif					{						if (noErr == (err = sym_loadone_v2(address,							token_peek)))						{							token_advance();							goto label_retry;						}					}				}			}		}		err = CombineErr(err, token_close_v2());	}	return err;}LOCALFUNC tMyErr sym_countTables_v2(MyDir_R *d){	tMyErr err;	ui4r x;	if (noErr == (err = ProgressBar_SetStage_v2(		"Finding size of symbolic names\311", sym_NTables)))	{		sym_Calloc = 0;		sym_Talloc = 0;		++sym_Talloc;		for (x = 0; x < sym_NTables; ++x) {			ProgressBarVal = x;			if (noErr != (err = CheckAbortRequested())) {				goto error_exit;			}			err = sym_countTable_v2(d, x);			if (noErr != err) {				goto error_exit;			}		}	}error_exit:	return err;}LOCALFUNC tMyErr sym_loadTables_v2(MyDir_R *d){	tMyErr err;	ui4r x;	if (noErr == (err = ProgressBar_SetStage_v2(		"Loading symbolic names\311", sym_Calloc)))	{		sym_Cn = 0;		sym_Tn = 0;		(*sym_T)[sym_Tn] = sym_Cn;		sym_Tn++;		for (x = 0; x < sym_NTables; ++x) {			sym_B[x] = sym_Tn;			err = sym_loadTable_v2(d, x);			if (noErr != err) {				goto error_exit;			}			sym_E[x] = sym_Tn;		}	}error_exit:	return err;}GLOBALFUNC tMyErr sym_load_v2(MyDir_R *d){	tMyErr err;	if (noErr == (err = sym_countTables_v2(d)))	if (noErr == (err = MyHandleNew_v2(sym_Calloc, (Handle *)&sym_C)))	if (noErr == (err = MyHandleNew_v2(sizeof(long) * sym_Talloc,		(Handle *)&sym_A)))	if (noErr == (err = MyHandleNew_v2(sizeof(long) * sym_Talloc,		(Handle *)&sym_T)))	if (noErr == (err = sym_loadTables_v2(d)))	{		if (sym_Tn != sym_Talloc) {			MyAlertFromCStr("sym_Talloc wrong");			err = kMyErrReported;		} else if (sym_Cn != sym_Calloc) {			MyAlertFromCStr("sym_Calloc wrong");			err = kMyErrReported;		} else {			/* ok */		}	}	return err;}LOCALPROC sym_get(uimr where, ps3p gsymbol){	uimr x1 = (*sym_T)[where - 1];	uimr x2 = (*sym_T)[where];	PStrFromPtr((MyPtr)&(*sym_C)[x1], x2 - x1, gsymbol);}#if sym_sortedLOCALVAR Boolean sym_found;LOCALVAR uimr sym_where; /* index into sym_A */LOCALPROC sym_search(ui4r table, uimr address){	uimr bottom;	uimr top;	uimr i;	uimr v;	uimr *p = *sym_A; /* assuming sym_A won't move after this */	bottom = sym_B[table];	top = sym_E[table];	if (bottom < top) {		--top;		do {			i = (bottom + top) / 2;			v = p[i];			if (v < address) {				bottom = i + 1;			} else if (v > address) {				top = i - 1;			} else {				sym_found = true;				sym_where = i;				return;			}		} while (bottom <= top);		sym_where = i;	}	sym_found = false;}LOCALPROC sym_translate(ui4r table, uimr address, ps3p gsymbol){	sym_search(table, address);	if (! sym_found) {		PStrCopy(gsymbol, (StringPtr)"\p**undefined**");	} else {		sym_get(sym_where, gsymbol);	}}#endifLOCALVAR uimr sym_iterI;LOCALVAR uimr sym_iterLimit;LOCALVAR uimr sym_iterAddr;LOCALVAR uimr sym_iterS;LOCALVAR blnr sym_iterDone;LOCALPROC sym_iterNext(void){	if (sym_iterI < sym_iterLimit) {		sym_iterAddr = (*sym_A)[sym_iterI];		sym_iterS = sym_iterI;		++sym_iterI;	} else {		sym_iterDone = trueblnr;	}}LOCALPROC sym_iterBegin(ui4r table){	sym_iterI = sym_B[table];	sym_iterLimit = sym_E[table];	sym_iterDone = falseblnr;	sym_iterNext();}