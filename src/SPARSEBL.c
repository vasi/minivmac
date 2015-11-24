/*
	SPARSEBDL.c

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

/*
	SPARSEBunDLe disk support.
*/

#ifndef AllFiles
#include "SYSDEPNS.h"
#include "EMCONFIG.h"
#include "MYOSGLUE.h"
#endif

#include "SPARSEBL.h"

#if HaveSparseBundle

IMPORTFUNC blnr FirstFreeDisk(tDrive *Drive_No);
IMPORTPROC DiskInsertNotify(tDrive Drive_No, blnr locked);
IMPORTPROC DiskEjectedNotify(tDrive Drive_No);


#define kSBCachedBands 16
/* Enough room for 32-bits in hex chars, plus trailing zero */
#define kSBBandNameSize 9

typedef enum {
	kSBBandInit, /* Uninitialized */
	kSBBandMissing, /* File doesn't exist */
	kSBBandFile, /* File is open */
} SparseBundleBandStatus;

/* A single band of a sparsebundle */
typedef struct {
	SparseBundleBandStatus Status;
	tDrive Drive_No;
	uimr Index;
	sbfl File;
	uimr DataSize;
} SparseBundleBand;

typedef struct {
	sbpt Path;
	uimr TotalSize;
	uimr BandSize;
	sbfl LockFile;
} SparseBundle;


LOCALVAR ui5b SparseBundleInsertedMask;
LOCALVAR SparseBundle SparseBundles[NumDrives];
LOCALVAR SparseBundleBand SparseBundleBands[kSBCachedBands];
LOCALVAR uimr SparseBundleBandEvict;


/* Insert/eject a sparsebundle disk */
LOCALPROC SBDiskInsert(tDrive Drive_No, blnr Locked);
LOCALPROC SBDiskEject(tDrive Drive_No);


/* Parse a sparsebundle plist */
LOCALFUNC blnr SBPlistParse(sbfl File, uimr *BandSize, uimr *TotalSize);


/* Open a band of a sparsebundle */
LOCALFUNC tMacErr SBBandOpen(tDrive Drive_No, SparseBundleBand **OutBand,
	uimr Index, blnr Write);

/* Close a band of a sparsebundle */
LOCALPROC SBBandClose(SparseBundleBand *Band);

/* An operation on a band of a sparsebundle */
typedef tMacErr (*SBBandOp)(tDrive Drive_No, uimr Index, ui3p Buffer,
	uimr Offset, uimr Count);

LOCALFUNC tMacErr SBBandRead(tDrive Drive_No, uimr Index, ui3p Buffer,
	uimr Offset, uimr Count);
LOCALFUNC tMacErr SBBandWrite(tDrive Drive_No, uimr Index, ui3p Buffer,
	uimr Offset, uimr Count);


GLOBALFUNC blnr DiskIsSB(tDrive Drive_No)
{
	if (!vSonyIsInserted(Drive_No)) {
		return falseblnr;
	}
	return (SparseBundleInsertedMask & ((ui5b)1 << Drive_No)) != 0;
}

LOCALPROC SBDiskInsert(tDrive Drive_No, blnr Locked)
{
	SparseBundleInsertedMask |= ((ui5b)1 << Drive_No);
	DiskInsertNotify(Drive_No, Locked);
}

LOCALPROC SBDiskEject(tDrive Drive_No)
{
	SparseBundleInsertedMask &= ~ ((ui5b)1 << Drive_No);;
	DiskEjectedNotify(Drive_No);
}

GLOBALPROC InitSB(void)
{
	uimr iband;

	for (iband = 0; iband < kSBCachedBands; ++iband) {
		SparseBundleBands[iband].Status = kSBBandInit;
	}
	SparseBundleBandEvict = 0;
	SparseBundleInsertedMask = 0;
}

