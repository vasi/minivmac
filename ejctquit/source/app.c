/*	app.c	Copyright (C) 2012 Paul Pratt	You can redistribute this file and/or modify it under the terms	of version 2 of the GNU General Public License as published by	the Free Software Foundation.  You should have received a copy	of the license along with this file; see the file COPYING.	This file is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the	license for more details.*/#include "MYMACAPI.i"#include "COREDEFS.i"#include "POW2UTIL.i"#include "MACENVRN.i"#include "MACINITS.i"#include "SAVEDERR.i"#include "EXTNSLIB.i"#define MKC_Shift 0x38#define ROMBase 0x02AE#define kDSK_Block_Base 0x00F40000#define kDSK_QuitOnEject 3LOCALPROC DiskOldQuitOnEject(void){	/*		if extension mechanism not present, see if this is old Mini vMac	*/	MyDriverDat_R *SonyVars = (MyDriverDat_R *)get_long(SonyVarsPtr);	if ((SonyVars != NULL)		&& ((1 & (ui5r)SonyVars) == 0)			/* for emulators like sheepshaver */		&& (SonyVars->zeroes[0] == 0)		&& (SonyVars->zeroes[1] == 0)		&& (SonyVars->zeroes[2] == 0)		/* && (SonyVars->zeroes[3] == 0) */		)	{		Ptr StartAddr = *(Ptr *)ROMBase;		if (StartAddr == (Ptr)0x00400000) {			ui5b CheckSum = get_long(StartAddr);			if ((CheckSum == 0x4D1EEEE1)				|| (CheckSum == 0x4D1EEAE1)				|| (CheckSum == 0x4D1F8172))			{				/* this is a Mac Plus, now check for patches */				if ((get_word(StartAddr + 3450) == 0x6022)					&& (get_word(StartAddr + 3752) == 0x4E71)					&& (get_word(StartAddr + 3728) == 0x4E71))				{					/* yes, this is old Mini vMac */					/* so set QuitOnEject the old way */					((short *)kDSK_Block_Base)[kDSK_QuitOnEject] = 1;				}			}		}	}}int main(void){	tMyErr err;	ui3b theKeys[16];	MyMacHeapInit();	MyMacToolBoxInit();	GetKeys(*(KeyMap *)theKeys);	if ((theKeys[MKC_Shift / 8] & (1 << (MKC_Shift & 7))) == 0) {		/* shift key not pressed */		err = DiskQuitOnEject();		if (kMyErrNoExtn == err) {			DiskOldQuitOnEject();		}	}}