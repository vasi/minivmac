/*
	SPARSEBDL.h

	Copyright (C) 2015 Dave Vasilevsky

	You can redistribute this file and/or modify it under the terms
	of version 2 of the GNU General Public License as published by
	the Free Software Foundation.  You should have received a copy
	of the license along with this file; see the file COPYING.

	This file is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	license for more details.
*/

#ifdef SPARSEBL_H
#error "header already included"
#else
#define SPARSEBL_H
#endif

#if HaveSparseBundle

/* Check if a given drive is a sparsebundle */
EXPORTFUNC blnr DiskIsSB(tDrive Drive_No);

/* Initialize/uninitialize any sparsebundle data */
EXPORTPROC InitSB(void);
EXPORTPROC UnInitSB(void);

/* Try to open a sparsebundle, return whether it succeeded */
EXPORTFUNC blnr SBOpen(sbpt Path);

/* Close a sparsebundle */
EXPORTFUNC tMacErr SBClose(tDrive Drive_No);

/* Transfer data to/from a sparsebundle */
EXPORTFUNC tMacErr SBTransfer(blnr IsWrite, ui3p Buffer,
	tDrive Drive_No, uimr Offset, uimr Count,
	ui5r *ActCount);

/* Get the size of a sparsebundle */
GLOBALFUNC tMacErr SBGetSize(tDrive Drive_No, ui5r *Size);

#endif