GLOBALPROC UnInitSB(void)
{
	tDrive i;
	uimr iband;

	for (i = 0; i < NumDrives; ++i) {
		if (DiskIsSB(i)) {
			SBClose(i);
		}
	}
	/* All bands should have been closed by that */
}

GLOBALFUNC blnr SBOpen(sbpt Path)
{
	ui3p plistPath[2];
	sbfl plistFile;
	uimr bandSize, totalSize;
	blnr ok;
	tDrive driveNo;
	SparseBundle *sb;
	SBFileOpenStatus status;
	uimr band;
	tMacErr err;
	blnr locked = falseblnr;

	/* Try to open the plist */
	plistPath[0] = (ui3p)"Info.plist";
	plistPath[1] = nullpr;
	err = SBFileOpen(&plistFile, &status, kSBFileOpenDefault, Path, plistPath);
	if (err) {
		return falseblnr;
	}

	/* Try to parse the plist */
	ok = SBPlistParse(plistFile, &bandSize, &totalSize);
	if (!ok) {
		return falseblnr;
	}

	/* TODO: Handle locked token */

	/* Put a sparsebundle structure in our list */
	if (!FirstFreeDisk(&driveNo)) {
		return falseblnr;
	}

	sb = &SparseBundles[driveNo];
	sb->Path = SBPathCopy(Path);
	if (!sb->Path) {
		return falseblnr;
	}
	sb->TotalSize = totalSize;
	sb->BandSize = bandSize;

	SBDiskInsert(driveNo, locked);
	return trueblnr;
}


GLOBALFUNC tMacErr SBGetSize(tDrive Drive_No, ui5r *Size)
{
	if (!DiskIsSB(Drive_No)) {
		return mnvm_paramErr;
	}
	*Size = SparseBundles[Drive_No].TotalSize;
	return mnvm_noErr;
}

GLOBALFUNC tMacErr SBClose(tDrive Drive_No)
{
	SparseBundle *sb;
	SparseBundleBand *band;
	uimr iband;

	if (!DiskIsSB(Drive_No)) {
		return mnvm_paramErr;
	}
	sb = &SparseBundles[Drive_No];
	SBPathDispose(sb->Path);
	SBDiskEject(Drive_No);

	/* Close any bands for this sparsebundle */
	for (iband = 0; iband < kSBCachedBands; ++iband) {
		band = &SparseBundleBands[iband];
		if (band->Status != kSBBandInit && band->Drive_No == Drive_No) {
			SBBandClose(band);
		}
	}
	return mnvm_noErr;
}

GLOBALFUNC tMacErr SBTransfer(blnr IsWrite, ui3p Buffer,
	tDrive Drive_No, uimr Offset, uimr Count,
	ui5r *ActCount)
{
	SparseBundle *sb;
	SBBandOp operation;
	ui3p bufferEnd;
	uimr bandIndex;
	uimr avail, length;
	tMacErr err;

	/* Sanity checks */
	if (!DiskIsSB(Drive_No)) {
		return mnvm_nsDrvErr;
	}
	sb = &SparseBundles[Drive_No];
	if (Offset > sb->TotalSize) {
		return mnvm_paramErr;
	}

	/* Special case EOF */
	if (Offset == sb->TotalSize) {
		*ActCount = 0;
		return mnvm_noErr;
	}

	/* Ensure Count is not too big */
	if (Count > sb->TotalSize - Offset) {
		Count = sb->TotalSize - Offset;
	}

	operation = IsWrite ? &SBBandWrite : &SBBandRead;
	bufferEnd = Buffer + Count;
	bandIndex = Offset / sb->BandSize;
	Offset = Offset % sb->BandSize;

	/* Iterate over bands */
	while (Buffer < bufferEnd) {
		length = bufferEnd - Buffer;
		avail = sb->BandSize - Offset;
		if (length > avail) {
			length = avail;
		}

		err = (*operation)(Drive_No, bandIndex, Buffer, Offset, length);
		if (err) {
			return err;
		}

		Buffer += length;
		Offset = 0;
		bandIndex += 1;
	}

	if (ActCount) {
		*ActCount = Count;
	}
	return mnvm_noErr;
}

