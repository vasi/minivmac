/*	WRDMCFLS.i	Copyright (C) 2010 Paul C. Pratt	You can redistribute this file and/or modify it under the terms	of version 2 of the GNU General Public License as published by	the Free Software Foundation.  You should have received a copy	of the license along with this file; see the file COPYING.	This file is distributed in the hope that it will be useful,	but WITHOUT ANY WARRANTY; without even the implied warranty of	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the	license for more details.*//*	WRite Digital Mars Compiler specific FiLeS*/#pragma segment DMCSupportLOCALPROC WriteMainRsrcObjDMCbuild(void){	WriteBgnDestFileLn();	WriteCStrToDestFile("rcc.exe -o");	WriteMainRsrcObjPath();	WriteCStrToDestFile(" ");	WriteMainRsrcSrcPath();	WriteEndDestFileLn();}LOCALPROC WriteDMCclMakeFile(void){	WriteDestFileLn("# make file generated by gryphel build system");	WriteBlankLineToDestFile();	WriteDestFileLn("mk_COptions = -c -r -WA");	/* -o+space seems to generate bad code, compiler version 8.42n */	WriteBlankLineToDestFile();	WriteBgnDestFileLn();	WriteCStrToDestFile("TheDefaultOutput:");	WriteMakeDependFile(WriteAppNamePath);	WriteEndDestFileLn();	WriteBlankLineToDestFile();	WriteBlankLineToDestFile();	vCheckWriteDestErr(DoAllSrcFilesWithSetup(DoSrcFileMakeCompile));	WriteBlankLineToDestFile();	WriteDestFileLn("ObjFiles  = \\");	++DestFileIndent;		DoAllSrcFilesStandardMakeObjects();		WriteBlankLineToDestFile();	--DestFileIndent;	WriteBlankLineToDestFile();	WriteMakeRule(WriteMainRsrcObjPath,		WriteMainRsrcObjMSCdeps, WriteMainRsrcObjDMCbuild);	WriteBlankLineToDestFile();	WriteBgnDestFileLn();	WriteAppNamePath();	WriteCStrToDestFile(": $(ObjFiles) ");	WriteMainRsrcObjPath();	WriteEndDestFileLn();	++DestFileIndent;	WriteBgnDestFileLn();	WriteCStrToDestFile(		"dmc.exe -L/exet:nt/su:windows:4.0 $(ObjFiles) ");	WriteMainRsrcObjPath();	WriteCStrToDestFile(" -o\"");	WriteAppNamePath();	WriteCStrToDestFile(		"\" winmm.lib ole32.lib uuid.lib comdlg32.lib shell32.lib"		" gdi32.lib");	WriteEndDestFileLn();	--DestFileIndent;	WriteBlankLineToDestFile();	WriteDestFileLn("clean:");	++DestFileIndent;		DoAllSrcFilesStandardErase();		WriteRmFile(WriteMainRsrcObjPath);		WriteRmFile(WriteAppNamePath);	--DestFileIndent;}LOCALFUNC tMyErr WriteDMCSpecificFiles(void){	return WriteADestFile(&OutputDirR,		"Makefile", "", WriteDMCclMakeFile);}