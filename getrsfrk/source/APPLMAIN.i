/*	APPLMAIN.c	Copyright (C) 2010 Paul C. Pratt	You can redistribute this file and/or modify it under the terms	of version 2 of the GNU General Public License as published by	the Free Software Foundation.  You should have received a copy	of the license along with this file; see the file COPYING.	This file is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the	license for more details.*//*	APPLication MAIN*/LOCALVAR MyDir_R BaseDirR;LOCALFUNC tMyErr DoFilter2(void){	tMyErr err;	Str255 dst_s;	MyDir_R src_d;	Str255 src_s;	short src_refnum;	short dst_refnum;	uimr n;	PStrFromCStr(dst_s, "bin");	GetInputFile(&src_d, src_s);	if (noErr == (err = MyCreateFileOverWrite_v2(&BaseDirR, dst_s))) {#if 0		if (noErr == (err = MyFileSetTypeCreator_v2(&BaseDirR, dst_s,			creator, fileType)))#endif		if (noErr == (err = MyFileOpenRFRead(&src_d, src_s, &src_refnum))) {			if (noErr == (err = MyOpenFileGetEOF_v2(src_refnum, &n))) {				if (noErr == (err = ProgressBar_SetStage_v2("Copying resource data", n))) {					if (noErr == (err = MyFileOpenWrite_v2(&BaseDirR, dst_s, &dst_refnum))) {						if (noErr == (err = MyOpenFileSetEOF_v2(dst_refnum, n))) {							if (noErr == (err = MyFileCopyBytes_v2(src_refnum, dst_refnum, n))) {							}						}						err = CombineErr(err, MyCloseFile_v2(dst_refnum));					}				}			}			err = CombineErr(err, MyCloseFile_v2(src_refnum));		}		if (noErr != err) {			(void) MyDeleteFile_v2(&BaseDirR, dst_s);				/* ignore any error, since already got one */		}	}	return err;}LOCALPROC ProgramMain(void){	vCheckSysErr(ProgressBar_SetStage_v2("Ready for a resource file\311", 0));label_1:	WaitForInput();	if (GotInputCur) {		if (! CheckSysErr(DoFilter2())) {			ClearInputA();			vCheckSysErr(ProgressBar_SetStage_v2("Aborted, ready for another file\311", 0));		} else {			vCheckSysErr(ProgressBar_SetStage_v2("Done, ready for another file\311", 0));		}		CloseInputCur();		goto label_1;	}}LOCALPROC ProgramZapVars(void){}LOCALPROC ProgramPreInit(void){	OneWindAppPreInit();}LOCALFUNC blnr ProgramInit(void){	if (CheckSysErr(MyMemory_Init_v2()))	if (CheckSysErr(OneWindAppInit_v2()))	if (CheckSysErr(MyHGetDir_v2(&BaseDirR)))	{		return trueblnr;	}	return falseblnr;}LOCALPROC ProgramUnInit(void){	OneWindAppUnInit();	MyMemory_UnInit();}int main(void){	ProgramZapVars();	ProgramPreInit();	if (ProgramInit()) {		ProgramMain();	}	ProgramUnInit();	return 0;}