LOCALFUNC tMacErr SBBandOpen(tDrive Drive_No, SparseBundleBand **OutBand,
	uimr Index, blnr Write)
{
	SparseBundle *sb;
	SparseBundleBandStatus bandStatus;
	SparseBundleBand *band;
	SBFileOpenFlags flags;
	SBFileOpenStatus status;
	simr iband;
	ui3r bandNameBuffer[kSBBandNameSize];
	ui3p bandName;
	ui3p bandPath[3];
	uimr bandSize;
	sbfl file;
	simr nibble;
	uimr idx;
	simr evict = -1;
	tMacErr err;

	/* Sanity checks */
	if (!DiskIsSB(Drive_No)) {
		return mnvm_nsDrvErr;
	}
	sb = &SparseBundles[Drive_No];
	if (!OutBand) {
		return mnvm_paramErr;
	}
	if (Index * sb->BandSize >= sb->TotalSize) {
		return mnvm_paramErr;
	}

	/* Check the cache */
	bandStatus = Write ? kSBBandFile : kSBBandMissing;
	for (iband = 0; iband < kSBCachedBands; ++iband) {
		band = &SparseBundleBands[iband];
		if (band->Status == kSBBandInit) {
			continue;
		}

		if (band->Drive_No == Drive_No && band->Index == Index) {
			/* Found a band in an ok state, use it */
			if (band->Status >= bandStatus) {
				*OutBand = band;
				return mnvm_noErr;
			}

			/* Found a band, but it's not in the state we need */
			evict = iband;
			break;
		}
	}

	/* Get the hex name of the band to open */
	bandName = &bandNameBuffer[kSBBandNameSize - 1];
	*bandName = '\0';
	idx = Index;
	while (idx > 0 || !*bandName) {
		bandName -= 1;
		nibble = idx % 16;
		if (nibble < 10) {
			*bandName = '0' + nibble;
		} else {
			*bandName = 'a' + nibble - 10;
		}
		idx /= 16;
	}

	/* Try to open the band */
	bandPath[0] = (ui3p)"bands";
	bandPath[1] = bandName;
	bandPath[2] = nullpr;

	bandStatus = kSBBandFile;
	flags = Write ? kSBFileOpenDefault : kSBFileOpenWrite;
	err = SBFileOpen(&file, &status, kSBFileOpenWrite, sb->Path, bandPath);
	if (!Write && status == kSBFileOpenFileMissing) {
		/* Ok if we're missing a file that we only want to read from */
		bandStatus = kSBBandMissing;
	} else if (err) {
		return err;
	}

	/* Get band size */
	if (bandStatus == kSBBandFile) {
		err = SBFileSize(file, &bandSize);
		if (err) {
			SBFileClose(file);
			return err;
		}
	}

	/* Make space for this band */
	if (evict == -1) {
		evict = SparseBundleBandEvict;
		SparseBundleBandEvict = (evict + 1) % kSBCachedBands;
	}
	band = &SparseBundleBands[evict];
	SBBandClose(band);

	/* Put the band in the cache */
	band->Status = bandStatus;
	band->Index = Index;
	if (bandStatus == kSBBandFile) {
		band->File = file;
		band->DataSize = bandSize;
	}

	*OutBand = band;
	return mnvm_noErr;
}

LOCALPROC SBBandClose(SparseBundleBand *Band) {
	if (Band->Status == kSBBandFile) {
		SBFileClose(Band->File);
	}
	Band->Status = kSBBandInit;
}

LOCALFUNC tMacErr SBBandRead(tDrive Drive_No, uimr Index, ui3p Buffer,
	uimr Offset, uimr Count)
{
	SparseBundleBand *band;
	tMacErr err;
	uimr actCount;

	err = SBBandOpen(Drive_No, &band, Index, falseblnr);
	if (err) {
		return err;
	}

	if (band->Status == kSBBandFile && Offset < band->DataSize) {
		err = SBFileTransfer(band->File, falseblnr, Buffer, Offset, Count,
			&actCount);
		if (err) {
			return err;
		}
		Buffer += actCount;
		Count -= actCount;
	}

	/* Fill the rest with zeros */
	while (Count-- > 0) {
		*Buffer++ = '\0';
	}

	return mnvm_noErr;
}

LOCALFUNC tMacErr SBBandWrite(tDrive Drive_No, uimr Index, ui3p Buffer,
	uimr Offset, uimr Count)
{
	SparseBundleBand *band;
	tMacErr err;
	uimr actCount;

	err = SBBandOpen(Drive_No, &band, Index, trueblnr);
	if (err) {
		return err;
	}

	err = SBFileTransfer(band->File, trueblnr, Buffer, Offset, Count,
		&actCount);
	if (err) {
		return err;
	}
	if (actCount != Count) {
		return mnvm_closErr;
	}
	return mnvm_noErr;
}


/* Find a plist value */
LOCALFUNC const char *SBPlistValue(const char *Buffer, const char *Key,
	const char *Type, uimr *Length);

/* Find a plist integer value */
LOCALFUNC blnr SBPlistValueInt(const char *Buffer, const char *Key,
	uimr *Result);

/* Get the length of a string */
LOCALFUNC uimr SBPlistStringLength(const char *Str);

/* Check for string equality */
LOCALFUNC blnr SBPlistStringEqual(const char *Test, const char *Target);

/* Find a string */
LOCALFUNC const char *SBPlistStringFind(const char *Buffer, const char *Search);

/* Skip whitespace */
LOCALFUNC const char *SBPlistSkipSpace(const char *Buffer);

/* Enough room to read a normal sparsebundle plist */
#define kSBPlistBufferSize 4096
/* Enough room to hold any plist key we care about */
#define kSBPlistKeySize 64
#define kSBPListXMLDecl "<?xml "
#define kSBPListDoctype "<!DOCTYPE plist "
#define kSBPlistSpace " \t\n"
#define kSBPlistKey "<key>"
#define kSBPlistKeyEnd "</key>"
#define kSBPlistValueInteger "<integer>"
#define kSBPlistValueString "<string>"
#define kSBPlistValueEnd '<'

#define kSBPlistBundleKey "diskimage-bundle-type"
#define kSBPlistBundleValue "com.apple.diskimage.sparsebundle"
#define kSBPlistVersionKey "bundle-backingstore-version"
#define kSBPlistVersionValue 1
#define kSBPlistSizeKey "size"
#define kSBPlistBandSizeKey "band-size"

LOCALFUNC blnr SBPlistParse(sbfl File, uimr *BandSize, uimr *TotalSize)
{
	char Buffer[kSBPlistBufferSize];
	tMacErr err;
	const char *value;
	uimr actCount;
	uimr length;
	uimr version;
	blnr ret = falseblnr;

	/* We don't really parse XML, just check if it looks ok */

	/* Read a good chunk of the file, shouldn't be longer than this */
	err = SBFileTransfer(File, falseblnr, (ui3p)Buffer, 0,
		kSBPlistBufferSize - 1, &actCount);
	SBFileClose(File);
	if (err) {
		return falseblnr;
	}
	Buffer[actCount] = '\0';

	/* Does it look like a plist? */
	if (!SBPlistStringEqual(Buffer, kSBPListXMLDecl)) {
		return falseblnr;
	}
	if (!SBPlistStringFind(Buffer, kSBPListDoctype)) {
		return falseblnr;
	}

	/* Is it a sparsebundle plist? */
	value = SBPlistValue(Buffer, kSBPlistBundleKey, kSBPlistValueString,
		&length);
	if (!value) {
		return falseblnr;
	}
	if (SBPlistStringLength(kSBPlistBundleValue) != length) {
		return falseblnr;
	}
	if (!SBPlistStringEqual(value, kSBPlistBundleValue)) {
		return falseblnr;
	}
	if (!SBPlistValueInt(Buffer, kSBPlistVersionKey, &version)) {
		return falseblnr;
	}
	if (version != kSBPlistVersionValue) {
		return falseblnr;
	}

	/* Read plist parameters */
	if (!SBPlistValueInt(Buffer, kSBPlistSizeKey, TotalSize)) {
		return falseblnr;
	}
	if (!SBPlistValueInt(Buffer, kSBPlistBandSizeKey, BandSize)) {
		return falseblnr;
	}

	return trueblnr;
}

LOCALFUNC const char *SBPlistValue(const char *Buffer, const char *Key,
	const char *Type, uimr *Length)
{
	char search[kSBPlistKeySize];
	const char *s;
	char *d;
	uimr needSize;

	/* Build the key */
	needSize = SBPlistStringLength(Key) + SBPlistStringLength(kSBPlistKey) +
		SBPlistStringLength(kSBPlistKeyEnd) + 1;
	if (needSize > kSBPlistKeySize) {
		return nullpr;
	}

	d = search;
	for (s = kSBPlistKey; *s; ++s) {
		*d++ = *s;
	}
	for (s = Key; *s; ++s) {
		*d++ = *s;
	}
	for (s = kSBPlistKeyEnd; *s; ++s) {
		*d++ = *s;
	}
	*d = '\0';

	/* Find the key */
	Buffer = SBPlistStringFind(Buffer, search);
	if (!Buffer) {
		return nullpr;
	}

	/* Skip whitespace */
	Buffer += SBPlistStringLength(search);
	Buffer = SBPlistSkipSpace(Buffer);

	/* Check the type */
	if (!SBPlistStringEqual(Buffer, Type)) {
		return nullpr;
	}
	Buffer += SBPlistStringLength(Type);

	/* Find the end */
	for (s = Buffer; *s && *s != '<'; ++s) {
		/* pass */
	}
	if (!*s) {
		return nullpr;
	}

	*Length = s - Buffer;
	return Buffer;
}

LOCALFUNC blnr SBPlistValueInt(const char *Buffer, const char *Key,
	uimr *Result)
{
	const char *s;
	uimr length;
	uimr i, n;
	ui3r c;

	s = SBPlistValue(Buffer, Key, kSBPlistValueInteger, &length);
	if (!s) {
		return falseblnr;
	}

	n = 0;
	for (i = 0; i < length; ++i) {
		n *= 10;
		c = s[i];
		if (c < '0' || c > '9') {
			return falseblnr;
		}
		n += c - '0';
	}

	*Result = n;
	return trueblnr;
}

LOCALFUNC blnr SBPlistStringEqual(const char *Test, const char *Target)
{
	while (*Target) {
		if (*Target != *Test) {
			return falseblnr;
		}
		++Target;
		++Test;
	}
	return trueblnr;
}

LOCALFUNC const char *SBPlistStringFind(const char *Buffer, const char *Search)
{
	while (*Buffer) {
		if (SBPlistStringEqual(Buffer, Search)) {
			return Buffer;
		}
		++Buffer;
	}
	return nullpr;
}

LOCALFUNC const char *SBPlistSkipSpace(const char *Buffer)
{
	blnr skip;
	const char *c;

	while (*Buffer) {
		skip = falseblnr;
		for (c = kSBPlistSpace; *c; ++c) {
			if (*c == *Buffer) {
				skip = trueblnr;
				break;
			}
		}

		if (!skip) {
			break;
		}
		++Buffer;
	}

	return Buffer;
}

LOCALFUNC uimr SBPlistStringLength(const char *Str)
{
	uimr len = 0;
	while (*Str++) {
		len++;
	}
	return len;
}


#endif
