/*
	MYOSGLUE.c

	Copyright (C) 2009 Philip Cummins, Richard F. Bannister,
		Paul C. Pratt

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
	MY Operating System GLUE. (for Macintosh OS X)

	All operating system dependent code for the
	Macintosh platform should go here.

	This code is descended from Richard F. Bannister's Macintosh
	port of vMac, by Philip Cummins.

	The main entry point 'main' is at the end of this file.
*/

#include "CNFGRAPI.h"
#include "SYSDEPNS.h"
#include "ENDIANAC.h"

#include "MYOSGLUE.h"

typedef struct {
	char *path;
	off_t size;
	off_t band_size;
} sparsebundle;

sparsebundle *sparsebundle_open(const char *path);
void sparsebundle_close(sparsebundle *sb);
ssize_t sparsebundle_read(sparsebundle *sb, void *buf, size_t nbyte,
	off_t offset);
ssize_t sparsebundle_write(sparsebundle *sb, void *buf, size_t nbyte,
	off_t offset);

/* --- adapting to API/ABI version differences --- */

/*
	if UsingCarbonLib, instead of native Macho,
	then some APIs are missing
*/
#ifndef UsingCarbonLib
#define UsingCarbonLib 0
#endif

LOCALVAR CFBundleRef AppServBunRef;

LOCALVAR blnr DidApplicationServicesBun = falseblnr;

LOCALFUNC blnr HaveApplicationServicesBun(void)
{
	if (! DidApplicationServicesBun) {
		AppServBunRef = CFBundleGetBundleWithIdentifier(
			CFSTR("com.apple.ApplicationServices"));
		DidApplicationServicesBun = trueblnr;
	}
	return (AppServBunRef != NULL);
}

#if MayFullScreen || UsingCarbonLib

LOCALVAR CFBundleRef HIToolboxBunRef;

LOCALVAR blnr DidHIToolboxBunRef = falseblnr;

LOCALFUNC blnr HaveHIToolboxBunRef(void)
{
	if (! DidHIToolboxBunRef) {
		HIToolboxBunRef = CFBundleGetBundleWithIdentifier(
			CFSTR("com.apple.HIToolbox"));
		DidHIToolboxBunRef = trueblnr;
	}
	return (HIToolboxBunRef != NULL);
}

#endif

LOCALVAR CFBundleRef AGLBunRef;

LOCALVAR blnr DidAGLBunRef = falseblnr;

LOCALFUNC blnr HaveAGLBunRef(void)
{
	if (! DidAGLBunRef) {
		AGLBunRef = CFBundleGetBundleWithIdentifier(
			CFSTR("com.apple.agl"));
		DidAGLBunRef = trueblnr;
	}
	return (AGLBunRef != NULL);
}


#if MayFullScreen

/* SetSystemUIModeProcPtr API always not available */

typedef UInt32                          MySystemUIMode;
typedef OptionBits                      MySystemUIOptions;

enum {
	MykUIModeNormal                 = 0,
	MykUIModeAllHidden              = 3
};

enum {
	MykUIOptionAutoShowMenuBar      = 1 << 0,
	MykUIOptionDisableAppleMenu     = 1 << 2,
	MykUIOptionDisableProcessSwitch = 1 << 3,
	MykUIOptionDisableForceQuit     = 1 << 4,
	MykUIOptionDisableSessionTerminate = 1 << 5,
	MykUIOptionDisableHide          = 1 << 6
};

typedef OSStatus (*SetSystemUIModeProcPtr)
	(MySystemUIMode inMode, MySystemUIOptions inOptions);
LOCALVAR SetSystemUIModeProcPtr MySetSystemUIMode = NULL;
LOCALVAR blnr DidSetSystemUIMode = falseblnr;

LOCALFUNC blnr HaveMySetSystemUIMode(void)
{
	if (! DidSetSystemUIMode) {
		if (HaveHIToolboxBunRef()) {
			MySetSystemUIMode =
				(SetSystemUIModeProcPtr)
				CFBundleGetFunctionPointerForName(
					HIToolboxBunRef, CFSTR("SetSystemUIMode"));
		}
		DidSetSystemUIMode = trueblnr;
	}
	return (MySetSystemUIMode != NULL);
}

#endif

/* In 10.1 or later */

typedef OSStatus (*LSCopyDisplayNameForRefProcPtr)
	(const FSRef *inRef, CFStringRef *outDisplayName);
LOCALVAR LSCopyDisplayNameForRefProcPtr MyLSCopyDisplayNameForRef
	= NULL;
LOCALVAR blnr DidLSCopyDisplayNameForRef = falseblnr;

LOCALFUNC blnr HaveMyLSCopyDisplayNameForRef(void)
{
	if (! DidLSCopyDisplayNameForRef) {
		if (HaveApplicationServicesBun()) {
			MyLSCopyDisplayNameForRef =
				(LSCopyDisplayNameForRefProcPtr)
				CFBundleGetFunctionPointerForName(
					AppServBunRef, CFSTR("LSCopyDisplayNameForRef"));
		}
		DidLSCopyDisplayNameForRef = trueblnr;
	}
	return (MyLSCopyDisplayNameForRef != NULL);
}

/* In 10.5 or later */

typedef GLboolean (*aglSetWindowRefProcPtr)
	(AGLContext ctx, WindowRef window);
LOCALVAR aglSetWindowRefProcPtr MyaglSetWindowRef = NULL;
LOCALVAR blnr DidaglSetWindowRef = falseblnr;

LOCALFUNC blnr HaveMyaglSetWindowRef(void)
{
	if (! DidaglSetWindowRef) {
		if (HaveAGLBunRef()) {
			MyaglSetWindowRef =
				(aglSetWindowRefProcPtr)
				CFBundleGetFunctionPointerForName(
					AGLBunRef, CFSTR("aglSetWindowRef"));
		}
		DidaglSetWindowRef = trueblnr;
	}
	return (MyaglSetWindowRef != NULL);
}

/* Deprecated as of 10.5 */

typedef CGrafPtr My_AGLDrawable;
typedef GLboolean (*aglSetDrawableProcPtr)
	(AGLContext ctx, My_AGLDrawable draw);
LOCALVAR aglSetDrawableProcPtr MyaglSetDrawable = NULL;
LOCALVAR blnr DidaglSetDrawable = falseblnr;

LOCALFUNC blnr HaveMyaglSetDrawable(void)
{
	if (! DidaglSetDrawable) {
		if (HaveAGLBunRef()) {
			MyaglSetDrawable =
				(aglSetDrawableProcPtr)
				CFBundleGetFunctionPointerForName(
					AGLBunRef, CFSTR("aglSetDrawable"));
		}
		DidaglSetDrawable = trueblnr;
	}
	return (MyaglSetDrawable != NULL);
}

/* routines not in carbon lib */


#if UsingCarbonLib

typedef CGDisplayErr
(*CGGetActiveDisplayListProcPtr) (
	CGDisplayCount       maxDisplays,
	CGDirectDisplayID *  activeDspys,
	CGDisplayCount *     dspyCnt);
LOCALVAR CGGetActiveDisplayListProcPtr MyCGGetActiveDisplayList = NULL;
LOCALVAR blnr DidCGGetActiveDisplayList = falseblnr;

LOCALFUNC blnr HaveMyCGGetActiveDisplayList(void)
{
	if (! DidCGGetActiveDisplayList) {
		if (HaveApplicationServicesBun()) {
			MyCGGetActiveDisplayList =
				(CGGetActiveDisplayListProcPtr)
				CFBundleGetFunctionPointerForName(
					AppServBunRef, CFSTR("CGGetActiveDisplayList"));
		}
		DidCGGetActiveDisplayList = trueblnr;
	}
	return (MyCGGetActiveDisplayList != NULL);
}

#else

#define HaveMyCGGetActiveDisplayList() trueblnr
#define MyCGGetActiveDisplayList CGGetActiveDisplayList

#endif /* ! UsingCarbonLib */


#if UsingCarbonLib

typedef CGRect
(*CGDisplayBoundsProcPtr) (CGDirectDisplayID display);
LOCALVAR CGDisplayBoundsProcPtr MyCGDisplayBounds = NULL;
LOCALVAR blnr DidCGDisplayBounds = falseblnr;

LOCALFUNC blnr HaveMyCGDisplayBounds(void)
{
	if (! DidCGDisplayBounds) {
		if (HaveApplicationServicesBun()) {
			MyCGDisplayBounds =
				(CGDisplayBoundsProcPtr)
				CFBundleGetFunctionPointerForName(
					AppServBunRef, CFSTR("CGDisplayBounds"));
		}
		DidCGDisplayBounds = trueblnr;
	}
	return (MyCGDisplayBounds != NULL);
}

#else

#define HaveMyCGDisplayBounds() trueblnr
#define MyCGDisplayBounds CGDisplayBounds

#endif /* ! UsingCarbonLib */


#if UsingCarbonLib

typedef size_t
(*CGDisplayPixelsWideProcPtr) (CGDirectDisplayID display);
LOCALVAR CGDisplayPixelsWideProcPtr MyCGDisplayPixelsWide = NULL;
LOCALVAR blnr DidCGDisplayPixelsWide = falseblnr;

LOCALFUNC blnr HaveMyCGDisplayPixelsWide(void)
{
	if (! DidCGDisplayPixelsWide) {
		if (HaveApplicationServicesBun()) {
			MyCGDisplayPixelsWide =
				(CGDisplayPixelsWideProcPtr)
				CFBundleGetFunctionPointerForName(
					AppServBunRef, CFSTR("CGDisplayPixelsWide"));
		}
		DidCGDisplayPixelsWide = trueblnr;
	}
	return (MyCGDisplayPixelsWide != NULL);
}

#else

#define HaveMyCGDisplayPixelsWide() trueblnr
#define MyCGDisplayPixelsWide CGDisplayPixelsWide

#endif /* ! UsingCarbonLib */


#if UsingCarbonLib

typedef size_t
(*CGDisplayPixelsHighProcPtr) (CGDirectDisplayID display);
LOCALVAR CGDisplayPixelsHighProcPtr MyCGDisplayPixelsHigh = NULL;
LOCALVAR blnr DidCGDisplayPixelsHigh = falseblnr;

LOCALFUNC blnr HaveMyCGDisplayPixelsHigh(void)
{
	if (! DidCGDisplayPixelsHigh) {
		if (HaveApplicationServicesBun()) {
			MyCGDisplayPixelsHigh =
				(CGDisplayPixelsHighProcPtr)
				CFBundleGetFunctionPointerForName(
					AppServBunRef, CFSTR("CGDisplayPixelsHigh"));
		}
		DidCGDisplayPixelsHigh = trueblnr;
	}
	return (MyCGDisplayPixelsHigh != NULL);
}

#else

#define HaveMyCGDisplayPixelsHigh() trueblnr
#define MyCGDisplayPixelsHigh CGDisplayPixelsHigh

#endif /* ! UsingCarbonLib */


#if UsingCarbonLib

typedef CGDisplayErr
(*CGDisplayHideCursorProcPtr) (CGDirectDisplayID display);
LOCALVAR CGDisplayHideCursorProcPtr MyCGDisplayHideCursor = NULL;
LOCALVAR blnr DidCGDisplayHideCursor = falseblnr;

LOCALFUNC blnr HaveMyCGDisplayHideCursor(void)
{
	if (! DidCGDisplayHideCursor) {
		if (HaveApplicationServicesBun()) {
			MyCGDisplayHideCursor =
				(CGDisplayHideCursorProcPtr)
				CFBundleGetFunctionPointerForName(
					AppServBunRef, CFSTR("CGDisplayHideCursor"));
		}
		DidCGDisplayHideCursor = trueblnr;
	}
	return (MyCGDisplayHideCursor != NULL);
}

#else

#define HaveMyCGDisplayHideCursor() trueblnr
#define MyCGDisplayHideCursor CGDisplayHideCursor

#endif /* ! UsingCarbonLib */


#if UsingCarbonLib

typedef CGDisplayErr
(*CGDisplayShowCursorProcPtr) (CGDirectDisplayID display);
LOCALVAR CGDisplayShowCursorProcPtr MyCGDisplayShowCursor = NULL;
LOCALVAR blnr DidCGDisplayShowCursor = falseblnr;

LOCALFUNC blnr HaveMyCGDisplayShowCursor(void)
{
	if (! DidCGDisplayShowCursor) {
		if (HaveApplicationServicesBun()) {
			MyCGDisplayShowCursor =
				(CGDisplayShowCursorProcPtr)
				CFBundleGetFunctionPointerForName(
					AppServBunRef, CFSTR("CGDisplayShowCursor"));
		}
		DidCGDisplayShowCursor = trueblnr;
	}
	return (MyCGDisplayShowCursor != NULL);
}

#else

#define HaveMyCGDisplayShowCursor() trueblnr
#define MyCGDisplayShowCursor CGDisplayShowCursor

#endif /* ! UsingCarbonLib */


#if 0

typedef CGDisplayErr (*CGDisplayMoveCursorToPointProcPtr)
	(CGDirectDisplayID display, CGPoint point);
LOCALVAR CGDisplayMoveCursorToPointProcPtr MyCGDisplayMoveCursorToPoint
	= NULL;
LOCALVAR blnr DidCGDisplayMoveCursorToPoint = falseblnr;

LOCALFUNC blnr HaveMyCGDisplayMoveCursorToPoint(void)
{
	if (! DidCGDisplayMoveCursorToPoint) {
		if (HaveApplicationServicesBun()) {
			MyCGDisplayMoveCursorToPoint =
				(CGDisplayMoveCursorToPointProcPtr)
				CFBundleGetFunctionPointerForName(
					AppServBunRef, CFSTR("CGDisplayMoveCursorToPoint"));
		}
		DidCGDisplayMoveCursorToPoint = trueblnr;
	}
	return (MyCGDisplayMoveCursorToPoint != NULL);
}

#endif /* 0 */


#if UsingCarbonLib

typedef CGEventErr
(*CGWarpMouseCursorPositionProcPtr) (CGPoint newCursorPosition);
LOCALVAR CGWarpMouseCursorPositionProcPtr MyCGWarpMouseCursorPosition
	= NULL;
LOCALVAR blnr DidCGWarpMouseCursorPosition = falseblnr;

LOCALFUNC blnr HaveMyCGWarpMouseCursorPosition(void)
{
	if (! DidCGWarpMouseCursorPosition) {
		if (HaveApplicationServicesBun()) {
			MyCGWarpMouseCursorPosition =
				(CGWarpMouseCursorPositionProcPtr)
				CFBundleGetFunctionPointerForName(
					AppServBunRef, CFSTR("CGWarpMouseCursorPosition"));
		}
		DidCGWarpMouseCursorPosition = trueblnr;
	}
	return (MyCGWarpMouseCursorPosition != NULL);
}

#else

#define HaveMyCGWarpMouseCursorPosition() trueblnr
#define MyCGWarpMouseCursorPosition CGWarpMouseCursorPosition

#endif /* ! UsingCarbonLib */


#if UsingCarbonLib

typedef CGEventErr
(*CGSetLocalEventsSuppressionIntervalProcPtr) (CFTimeInterval seconds);
LOCALVAR CGSetLocalEventsSuppressionIntervalProcPtr
	MyCGSetLocalEventsSuppressionInterval = NULL;
LOCALVAR blnr DidCGSetLocalEventsSuppressionInterval = falseblnr;

LOCALFUNC blnr HaveMyCGSetLocalEventsSuppressionInterval(void)
{
	if (! DidCGSetLocalEventsSuppressionInterval) {
		if (HaveApplicationServicesBun()) {
			MyCGSetLocalEventsSuppressionInterval =
				(CGSetLocalEventsSuppressionIntervalProcPtr)
				CFBundleGetFunctionPointerForName(
					AppServBunRef,
					CFSTR("CGSetLocalEventsSuppressionInterval"));
		}
		DidCGSetLocalEventsSuppressionInterval = trueblnr;
	}
	return (MyCGSetLocalEventsSuppressionInterval != NULL);
}

#else

#define HaveMyCGSetLocalEventsSuppressionInterval() trueblnr
#define MyCGSetLocalEventsSuppressionInterval \
	CGSetLocalEventsSuppressionInterval

#endif /* ! UsingCarbonLib */


#if UsingCarbonLib

typedef OSStatus (*CreateStandardAlertProcPtr) (
	AlertType alertType,
	CFStringRef error,
	CFStringRef explanation,
	const AlertStdCFStringAlertParamRec * param,
	DialogRef * outAlert
);
LOCALVAR CreateStandardAlertProcPtr MyCreateStandardAlert = NULL;
LOCALVAR blnr DidCreateStandardAlert = falseblnr;

LOCALFUNC blnr HaveMyCreateStandardAlert(void)
{
	if (! DidCreateStandardAlert) {
		if (HaveHIToolboxBunRef()) {
			MyCreateStandardAlert =
				(CreateStandardAlertProcPtr)
				CFBundleGetFunctionPointerForName(
					HIToolboxBunRef, CFSTR("CreateStandardAlert"));
		}
		DidCreateStandardAlert = trueblnr;
	}
	return (MyCreateStandardAlert != NULL);
}

#else

#define HaveMyCreateStandardAlert() trueblnr
#define MyCreateStandardAlert CreateStandardAlert

#endif /* ! UsingCarbonLib */


#if UsingCarbonLib

typedef OSStatus (*RunStandardAlertProcPtr) (
	DialogRef inAlert,
	ModalFilterUPP filterProc,
	DialogItemIndex * outItemHit
);
LOCALVAR RunStandardAlertProcPtr MyRunStandardAlert = NULL;
LOCALVAR blnr DidRunStandardAlert = falseblnr;

LOCALFUNC blnr HaveMyRunStandardAlert(void)
{
	if (! DidRunStandardAlert) {
		if (HaveHIToolboxBunRef()) {
			MyRunStandardAlert =
				(RunStandardAlertProcPtr)
				CFBundleGetFunctionPointerForName(
					HIToolboxBunRef, CFSTR("RunStandardAlert"));
		}
		DidRunStandardAlert = trueblnr;
	}
	return (MyRunStandardAlert != NULL);
}

#else

#define HaveMyRunStandardAlert() trueblnr
#define MyRunStandardAlert RunStandardAlert

#endif /* ! UsingCarbonLib */


typedef CGDirectDisplayID (*CGMainDisplayIDProcPtr)(void);

LOCALVAR CGMainDisplayIDProcPtr MyCGMainDisplayID = NULL;
LOCALVAR blnr DidCGMainDisplayID = falseblnr;

LOCALFUNC blnr HaveMyCGMainDisplayID(void)
{
	if (! DidCGMainDisplayID) {
		if (HaveApplicationServicesBun()) {
			MyCGMainDisplayID =
				(CGMainDisplayIDProcPtr)
				CFBundleGetFunctionPointerForName(
					AppServBunRef, CFSTR("CGMainDisplayID"));
		}
		DidCGMainDisplayID = trueblnr;
	}
	return (MyCGMainDisplayID != NULL);
}

#ifndef kCGNullDirectDisplay /* not in MPW Headers */
#define kCGNullDirectDisplay ((CGDirectDisplayID)0)
#endif

typedef CGError
(*CGDisplayRegisterReconfigurationCallbackProcPtr) (
	CGDisplayReconfigurationCallBack proc,
	void *userInfo
	);
LOCALVAR CGDisplayRegisterReconfigurationCallbackProcPtr
	MyCGDisplayRegisterReconfigurationCallback = NULL;
LOCALVAR blnr DidCGDisplayRegisterReconfigurationCallback = falseblnr;

LOCALFUNC blnr HaveMyCGDisplayRegisterReconfigurationCallback(void)
{
	if (! DidCGDisplayRegisterReconfigurationCallback) {
		if (HaveApplicationServicesBun()) {
			MyCGDisplayRegisterReconfigurationCallback =
				(CGDisplayRegisterReconfigurationCallbackProcPtr)
				CFBundleGetFunctionPointerForName(
					AppServBunRef,
					CFSTR("CGDisplayRegisterReconfigurationCallback"));
		}
		DidCGDisplayRegisterReconfigurationCallback = trueblnr;
	}
	return (MyCGDisplayRegisterReconfigurationCallback != NULL);
}


typedef CGError
(*CGDisplayRemoveReconfigurationCallbackProcPtr) (
	CGDisplayReconfigurationCallBack proc,
	void *userInfo
	);
LOCALVAR CGDisplayRemoveReconfigurationCallbackProcPtr
	MyCGDisplayRemoveReconfigurationCallback = NULL;
LOCALVAR blnr DidCGDisplayRemoveReconfigurationCallback = falseblnr;

LOCALFUNC blnr HaveMyCGDisplayRemoveReconfigurationCallback(void)
{
	if (! DidCGDisplayRemoveReconfigurationCallback) {
		if (HaveApplicationServicesBun()) {
			MyCGDisplayRemoveReconfigurationCallback =
				(CGDisplayRemoveReconfigurationCallbackProcPtr)
				CFBundleGetFunctionPointerForName(
					AppServBunRef,
					CFSTR("CGDisplayRemoveReconfigurationCallback"));
		}
		DidCGDisplayRemoveReconfigurationCallback = trueblnr;
	}
	return (MyCGDisplayRemoveReconfigurationCallback != NULL);
}


typedef boolean_t (*CGCursorIsVisibleProcPtr)(void);

LOCALVAR CGCursorIsVisibleProcPtr MyCGCursorIsVisible = NULL;
LOCALVAR blnr DidCGCursorIsVisible = falseblnr;

LOCALFUNC blnr HaveMyCGCursorIsVisible(void)
{
	if (! DidCGCursorIsVisible) {
		if (HaveApplicationServicesBun()) {
			MyCGCursorIsVisible =
				(CGCursorIsVisibleProcPtr)
				CFBundleGetFunctionPointerForName(
					AppServBunRef, CFSTR("CGCursorIsVisible"));
		}
		DidCGCursorIsVisible = trueblnr;
	}
	return (MyCGCursorIsVisible != NULL);
}


/* --- end of adapting to API/ABI version differences --- */

/* --- some simple utilities --- */

GLOBALPROC MyMoveBytes(anyp srcPtr, anyp destPtr, si5b byteCount)
{
	(void) memcpy((char *)destPtr, (char *)srcPtr, byteCount);
}

LOCALPROC PStrFromChar(ps3p r, char x)
{
	r[0] = 1;
	r[1] = (char)x;
}

/* --- mac style errors --- */

#define CheckSavetMacErr(result) (mnvm_noErr == (err = (result)))
	/*
		where 'err' is a variable of type tMacErr in the function
		this is used in
	*/

#define To_tMacErr(result) ((tMacErr)(ui4b)(result))

#define CheckSaveMacErr(result) (CheckSavetMacErr(To_tMacErr(result)))


#include "STRCONST.h"

#define NeedCell2UnicodeMap 1

#include "INTLCHAR.h"

LOCALPROC UniCharStrFromSubstCStr(int *L, UniChar *x, char *s,
	blnr AddEllipsis)
{
	int i;
	int L0;
	ui3b ps[ClStrMaxLength];

	ClStrFromSubstCStr(&L0, ps, s);
	if (AddEllipsis) {
		ClStrAppendChar(&L0, ps, kCellEllipsis);
	}

	for (i = 0; i < L0; ++i) {
		x[i] = Cell2UnicodeMap[ps[i]];
	}

	*L = L0;
}

#define NotAfileRef (-1)

LOCALFUNC tMacErr MyMakeFSRefUniChar(FSRef *ParentRef,
	UniCharCount fileNameLength, const UniChar *fileName,
	blnr *isFolder, FSRef *ChildRef)
{
	tMacErr err;
	Boolean isFolder0;
	Boolean isAlias;

	if (CheckSaveMacErr(FSMakeFSRefUnicode(ParentRef,
		fileNameLength, fileName, kTextEncodingUnknown,
		ChildRef)))
	if (CheckSaveMacErr(FSResolveAliasFile(ChildRef,
		TRUE, &isFolder0, &isAlias)))
	{
		*isFolder = isFolder0;
	}

	return err;
}

LOCALFUNC tMacErr MyMakeFSRefC(FSRef *ParentRef, char *fileName,
	blnr *isFolder, FSRef *ChildRef)
{
	int L;
	UniChar x[ClStrMaxLength];

	UniCharStrFromSubstCStr(&L, x, fileName, falseblnr);
	return MyMakeFSRefUniChar(ParentRef, L, x,
		isFolder, ChildRef);
}

LOCALFUNC tMacErr OpenNamedFileInFolderRef(FSRef *ParentRef,
	char *fileName, short *refnum)
{
	tMacErr err;
	blnr isFolder;
	FSRef ChildRef;
	HFSUniStr255 forkName;

	if (CheckSavetMacErr(MyMakeFSRefC(ParentRef, fileName,
		&isFolder, &ChildRef)))
	if (CheckSaveMacErr(FSGetDataForkName(&forkName)))
	if (CheckSaveMacErr(FSOpenFork(&ChildRef, forkName.length,
		forkName.unicode, fsRdPerm, refnum)))
	{
		/* ok */
	}

	return err;
}

#if dbglog_HAVE || UseActvFile
LOCALFUNC tMacErr OpenWriteNamedFileInFolderRef(FSRef *ParentRef,
	char *fileName, short *refnum)
{
	tMacErr err;
	blnr isFolder;
	FSRef ChildRef;
	HFSUniStr255 forkName;
	int L;
	UniChar x[ClStrMaxLength];

	UniCharStrFromSubstCStr(&L, x, fileName, falseblnr);
	err = MyMakeFSRefUniChar(ParentRef, L, x, &isFolder, &ChildRef);
	if (mnvm_fnfErr == err) {
		err = To_tMacErr(FSCreateFileUnicode(ParentRef, L, x, 0, NULL,
			&ChildRef, NULL));
	}
	if (mnvm_noErr == err) {
		if (CheckSaveMacErr(FSGetDataForkName(&forkName)))
		if (CheckSaveMacErr(FSOpenFork(&ChildRef, forkName.length,
			forkName.unicode, fsRdWrPerm, refnum)))
		{
			/* ok */
		}
	}

	return err;
}
#endif

LOCALFUNC tMacErr FindNamedChildRef(FSRef *ParentRef,
	char *ChildName, FSRef *ChildRef)
{
	tMacErr err;
	blnr isFolder;

	if (CheckSavetMacErr(MyMakeFSRefC(ParentRef, ChildName,
		&isFolder, ChildRef)))
	{
		if (! isFolder) {
			err = mnvm_miscErr;
		}
	}

	return err;
}

LOCALVAR FSRef MyDatDirRef;

LOCALVAR CFStringRef MyAppName = NULL;

LOCALPROC UnInitMyApplInfo(void)
{
	if (MyAppName != NULL) {
		CFRelease(MyAppName);
	}
}

LOCALFUNC blnr InitMyApplInfo(void)
{
	ProcessSerialNumber currentProcess = {0, kCurrentProcess};
	FSRef fsRef;
	FSRef parentRef;

	if (noErr == GetProcessBundleLocation(&currentProcess,
		&fsRef))
	if (noErr == FSGetCatalogInfo(&fsRef, kFSCatInfoNone,
		NULL, NULL, NULL, &parentRef))
	{
		FSRef ContentsRef;
		FSRef DatRef;

		MyDatDirRef = parentRef;
		if (mnvm_noErr == FindNamedChildRef(&fsRef, "Contents",
			&ContentsRef))
		if (mnvm_noErr == FindNamedChildRef(&ContentsRef, "mnvm_dat",
			&DatRef))
		{
			MyDatDirRef = DatRef;
		}

		if (HaveMyLSCopyDisplayNameForRef()) {
			if (noErr == MyLSCopyDisplayNameForRef(&fsRef, &MyAppName))
			{
				return trueblnr;
			}
		}

		if (noErr == CopyProcessName(&currentProcess, &MyAppName)) {
			return trueblnr;
		}
	}
	return falseblnr;
}

/* --- sending debugging info to file --- */

#if dbglog_HAVE

LOCALVAR SInt16 dbglog_File = NotAfileRef;

LOCALFUNC blnr dbglog_open0(void)
{
	tMacErr err;

	err = OpenWriteNamedFileInFolderRef(&MyDatDirRef,
		"dbglog.txt", &dbglog_File);

	return (mnvm_noErr == err);
}

LOCALPROC dbglog_write0(char *s, uimr L)
{
	ByteCount actualCount;

	if (dbglog_File != NotAfileRef) {
		(void) FSWriteFork(
			dbglog_File,
			fsFromMark,
			0,
			L,
			s,
			&actualCount);
	}
}

LOCALPROC dbglog_close0(void)
{
	if (dbglog_File != NotAfileRef) {
		(void) FSSetForkSize(dbglog_File, fsFromMark, 0);
		(void) FSCloseFork(dbglog_File);
		dbglog_File = NotAfileRef;
	}
}

#endif

#if 1 /* (0 != vMacScreenDepth) && (vMacScreenDepth < 4) */
#define WantColorTransValid 1
#endif

#include "COMOSGLU.h"

/* --- sound --- */

LOCALVAR ui5b CurEmulatedTime = 0;

#if MySoundEnabled

#define kLn2SoundBuffers 4 /* kSoundBuffers must be a power of two */
#define kSoundBuffers (1 << kLn2SoundBuffers)
#define kSoundBuffMask (kSoundBuffers - 1)

#define DesiredMinFilledSoundBuffs 3
	/*
		if too big then sound lags behind emulation.
		if too small then sound will have pauses.
	*/

#define kLnOneBuffLen 9
#define kLnAllBuffLen (kLn2SoundBuffers + kLnOneBuffLen)
#define kOneBuffLen (1UL << kLnOneBuffLen)
#define kAllBuffLen (1UL << kLnAllBuffLen)
#define kLnOneBuffSz (kLnOneBuffLen + kLn2SoundSampSz - 3)
#define kLnAllBuffSz (kLnAllBuffLen + kLn2SoundSampSz - 3)
#define kOneBuffSz (1UL << kLnOneBuffSz)
#define kAllBuffSz (1UL << kLnAllBuffSz)
#define kOneBuffMask (kOneBuffLen - 1)
#define kAllBuffMask (kAllBuffLen - 1)
#define dbhBufferSize (kAllBuffSz + kOneBuffSz)

#define dbglog_SoundStuff 0
#define dbglog_SoundBuffStats (dbglog_HAVE && 0)

LOCALVAR tpSoundSamp TheSoundBuffer = nullpr;
volatile static ui4b ThePlayOffset;
volatile static ui4b TheFillOffset;
volatile static blnr wantplaying;
volatile static ui4b MinFilledSoundBuffs;
#if dbglog_SoundBuffStats
LOCALVAR ui4b MaxFilledSoundBuffs;
#endif
LOCALVAR ui4b TheWriteOffset;

#if MySoundRecenterSilence
#define SilentBlockThreshold 96
LOCALVAR trSoundSamp LastSample = 0x00;
LOCALVAR trSoundSamp LastModSample;
LOCALVAR ui4r SilentBlockCounter;
#endif

LOCALPROC RampSound(tpSoundSamp p,
	trSoundSamp BeginVal, trSoundSamp EndVal)
{
	int i;
	ui5r v = (((ui5r)BeginVal) << kLnOneBuffLen) + (kLnOneBuffLen >> 1);

	for (i = kOneBuffLen; --i >= 0; ) {
		*p++ = v >> kLnOneBuffLen;
		v = v + EndVal - BeginVal;
	}
}

#if 4 == kLn2SoundSampSz
LOCALPROC ConvertSoundBlockToNative(tpSoundSamp p)
{
	int i;

	for (i = kOneBuffLen; --i >= 0; ) {
		*p++ -= 0x8000;
	}
}
#else
#define ConvertSoundBlockToNative(p)
#endif

#if 4 == kLn2SoundSampSz
#define ConvertSoundSampleToNative(v) ((v) + 0x8000)
#else
#define ConvertSoundSampleToNative(v) (v)
#endif

/* Structs */
struct PerChanInfo {
	volatile ui4b (*CurPlayOffset);
	volatile ui4b (*CurFillOffset);
	volatile ui4b (*MinFilledSoundBuffs);
	volatile blnr PlayingBuffBlock;
	volatile trSoundSamp lastv;
	volatile blnr (*wantplaying);
	tpSoundSamp dbhBufferPtr;
	CmpSoundHeader /* ExtSoundHeader */ soundHeader;
};
typedef struct PerChanInfo   PerChanInfo;
typedef struct PerChanInfo * PerChanInfoPtr;


LOCALVAR PerChanInfo TheperChanInfoR;

LOCALVAR SndCallBackUPP gCarbonSndPlayDoubleBufferCallBackUPP = NULL;

LOCALVAR SndChannelPtr sndChannel = NULL; /* our sound channel */

LOCALPROC MySound_BeginPlaying(void)
{
#if dbglog_SoundStuff
	fprintf(stderr, "MySound_BeginPlaying\n");
#endif

	if (NULL != sndChannel) {
		SndCommand callBack;

		callBack.cmd = callBackCmd;
		callBack.param1 = 0; /* unused */
		callBack.param2 = (long)&TheperChanInfoR;

		sndChannel->callBack = gCarbonSndPlayDoubleBufferCallBackUPP;

		(void) SndDoCommand (sndChannel, &callBack, true);
	}
}

LOCALPROC MySound_WroteABlock(void)
{
#if MySoundRecenterSilence || (4 == kLn2SoundSampSz)
	ui4b PrevWriteOffset = TheWriteOffset - kOneBuffLen;
	tpSoundSamp p = TheSoundBuffer + (PrevWriteOffset & kAllBuffMask);
#endif

#if MySoundRecenterSilence
	int i;
	tpSoundSamp p0;
	trSoundSamp lastv = LastSample;
	blnr GotSilentBlock = trueblnr;

	p0 = p;
	for (i = kOneBuffLen; --i >= 0; ) {
		trSoundSamp v = *p++;
		if (v != lastv) {
			LastSample = *(p0 + kOneBuffLen - 1);
			GotSilentBlock = falseblnr;
			goto label_done;
		}
	}
label_done:
	p = p0;

	if (GotSilentBlock) {
		if ((! wantplaying) && (PrevWriteOffset == ThePlayOffset)) {
			TheWriteOffset = PrevWriteOffset;
			return; /* forget this block */
		}
		++SilentBlockCounter;
#if dbglog_SoundStuff
		fprintf(stderr, "GotSilentBlock %d\n", SilentBlockCounter);
#endif
		if (SilentBlockCounter >= SilentBlockThreshold) {
			trSoundSamp NewModSample;

			if (SilentBlockThreshold == SilentBlockCounter) {
				LastModSample = LastSample;
			} else {
				SilentBlockCounter = SilentBlockThreshold;
					/* prevent overflow */
			}
#if 3 == kLn2SoundSampSz
			if (LastModSample > kCenterSound) {
				NewModSample = LastModSample - 1;
			} else if (LastModSample < kCenterSound) {
				NewModSample = LastModSample + 1;
			} else {
				NewModSample = kCenterSound;
			}
#elif 4 == kLn2SoundSampSz
			if (LastModSample > kCenterSound + 0x0100) {
				NewModSample = LastModSample - 0x0100;
			} else if (LastModSample < kCenterSound - 0x0100) {
				NewModSample = LastModSample + 0x0100;
			} else {
				NewModSample = kCenterSound;
			}
#else
#error "unsupported kLn2SoundSampSz"
#endif
#if dbglog_SoundStuff
			fprintf(stderr, "LastModSample %d\n", LastModSample);
#endif
			RampSound(p, LastModSample, NewModSample);
			LastModSample = NewModSample;
		}
	} else {
#if EnableAutoSlow && 0
		QuietEnds();
#endif

		if (SilentBlockCounter >= SilentBlockThreshold) {
			tpSoundSamp pramp;
			ui4b TotLen = TheWriteOffset
				- ThePlayOffset;
			ui4b TotBuffs = TotLen >> kLnOneBuffLen;

			if (TotBuffs >= 3) {
				pramp = TheSoundBuffer
					+ ((PrevWriteOffset - kOneBuffLen) & kAllBuffMask);
			} else {
				pramp = p;
				p = TheSoundBuffer + (TheWriteOffset & kAllBuffMask);
				MyMoveBytes((anyp)pramp, (anyp)p, kOneBuffSz);
				TheWriteOffset += kOneBuffLen;
			}
#if dbglog_SoundStuff
			fprintf(stderr, "LastModSample %d\n", LastModSample);
			fprintf(stderr, "LastSample %d\n", LastSample);
#endif
			RampSound(pramp, LastModSample, LastSample);
			ConvertSoundBlockToNative(pramp);
		}
		SilentBlockCounter = 0;
	}
#endif

	ConvertSoundBlockToNative(p);

	if (wantplaying) {
		TheFillOffset = TheWriteOffset;
	} else if (((TheWriteOffset - ThePlayOffset) >> kLnOneBuffLen) < 12)
	{
		/* just wait */
	} else {
		TheFillOffset = TheWriteOffset;
		wantplaying = trueblnr;
		MySound_BeginPlaying();
	}

#if dbglog_SoundBuffStats
	{
		ui4b ToPlayLen = TheFillOffset
			- ThePlayOffset;
		ui4b ToPlayBuffs = ToPlayLen >> kLnOneBuffLen;

		if (ToPlayBuffs > MaxFilledSoundBuffs) {
			MaxFilledSoundBuffs = ToPlayBuffs;
		}
	}
#endif
}

GLOBALPROC MySound_EndWrite(ui4r actL)
{
	TheWriteOffset += actL;

	if (0 == (TheWriteOffset & kOneBuffMask)) {
		/* just finished a block */

		MySound_WroteABlock();
	}
}

GLOBALFUNC tpSoundSamp MySound_BeginWrite(ui4r n, ui4r *actL)
{
	ui4b ToFillLen = kAllBuffLen - (TheWriteOffset - ThePlayOffset);
	ui4b WriteBuffContig =
		kOneBuffLen - (TheWriteOffset & kOneBuffMask);

	if (WriteBuffContig < n) {
		n = WriteBuffContig;
	}
	if (ToFillLen < n) {
		/* overwrite previous buffer */
		TheWriteOffset -= kOneBuffLen;
	}

	*actL = n;
	return TheSoundBuffer + (TheWriteOffset & kAllBuffMask);
}

LOCALPROC MySound_SecondNotify(void)
{
	if (sndChannel != NULL) {
		if (MinFilledSoundBuffs > DesiredMinFilledSoundBuffs) {
			++CurEmulatedTime;
		} else if (MinFilledSoundBuffs < DesiredMinFilledSoundBuffs) {
			--CurEmulatedTime;
		}
#if dbglog_SoundBuffStats
		fprintf(DumpFile, "MinFilledSoundBuffs = %d\n",
			MinFilledSoundBuffs);
		fprintf(DumpFile, "MaxFilledSoundBuffs = %d\n",
			MaxFilledSoundBuffs);
		MaxFilledSoundBuffs = 0;
#endif
		MinFilledSoundBuffs = kSoundBuffers;
	}
}

#endif

/* --- time, date --- */

/*
	be sure to avoid getting confused if TickCount
	overflows and wraps.
*/

LOCALVAR ui5b TrueEmulatedTime = 0;

LOCALVAR EventTime NextTickChangeTime;

#define MyTickDuration (kEventDurationSecond / 60.14742)

LOCALPROC UpdateTrueEmulatedTime(void)
{
	EventTime LatestTime = GetCurrentEventTime();
	EventTime TimeDiff = LatestTime - NextTickChangeTime;

	if (TimeDiff >= 0.0) {
		if (TimeDiff > 3 * MyTickDuration) {
			/* emulation interrupted, forget it */
			++TrueEmulatedTime;
			NextTickChangeTime = LatestTime + MyTickDuration;
		} else {
			do {
				++TrueEmulatedTime;
				TimeDiff -= MyTickDuration;
				NextTickChangeTime += MyTickDuration;
			} while (TimeDiff >= 0.0);
		}
	}
}

LOCALVAR ui5b OnTrueTime = 0;

GLOBALFUNC blnr ExtraTimeNotOver(void)
{
	UpdateTrueEmulatedTime();
	return TrueEmulatedTime == OnTrueTime;
}

/* LOCALVAR EventTime ETimeBase; */
LOCALVAR CFAbsoluteTime ATimeBase;
LOCALVAR ui5b TimeSecBase;

LOCALFUNC blnr CheckDateTime(void)
{
	ui5b NewMacDateInSecond = TimeSecBase
		+ (ui5b)(CFAbsoluteTimeGetCurrent() - ATimeBase);
	/*
		ui5b NewMacDateInSecond = TimeSecBase
			+ (ui5b)(GetCurrentEventTime() - ETimeBase);
	*/
	/*
		ui5b NewMacDateInSecond = ((ui5b)(CFAbsoluteTimeGetCurrent()))
			+ 3061137600UL;
	*/

	if (CurMacDateInSeconds != NewMacDateInSecond) {
		CurMacDateInSeconds = NewMacDateInSecond;
		return trueblnr;
	} else {
		return falseblnr;
	}
}

/* --- parameter buffers --- */

#if IncludePbufs
LOCALVAR void *PbufDat[NumPbufs];
#endif

#if IncludePbufs
GLOBALFUNC tMacErr PbufNew(ui5b count, tPbuf *r)
{
	tPbuf i;
	void *p;
	tMacErr err = mnvm_miscErr;

	if (FirstFreePbuf(&i)) {
		p = calloc(1, count);
		if (p != NULL) {
			*r = i;
			PbufDat[i] = p;
			PbufNewNotify(i, count);

			err = mnvm_noErr;
		}
	}

	return err;
}
#endif

#if IncludePbufs
GLOBALPROC PbufDispose(tPbuf i)
{
	free(PbufDat[i]);
	PbufDisposeNotify(i);
}
#endif

#if IncludePbufs
LOCALPROC UnInitPbufs(void)
{
	tPbuf i;

	for (i = 0; i < NumPbufs; ++i) {
		if (PbufIsAllocated(i)) {
			PbufDispose(i);
		}
	}
}
#endif

#if IncludePbufs
GLOBALPROC PbufTransfer(ui3p Buffer,
	tPbuf i, ui5r offset, ui5r count, blnr IsWrite)
{
	void *p = ((ui3p)PbufDat[i]) + offset;
	if (IsWrite) {
		(void) memcpy(p, Buffer, count);
	} else {
		(void) memcpy(Buffer, p, count);
	}
}
#endif

/* --- drives --- */

LOCALVAR sparsebundle *Sparsebundles[NumDrives];
LOCALVAR SInt16 Drives[NumDrives]; /* open disk image files */

GLOBALFUNC tMacErr vSonyTransfer(blnr IsWrite, ui3p Buffer,
	tDrive Drive_No, ui5r Sony_Start, ui5r Sony_Count,
	ui5r *Sony_ActCount)
{
	ByteCount actualCount;
	tMacErr result;
	ssize_t sb_ret;
	sparsebundle *sb = Sparsebundles[Drive_No];

	if (IsWrite) {
		if (sb) {
			sb_ret = sparsebundle_write(sb, Buffer, Sony_Count, Sony_Start);
		} else {
			result = To_tMacErr(FSWriteFork(
				Drives[Drive_No],
				fsFromStart,
				Sony_Start,
				Sony_Count,
				Buffer,
				&actualCount));
		}
	} else {
		if (sb) {
			sb_ret = sparsebundle_read(sb, Buffer, Sony_Count, Sony_Start);
		} else {
			result = To_tMacErr(FSReadFork(
				Drives[Drive_No],
				fsFromStart,
				Sony_Start,
				Sony_Count,
				Buffer,
				&actualCount));
		}
	}

	if (sb) {
		if (sb_ret == -1) {
			return mnvm_miscErr;
		}
		actualCount = sb_ret;
		result = mnvm_noErr;
	}

	if (nullpr != Sony_ActCount) {
		*Sony_ActCount = actualCount;
	}

	return result;
}

GLOBALFUNC tMacErr vSonyGetSize(tDrive Drive_No, ui5r *Sony_Count)
{
	if (Sparsebundles[Drive_No]) {
		*Sony_Count = Sparsebundles[Drive_No]->size;
		return mnvm_noErr;
	} else {
		SInt64 forkSize;
		tMacErr err = To_tMacErr(
			FSGetForkSize(Drives[Drive_No], &forkSize));
		*Sony_Count = forkSize;
		return err;
	}
}

GLOBALFUNC tMacErr vSonyEject(tDrive Drive_No)
{
	SInt16 refnum = Drives[Drive_No];
	sparsebundle *sb = Sparsebundles[Drive_No];

	Drives[Drive_No] = NotAfileRef;
	Sparsebundles[Drive_No] = NULL;

	DiskEjectedNotify(Drive_No);

	if (sb) {
		sparsebundle_close(sb);
	} else {
		(void) FSCloseFork(refnum);
	}

	return mnvm_noErr;
}

#if IncludeSonyNew
GLOBALFUNC tMacErr vSonyEjectDelete(tDrive Drive_No)
{
	FSRef ref;
	tMacErr err0;
	tMacErr err;

	err0 = To_tMacErr(FSGetForkCBInfo(Drives[Drive_No], 0,
		NULL /* iterator */,
		NULL /* actualRefNum */,
		NULL /* forkInfo */,
		&ref /* ref */,
		NULL /* outForkName */));
	err = vSonyEject(Drive_No);

	if (mnvm_noErr != err0) {
		err = err0;
	} else {
		(void) FSDeleteObject(&ref);
	}

	return err;
}
#endif

#if IncludeSonyGetName
GLOBALFUNC tMacErr vSonyGetName(tDrive Drive_No, tPbuf *r)
{
	FSRef ref;
	HFSUniStr255 outName;
	CFStringRef DiskName;
	tMacErr err;

	if (CheckSaveMacErr(FSGetForkCBInfo(Drives[Drive_No], 0,
		NULL /* iterator */,
		NULL /* actualRefNum */,
		NULL /* forkInfo */,
		&ref /* ref */,
		NULL /* outForkName */)))
	if (CheckSaveMacErr(FSGetCatalogInfo(&ref,
		kFSCatInfoNone /* whichInfo */,
		NULL /* catalogInfo */,
		&outName /* outName */,
		NULL /* fsSpec */,
		NULL /* parentRef */)))
	{
		DiskName = CFStringCreateWithCharacters(
			kCFAllocatorDefault, outName.unicode,
			outName.length);
		if (NULL != DiskName) {
			tPbuf i;

			if (CheckSavetMacErr(PbufNew(outName.length, &i))) {
				if (CFStringGetBytes(DiskName,
					CFRangeMake(0, outName.length),
					kCFStringEncodingMacRoman,
					'?', false,
					PbufDat[i],
					outName.length,
					NULL) != outName.length)
				{
					err = mnvm_miscErr;
				}
				if (mnvm_noErr != err) {
					PbufDispose(i);
				} else {
					*r = i;
				}
			}
			CFRelease(DiskName);
		}
	}

	return err;
}
#endif

#if IncludeHostTextClipExchange
GLOBALFUNC tMacErr HTCEexport(tPbuf i)
{
	tMacErr err;
	ScrapRef scrapRef;

	if (CheckSaveMacErr(ClearCurrentScrap()))
	if (CheckSaveMacErr(GetCurrentScrap(&scrapRef)))
	if (CheckSaveMacErr(PutScrapFlavor(
		scrapRef,
		FOUR_CHAR_CODE('TEXT'),
		kScrapFlavorMaskNone,
		PbufSize[i],
		PbufDat[i])))
	{
		/* ok */
	}

	PbufDispose(i);

	return err;
}
#endif

#if IncludeHostTextClipExchange
GLOBALFUNC tMacErr HTCEimport(tPbuf *r)
{
	tMacErr err;
	ScrapRef scrap;
	ScrapFlavorFlags flavorFlags;
	Size byteCount;
	tPbuf i;

	if (CheckSaveMacErr(GetCurrentScrap(&scrap)))
	if (CheckSaveMacErr(GetScrapFlavorFlags(scrap,
		'TEXT', &flavorFlags)))
	if (CheckSaveMacErr(GetScrapFlavorSize(scrap,
		'TEXT', &byteCount)))
	if (CheckSavetMacErr(PbufNew(byteCount, &i)))
	{
		Size byteCount2 = byteCount;
		if (CheckSaveMacErr(GetScrapFlavorData(scrap,
			'TEXT', &byteCount2,
			PbufDat[i])))
		{
			if (byteCount != byteCount2) {
				err = mnvm_miscErr;
			}
		}
		if (mnvm_noErr != err) {
			PbufDispose(i);
		} else {
			*r = i;
		}
	}

	return err;
}
#endif


#if EmLocalTalk

#include "BPFILTER.h"

#endif


/* --- platform independent code can be thought of as going here --- */

#include "PROGMAIN.h"

/* --- control mode and internationalization --- */

#include "CONTROLM.h"


/* --- video out --- */

LOCALVAR WindowPtr gMyMainWindow = NULL;
LOCALVAR WindowPtr gMyOldWindow = NULL;

#if MayFullScreen
LOCALVAR short hOffset;
LOCALVAR short vOffset;
#endif

#if MayFullScreen
LOCALVAR blnr GrabMachine = falseblnr;
#endif

#if VarFullScreen
LOCALVAR blnr UseFullScreen = (WantInitFullScreen != 0);
#endif

#if EnableMagnify
LOCALVAR blnr UseMagnify = (WantInitMagnify != 0);
#endif

#if EnableMagnify
LOCALPROC MyScaleRect(Rect *r)
{
	r->left *= MyWindowScale;
	r->right *= MyWindowScale;
	r->top *= MyWindowScale;
	r->bottom *= MyWindowScale;
}
#endif

LOCALPROC SetScrnRectFromCoords(Rect *r,
	si4b top, si4b left, si4b bottom, si4b right)
{
	r->left = left;
	r->right = right;
	r->top = top;
	r->bottom = bottom;

#if VarFullScreen
	if (UseFullScreen)
#endif
#if MayFullScreen
	{
		OffsetRect(r, - ViewHStart, - ViewVStart);
	}
#endif

#if EnableMagnify
	if (UseMagnify) {
		MyScaleRect(r);
	}
#endif

#if VarFullScreen
	if (UseFullScreen)
#endif
#if MayFullScreen
	{
		OffsetRect(r, hOffset, vOffset);
	}
#endif
}

LOCALVAR ui3p ScalingBuff = nullpr;

LOCALVAR ui3p CLUT_final;

#define CLUT_finalsz1 (256 * 8)

#if (0 != vMacScreenDepth) && (vMacScreenDepth < 4)

#define CLUT_finalClrSz (256 << (5 - vMacScreenDepth))

#define CLUT_finalsz ((CLUT_finalClrSz > CLUT_finalsz1) \
	? CLUT_finalClrSz : CLUT_finalsz1)

#else
#define CLUT_finalsz CLUT_finalsz1
#endif


#define ScrnMapr_DoMap UpdateBWLuminanceCopy
#define ScrnMapr_Src GetCurDrawBuff()
#define ScrnMapr_Dst ScalingBuff
#define ScrnMapr_SrcDepth 0
#define ScrnMapr_DstDepth 3
#define ScrnMapr_Map CLUT_final

#include "SCRNMAPR.h"


#if (0 != vMacScreenDepth) && (vMacScreenDepth < 4)

#define ScrnMapr_DoMap UpdateMappedColorCopy
#define ScrnMapr_Src GetCurDrawBuff()
#define ScrnMapr_Dst ScalingBuff
#define ScrnMapr_SrcDepth vMacScreenDepth
#define ScrnMapr_DstDepth 5
#define ScrnMapr_Map CLUT_final

#include "SCRNMAPR.h"

#endif

#if vMacScreenDepth >= 4

#define ScrnTrns_DoTrans UpdateTransColorCopy
#define ScrnTrns_Src GetCurDrawBuff()
#define ScrnTrns_Dst ScalingBuff
#define ScrnTrns_SrcDepth vMacScreenDepth
#define ScrnTrns_DstDepth 5
#define ScrnTrns_DstZLo 1

#include "SCRNTRNS.h"

#endif

LOCALPROC UpdateLuminanceCopy(si4b top, si4b left,
	si4b bottom, si4b right)
{
	int i;

#if 0 != vMacScreenDepth
	if (UseColorMode) {

#if vMacScreenDepth < 4

		if (! ColorTransValid) {
			int j;
			int k;
			ui5p p4;

			p4 = (ui5p)CLUT_final;
			for (i = 0; i < 256; ++i) {
				for (k = 1 << (3 - vMacScreenDepth); --k >= 0; ) {
					j = (i >> (k << vMacScreenDepth)) & (CLUT_size - 1);
					*p4++ = (((long)CLUT_reds[j] & 0xFF00) << 16)
						| (((long)CLUT_greens[j] & 0xFF00) << 8)
						| ((long)CLUT_blues[j] & 0xFF00);
				}
			}
			ColorTransValid = trueblnr;
		}

		UpdateMappedColorCopy(top, left, bottom, right);

#else
		UpdateTransColorCopy(top, left, bottom, right);
#endif

	} else
#endif
	{
		if (! ColorTransValid) {
			int k;
			ui3p p4 = (ui3p)CLUT_final;

			for (i = 0; i < 256; ++i) {
				for (k = 8; --k >= 0; ) {
					*p4++ = ((i >> k) & 0x01) - 1;
				}
			}
			ColorTransValid = trueblnr;
		}

		UpdateBWLuminanceCopy(top, left, bottom, right);
	}
}

LOCALVAR AGLContext ctx = NULL;
LOCALVAR short GLhOffset;
LOCALVAR short GLvOffset;

#ifndef UseAGLdoublebuff
#define UseAGLdoublebuff 0
#endif

LOCALPROC MyDrawWithOpenGL(ui4r top, ui4r left, ui4r bottom, ui4r right)
{
	if (NULL == ctx) {
		/* oops */
	} else if (GL_TRUE != aglSetCurrentContext(ctx)) {
		/* err = aglReportError() */
	} else {
		si4b top2;
		si4b left2;

#if UseAGLdoublebuff
		/* redraw all */
		top = 0;
		left = 0;
		bottom = vMacScreenHeight;
		right = vMacScreenWidth;
#endif

#if VarFullScreen
		if (UseFullScreen)
#endif
#if MayFullScreen
		{
			if (top < ViewVStart) {
				top = ViewVStart;
			}
			if (left < ViewHStart) {
				left = ViewHStart;
			}
			if (bottom > ViewVStart + ViewVSize) {
				bottom = ViewVStart + ViewVSize;
			}
			if (right > ViewHStart + ViewHSize) {
				right = ViewHStart + ViewHSize;
			}

			if ((top >= bottom) || (left >= right)) {
				goto label_exit;
			}
		}
#endif

		top2 = top;
		left2 = left;

#if VarFullScreen
		if (UseFullScreen)
#endif
#if MayFullScreen
		{
			left2 -= ViewHStart;
			top2 -= ViewVStart;
		}
#endif

#if EnableMagnify
		if (UseMagnify) {
			top2 *= MyWindowScale;
			left2 *= MyWindowScale;
		}
#endif

#if 0
		glClear(GL_COLOR_BUFFER_BIT);
		glBitmap(vMacScreenWidth,
			vMacScreenHeight,
			0,
			0,
			0,
			0,
			(const GLubyte *)GetCurDrawBuff());
#endif
#if 1
		UpdateLuminanceCopy(top, left, bottom, right);
		glRasterPos2i(GLhOffset + left2, GLvOffset - top2);
#if 0 != vMacScreenDepth
		if (UseColorMode) {
			glDrawPixels(right - left,
				bottom - top,
				GL_RGBA,
				GL_UNSIGNED_INT_8_8_8_8,
				ScalingBuff + (left + top * vMacScreenWidth) * 4
				);
		} else
#endif
		{
			glDrawPixels(right - left,
				bottom - top,
				GL_LUMINANCE,
				GL_UNSIGNED_BYTE,
				ScalingBuff + (left + top * vMacScreenWidth)
				);
		}
#endif

#if 0 /* a very quick and dirty check of where drawing */
		glDrawPixels(right - left,
			1,
			GL_RED,
			GL_UNSIGNED_BYTE,
			ScalingBuff + (left + top * vMacScreenWidth)
			);

		glDrawPixels(1,
			bottom - top,
			GL_RED,
			GL_UNSIGNED_BYTE,
			ScalingBuff + (left + top * vMacScreenWidth)
			);
#endif

#if UseAGLdoublebuff
		aglSwapBuffers(ctx);
#else
		glFlush();
#endif
	}

#if MayFullScreen
label_exit:
	;
#endif
}

LOCALPROC Update_Screen(void)
{
	MyDrawWithOpenGL(0, 0, vMacScreenHeight, vMacScreenWidth);
}

LOCALPROC MyDrawChangesAndClear(void)
{
	if (ScreenChangedBottom > ScreenChangedTop) {
		MyDrawWithOpenGL(ScreenChangedTop, ScreenChangedLeft,
			ScreenChangedBottom, ScreenChangedRight);
		ScreenClearChanges();
	}
}


LOCALVAR blnr MouseIsOutside = falseblnr;
	/*
		MouseIsOutside true if sure mouse outside our window. If in
		our window, or not sure, set false.
	*/

LOCALVAR blnr WantCursorHidden = falseblnr;

LOCALPROC MousePositionNotify(Point NewMousePos)
{
	/*
		Not MouseIsOutside includes in the title bar, etc, so have
		to check if in content area.
	*/

	Rect r;
	blnr ShouldHaveCursorHidden = ! MouseIsOutside;

	GetWindowBounds(gMyMainWindow, kWindowContentRgn, &r);

	NewMousePos.h -= r.left;
	NewMousePos.v -= r.top;

#if VarFullScreen
	if (UseFullScreen)
#endif
#if MayFullScreen
	{
		NewMousePos.h -= hOffset;
		NewMousePos.v -= vOffset;
	}
#endif

#if EnableMagnify
	if (UseMagnify) {
		NewMousePos.h /= MyWindowScale;
		NewMousePos.v /= MyWindowScale;
	}
#endif

#if VarFullScreen
	if (UseFullScreen)
#endif
#if MayFullScreen
	{
		NewMousePos.h += ViewHStart;
		NewMousePos.v += ViewVStart;
	}
#endif

#if EnableMouseMotion && MayFullScreen
	if (HaveMouseMotion) {
		MyMousePositionSetDelta(NewMousePos.h - SavedMouseH,
			NewMousePos.v - SavedMouseV);
		SavedMouseH = NewMousePos.h;
		SavedMouseV = NewMousePos.v;
	} else
#endif
	{
		if (NewMousePos.h < 0) {
			NewMousePos.h = 0;
			ShouldHaveCursorHidden = falseblnr;
		} else if (NewMousePos.h >= vMacScreenWidth) {
			NewMousePos.h = vMacScreenWidth - 1;
			ShouldHaveCursorHidden = falseblnr;
		}
		if (NewMousePos.v < 0) {
			NewMousePos.v = 0;
			ShouldHaveCursorHidden = falseblnr;
		} else if (NewMousePos.v >= vMacScreenHeight) {
			NewMousePos.v = vMacScreenHeight - 1;
			ShouldHaveCursorHidden = falseblnr;
		}

		/* if (ShouldHaveCursorHidden || CurMouseButton) */
		/*
			for a game like arkanoid, would like mouse to still
			move even when outside window in one direction
		*/
		MyMousePositionSet(NewMousePos.h, NewMousePos.v);
	}

	WantCursorHidden = ShouldHaveCursorHidden;
}

LOCALPROC CheckMouseState(void)
{
	Point NewMousePos;
	GetGlobalMouse(&NewMousePos);
		/*
			Deprecated, but haven't found usable replacement.
			Between window deactivate and then reactivate,
			mouse can move without getting kEventMouseMoved.
			Also no way to get initial position.
			(Also don't get kEventMouseMoved after
			using menu bar. Or while using menubar, but
			that isn't too important.)
		*/
	MousePositionNotify(NewMousePos);
}

LOCALVAR blnr gLackFocusFlag = falseblnr;
LOCALVAR blnr gWeAreActive = falseblnr;

LOCALPROC RunEmulatedTicksToTrueTime(void)
{
	si3b n = OnTrueTime - CurEmulatedTime;

	if (n > 0) {
		if (CheckDateTime()) {
#if MySoundEnabled
			MySound_SecondNotify();
#endif
		}

		if (gWeAreActive) {
			CheckMouseState();
		}

		DoEmulateOneTick();
		++CurEmulatedTime;

#if EnableMouseMotion && MayFullScreen
		if (HaveMouseMotion) {
			AutoScrollScreen();
		}
#endif
		MyDrawChangesAndClear();

		if (n > 8) {
			/* emulation not fast enough */
			n = 8;
			CurEmulatedTime = OnTrueTime - n;
		}

		if (ExtraTimeNotOver() && (--n > 0)) {
			/* lagging, catch up */

			EmVideoDisable = trueblnr;

			do {
				DoEmulateOneTick();
				++CurEmulatedTime;
			} while (ExtraTimeNotOver()
				&& (--n > 0));

			EmVideoDisable = falseblnr;
		}

		EmLagTime = n;
	}
}

LOCALVAR EventRef EventForMyLowPriority = nil;

LOCALPROC PostMyLowPriorityTasksEvent(void)
{
	EventQueueRef mq = GetMainEventQueue();

	if (IsEventInQueue(mq, EventForMyLowPriority)) {
		(void) RemoveEventFromQueue(mq, EventForMyLowPriority);
	}
	(void) SetEventTime(EventForMyLowPriority, GetCurrentEventTime());

	if (noErr == PostEventToQueue(mq,
		EventForMyLowPriority, kEventPriorityLow))
	{
	}
}

LOCALVAR blnr CurSpeedStopped = trueblnr;

LOCALPROC PostIfStoppedLowPriorityEvent(void)
{
	if (CurSpeedStopped) {
		PostMyLowPriorityTasksEvent();
	}
}

static pascal void MyTimerProc(EventLoopTimerRef inTimer,
	void *inUserData)
{
	UnusedParam(inUserData);

	if (CurSpeedStopped) {
		(void) SetEventLoopTimerNextFireTime(
			inTimer, kEventDurationForever);
	} else {
		UpdateTrueEmulatedTime();
		{
			EventTimeout inTimeout =
				NextTickChangeTime - GetCurrentEventTime();
			if (inTimeout > 0.0) {
				(void) SetEventLoopTimerNextFireTime(
					inTimer, inTimeout);
				/*
					already a periodic timer, this is just to make
					sure of accuracy.
				*/
			}
		}

		OnTrueTime = TrueEmulatedTime;
		RunEmulatedTicksToTrueTime();

		PostMyLowPriorityTasksEvent();
	}
}

LOCALVAR EventLoopTimerRef MyTimerRef = NULL;

LOCALFUNC blnr InitMyLowPriorityTasksEvent(void)
{
	if (noErr != InstallEventLoopTimer(GetMainEventLoop(),
		kEventDurationMinute, /* will set actual time later */
		MyTickDuration,
		NewEventLoopTimerUPP(MyTimerProc),
		NULL, &MyTimerRef))
	{
		MyTimerRef = NULL;
	} else if (noErr != CreateEvent(nil,
		'MnvM', 'MnvM', GetCurrentEventTime(),
		kEventAttributeNone, &EventForMyLowPriority))
	{
		EventForMyLowPriority = nil;
	} else {
		if (noErr == PostEventToQueue(GetMainEventQueue(),
			EventForMyLowPriority, kEventPriorityLow))
		{
			return trueblnr;
			/* ReleaseEvent(EventForMyLowPriority); */
		}
	}

	return falseblnr;
}

LOCALPROC UnInitMyLowPriorityTasksEvent(void)
{
	if (NULL != MyTimerRef) {
		(void) RemoveEventLoopTimer(MyTimerRef);
	}
	if (nil != EventForMyLowPriority) {
		EventQueueRef mq = GetMainEventQueue();

		if (IsEventInQueue(mq, EventForMyLowPriority)) {
			(void) RemoveEventFromQueue(mq, EventForMyLowPriority);
		}
		ReleaseEvent(EventForMyLowPriority);
	}
}

/* --- keyboard --- */

LOCALVAR UInt32 SavedModifiers = 0;

LOCALPROC MyUpdateKeyboardModifiers(UInt32 theModifiers)
{
	UInt32 ChangedModifiers = theModifiers ^ SavedModifiers;

	if (0 != ChangedModifiers) {
		if (0 != (ChangedModifiers & shiftKey)) {
			Keyboard_UpdateKeyMap2(MKC_Shift,
				(shiftKey & theModifiers) != 0);
		}
		if (0 != (ChangedModifiers & cmdKey)) {
			Keyboard_UpdateKeyMap2(MKC_Command,
				(cmdKey & theModifiers) != 0);
		}
		if (0 != (ChangedModifiers & alphaLock)) {
			Keyboard_UpdateKeyMap2(MKC_CapsLock,
				(alphaLock & theModifiers) != 0);
		}
		if (0 != (ChangedModifiers & optionKey)) {
			Keyboard_UpdateKeyMap2(MKC_Option,
				(optionKey & theModifiers) != 0);
		}
		if (0 != (ChangedModifiers & controlKey)) {
			Keyboard_UpdateKeyMap2(MKC_Control,
				(controlKey & theModifiers) != 0);
		}

		SavedModifiers = theModifiers;
	}
}

LOCALPROC ReconnectKeyCodes3(void)
{
	/*
		turn off any modifiers (other than alpha)
		that were turned on by drag and drop,
		unless still being held down.
	*/

	UInt32 theModifiers = GetCurrentKeyModifiers();

	MyUpdateKeyboardModifiers(theModifiers
		& (SavedModifiers | alphaLock));

	SavedModifiers = theModifiers;
}

/* --- display utilities --- */

/* DoForEachDisplay adapted from Apple Technical Q&A QA1168 */

typedef void
(*ForEachDisplayProcPtr) (CGDirectDisplayID display);

LOCALPROC DoForEachDisplay0(CGDisplayCount dspCount,
	CGDirectDisplayID *displays, ForEachDisplayProcPtr p)
{
	CGDisplayCount i;

	if (noErr == MyCGGetActiveDisplayList(dspCount,
		displays, &dspCount))
	{
		for (i = 0; i < dspCount; ++i) {
			p(displays[i]);
		}
	}
}

LOCALPROC DoForEachDisplay(ForEachDisplayProcPtr p)
{
	CGDisplayCount dspCount = 0;

	if (HaveMyCGGetActiveDisplayList()
		&& (noErr == MyCGGetActiveDisplayList(0, NULL, &dspCount)))
	{
		if (dspCount <= 2) {
			CGDirectDisplayID displays[2];
			DoForEachDisplay0(dspCount, displays, p);
		} else {
			CGDirectDisplayID *displays =
				calloc((size_t)dspCount, sizeof(CGDirectDisplayID));
			if (NULL != displays) {
				DoForEachDisplay0(dspCount, displays, p);
				free(displays);
			}
		}
	}
}

LOCALVAR void *datp;

LOCALPROC MyMainDisplayIDProc(CGDirectDisplayID display)
{
	CGDirectDisplayID *p = (CGDirectDisplayID *)datp;

	if (kCGNullDirectDisplay == *p) {
		*p = display;
	}
}

LOCALFUNC CGDirectDisplayID MyMainDisplayID(void)
{
	if (HaveMyCGMainDisplayID()) {
		return MyCGMainDisplayID();
	} else {
		/* for before OS X 10.2 */
		CGDirectDisplayID r = kCGNullDirectDisplay;
		void *savedatp = datp;
		datp = (void *)&r;
		DoForEachDisplay(MyMainDisplayIDProc);
		datp = savedatp;
		return r;
	}
}

/* --- cursor hiding --- */

#if 0
LOCALPROC MyShowCursorProc(CGDirectDisplayID display)
{
	(void) CGDisplayShowCursor(display);
}
#endif

LOCALPROC MyShowCursor(void)
{
#if 0
	/* ShowCursor(); deprecated */
	DoForEachDisplay(MyShowCursorProc);
#endif
	if (HaveMyCGDisplayShowCursor()) {
		(void) MyCGDisplayShowCursor(MyMainDisplayID());
			/* documentation now claims argument ignored */
	}
}

#if 0
LOCALPROC MyHideCursorProc(CGDirectDisplayID display)
{
	(void) CGDisplayHideCursor(display);
}
#endif

LOCALPROC MyHideCursor(void)
{
#if 0
	/* HideCursor(); deprecated */
	DoForEachDisplay(MyHideCursorProc);
#endif
	if (HaveMyCGDisplayHideCursor()) {
		(void) MyCGDisplayHideCursor(MyMainDisplayID());
			/* documentation now claims argument ignored */
	}
}

LOCALVAR blnr HaveCursorHidden = falseblnr;

LOCALPROC ForceShowCursor(void)
{
	if (HaveCursorHidden) {
		HaveCursorHidden = falseblnr;
		MyShowCursor();
	}
}

/* --- cursor moving --- */

LOCALPROC SetCursorArrow(void)
{
	SetThemeCursor(kThemeArrowCursor);
}

LOCALFUNC blnr MyMoveMouse(si4b h, si4b v)
{
	Point CurMousePos;
	Rect r;

#if VarFullScreen
	if (UseFullScreen)
#endif
#if MayFullScreen
	{
		h -= ViewHStart;
		v -= ViewVStart;
	}
#endif

#if EnableMagnify
	if (UseMagnify) {
		h *= MyWindowScale;
		v *= MyWindowScale;
	}
#endif

#if VarFullScreen
	if (UseFullScreen)
#endif
#if MayFullScreen
	{
		h += hOffset;
		v += vOffset;
	}
#endif

	GetWindowBounds(gMyMainWindow, kWindowContentRgn, &r);
	CurMousePos.h = r.left + h;
	CurMousePos.v = r.top + v;

	/*
		This method from SDL_QuartzWM.m, "Simple DirectMedia Layer",
		Copyright (C) 1997-2003 Sam Lantinga
	*/
	if (HaveMyCGSetLocalEventsSuppressionInterval()) {
		if (noErr != MyCGSetLocalEventsSuppressionInterval(0.0)) {
			/* don't use MacMsg which can call MyMoveMouse */
		}
	}
	if (HaveMyCGWarpMouseCursorPosition()) {
		CGPoint pt;
		pt.x = CurMousePos.h;
		pt.y = CurMousePos.v;
		if (noErr != MyCGWarpMouseCursorPosition(pt)) {
			/* don't use MacMsg which can call MyMoveMouse */
		}
	}
#if 0
	if (HaveMyCGDisplayMoveCursorToPoint()) {
		CGPoint pt;
		pt.x = CurMousePos.h;
		pt.y = CurMousePos.v;
		if (noErr != MyCGDisplayMoveCursorToPoint(
			MyMainDisplayID(), pt))
		{
			/* don't use MacMsg which can call MyMoveMouse */
		}
	}
#endif

	return trueblnr;
}

#if EnableMouseMotion && MayFullScreen
LOCALPROC AdjustMouseMotionGrab(void)
{
	if (gMyMainWindow != NULL) {
#if MayFullScreen
		if (GrabMachine) {
			/*
				if magnification changes, need to reset,
				even if HaveMouseMotion already true
			*/
			if (MyMoveMouse(ViewHStart + (ViewHSize / 2),
				ViewVStart + (ViewVSize / 2)))
			{
				SavedMouseH = ViewHStart + (ViewHSize / 2);
				SavedMouseV = ViewVStart + (ViewVSize / 2);
				HaveMouseMotion = trueblnr;
			}
		} else
#endif
		{
			if (HaveMouseMotion) {
				(void) MyMoveMouse(CurMouseH, CurMouseV);
				HaveMouseMotion = falseblnr;
			}
		}
	}
}
#endif

#if EnableMouseMotion && MayFullScreen
LOCALPROC MyMouseConstrain(void)
{
	si4b shiftdh;
	si4b shiftdv;

	if (SavedMouseH < ViewHStart + (ViewHSize / 4)) {
		shiftdh = ViewHSize / 2;
	} else if (SavedMouseH > ViewHStart + ViewHSize - (ViewHSize / 4)) {
		shiftdh = - ViewHSize / 2;
	} else {
		shiftdh = 0;
	}
	if (SavedMouseV < ViewVStart + (ViewVSize / 4)) {
		shiftdv = ViewVSize / 2;
	} else if (SavedMouseV > ViewVStart + ViewVSize - (ViewVSize / 4)) {
		shiftdv = - ViewVSize / 2;
	} else {
		shiftdv = 0;
	}
	if ((shiftdh != 0) || (shiftdv != 0)) {
		SavedMouseH += shiftdh;
		SavedMouseV += shiftdv;
		if (! MyMoveMouse(SavedMouseH, SavedMouseV)) {
			HaveMouseMotion = falseblnr;
		}
	}
}
#endif

#if 0
LOCALFUNC blnr InitMousePosition(void)
{
	/*
		Since there doesn't seem to be any nondeprecated
		way to get initial cursor position, instead
		start by moving cursor to known position.
	*/

#if VarFullScreen
	if (! UseFullScreen)
#endif
#if MayNotFullScreen
	{
		CurMouseH = 16;
		CurMouseV = 16;
		WantCursorHidden = trueblnr;
		(void) MyMoveMouse(CurMouseH, CurMouseV);
	}
#endif

	return trueblnr;
}
#endif

/* --- time, date, location, part 2 --- */

#include "DATE2SEC.h"

LOCALFUNC blnr InitLocationDat(void)
{
	MachineLocation loc;

	ReadLocation(&loc);
	CurMacLatitude = (ui5b)loc.latitude;
	CurMacLongitude = (ui5b)loc.longitude;
	CurMacDelta = (ui5b)loc.u.gmtDelta;

	{
		CFTimeZoneRef tz = CFTimeZoneCopySystem();
		if (tz) {
			/* CFAbsoluteTime */ ATimeBase = CFAbsoluteTimeGetCurrent();
			/* ETimeBase = GetCurrentEventTime(); */
			{
				CFGregorianDate d = CFAbsoluteTimeGetGregorianDate(
					ATimeBase, tz);
				double floorsec = floor(d.second);
				ATimeBase -= (d.second - floorsec);
				/* ETimeBase -= (d.second - floorsec); */
				TimeSecBase = Date2MacSeconds(floorsec,
					d.minute, d.hour,
					d.day, d.month, d.year);

				(void) CheckDateTime();
			}
			CFRelease(tz);
		}
	}

	return trueblnr;
}

LOCALPROC StartUpTimeAdjust(void)
{
	NextTickChangeTime = GetCurrentEventTime() + MyTickDuration;
}

/* --- sound, part 2 --- */

#if MySoundEnabled

LOCALPROC MySound_Start0(void)
{
	ThePlayOffset = 0;
	TheFillOffset = 0;
	TheWriteOffset = 0;
	MinFilledSoundBuffs = kSoundBuffers;
#if dbglog_SoundBuffStats
	MaxFilledSoundBuffs = 0;
#endif
	wantplaying = falseblnr;

#if MySoundRecenterSilence
	LastModSample = kCenterSound;
	SilentBlockCounter = SilentBlockThreshold;
#endif
}

/*
	Some of this code descended from CarbonSndPlayDB, an
	example from Apple, as found being used in vMac for Mac OS.
*/

#define SOUND_SAMPLERATE rate22khz
	/* = 0x56EE8BA3 = (7833600 * 2 / 704) << 16 */

LOCALPROC InsertSndDoCommand(SndChannelPtr chan, SndCommand * newCmd)
{
	if (-1 == chan->qHead) {
		chan->qHead = chan->qTail;
	}

	if (1 <= chan->qHead) {
		chan->qHead--;
	} else {
		chan->qHead = chan->qTail;
	}

	chan->queue[chan->qHead] = *newCmd;
}

/* call back */ static pascal void
MySound_CallBack(SndChannelPtr theChannel, SndCommand * theCallBackCmd)
{
	PerChanInfoPtr perChanInfoPtr =
		(PerChanInfoPtr)(theCallBackCmd->param2);
	blnr wantplaying0 = *perChanInfoPtr->wantplaying;

#if dbglog_SoundStuff
	fprintf(stderr, "Enter MySound_CallBack\n");
#endif

	if (perChanInfoPtr->PlayingBuffBlock) {
		/* finish with last sample */
#if dbglog_SoundStuff
		fprintf(stderr, "done with sample\n");
#endif

		*perChanInfoPtr->CurPlayOffset += kOneBuffLen;
		perChanInfoPtr->PlayingBuffBlock = falseblnr;
	}

	if ((! wantplaying0) && (kCenterSound == perChanInfoPtr->lastv)) {
#if dbglog_SoundStuff
		fprintf(stderr, "terminating\n");
#endif
	} else {
		SndCommand playCmd;
		tpSoundSamp p;
		ui4b CurPlayOffset = *perChanInfoPtr->CurPlayOffset;
		ui4b ToPlayLen = *perChanInfoPtr->CurFillOffset - CurPlayOffset;
		ui4b FilledSoundBuffs = ToPlayLen >> kLnOneBuffLen;

		if (FilledSoundBuffs < *perChanInfoPtr->MinFilledSoundBuffs) {
			*perChanInfoPtr->MinFilledSoundBuffs = FilledSoundBuffs;
		}

		if (wantplaying0 && (0 != FilledSoundBuffs)) {
			/* play next sample */
			p = perChanInfoPtr->dbhBufferPtr
				+ (CurPlayOffset & kAllBuffMask);
			perChanInfoPtr->PlayingBuffBlock = trueblnr;
			perChanInfoPtr->lastv =
				ConvertSoundSampleToNative(*(p + kOneBuffLen - 1));
#if dbglog_SoundStuff
			fprintf(stderr, "playing sample\n");
#endif
		} else {
#if dbglog_SoundStuff
			fprintf(stderr, "playing transistion\n");
#endif
			/* play transition */
			trSoundSamp v0 = perChanInfoPtr->lastv;
			trSoundSamp v1 = v0;
			p = perChanInfoPtr->dbhBufferPtr + kAllBuffLen;
			if (! wantplaying0) {
#if dbglog_SoundStuff
				fprintf(stderr, "transistion to silence\n");
#endif
				v1 = kCenterSound;
				perChanInfoPtr->lastv = kCenterSound;
			}

#if dbglog_SoundStuff
			fprintf(stderr, "v0 %d\n", v0);
			fprintf(stderr, "v1 %d\n", v1);
#endif

			RampSound(p, v0, v1);
			ConvertSoundBlockToNative(p);
		}

		perChanInfoPtr->soundHeader.samplePtr = (Ptr)p;
		perChanInfoPtr->soundHeader.numFrames =
			(unsigned long)kOneBuffLen;

		/* Insert our callback command */
		InsertSndDoCommand (theChannel, theCallBackCmd);

#if 0
		{
			int i;
			tpSoundSamp pS =
				(tpSoundSamp)perChanInfoPtr->soundHeader.samplePtr;

			for (i = perChanInfoPtr->soundHeader.numFrames; --i >= 0; )
			{
				fprintf(stderr, "%d\n", *pS++);
			}
		}
#endif

		/* Play the next buffer */
		playCmd.cmd = bufferCmd;
		playCmd.param1 = 0;
		playCmd.param2 = (long)&(perChanInfoPtr->soundHeader);
		InsertSndDoCommand (theChannel, &playCmd);
	}
}


LOCALPROC MySound_Start(void)
{
	if (NULL == sndChannel) {
		SndChannelPtr  chan = NULL;

		MySound_Start0();

		SndNewChannel(&chan, sampledSynth, initMono, nil);
		if (chan != NULL) {
			sndChannel = chan;

			TheperChanInfoR.PlayingBuffBlock = falseblnr;
			TheperChanInfoR.lastv = kCenterSound;
		}
	}
}

#define IgnorableEventMask \
	(mUpMask | keyDownMask | keyUpMask | autoKeyMask)

LOCALPROC MySound_Stop(void)
{
	if (sndChannel != NULL) {
#if 1
/*
		this may not be necessary, but try to clean up
		in case it might help prevent problems.
*/
		SCStatus r;
		blnr busy = falseblnr;

		wantplaying = falseblnr;
		do {
			r.scChannelBusy = falseblnr; /* what is this for? */
			if (noErr == SndChannelStatus(sndChannel,
				sizeof(SCStatus), &r))
			{
				busy = r.scChannelBusy;
			}
#if 0
			if (busy) {
				/*
					give time back, particularly important
					if got here on a suspend event.
				*/
				/*
					Oops, no. Not with carbon events. Our
					own callbacks can get called, such
					as MyTimerProc.
				*/
				EventRecord theEvent;

				{
					(void) WaitNextEvent(IgnorableEventMask,
						&theEvent, 1, NULL);
				}
			}
#endif
		} while (busy);
#endif
		SndDisposeChannel(sndChannel, true);
		sndChannel = NULL;
	}
}

LOCALFUNC blnr MySound_Init(void)
{
	gCarbonSndPlayDoubleBufferCallBackUPP =
		NewSndCallBackUPP(MySound_CallBack);
	if (gCarbonSndPlayDoubleBufferCallBackUPP != NULL) {
		TheperChanInfoR.dbhBufferPtr = TheSoundBuffer;

		TheperChanInfoR.CurPlayOffset = &ThePlayOffset;
		TheperChanInfoR.CurFillOffset = &TheFillOffset;
		TheperChanInfoR.MinFilledSoundBuffs = &MinFilledSoundBuffs;
		TheperChanInfoR.wantplaying = &wantplaying;

		/* Init basic per channel information */
		TheperChanInfoR.soundHeader.sampleRate = SOUND_SAMPLERATE;
			/* sample rate */
		TheperChanInfoR.soundHeader.numChannels = 1; /* one channel */
		TheperChanInfoR.soundHeader.loopStart = 0;
		TheperChanInfoR.soundHeader.loopEnd = 0;
		TheperChanInfoR.soundHeader.encode = cmpSH /* extSH */;
		TheperChanInfoR.soundHeader.baseFrequency = kMiddleC;
		TheperChanInfoR.soundHeader.numFrames =
			(unsigned long)kOneBuffLen;
		/* TheperChanInfoR.soundHeader.AIFFSampleRate = 0; */
			/* unused */
		TheperChanInfoR.soundHeader.markerChunk = nil;
		TheperChanInfoR.soundHeader.futureUse2 = 0;
		TheperChanInfoR.soundHeader.stateVars = nil;
		TheperChanInfoR.soundHeader.leftOverSamples = nil;
		TheperChanInfoR.soundHeader.compressionID = 0;
			/* no compression */
		TheperChanInfoR.soundHeader.packetSize = 0;
			/* no compression */
		TheperChanInfoR.soundHeader.snthID = 0;
		TheperChanInfoR.soundHeader.sampleSize = (1 << kLn2SoundSampSz);
			/* 8 or 16 bits per sample */
		TheperChanInfoR.soundHeader.sampleArea[0] = 0;
#if 3 == kLn2SoundSampSz
		TheperChanInfoR.soundHeader.format = kSoundNotCompressed;
#elif 4 == kLn2SoundSampSz
		TheperChanInfoR.soundHeader.format = k16BitNativeEndianFormat;
#else
#error "unsupported kLn2SoundSampSz"
#endif
		TheperChanInfoR.soundHeader.samplePtr = (Ptr)TheSoundBuffer;

		return trueblnr;
	}
	return falseblnr;
}

#endif


LOCALPROC MyAdjustGLforSize(int h, int v)
{
	if (GL_TRUE != aglSetCurrentContext(ctx)) {
		/* err = aglReportError() */
	} else {

		glClearColor (0.0, 0.0, 0.0, 1.0);

#if 1
		glViewport(0, 0, h, v);
		glMatrixMode(GL_PROJECTION);
		glLoadIdentity();
		glOrtho(0, h, 0, v, -1.0, 1.0);
		glMatrixMode(GL_MODELVIEW);
#endif

		glColor3f(0.0, 0.0, 0.0);
#if EnableMagnify
		if (UseMagnify) {
			glPixelZoom(MyWindowScale, - MyWindowScale);
		} else
#endif
		{
			glPixelZoom(1, -1);
		}
		glPixelStorei(GL_UNPACK_ROW_LENGTH, vMacScreenWidth);

		glClear(GL_COLOR_BUFFER_BIT);

		if (GL_TRUE != aglSetCurrentContext(NULL)) {
			/* err = aglReportError() */
		}

		ScreenChangedAll();
	}
}

LOCALVAR blnr WantScreensChangedCheck = falseblnr;

LOCALPROC MyUpdateOpenGLContext(void)
{
	if (NULL == ctx) {
		/* oops */
	} else if (GL_TRUE != aglSetCurrentContext(ctx)) {
		/* err = aglReportError() */
	} else {
		aglUpdateContext(ctx);
	}
}

#if 0 /* some experiments */
LOCALVAR CGrafPtr GrabbedPort = NULL;
#endif

#if 0
LOCALPROC AdjustMainScreenGrab(void)
{
	if (GrabMachine) {
		if (NULL == GrabbedPort) {
			/* CGDisplayCapture(MyMainDisplayID()); */
			CGCaptureAllDisplays();
			/* CGDisplayHideCursor( MyMainDisplayID() ); */
			GrabbedPort =
				CreateNewPortForCGDisplayID((UInt32)MyMainDisplayID());
			LockPortBits (GrabbedPort);
		}
	} else {
		if (GrabbedPort != NULL) {
			UnlockPortBits (GrabbedPort);
			/* CGDisplayShowCursor( MyMainDisplayID() ); */
			/* CGDisplayRelease(MyMainDisplayID()); */
			CGReleaseAllDisplays();
			GrabbedPort = NULL;
		}
	}
}
#endif

#if 0
typedef CGDisplayErr (*CGReleaseAllDisplaysProcPtr)
	(void);

LOCALPROC MyReleaseAllDisplays(void)
{
	if (HaveApplicationServicesBun()) {
		CGReleaseAllDisplaysProcPtr ReleaseAllDisplaysProc =
			(CGReleaseAllDisplaysProcPtr)
			CFBundleGetFunctionPointerForName(
				AppServBunRef, CFSTR("CGReleaseAllDisplays"));
		if (ReleaseAllDisplaysProc != NULL) {
			ReleaseAllDisplaysProc();
		}
	}
}

typedef CGDisplayErr (*CGCaptureAllDisplaysProcPtr)
	(void);

LOCALPROC MyCaptureAllDisplays(void)
{
	if (HaveApplicationServicesBun()) {
		CGCaptureAllDisplaysProcPtr CaptureAllDisplaysProc =
			(CGCaptureAllDisplaysProcPtr)
			CFBundleGetFunctionPointerForName(
				AppServBunRef, CFSTR("CGCaptureAllDisplays"));
		if (CaptureAllDisplaysProc != NULL) {
			CaptureAllDisplaysProc();
		}
	}
}
#endif

LOCALVAR AGLPixelFormat window_fmt = NULL;
LOCALVAR AGLContext window_ctx = NULL;

#ifndef UseAGLfullscreen
#define UseAGLfullscreen 0
#endif

#if UseAGLfullscreen
LOCALVAR AGLPixelFormat fullscreen_fmt = NULL;
LOCALVAR AGLContext fullscreen_ctx = NULL;
#endif

#if UseAGLfullscreen
LOCALPROC MaybeFullScreen(void)
{
	if (
#if VarFullScreen
		UseFullScreen &&
#endif
		(NULL == fullscreen_ctx)
		&& HaveMyCGDisplayPixelsWide()
		&& HaveMyCGDisplayPixelsHigh())
	{
		static const GLint fullscreen_attrib[] = {AGL_RGBA,
			AGL_NO_RECOVERY,
			AGL_FULLSCREEN,
			AGL_SINGLE_RENDERER, AGL_ACCELERATED,
#if UseAGLdoublebuff
			AGL_DOUBLEBUFFER,
#endif
			AGL_NONE};
		GDHandle theDevice;
		CGDirectDisplayID CurMainDisplayID = MyMainDisplayID();

		DMGetGDeviceByDisplayID(
			(DisplayIDType)CurMainDisplayID, &theDevice, false);
		fullscreen_fmt = aglChoosePixelFormat(
			&theDevice, 1, fullscreen_attrib);
		if (NULL == fullscreen_fmt) {
			/* err = aglReportError() */
		} else {
			fullscreen_ctx = aglCreateContext(fullscreen_fmt, NULL);
			if (NULL == fullscreen_ctx) {
				/* err = aglReportError() */
			} else {
				/* MyCaptureAllDisplays(); */
				if (GL_TRUE != aglSetFullScreen(fullscreen_ctx,
					0, 0, 0, 0))
				{
					/* err = aglReportError() */
				} else {
					Rect r;

					int h = MyCGDisplayPixelsWide(CurMainDisplayID);
					int v = MyCGDisplayPixelsHigh(CurMainDisplayID);

					GetWindowBounds(gMyMainWindow, kWindowContentRgn,
						&r);

					GLhOffset = r.left + hOffset;
					GLvOffset = v - (r.top + vOffset);

					ctx = fullscreen_ctx;
					MyAdjustGLforSize(h, v);
					return;
				}
				/* MyReleaseAllDisplays(); */

				if (GL_TRUE != aglDestroyContext(fullscreen_ctx)) {
					/* err = aglReportError() */
				}
				fullscreen_ctx = NULL;
			}

			aglDestroyPixelFormat (fullscreen_fmt);
			fullscreen_fmt = NULL;
		}
	}
}
#endif

#if UseAGLfullscreen
LOCALPROC NoFullScreen(void)
{
	if (fullscreen_ctx != NULL) {
		Rect r;
		int h;
		int v;

		GetWindowBounds(gMyMainWindow, kWindowContentRgn, &r);

		h = r.right - r.left;
		v = r.bottom - r.top;

		GLhOffset = hOffset;
		GLvOffset = v - vOffset;

		ctx = window_ctx;

		MyAdjustGLforSize(h, v);

		Update_Screen();

		if (fullscreen_ctx != NULL) {
			if (GL_TRUE != aglDestroyContext(fullscreen_ctx)) {
				/* err = aglReportError() */
			}
			fullscreen_ctx = NULL;
		}
		if (fullscreen_fmt != NULL) {
			aglDestroyPixelFormat(fullscreen_fmt);
			fullscreen_fmt = NULL;
		}
	}
}
#endif

#if UseAGLfullscreen
LOCALPROC AdjustOpenGLGrab(void)
{
	if (GrabMachine) {
		MaybeFullScreen();
	} else {
		NoFullScreen();
	}
}
#endif

#if MayFullScreen
LOCALPROC AdjustMachineGrab(void)
{
#if EnableMouseMotion
	AdjustMouseMotionGrab();
#endif
#if UseAGLfullscreen
	AdjustOpenGLGrab();
#endif
#if 0
	AdjustMainScreenGrab();
#endif
}
#endif

#if MayFullScreen
LOCALPROC UngrabMachine(void)
{
	GrabMachine = falseblnr;
	AdjustMachineGrab();
}
#endif

LOCALPROC ClearWeAreActive(void)
{
	if (gWeAreActive) {
		gWeAreActive = falseblnr;

		DisconnectKeyCodes2();

		SavedModifiers &= alphaLock;

		MyMouseButtonSet(falseblnr);

#if MayFullScreen
		UngrabMachine();
#endif

		ForceShowCursor();

		PostIfStoppedLowPriorityEvent();
	}
}

/* --- basic dialogs --- */

LOCALFUNC CFStringRef CFStringCreateFromSubstCStr(char *s,
	blnr AddEllipsis)
{
	int L;
	UniChar x[ClStrMaxLength];

	UniCharStrFromSubstCStr(&L, x, s, AddEllipsis);

	return CFStringCreateWithCharacters(kCFAllocatorDefault, x, L);
}

#define kMyStandardAlert 128

LOCALPROC CheckSavedMacMsg(void)
{
	/* called only on quit, if error saved but not yet reported */

	if (nullpr != SavedBriefMsg) {
		if (HaveMyCreateStandardAlert() && HaveMyRunStandardAlert()) {
			CFStringRef briefMsgu = CFStringCreateFromSubstCStr(
				SavedBriefMsg, falseblnr);
			if (NULL != briefMsgu) {
				CFStringRef longMsgu = CFStringCreateFromSubstCStr(
					SavedLongMsg, falseblnr);
				if (NULL != longMsgu) {
					DialogRef TheAlert;
					OSStatus err = MyCreateStandardAlert(
						(SavedFatalMsg) ? kAlertStopAlert
							: kAlertCautionAlert,
						briefMsgu, longMsgu, NULL,
						&TheAlert);
					if (noErr == err) {
						(void) MyRunStandardAlert(TheAlert, NULL, NULL);
					}
					CFRelease(longMsgu);
				}
				CFRelease(briefMsgu);
			}
		}

		SavedBriefMsg = nullpr;
	}
}

LOCALVAR blnr gTrueBackgroundFlag = falseblnr;
LOCALVAR blnr ADialogIsUp = falseblnr;

LOCALPROC MyBeginDialog(void)
{
	ClearWeAreActive();
	ADialogIsUp = trueblnr;
}

LOCALPROC MyEndDialog(void)
{
	ADialogIsUp = falseblnr;
	PostIfStoppedLowPriorityEvent();
}

/* --- hide/show menubar --- */

#if MayFullScreen
LOCALPROC My_HideMenuBar(void)
{
	if (HaveMySetSystemUIMode()) {
		(void) MySetSystemUIMode(MykUIModeAllHidden,
			MykUIOptionDisableAppleMenu
			| MykUIOptionDisableProcessSwitch
			/* | MykUIOptionDisableForceQuit */ /* too dangerous */
			/* | MykUIOptionDisableSessionTerminate */);
	} else {
		if (IsMenuBarVisible()) {
			HideMenuBar();
		}
	}
}
#endif

#if MayFullScreen
LOCALPROC My_ShowMenuBar(void)
{
	if (HaveMySetSystemUIMode()) {
		(void) MySetSystemUIMode(MykUIModeNormal,
			0);
	} else {
		if (! IsMenuBarVisible()) {
			ShowMenuBar();
		}
	}
}
#endif

/* --- drives, part 2 --- */

LOCALPROC InitDrives(void)
{
	/*
		This isn't really needed, Drives[i]
		need not have valid value when not vSonyIsInserted[i].
	*/
	tDrive i;

	for (i = 0; i < NumDrives; ++i) {
		Drives[i] = NotAfileRef;
		Sparsebundles[i] = NULL;
	}
}

LOCALPROC UnInitDrives(void)
{
	tDrive i;

	for (i = 0; i < NumDrives; ++i) {
		if (vSonyIsInserted(i)) {
			(void) vSonyEject(i);
		}
	}
}

LOCALFUNC tMacErr Sony_Insert0(SInt16 refnum, sparsebundle *sb, blnr locked)
{
	tDrive Drive_No;

	if (! FirstFreeDisk(&Drive_No)) {
	if (sb) {
		sparsebundle_close(sb);
	} else {
		(void) FSCloseFork(refnum);
	}
		return mnvm_tmfoErr;
	} else {
		Drives[Drive_No] = refnum;
		Sparsebundles[Drive_No] = sb;
		DiskInsertNotify(Drive_No, locked);
		return mnvm_noErr;
	}
}

LOCALPROC ReportStandardOpenDiskError(tMacErr err)
{
	if (mnvm_noErr != err) {
		if (mnvm_tmfoErr == err) {
			MacMsg(kStrTooManyImagesTitle,
				kStrTooManyImagesMessage, falseblnr);
		} else if (mnvm_opWrErr == err) {
			MacMsg(kStrImageInUseTitle,
				kStrImageInUseMessage, falseblnr);
		} else {
			MacMsg(kStrOpenFailTitle, kStrOpenFailMessage, falseblnr);
		}
	}
}

LOCALFUNC tMacErr InsertADiskFromFSRef(FSRef *theRef)
{
	tMacErr err;
	HFSUniStr255 forkName;
	SInt16 refnum;
	UInt8 path[PATH_MAX];
	blnr locked = falseblnr;

	if (CheckSaveMacErr(FSRefMakePath(theRef, path, PATH_MAX))) {
		sparsebundle *sb = sparsebundle_open((const char *)path);
		if (sb) {
			Sony_Insert0(0, sb, falseblnr);
			return mnvm_noErr;
		}
	}

	if (CheckSaveMacErr(FSGetDataForkName(&forkName))) {
		err = To_tMacErr(FSOpenFork(theRef, forkName.length,
			forkName.unicode, fsRdWrPerm, &refnum));
		switch (err) {
			case mnvm_permErr:
			case mnvm_wrPermErr:
			case mnvm_afpAccessDenied:
				locked = trueblnr;
				err = To_tMacErr(FSOpenFork(theRef, forkName.length,
					forkName.unicode, fsRdPerm, &refnum));
				break;
			default:
				break;
		}
		if (mnvm_noErr == err) {
			err = Sony_Insert0(refnum, NULL, locked);
		}
	}

	return err;
}

LOCALFUNC tMacErr InsertDisksFromDocList(AEDescList *docList)
{
	tMacErr err = mnvm_noErr;
	long itemsInList;
	long index;
	AEKeyword keyword;
	DescType typeCode;
	FSRef theRef;
	Size actualSize;

	if (CheckSaveMacErr(AECountItems(docList, &itemsInList))) {
		for (index = 1; index <= itemsInList; ++index) {
			if (CheckSaveMacErr(AEGetNthPtr(docList, index, typeFSRef,
				&keyword, &typeCode, (Ptr)&theRef,
				sizeof(FSRef), &actualSize)))
			if (CheckSavetMacErr(InsertADiskFromFSRef(&theRef)))
			{
			}
			if (mnvm_noErr != err) {
				goto label_fail;
			}
		}
	}

label_fail:
	return err;
}

LOCALFUNC tMacErr InsertADiskFromNameEtc(FSRef *ParentRef,
	char *fileName)
{
	tMacErr err;
	blnr isFolder;
	FSRef ChildRef;

	if (CheckSavetMacErr(MyMakeFSRefC(ParentRef, fileName,
		&isFolder, &ChildRef)))
	{
		if (isFolder) {
			err = mnvm_miscErr;
		} else {
			if (CheckSavetMacErr(InsertADiskFromFSRef(&ChildRef))) {
				/* ok */
			}
		}
	}

	return err;
}

#if IncludeSonyNew
LOCALFUNC tMacErr WriteZero(SInt16 refnum, ui5b L)
{
#define ZeroBufferSize 2048
	tMacErr err = mnvm_noErr;
	ui5b i;
	ui3b buffer[ZeroBufferSize];
	ByteCount actualCount;
	ui5b offset = 0;

	memset(&buffer, 0, ZeroBufferSize);

	while (L > 0) {
		i = (L > ZeroBufferSize) ? ZeroBufferSize : L;
		if (! CheckSaveMacErr(FSWriteFork(refnum,
			fsFromStart,
			offset,
			i,
			buffer,
			&actualCount)))
		{
			goto label_fail;
		}
		L -= i;
		offset += i;
	}

label_fail:
	return err;
}
#endif

#if IncludeSonyNew
LOCALFUNC tMacErr MyCreateFileCFStringRef(FSRef *saveFileParent,
	CFStringRef saveFileName, FSRef *NewRef)
{
	tMacErr err;
	UniChar buffer[255];

	CFIndex len = CFStringGetLength(saveFileName);

	if (len > 255) {
		len = 255;
	}

	CFStringGetCharacters(saveFileName, CFRangeMake(0, len), buffer);

	err = To_tMacErr(FSMakeFSRefUnicode(saveFileParent, len,
		buffer, kTextEncodingUnknown, NewRef));
	if (mnvm_fnfErr == err) { /* file is not there yet - create it */
		err = To_tMacErr(FSCreateFileUnicode(saveFileParent,
			len, buffer, 0, NULL, NewRef, NULL));
	}

	return err;
}
#endif

#if IncludeSonyNew
LOCALFUNC tMacErr MakeNewDisk0(FSRef *saveFileParent,
	CFStringRef saveFileName, ui5b L)
{
	tMacErr err;
	FSRef NewRef;
	HFSUniStr255 forkName;
	SInt16 refnum;

	if (CheckSavetMacErr(
		MyCreateFileCFStringRef(saveFileParent, saveFileName, &NewRef)))
	{
		if (CheckSaveMacErr(FSGetDataForkName(&forkName)))
		if (CheckSaveMacErr(FSOpenFork(&NewRef, forkName.length,
			forkName.unicode, fsRdWrPerm, &refnum)))
		{
			SInt64 forkSize = L;
			if (CheckSaveMacErr(
				FSSetForkSize(refnum, fsFromStart, forkSize)))
			/*
				zero out fork. It looks like this is already done,
				but documentation says this isn't guaranteed.
			*/
			if (CheckSavetMacErr(WriteZero(refnum, L)))
			{
				err = Sony_Insert0(refnum, NULL, falseblnr);
				refnum = NotAfileRef;
			}
			if (NotAfileRef != refnum) {
				(void) FSCloseFork(refnum);
			}
		}
		if (mnvm_noErr != err) {
			(void) FSDeleteObject(&NewRef);
		}
	}

	return err;
}
#endif

#if IncludeSonyNameNew
LOCALFUNC CFStringRef CFStringCreateWithPbuf(tPbuf i)
{
	return CFStringCreateWithBytes(NULL,
		(UInt8 *)PbufDat[i], PbufSize[i],
		kCFStringEncodingMacRoman, false);
}
#endif

pascal Boolean NavigationFilterProc(
	AEDesc* theItem, void* info, void* NavCallBackUserData,
	NavFilterModes theNavFilterModes);
pascal Boolean NavigationFilterProc(
	AEDesc* theItem, void* info, void* NavCallBackUserData,
	NavFilterModes theNavFilterModes)
{
	/* NavFileOrFolderInfo* theInfo = (NavFileOrFolderInfo*)info; */
	UnusedParam(theItem);
	UnusedParam(info);
	UnusedParam(theNavFilterModes);
	UnusedParam(NavCallBackUserData);

	return true; /* display all items */
}


pascal void NavigationEventProc(
	NavEventCallbackMessage callBackSelector,
	NavCBRecPtr callBackParms, void *NavCallBackUserData);
pascal void NavigationEventProc(
	NavEventCallbackMessage callBackSelector,
	NavCBRecPtr callBackParms, void *NavCallBackUserData)
{
	UnusedParam(NavCallBackUserData);

	switch (callBackSelector) {
		case kNavCBEvent: /* probably not needed in os x */
			switch (callBackParms->eventData.eventDataParms.event->what)
			{
				case updateEvt:
					{
						WindowPtr which =
							(WindowPtr)callBackParms
								->eventData.eventDataParms.event
								->message;

						BeginUpdate(which);

						if (which == gMyMainWindow) {
							Update_Screen();
						}

						EndUpdate(which);
					}
					break;
			}
			break;
#if 0
		case kNavCBUserAction:
			{
				NavUserAction userAction = NavDialogGetUserAction(
					callBackParms->context);
				switch (userAction) {
					case kNavUserActionOpen: {
						/* got something to open */
						break;
					}
				}
			}
			break;
		case kNavCBTerminate:
			break;
#endif
	}
}

LOCALPROC InsertADisk0(void)
{
	NavDialogRef theOpenDialog;
	NavDialogCreationOptions dialogOptions;
	NavReplyRecord theReply;
	NavTypeListHandle openList = NULL;
	NavEventUPP gEventProc = NewNavEventUPP(NavigationEventProc);
	NavObjectFilterUPP filterUPP =
		NewNavObjectFilterUPP(NavigationFilterProc);

	if (noErr == NavGetDefaultDialogCreationOptions(&dialogOptions)) {
		dialogOptions.modality = kWindowModalityAppModal;
		dialogOptions.optionFlags |= kNavDontAutoTranslate;
		dialogOptions.optionFlags &= ~ kNavAllowPreviews;
		if (noErr == NavCreateGetFileDialog(&dialogOptions,
			(NavTypeListHandle)openList,
			gEventProc, NULL,
			filterUPP, NULL, &theOpenDialog))
		{
			MyBeginDialog();
			(void) NavDialogRun(theOpenDialog);
			MyEndDialog();
			if (noErr == NavDialogGetReply(theOpenDialog,
				&theReply))
			{
				if (theReply.validRecord) {
					ReportStandardOpenDiskError(
						InsertDisksFromDocList(&theReply.selection));
				}
				(void) NavDisposeReply(&theReply);
			}
			NavDialogDispose(theOpenDialog);
		}
	}

	DisposeNavEventUPP(gEventProc);
	DisposeNavObjectFilterUPP(filterUPP);
}

#if IncludeSonyNew
LOCALPROC MakeNewDisk(ui5b L, CFStringRef NewDiskName)
{
	NavDialogRef theSaveDialog;
	NavDialogCreationOptions dialogOptions;
	NavReplyRecord theReply;
	NavEventUPP gEventProc = NewNavEventUPP(NavigationEventProc);

	if (noErr == NavGetDefaultDialogCreationOptions(&dialogOptions)) {
		dialogOptions.modality = kWindowModalityAppModal;
		dialogOptions.saveFileName = NewDiskName;
		if (noErr == NavCreatePutFileDialog(&dialogOptions,
			'TEXT', 'MPS ',
			gEventProc, NULL,
			&theSaveDialog))
		{
			MyBeginDialog();
			(void) NavDialogRun(theSaveDialog);
			MyEndDialog();
			if (noErr == NavDialogGetReply(theSaveDialog,
				&theReply))
			{
				if (theReply.validRecord) {
					long itemsInList;
					AEKeyword keyword;
					DescType typeCode;
					FSRef theRef;
					Size actualSize;

					if (noErr == AECountItems(
						&theReply.selection, &itemsInList))
					{
						if (itemsInList == 1) {
							if (noErr == AEGetNthPtr(
								&theReply.selection, 1, typeFSRef,
								&keyword, &typeCode, (Ptr)&theRef,
								sizeof(FSRef), &actualSize))
							{
								ReportStandardOpenDiskError(
									MakeNewDisk0(&theRef,
										theReply.saveFileName, L));
							}
						}
					}
				}
				(void) NavDisposeReply(&theReply);
			}
			NavDialogDispose(theSaveDialog);
		}
	}

	DisposeNavEventUPP(gEventProc);
}
#endif

LOCALFUNC tMacErr OpenMacRom(SInt16 *refnum)
{
	tMacErr err;

	err = OpenNamedFileInFolderRef(&MyDatDirRef, RomFileName, refnum);
	if (mnvm_fnfErr == err) {
		FSRef PrefRef;
		FSRef GryphelRef;
		FSRef ROMsRef;

		if (CheckSaveMacErr(FSFindFolder(kUserDomain,
			kPreferencesFolderType, kDontCreateFolder, &PrefRef)))
		if (CheckSavetMacErr(FindNamedChildRef(&PrefRef,
			"Gryphel", &GryphelRef)))
		if (CheckSavetMacErr(FindNamedChildRef(&GryphelRef,
			"mnvm_rom", &ROMsRef)))
		if (CheckSavetMacErr(OpenNamedFileInFolderRef(&ROMsRef,
			RomFileName, refnum)))
		{
			/* ok */
		}
	}

	return err;
}

LOCALFUNC blnr LoadMacRom(void)
{
	tMacErr err;
	SInt16 refnum;

	if (CheckSavetMacErr(OpenMacRom(&refnum))) {
		ByteCount actualCount;
		if (CheckSaveMacErr(FSReadFork(refnum, fsFromStart, 0,
			kROM_Size, ROM, &actualCount)))
		{
		}
		(void) FSCloseFork(refnum);
	}

	if (mnvm_noErr != err) {
		if (mnvm_fnfErr == err) {
			MacMsg(kStrNoROMTitle, kStrNoROMMessage, trueblnr);
		} else if (mnvm_eofErr == err) {
			MacMsg(kStrShortROMTitle, kStrShortROMMessage, trueblnr);
		} else {
			MacMsg(kStrNoReadROMTitle, kStrNoReadROMMessage, trueblnr);
		}

		SpeedStopped = trueblnr;
	}

	return trueblnr; /* keep launching Mini vMac, regardless */
}

LOCALFUNC blnr LoadInitialImages(void)
{
	tMacErr err = mnvm_noErr;
	int n = NumDrives > 9 ? 9 : NumDrives;
	int i;
	char s[16] = "disk?.dsk";

	for (i = 1; i <= n; ++i) {
		s[4] = '0' + i;
		if (! CheckSavetMacErr(InsertADiskFromNameEtc(&MyDatDirRef, s)))
		{
			if (mnvm_fnfErr != err) {
				ReportStandardOpenDiskError(err);
			}
			/* stop on first error (including file not found) */
			goto label_done;
		}
	}

label_done:
	return trueblnr;
}

#if UseActvFile

#define ActvCodeFileName "act_1"

LOCALFUNC tMacErr OpenActvCodeFile(SInt16 *refnum)
{
	tMacErr err;
	FSRef PrefRef;
	FSRef GryphelRef;
	FSRef ActRef;

	if (CheckSaveMacErr(FSFindFolder(kUserDomain,
		kPreferencesFolderType, kDontCreateFolder, &PrefRef)))
	if (CheckSavetMacErr(FindNamedChildRef(&PrefRef,
		"Gryphel", &GryphelRef)))
	if (CheckSavetMacErr(FindNamedChildRef(&GryphelRef,
		"mnvm_act", &ActRef)))
	if (CheckSavetMacErr(OpenNamedFileInFolderRef(&ActRef,
		ActvCodeFileName, refnum)))
	{
		/* ok */
	}

	return err;
}

LOCALFUNC tMacErr ActvCodeFileLoad(ui3p p)
{
	tMacErr err;
	SInt16 refnum;

	if (CheckSavetMacErr(OpenActvCodeFile(&refnum))) {
		ByteCount actualCount;
		err = To_tMacErr(FSReadFork(refnum, fsFromStart, 0,
			ActvCodeFileLen, p, &actualCount));
		(void) FSCloseFork(refnum);
	}

	return err;
}

LOCALFUNC tMacErr FindOrMakeNamedChildRef(FSRef *ParentRef,
	char *ChildName, FSRef *ChildRef)
{
	tMacErr err;
	blnr isFolder;
	int L;
	UniChar x[ClStrMaxLength];

	UniCharStrFromSubstCStr(&L, x, ChildName, falseblnr);
	if (CheckSavetMacErr(MyMakeFSRefUniChar(ParentRef, L, x,
		&isFolder, ChildRef)))
	{
		if (! isFolder) {
			err = mnvm_miscErr;
		}
	}
	if (mnvm_fnfErr == err) {
		err = To_tMacErr(FSCreateDirectoryUnicode(
			ParentRef, L, x, kFSCatInfoNone, NULL,
			ChildRef, NULL, NULL));
	}

	return err;
}

LOCALFUNC tMacErr ActvCodeFileSave(ui3p p)
{
	tMacErr err;
	SInt16 refnum;
	FSRef PrefRef;
	FSRef GryphelRef;
	FSRef ActRef;
	ByteCount count = ActvCodeFileLen;

	if (CheckSaveMacErr(FSFindFolder(kUserDomain,
		kPreferencesFolderType, kDontCreateFolder, &PrefRef)))
	if (CheckSavetMacErr(FindOrMakeNamedChildRef(&PrefRef,
		"Gryphel", &GryphelRef)))
	if (CheckSavetMacErr(FindOrMakeNamedChildRef(&GryphelRef,
		"mnvm_act", &ActRef)))
	if (CheckSavetMacErr(OpenWriteNamedFileInFolderRef(&ActRef,
		ActvCodeFileName, &refnum)))
	{
		ByteCount actualCount;
		err = To_tMacErr(FSWriteFork(refnum, fsFromStart, 0,
			count, p, &actualCount));
		(void) FSCloseFork(refnum);
	}

	return err;
}

#endif /* UseActvFile */

/* --- utilities for adapting to the environment --- */

LOCALPROC MyGetScreenBitsBounds(Rect *r)
{
	if (HaveMyCGDisplayBounds()) {
		CGRect cgr = MyCGDisplayBounds(MyMainDisplayID());

		r->left = cgr.origin.x;
		r->top = cgr.origin.y;
		r->right = cgr.origin.x + cgr.size.width;
		r->bottom = cgr.origin.y + cgr.size.height;
	}
}

#if MayNotFullScreen
LOCALPROC InvalWholeWindow(WindowRef mw)
{
	Rect bounds;

	GetWindowPortBounds(mw, &bounds);
	InvalWindowRect(mw, &bounds);
}
#endif

#if MayNotFullScreen
LOCALPROC MySetMacWindContRect(WindowRef mw, Rect *r)
{
	(void) SetWindowBounds (mw, kWindowContentRgn, r);
	InvalWholeWindow(mw);
}
#endif

#if MayNotFullScreen
LOCALFUNC blnr MyGetWindowTitleBounds(WindowRef mw, Rect *r)
{
	return (noErr == GetWindowBounds(mw, kWindowTitleBarRgn, r));
}
#endif

#if MayNotFullScreen
LOCALFUNC blnr MyGetWindowContBounds(WindowRef mw, Rect *r)
{
	return (noErr == GetWindowBounds(mw, kWindowContentRgn, r));
}
#endif

LOCALPROC MyGetGrayRgnBounds(Rect *r)
{
	GetRegionBounds(GetGrayRgn(), (Rect *)r);
}

#define openOnly 1
#define openPrint 2

LOCALFUNC blnr GotRequiredParams(AppleEvent *theAppleEvent)
{
	DescType typeCode;
	Size actualSize;
	OSErr theErr;

	theErr = AEGetAttributePtr(theAppleEvent, keyMissedKeywordAttr,
				typeWildCard, &typeCode, NULL, 0, &actualSize);
	if (errAEDescNotFound == theErr) { /* No more required params. */
		return trueblnr;
	} else if (noErr == theErr) { /* More required params! */
		return /* CheckSysCode(errAEEventNotHandled) */ falseblnr;
	} else { /* Unexpected Error! */
		return /* CheckSysCode(theErr) */ falseblnr;
	}
}

LOCALFUNC blnr GotRequiredParams0(AppleEvent *theAppleEvent)
{
	DescType typeCode;
	Size actualSize;
	OSErr theErr;

	theErr = AEGetAttributePtr(theAppleEvent, keyMissedKeywordAttr,
				typeWildCard, &typeCode, NULL, 0, &actualSize);
	if (errAEDescNotFound == theErr) { /* No more required params. */
		return trueblnr;
	} else if (noErr == theErr) { /* More required params! */
		return trueblnr; /* errAEEventNotHandled; */ /*^*/
	} else { /* Unexpected Error! */
		return /* CheckSysCode(theErr) */ falseblnr;
	}
}

/* call back */ static pascal OSErr OpenOrPrintFiles(
	AppleEvent *theAppleEvent, AppleEvent *reply, long aRefCon)
{
	/*
		Adapted from IM VI: AppleEvent Manager:
		Handling Required AppleEvents
	*/
	AEDescList docList;

	UnusedParam(reply);
	UnusedParam(aRefCon);
	/* put the direct parameter (a list of descriptors) into docList */
	if (noErr == (AEGetParamDesc(theAppleEvent, keyDirectObject,
		typeAEList, &docList)))
	{
		if (GotRequiredParams0(theAppleEvent)) {
			/* Check for missing required parameters */
			/* printIt = (openPrint == aRefCon) */
			ReportStandardOpenDiskError(
				InsertDisksFromDocList(&docList));
		}
		/* vCheckSysCode */ (void) (AEDisposeDesc(&docList));
	}

	PostIfStoppedLowPriorityEvent();

	return /* GetASysResultCode() */ 0;
}

/* call back */ static pascal OSErr DoOpenEvent(
	AppleEvent *theAppleEvent, AppleEvent *reply, long aRefCon)
/*
	This is the alternative to getting an
	open document event on startup.
*/
{
	UnusedParam(reply);
	UnusedParam(aRefCon);
	if (GotRequiredParams0(theAppleEvent)) {
	}
	return /* GetASysResultCode() */ 0;
		/* Make sure there are no additional "required" parameters. */
}


/* call back */ static pascal OSErr DoQuitEvent(
	AppleEvent *theAppleEvent, AppleEvent *reply, long aRefCon)
{
	UnusedParam(reply);
	UnusedParam(aRefCon);
	if (GotRequiredParams(theAppleEvent)) {
		RequestMacOff = trueblnr;
	}

	PostIfStoppedLowPriorityEvent();

	return /* GetASysResultCode() */ 0;
}

LOCALFUNC blnr MyInstallEventHandler(AEEventClass theAEEventClass,
	AEEventID theAEEventID, ProcPtr p,
	long handlerRefcon, blnr isSysHandler)
{
	return noErr == (AEInstallEventHandler(theAEEventClass,
		theAEEventID, NewAEEventHandlerUPP((AEEventHandlerProcPtr)p),
		handlerRefcon, isSysHandler));
}

LOCALPROC InstallAppleEventHandlers(void)
{
	if (noErr == AESetInteractionAllowed(kAEInteractWithLocal))
	if (MyInstallEventHandler(kCoreEventClass, kAEOpenApplication,
		(ProcPtr)DoOpenEvent, 0, falseblnr))
	if (MyInstallEventHandler(kCoreEventClass, kAEOpenDocuments,
		(ProcPtr)OpenOrPrintFiles, openOnly, falseblnr))
	if (MyInstallEventHandler(kCoreEventClass, kAEPrintDocuments,
		(ProcPtr)OpenOrPrintFiles, openPrint, falseblnr))
	if (MyInstallEventHandler(kCoreEventClass, kAEQuitApplication,
		(ProcPtr)DoQuitEvent, 0, falseblnr))
	{
	}
}

static pascal OSErr GlobalTrackingHandler(DragTrackingMessage message,
	WindowRef theWindow, void *handlerRefCon, DragReference theDragRef)
{
	RgnHandle hilightRgn;
	Rect Bounds;

	UnusedParam(theWindow);
	UnusedParam(handlerRefCon);
	switch(message) {
		case kDragTrackingEnterWindow:
			hilightRgn = NewRgn();
			if (hilightRgn != NULL) {
				SetScrnRectFromCoords(&Bounds,
					0, 0, vMacScreenHeight, vMacScreenWidth);
				RectRgn(hilightRgn, &Bounds);
				ShowDragHilite(theDragRef, hilightRgn, true);
				DisposeRgn(hilightRgn);
			}
			break;
		case kDragTrackingLeaveWindow:
			HideDragHilite(theDragRef);
			break;
	}

	return noErr;
}

LOCALFUNC tMacErr InsertADiskOrAliasFromFSRef(FSRef *theRef)
{
	tMacErr err;
	Boolean isFolder;
	Boolean isAlias;

	if (CheckSaveMacErr(FSResolveAliasFile(theRef, true,
		&isFolder, &isAlias)))
	{
		err = InsertADiskFromFSRef(theRef);
	}

	return err;
}

LOCALFUNC tMacErr InsertADiskOrAliasFromSpec(FSSpec *spec)
{
	tMacErr err;
	FSRef newRef;

	if (CheckSaveMacErr(FSpMakeFSRef(spec, &newRef)))
	if (CheckSavetMacErr(InsertADiskOrAliasFromFSRef(&newRef)))
	{
		/* ok */
	}

	return err;
}

static pascal OSErr GlobalReceiveHandler(WindowRef pWindow,
	void *handlerRefCon, DragReference theDragRef)
{
	SInt16 mouseUpModifiers;
	unsigned short items;
	unsigned short index;
	ItemReference theItem;
	Size SentSize;
	HFSFlavor r;

	UnusedParam(pWindow);
	UnusedParam(handlerRefCon);

	if (noErr == GetDragModifiers(theDragRef,
		NULL, NULL, &mouseUpModifiers))
	{
		MyUpdateKeyboardModifiers(mouseUpModifiers);
	}

	if (noErr == CountDragItems(theDragRef, &items)) {
		for (index = 1; index <= items; ++index) {
			if (noErr == GetDragItemReferenceNumber(theDragRef,
				index, &theItem))
			if (noErr == GetFlavorDataSize(theDragRef,
				theItem, flavorTypeHFS, &SentSize))
				/*
					On very old macs SentSize might only be big enough
					to hold the actual file name. Have not seen this
					in OS X, but still leave the check
					as '<=' instead of '=='.
				*/
			if (SentSize <= sizeof(HFSFlavor))
			if (noErr == GetFlavorData(theDragRef, theItem,
				flavorTypeHFS, (Ptr)&r, &SentSize, 0))
			{
				ReportStandardOpenDiskError(
					InsertADiskOrAliasFromSpec(&r.fileSpec));
			}
		}

#if 1
		if (gTrueBackgroundFlag) {
			ProcessSerialNumber currentProcess = {0, kCurrentProcess};

			(void) SetFrontProcess(&currentProcess);
		}
#endif
	}

	PostIfStoppedLowPriorityEvent();

	return noErr;
}

LOCALVAR DragTrackingHandlerUPP gGlobalTrackingHandler = NULL;
LOCALVAR DragReceiveHandlerUPP gGlobalReceiveHandler = NULL;

LOCALPROC UnPrepareForDragging(void)
{
	if (NULL != gGlobalReceiveHandler) {
		RemoveReceiveHandler(gGlobalReceiveHandler, gMyMainWindow);
		DisposeDragReceiveHandlerUPP(gGlobalReceiveHandler);
		gGlobalReceiveHandler = NULL;
	}
	if (NULL != gGlobalTrackingHandler) {
		RemoveTrackingHandler(gGlobalTrackingHandler, gMyMainWindow);
		DisposeDragTrackingHandlerUPP(gGlobalTrackingHandler);
		gGlobalTrackingHandler = NULL;
	}
}

LOCALFUNC blnr PrepareForDragging(void)
{
	blnr IsOk = falseblnr;

	gGlobalTrackingHandler = NewDragTrackingHandlerUPP(
		GlobalTrackingHandler);
	if (gGlobalTrackingHandler != NULL) {
		gGlobalReceiveHandler = NewDragReceiveHandlerUPP(
			GlobalReceiveHandler);
		if (gGlobalReceiveHandler != NULL) {
			if (noErr == InstallTrackingHandler(gGlobalTrackingHandler,
				gMyMainWindow, nil))
			{
				if (noErr == InstallReceiveHandler(
					gGlobalReceiveHandler, gMyMainWindow, nil))
				{
					IsOk = trueblnr;
				}
			}
		}
	}

	return IsOk;
}

LOCALPROC HandleEventLocation(EventRef theEvent)
{
	Point NewMousePos;

	if (! gWeAreActive) {
		return;
	}

	if (noErr == GetEventParameter(theEvent,
		kEventParamMouseLocation,
		typeQDPoint,
		NULL,
		sizeof(NewMousePos),
		NULL,
		&NewMousePos))
	{
		MousePositionNotify(NewMousePos);
	}
}

LOCALPROC HandleEventModifiers(EventRef theEvent)
{
	UInt32 theModifiers;

	if (gWeAreActive) {
		GetEventParameter(theEvent, kEventParamKeyModifiers,
			typeUInt32, NULL, sizeof(typeUInt32), NULL, &theModifiers);

		MyUpdateKeyboardModifiers(theModifiers);
	}
}

LOCALVAR blnr IsOurMouseMove;

static pascal OSStatus windowEventHandler(
	EventHandlerCallRef nextHandler, EventRef theEvent,
	void* userData)
{
	OSStatus result = eventNotHandledErr;
	UInt32 eventClass = GetEventClass(theEvent);
	UInt32 eventKind = GetEventKind(theEvent);

	UnusedParam(nextHandler);
	UnusedParam(userData);
	switch(eventClass) {
		case kEventClassWindow:
			switch(eventKind) {
				case kEventWindowClose:
					RequestMacOff = trueblnr;
					result = noErr;
					PostIfStoppedLowPriorityEvent();
					break;
				case kEventWindowDrawContent:
					Update_Screen();
					result = noErr;
					break;
				case kEventWindowClickContentRgn:
					MouseIsOutside = falseblnr;
					HandleEventLocation(theEvent);
					HandleEventModifiers(theEvent);
					MyMouseButtonSet(trueblnr);
					result = noErr;
					break;
				case kEventWindowFocusAcquired:
					gLackFocusFlag = falseblnr;
					result = noErr;
					PostIfStoppedLowPriorityEvent();
					break;
				case kEventWindowFocusRelinquish:
					{
						WindowRef window;

						(void) GetEventParameter(theEvent,
							kEventParamDirectObject, typeWindowRef,
							NULL, sizeof(WindowRef), NULL, &window);
						if ((window == gMyMainWindow)
							&& (window != gMyOldWindow))
						{
							ClearWeAreActive();
							gLackFocusFlag = trueblnr;
						}
					}
					result = noErr;
					break;
			}
			break;
		case kEventClassMouse:
			switch(eventKind) {
				case kEventMouseMoved:
				case kEventMouseDragged:
					MouseIsOutside = falseblnr;
#if 0 /* don't bother, CheckMouseState will take care of it, better */
					HandleEventLocation(theEvent);
					HandleEventModifiers(theEvent);
#endif
					IsOurMouseMove = trueblnr;
					result = noErr;
					break;
			}
			break;
	}

	return result;
}

LOCALFUNC blnr MyCreateNewWindow(Rect *Bounds, WindowPtr *theWindow)
{
	WindowPtr ResultWin;
	blnr IsOk = falseblnr;

	if (noErr == CreateNewWindow(

#if VarFullScreen
		UseFullScreen ?
#endif
#if MayFullScreen
			/*
				appears not to work properly with aglSetWindowRef
				at least in OS X 10.5.5
				also doesn't seem to be needed. maybe dates from when
				didn't cover all screens in full screen mode.
			*/
			/*
				Oops, no, kDocumentWindowClass doesn't seem to
				work quite right if made immediately after
				launch, title bar gets moved onscreen. At least
				in Intel 10.5.6, doesn't happen in PowerPC 10.4.11.
				Oddly, this problem doesn't happen if icon
				already in dock before launch, but perhaps
				that is just a timing issue.
				So use kPlainWindowClass after all.
			*/
			kPlainWindowClass
#endif
#if VarFullScreen
			:
#endif
#if MayNotFullScreen
			kDocumentWindowClass
#endif
		,

#if VarFullScreen
		UseFullScreen ?
#endif
#if MayFullScreen
			/* kWindowStandardHandlerAttribute */ 0
#endif
#if VarFullScreen
			:
#endif
#if MayNotFullScreen
			kWindowCloseBoxAttribute
				| kWindowCollapseBoxAttribute
#endif
		,

		Bounds, &ResultWin
	))
	{
#if VarFullScreen
		if (! UseFullScreen)
#endif
#if MayNotFullScreen
		{
			SetWindowTitleWithCFString(ResultWin,
				MyAppName /* CFSTR("Mini vMac") */);
		}
#endif
		InstallStandardEventHandler(GetWindowEventTarget(ResultWin));
		{
			static const EventTypeSpec windowEvents[] =
				{
					{kEventClassWindow, kEventWindowClose},
					{kEventClassWindow, kEventWindowDrawContent},
					{kEventClassWindow, kEventWindowClickContentRgn},
					{kEventClassMouse, kEventMouseMoved},
					{kEventClassMouse, kEventMouseDragged},
					{kEventClassWindow, kEventWindowFocusAcquired},
					{kEventClassWindow, kEventWindowFocusRelinquish}
				};
			InstallWindowEventHandler(ResultWin,
				NewEventHandlerUPP(windowEventHandler),
				GetEventTypeCount(windowEvents),
				windowEvents, 0, NULL);
		}

		*theWindow = ResultWin;

		IsOk = trueblnr;
	}

	return IsOk;
}

LOCALPROC ZapMyWState(void)
{
	gMyMainWindow = NULL;
	window_fmt = NULL;
	window_ctx = NULL;
	gGlobalReceiveHandler = NULL;
	gGlobalTrackingHandler = NULL;
}

LOCALPROC CloseAglCurrentContext(void)
{
	if (ctx != NULL) {
		/*
			Only because MyDrawWithOpenGL doesn't
			bother to do this. No one
			uses the CurrentContext
			without settting it first.
		*/
		if (GL_TRUE != aglSetCurrentContext(NULL)) {
			/* err = aglReportError() */
		}
		ctx = NULL;
	}
}

LOCALPROC CloseMainWindow(void)
{
	UnPrepareForDragging();

	if (window_ctx != NULL) {
		if (GL_TRUE != aglDestroyContext(window_ctx)) {
			/* err = aglReportError() */
		}
		window_ctx = NULL;
	}

	if (window_fmt != NULL) {
		aglDestroyPixelFormat(window_fmt);
		window_fmt = NULL;
	}

	if (gMyMainWindow != NULL) {
		DisposeWindow(gMyMainWindow);
		gMyMainWindow = NULL;
	}
}

enum {
	kMagStateNormal,
#if EnableMagnify
	kMagStateMagnifgy,
#endif
	kNumMagStates
};

#define kMagStateAuto kNumMagStates

#if MayNotFullScreen
LOCALVAR int CurWinIndx;
LOCALVAR blnr HavePositionWins[kNumMagStates];
LOCALVAR Point WinPositionWins[kNumMagStates];
#endif

LOCALFUNC blnr CreateMainWindow(void)
{
#if MayNotFullScreen
	int WinIndx;
#endif
	Rect MainScrnBounds;
	Rect AllScrnBounds;
	Rect NewWinRect;
	short leftPos;
	short topPos;
	short NewWindowHeight = vMacScreenHeight;
	short NewWindowWidth = vMacScreenWidth;
	blnr IsOk = falseblnr;

#if VarFullScreen
	if (UseFullScreen) {
		My_HideMenuBar();
	} else {
		My_ShowMenuBar();
	}
#else
#if MayFullScreen
	My_HideMenuBar();
#endif
#endif

	MyGetGrayRgnBounds(&AllScrnBounds);
	MyGetScreenBitsBounds(&MainScrnBounds);

#if EnableMagnify
	if (UseMagnify) {
		NewWindowHeight *= MyWindowScale;
		NewWindowWidth *= MyWindowScale;
	}
#endif

	leftPos = MainScrnBounds.left
		+ ((MainScrnBounds.right - MainScrnBounds.left)
			- NewWindowWidth) / 2;
	topPos = MainScrnBounds.top
		+ ((MainScrnBounds.bottom - MainScrnBounds.top)
			- NewWindowHeight) / 2;
	if (leftPos < MainScrnBounds.left) {
		leftPos = MainScrnBounds.left;
	}
	if (topPos < MainScrnBounds.top) {
		topPos = MainScrnBounds.top;
	}

#if VarFullScreen
	if (UseFullScreen)
#endif
#if MayFullScreen
	{
		ViewHSize = MainScrnBounds.right - MainScrnBounds.left;
		ViewVSize = MainScrnBounds.bottom - MainScrnBounds.top;
#if EnableMagnify
		if (UseMagnify) {
			ViewHSize /= MyWindowScale;
			ViewVSize /= MyWindowScale;
		}
#endif
		if (ViewHSize >= vMacScreenWidth) {
			ViewHStart = 0;
			ViewHSize = vMacScreenWidth;
		} else {
			ViewHSize &= ~ 1;
		}
		if (ViewVSize >= vMacScreenHeight) {
			ViewVStart = 0;
			ViewVSize = vMacScreenHeight;
		} else {
			ViewVSize &= ~ 1;
		}
	}
#endif

	/* Create window rectangle and centre it on the screen */
	SetRect(&MainScrnBounds, 0, 0, NewWindowWidth, NewWindowHeight);
	OffsetRect(&MainScrnBounds, leftPos, topPos);

#if VarFullScreen
	if (UseFullScreen)
#endif
#if MayFullScreen
	{
		NewWinRect = AllScrnBounds;
	}
#endif
#if VarFullScreen
	else
#endif
#if MayNotFullScreen
	{
#if EnableMagnify
		if (UseMagnify) {
			WinIndx = kMagStateMagnifgy;
		} else
#endif
		{
			WinIndx = kMagStateNormal;
		}

		if (! HavePositionWins[WinIndx]) {
			WinPositionWins[WinIndx].h = leftPos;
			WinPositionWins[WinIndx].v = topPos;
			HavePositionWins[WinIndx] = trueblnr;
			NewWinRect = MainScrnBounds;
		} else {
			SetRect(&NewWinRect, 0, 0, NewWindowWidth, NewWindowHeight);
			OffsetRect(&NewWinRect,
				WinPositionWins[WinIndx].h, WinPositionWins[WinIndx].v);
		}
	}
#endif

#if MayNotFullScreen
	CurWinIndx = WinIndx;
#endif

#if VarFullScreen
	if (UseFullScreen)
#endif
#if MayFullScreen
	{
		hOffset = MainScrnBounds.left - AllScrnBounds.left;
		vOffset = MainScrnBounds.top - AllScrnBounds.top;
	}
#endif

	if (MyCreateNewWindow(&NewWinRect, &gMyMainWindow)) {
		static const GLint window_attrib[] = {AGL_RGBA,
#if UseAGLdoublebuff
			AGL_DOUBLEBUFFER,
#endif
			/* AGL_DEPTH_SIZE, 16,  */
			AGL_NONE};

#if 0 != vMacScreenDepth
		ColorModeWorks = trueblnr;
#endif

		window_fmt = aglChoosePixelFormat(NULL, 0, window_attrib);
		if (NULL == window_fmt) {
			/* err = aglReportError() */
		} else {
			window_ctx = aglCreateContext(window_fmt, NULL);
			if (NULL == window_ctx) {
				/* err = aglReportError() */
			} else {

				ShowWindow(gMyMainWindow);

				if (GL_TRUE != (
					/*
						aglSetDrawable is deprecated, but use it anyway
						if at all possible, because aglSetWindowRef
						doesn't seeem to work properly on a
						kPlainWindowClass window.
						Should move to Cocoa.
					*/
					HaveMyaglSetDrawable()
					? MyaglSetDrawable(window_ctx,
						GetWindowPort(gMyMainWindow))
					:
					HaveMyaglSetWindowRef()
					? MyaglSetWindowRef(window_ctx, gMyMainWindow)
					:
					GL_FALSE))
				{
					/* err = aglReportError() */
				} else {
					ctx = window_ctx;

#if VarFullScreen
					if (UseFullScreen)
#endif
#if MayFullScreen
					{
						int h = NewWinRect.right - NewWinRect.left;
						int v = NewWinRect.bottom - NewWinRect.top;

						GLhOffset = hOffset;
						GLvOffset = v - vOffset;
						MyAdjustGLforSize(h, v);
					}
#endif
#if VarFullScreen
					else
#endif
#if MayNotFullScreen
					{
						GLhOffset = 0;
						GLvOffset = NewWindowHeight;
						MyAdjustGLforSize(NewWindowWidth,
							NewWindowHeight);
					}
#endif

#if UseAGLdoublebuff && 1
					{
						GLint agSwapInterval = 1;
						if (GL_TRUE != aglSetInteger(
							window_ctx, AGL_SWAP_INTERVAL,
							&agSwapInterval))
						{
							MacMsg("oops", "aglSetInteger failed",
								falseblnr);
						} else {
							/*
								MacMsg("good", "aglSetInteger ok",
									falseblnr);
							*/
						}
					}
#endif

#if VarFullScreen
					if (! UseFullScreen)
#endif
#if MayNotFullScreen
					{
						/* check if window rect valid */
						Rect tr;

						if (MyGetWindowTitleBounds(gMyMainWindow, &tr))
						{
							if (! RectInRgn(&tr, GetGrayRgn())) {
								MySetMacWindContRect(gMyMainWindow,
									&MainScrnBounds);
								if (MyGetWindowTitleBounds(
									gMyMainWindow, &tr))
								{
									if (! RectInRgn(&tr, GetGrayRgn()))
									{
										OffsetRect(&MainScrnBounds, 0,
											AllScrnBounds.top - tr.top);
										MySetMacWindContRect(
											gMyMainWindow,
											&MainScrnBounds);
									}
								}
							}
						}
					}
#endif

					(void) PrepareForDragging();

					IsOk = trueblnr;
				}
			}
		}
	}

	return IsOk;
}

struct MyWState {
	WindowPtr f_MainWindow;
	AGLPixelFormat f_fmt;
	AGLContext f_ctx;
#if MayFullScreen
	short f_hOffset;
	short f_vOffset;
	ui4r f_ViewHSize;
	ui4r f_ViewVSize;
	ui4r f_ViewHStart;
	ui4r f_ViewVStart;
#endif
#if VarFullScreen
	blnr f_UseFullScreen;
#endif
#if EnableMagnify
	blnr f_UseMagnify;
#endif
#if MayNotFullScreen
	int f_CurWinIndx;
#endif
	short f_GLhOffset;
	short f_GLvOffset;
	DragTrackingHandlerUPP f_gGlobalTrackingHandler;
	DragReceiveHandlerUPP f_gGlobalReceiveHandler;
};
typedef struct MyWState MyWState;

LOCALPROC GetMyWState(MyWState *r)
{
	r->f_MainWindow = gMyMainWindow;
	r->f_fmt = window_fmt;
	r->f_ctx = window_ctx;
#if MayFullScreen
	r->f_hOffset = hOffset;
	r->f_vOffset = vOffset;
	r->f_ViewHSize = ViewHSize;
	r->f_ViewVSize = ViewVSize;
	r->f_ViewHStart = ViewHStart;
	r->f_ViewVStart = ViewVStart;
#endif
#if VarFullScreen
	r->f_UseFullScreen = UseFullScreen;
#endif
#if EnableMagnify
	r->f_UseMagnify = UseMagnify;
#endif
#if MayNotFullScreen
	r->f_CurWinIndx = CurWinIndx;
#endif
	r->f_GLhOffset = GLhOffset;
	r->f_GLvOffset = GLvOffset;
	r->f_gGlobalTrackingHandler = gGlobalTrackingHandler;
	r->f_gGlobalReceiveHandler = gGlobalReceiveHandler;
}

LOCALPROC SetMyWState(MyWState *r)
{
	gMyMainWindow = r->f_MainWindow;
	window_fmt = r->f_fmt;
	window_ctx = r->f_ctx;
#if MayFullScreen
	hOffset = r->f_hOffset;
	vOffset = r->f_vOffset;
	ViewHSize = r->f_ViewHSize;
	ViewVSize = r->f_ViewVSize;
	ViewHStart = r->f_ViewHStart;
	ViewVStart = r->f_ViewVStart;
#endif
#if VarFullScreen
	UseFullScreen = r->f_UseFullScreen;
#endif
#if EnableMagnify
	UseMagnify = r->f_UseMagnify;
#endif
#if MayNotFullScreen
	CurWinIndx = r->f_CurWinIndx;
#endif
	GLhOffset = r->f_GLhOffset;
	GLvOffset = r->f_GLvOffset;
	gGlobalTrackingHandler = r->f_gGlobalTrackingHandler;
	gGlobalReceiveHandler = r->f_gGlobalReceiveHandler;

	ctx = window_ctx;
}

LOCALFUNC blnr ReCreateMainWindow(void)
{
	MyWState old_state;
	MyWState new_state;

#if VarFullScreen
	if (! UseFullScreen)
#endif
#if MayNotFullScreen
	{
		/* save old position */
		if (gMyMainWindow != NULL) {
			Rect r;

			if (MyGetWindowContBounds(gMyMainWindow, &r)) {
				WinPositionWins[CurWinIndx].h = r.left;
				WinPositionWins[CurWinIndx].v = r.top;
			}
		}
	}
#endif

#if MayFullScreen
	UngrabMachine();
#endif

	CloseAglCurrentContext();

	gMyOldWindow = gMyMainWindow;

	GetMyWState(&old_state);

	ZapMyWState();

#if VarFullScreen
	UseFullScreen = WantFullScreen;
#endif
#if EnableMagnify
	UseMagnify = WantMagnify;
#endif

	if (! CreateMainWindow()) {
		gMyOldWindow = NULL;
		CloseMainWindow();
		SetMyWState(&old_state);

#if VarFullScreen
		if (UseFullScreen) {
			My_HideMenuBar();
		} else {
			My_ShowMenuBar();
		}
#endif

		/* avoid retry */
#if VarFullScreen
		WantFullScreen = UseFullScreen;
#endif
#if EnableMagnify
		WantMagnify = UseMagnify;
#endif

		return falseblnr;
	} else {
		GetMyWState(&new_state);
		SetMyWState(&old_state);
		CloseMainWindow();
		gMyOldWindow = NULL;
		SetMyWState(&new_state);

		if (HaveCursorHidden) {
			(void) MyMoveMouse(CurMouseH, CurMouseV);
			WantCursorHidden = trueblnr;
		} else {
			MouseIsOutside = falseblnr; /* don't know */
		}

		return trueblnr;
	}
}

#if VarFullScreen && EnableMagnify
enum {
	kWinStateWindowed,
#if EnableMagnify
	kWinStateFullScreen,
#endif
	kNumWinStates
};
#endif

#if VarFullScreen && EnableMagnify
LOCALVAR int WinMagStates[kNumWinStates];
#endif

LOCALPROC ZapWinStateVars(void)
{
#if MayNotFullScreen
	{
		int i;

		for (i = 0; i < kNumMagStates; ++i) {
			HavePositionWins[i] = falseblnr;
		}
	}
#endif
#if VarFullScreen && EnableMagnify
	{
		int i;

		for (i = 0; i < kNumWinStates; ++i) {
			WinMagStates[i] = kMagStateAuto;
		}
	}
#endif
}

#if VarFullScreen
LOCALPROC ToggleWantFullScreen(void)
{
	WantFullScreen = ! WantFullScreen;

#if EnableMagnify
	{
		int OldWinState =
			UseFullScreen ? kWinStateFullScreen : kWinStateWindowed;
		int OldMagState =
			UseMagnify ? kMagStateMagnifgy : kMagStateNormal;
		int NewWinState =
			WantFullScreen ? kWinStateFullScreen : kWinStateWindowed;
		int NewMagState = WinMagStates[NewWinState];
		WinMagStates[OldWinState] = OldMagState;
		if (kMagStateAuto != NewMagState) {
			WantMagnify = (kMagStateMagnifgy == NewMagState);
		} else {
			WantMagnify = falseblnr;
			if (WantFullScreen
				&& HaveMyCGDisplayPixelsWide()
				&& HaveMyCGDisplayPixelsHigh())
			{
				CGDirectDisplayID CurMainDisplayID = MyMainDisplayID();

				if ((MyCGDisplayPixelsWide(CurMainDisplayID)
					>= vMacScreenWidth * MyWindowScale)
					&& (MyCGDisplayPixelsHigh(CurMainDisplayID)
					>= vMacScreenHeight * MyWindowScale)
					)
				{
					WantMagnify = trueblnr;
				}
			}
		}
	}
#endif
}
#endif

LOCALPROC LeaveSpeedStopped(void)
{
#if MySoundEnabled
	MySound_Start();
#endif

	StartUpTimeAdjust();
	(void) SetEventLoopTimerNextFireTime(
		MyTimerRef, MyTickDuration);
}

LOCALPROC EnterSpeedStopped(void)
{
#if MySoundEnabled
	MySound_Stop();
#endif
}

LOCALPROC DoNotInBackgroundTasks(void)
{
#if 0
	if (HaveMyCGCursorIsVisible()) {
		HaveCursorHidden = ! MyCGCursorIsVisible();

		/*
			This shouldn't be needed, but have seen
			cursor state get messed up in 10.4.
			If the os x hide count gets off, this
			should fix it within a few ticks.

			oops, no, doesn't seem to be accurate,
			and makes things worse. particularly if
			cursor in obscured state after typing
			into dialog.
		*/
		/* trying a different approach further below */
	}
#endif

	if (HaveCursorHidden != (
#if MayNotFullScreen
		(WantCursorHidden
#if VarFullScreen
			|| UseFullScreen
#endif
		) &&
#endif
		gWeAreActive && ! CurSpeedStopped))
	{
		HaveCursorHidden = ! HaveCursorHidden;
		if (HaveCursorHidden) {
			MyHideCursor();
		} else {
			/*
				kludge for OS X, where mouse over Dock devider
				changes cursor, and never sets it back.
			*/
			SetCursorArrow();

			MyShowCursor();
		}
	}

	/* check if actual cursor visibility is what it should be */
	if (HaveMyCGCursorIsVisible()) {
		/* but only in OS X 10.3 and later */
		if (MyCGCursorIsVisible()) {
			if (HaveCursorHidden) {
				MyHideCursor();
				if (MyCGCursorIsVisible()) {
					/*
						didn't work, attempt undo so that
						hide cursor count won't get large
					*/
					MyShowCursor();
				}
			}
		} else {
			if (! HaveCursorHidden) {
				MyShowCursor();
				/*
					don't check if worked, assume can't decrement
					hide cursor count below 0
				*/
			}
		}
	}
}

LOCALPROC CheckForSavedTasks(void)
{
	if (MyEvtQNeedRecover) {
		MyEvtQNeedRecover = falseblnr;

		/* attempt cleanup, MyEvtQNeedRecover may get set again */
		MyEvtQTryRecoverFromFull();
	}

#if EnableMouseMotion && MayFullScreen
	if (HaveMouseMotion) {
		MyMouseConstrain();
	}
#endif

	if (RequestMacOff) {
		RequestMacOff = falseblnr;
		if (AnyDiskInserted()) {
			MacMsgOverride(kStrQuitWarningTitle,
				kStrQuitWarningMessage);
		} else {
			ForceMacOff = trueblnr;
		}
	}

	if (ForceMacOff) {
		QuitApplicationEventLoop();
		return;
	}

	if (! gWeAreActive) {
		if (! (gTrueBackgroundFlag || ADialogIsUp || gLackFocusFlag)) {
			gWeAreActive = trueblnr;
			ReconnectKeyCodes3();
			SetCursorArrow();
		}
	}

#if VarFullScreen
	if (gTrueBackgroundFlag && WantFullScreen) {
		ToggleWantFullScreen();
	}
#endif

	if (CurSpeedStopped != (SpeedStopped ||
		(gTrueBackgroundFlag && ! RunInBackground
#if EnableAutoSlow && 0
			&& (QuietSubTicks >= 4092)
#endif
		)))
	{
		CurSpeedStopped = ! CurSpeedStopped;
		if (CurSpeedStopped) {
			EnterSpeedStopped();
		} else {
			LeaveSpeedStopped();
		}
	}

#if EnableMagnify || VarFullScreen
	if (gWeAreActive) {
		if (0
#if EnableMagnify
			|| (UseMagnify != WantMagnify)
#endif
#if VarFullScreen
			|| (UseFullScreen != WantFullScreen)
#endif
			)
		{
			(void) ReCreateMainWindow();
		}
	}
#endif

#if MayFullScreen
	if (GrabMachine != (
#if VarFullScreen
		UseFullScreen &&
#endif
		gWeAreActive && ! CurSpeedStopped))
	{
		GrabMachine = ! GrabMachine;
		AdjustMachineGrab();
	}
#endif

	if ((nullpr != SavedBriefMsg) & ! MacMsgDisplayed) {
		MacMsgDisplayOn();
	}

	if (WantScreensChangedCheck) {
		WantScreensChangedCheck = falseblnr;
		MyUpdateOpenGLContext();
	}

	if (NeedWholeScreenDraw) {
		NeedWholeScreenDraw = falseblnr;
		ScreenChangedAll();
	}

	MyDrawChangesAndClear();

	if (! gWeAreActive) {
		/*
			dialog during drag and drop hangs if in background
				and don't want recursive dialogs
			so wait til later to display dialog
		*/
	} else {
#if IncludeSonyNew
		if (vSonyNewDiskWanted) {
#if IncludeSonyNameNew
			if (vSonyNewDiskName != NotAPbuf) {
				CFStringRef NewDiskName =
					CFStringCreateWithPbuf(vSonyNewDiskName);
				MakeNewDisk(vSonyNewDiskSize, NewDiskName);
				if (NewDiskName != NULL) {
					CFRelease(NewDiskName);
				}
				PbufDispose(vSonyNewDiskName);
				vSonyNewDiskName = NotAPbuf;
			} else
#endif
			{
				MakeNewDisk(vSonyNewDiskSize, NULL);
			}
			vSonyNewDiskWanted = falseblnr;
				/* must be done after may have gotten disk */
		}
#endif
		if (RequestInsertDisk) {
			RequestInsertDisk = falseblnr;
			InsertADisk0();

			PostIfStoppedLowPriorityEvent();
		}
	}

	if (gWeAreActive) {
		DoNotInBackgroundTasks();
	}
}

#define CheckItem CheckMenuItem

/* Menu Constants */

#define kAppleMenu   128
#define kFileMenu    129
#define kSpecialMenu 130

enum {
	kCmdIdNull,
	kCmdIdMoreCommands,

	kNumCmdIds
};

LOCALFUNC OSStatus MyProcessCommand(MenuCommand inCommandID)
{
	OSStatus result = noErr;

	switch (inCommandID) {
		case kHICommandAbout:
			DoAboutMsg();
			break;
		case kHICommandQuit:
			RequestMacOff = trueblnr;
			break;
		case kHICommandOpen:
			RequestInsertDisk = trueblnr;
			break;
		case kCmdIdMoreCommands:
			DoMoreCommandsMsg();
			break;
		default:
			result = eventNotHandledErr;
			break;
	}

	return result;
}

LOCALFUNC OSStatus Keyboard_UpdateKeyMap3(EventRef theEvent, blnr down)
{
	UInt32 uiKeyCode;

	HandleEventModifiers(theEvent);
	GetEventParameter(theEvent, kEventParamKeyCode, typeUInt32, NULL,
		sizeof(uiKeyCode), NULL, &uiKeyCode);
	Keyboard_UpdateKeyMap2(uiKeyCode & 0x000000FF, down);
	return noErr;
}

static pascal OSStatus MyEventHandler(EventHandlerCallRef nextHandler,
	EventRef theEvent, void * userData)
{
	OSStatus result = eventNotHandledErr;
	UInt32 eventClass = GetEventClass(theEvent);
	UInt32 eventKind = GetEventKind(theEvent);

	UnusedParam(userData);

	switch (eventClass) {
		case kEventClassMouse:
			switch (eventKind) {
				case kEventMouseDown:
#if MayFullScreen
					if (GrabMachine) {
						HandleEventLocation(theEvent);
						HandleEventModifiers(theEvent);
						MyMouseButtonSet(trueblnr);
						result = noErr;
					} else
#endif
					{
						result = CallNextEventHandler(
							nextHandler, theEvent);
					}
					break;
				case kEventMouseUp:
					HandleEventLocation(theEvent);
					HandleEventModifiers(theEvent);
					MyMouseButtonSet(falseblnr);
#if MayFullScreen
					if (GrabMachine) {
						result = noErr;
					} else
#endif
					{
						result = CallNextEventHandler(
							nextHandler, theEvent);
					}
					break;
				case kEventMouseMoved:
				case kEventMouseDragged:
					IsOurMouseMove = falseblnr;
					result = CallNextEventHandler(
						nextHandler, theEvent);
						/*
							Actually, mousing over window does't seem
							to go through here, it goes directly to
							the window routine. But since not documented
							either way, leave the check in case this
							changes.
						*/
					if (! IsOurMouseMove) {
						MouseIsOutside = trueblnr;
#if 0 /* don't bother, CheckMouseState will take care of it, better */
						HandleEventLocation(theEvent);
						HandleEventModifiers(theEvent);
#endif
					}
					break;
			}
			break;
		case kEventClassApplication:
			switch (eventKind) {
				case kEventAppActivated:
					gTrueBackgroundFlag = falseblnr;
					result = noErr;
					PostIfStoppedLowPriorityEvent();
					break;
				case kEventAppDeactivated:
					gTrueBackgroundFlag = trueblnr;
					result = noErr;
					ClearWeAreActive();
					break;
			}
			break;
		case kEventClassCommand:
			switch (eventKind) {
				case kEventProcessCommand:
					{
						HICommand hiCommand;

						GetEventParameter(theEvent,
							kEventParamDirectObject, typeHICommand,
							NULL, sizeof(HICommand), NULL, &hiCommand);
						result = MyProcessCommand(hiCommand.commandID);
						PostIfStoppedLowPriorityEvent();
					}
					break;
			}
			break;
		case kEventClassKeyboard:
			if (! gWeAreActive) {
				return CallNextEventHandler(nextHandler, theEvent);
			} else {
				switch (eventKind) {
					case kEventRawKeyDown:
						result = Keyboard_UpdateKeyMap3(
							theEvent, trueblnr);
						PostIfStoppedLowPriorityEvent();
						break;
					case kEventRawKeyUp:
						result = Keyboard_UpdateKeyMap3(
							theEvent, falseblnr);
						PostIfStoppedLowPriorityEvent();
						break;
					case kEventRawKeyModifiersChanged:
						HandleEventModifiers(theEvent);
						result = noErr;
						PostIfStoppedLowPriorityEvent();
						break;
					default:
						break;
				}
			}
			break;
		case 'MnvM':
			if ('MnvM' == eventKind) {
				CheckForSavedTasks();
				if (! CurSpeedStopped) {
					DoEmulateExtraTime();
				}
			}
			break;
		default:
			break;
	}
	return result;
}

LOCALPROC AppendMenuConvertCStr(
	MenuRef menu,
	MenuCommand inCommandID,
	char *s, blnr WantEllipsis)
{
	CFStringRef cfStr = CFStringCreateFromSubstCStr(s, WantEllipsis);
	if (NULL != cfStr) {
		AppendMenuItemTextWithCFString(menu, cfStr,
			0, inCommandID, NULL);
		CFRelease(cfStr);
	}
}

LOCALPROC AppendMenuSep(MenuRef menu)
{
	AppendMenuItemTextWithCFString(menu, NULL,
		kMenuItemAttrSeparator, 0, NULL);
}

LOCALFUNC MenuRef NewMenuFromConvertCStr(short menuID, char *s)
{
	MenuRef menu = NULL;

	CFStringRef cfStr = CFStringCreateFromSubstCStr(s, falseblnr);
	if (NULL != cfStr) {
		OSStatus err = CreateNewMenu(menuID, 0, &menu);
		if (err != noErr) {
			menu = NULL;
		} else {
			(void) SetMenuTitleWithCFString(menu, cfStr);
		}
		CFRelease(cfStr);
	}

	return menu;
}

LOCALPROC RemoveCommandKeysInMenu(MenuRef theMenu)
{
	MenuRef outHierMenu;
	int i;
	UInt16 n = CountMenuItems(theMenu);

	for (i = 1; i <= n; ++i) {
		SetItemCmd(theMenu, i, 0);
		if (noErr == GetMenuItemHierarchicalMenu(
			theMenu, i, &outHierMenu)
			&& (NULL != outHierMenu))
		{
			RemoveCommandKeysInMenu(outHierMenu);
		}
	}
}

LOCALFUNC blnr InstallOurMenus(void)
{
	MenuRef menu;
	Str255 s;

	PStrFromChar(s, (char)20);
	menu = NewMenu(kAppleMenu, s);
	if (menu != NULL) {
		AppendMenuConvertCStr(menu,
			kHICommandAbout,
			kStrMenuItemAbout,
			falseblnr
			);
		AppendMenuSep(menu);
		InsertMenu(menu, 0);
	}

	menu = NewMenuFromConvertCStr(kFileMenu, kStrMenuFile);
	if (menu != NULL) {
		AppendMenuConvertCStr(menu,
			kHICommandOpen,
			kStrMenuItemOpen, trueblnr);
		InsertMenu(menu, 0);
	}

	menu = NewMenuFromConvertCStr(kSpecialMenu, kStrMenuSpecial);
	if (menu != NULL) {
		AppendMenuConvertCStr(menu,
			kCmdIdMoreCommands,
			kStrMenuItemMore, trueblnr);
		InsertMenu(menu, 0);
	}

	{
		MenuRef outMenu;
		MenuItemIndex outIndex;

		if (noErr == GetIndMenuItemWithCommandID(
			NULL, kHICommandQuit, 1, &outMenu, &outIndex))
		{
			RemoveCommandKeysInMenu(outMenu);
		}
	}

	DrawMenuBar();

	return trueblnr;
}

LOCALFUNC blnr InstallOurAppearanceClient(void)
{
	RegisterAppearanceClient(); /* maybe not needed ? */
	return trueblnr;
}

LOCALVAR blnr DisplayRegistrationCallBackSuccessful = falseblnr;

static void DisplayRegisterReconfigurationCallback(
	CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags,
	void *userInfo)
{
	UnusedParam(display);
	UnusedParam(userInfo);

	if (0 != (flags & kCGDisplayBeginConfigurationFlag)) {
		/* fprintf(stderr, "kCGDisplayBeginConfigurationFlag\n"); */
	} else {
#if 0
		if (0 != (flags & kCGDisplayMovedFlag)) {
			fprintf(stderr, "kCGDisplayMovedFlag\n");
		}
		if (0 != (flags & kCGDisplaySetMainFlag)) {
			fprintf(stderr, "kCGDisplaySetMainFlag\n");
		}
		if (0 != (flags & kCGDisplaySetModeFlag)) {
			fprintf(stderr, "kCGDisplaySetModeFlag\n");
		}

		if (0 != (flags & kCGDisplayAddFlag)) {
			fprintf(stderr, "kCGDisplayAddFlag\n");
		}
		if (0 != (flags & kCGDisplayRemoveFlag)) {
			fprintf(stderr, "kCGDisplayRemoveFlag\n");
		}

		if (0 != (flags & kCGDisplayEnabledFlag)) {
			fprintf(stderr, "kCGDisplayEnabledFlag\n");
		}
		if (0 != (flags & kCGDisplayDisabledFlag)) {
			fprintf(stderr, "kCGDisplayDisabledFlag\n");
		}

		if (0 != (flags & kCGDisplayMirrorFlag)) {
			fprintf(stderr, "kCGDisplayMirrorFlag\n");
		}
		if (0 != (flags & kCGDisplayUnMirrorFlag)) {
			fprintf(stderr, "kCGDisplayMirrorFlag\n");
		}
#endif

		WantScreensChangedCheck = trueblnr;

#if VarFullScreen
		if (WantFullScreen) {
			ToggleWantFullScreen();
		}
#endif
	}
}

LOCALFUNC blnr InstallOurEventHandlers(void)
{
	EventTypeSpec eventTypes[] = {
		{kEventClassMouse, kEventMouseDown},
		{kEventClassMouse, kEventMouseUp},
		{kEventClassMouse, kEventMouseMoved},
		{kEventClassMouse, kEventMouseDragged},
		{kEventClassKeyboard, kEventRawKeyModifiersChanged},
		{kEventClassKeyboard, kEventRawKeyDown},
		{kEventClassKeyboard, kEventRawKeyUp},
		{kEventClassApplication, kEventAppActivated},
		{kEventClassApplication, kEventAppDeactivated},
		{kEventClassCommand, kEventProcessCommand},
		{'MnvM', 'MnvM'}
	};

	InstallApplicationEventHandler(
		NewEventHandlerUPP(MyEventHandler),
		GetEventTypeCount(eventTypes),
		eventTypes, NULL, NULL);

	InitKeyCodes();

	InstallAppleEventHandlers();

	if (HaveMyCGDisplayRegisterReconfigurationCallback()) {
		if (kCGErrorSuccess ==
			MyCGDisplayRegisterReconfigurationCallback(
				DisplayRegisterReconfigurationCallback, NULL))
		{
			DisplayRegistrationCallBackSuccessful = trueblnr;
		}
	}

	/* (void) SetMouseCoalescingEnabled(false, NULL); */

	return trueblnr;
}

LOCALPROC UnInstallOurEventHandlers(void)
{
	if (DisplayRegistrationCallBackSuccessful) {
		if (HaveMyCGDisplayRemoveReconfigurationCallback()) {
			MyCGDisplayRemoveReconfigurationCallback(
				DisplayRegisterReconfigurationCallback, NULL);
		}
	}
}

LOCALPROC ReserveAllocAll(void)
{
#if dbglog_HAVE
	dbglog_ReserveAlloc();
#endif
	ReserveAllocOneBlock(&ROM, kROM_Size, 5, falseblnr);
	ReserveAllocOneBlock(&screencomparebuff,
		vMacScreenNumBytes, 5, trueblnr);
	ReserveAllocOneBlock(&CntrlDisplayBuff,
		vMacScreenNumBytes, 5, falseblnr);
	ReserveAllocOneBlock(&ScalingBuff, vMacScreenNumPixels
#if 0 != vMacScreenDepth
		* 4
#endif
		, 5, falseblnr);
	ReserveAllocOneBlock(&CLUT_final, CLUT_finalsz, 5, falseblnr);
#if MySoundEnabled
	ReserveAllocOneBlock((ui3p *)&TheSoundBuffer,
		dbhBufferSize, 5, falseblnr);
#endif

	EmulationReserveAlloc();
}

LOCALFUNC blnr AllocMyMemory(void)
{
	uimr n;
	blnr IsOk = falseblnr;

	ReserveAllocOffset = 0;
	ReserveAllocBigBlock = nullpr;
	ReserveAllocAll();
	n = ReserveAllocOffset;
	ReserveAllocBigBlock = (ui3p)calloc(1, n);
	if (NULL == ReserveAllocBigBlock) {
		MacMsg(kStrOutOfMemTitle, kStrOutOfMemMessage, trueblnr);
	} else {
		ReserveAllocOffset = 0;
		ReserveAllocAll();
		if (n != ReserveAllocOffset) {
			/* oops, program error */
		} else {
			IsOk = trueblnr;
		}
	}

	return IsOk;
}

LOCALFUNC blnr InitOSGLU(void)
{
	if (AllocMyMemory())
	if (InitMyApplInfo())
#if dbglog_HAVE
	if (dbglog_open())
#endif
	if (InstallOurAppearanceClient())
	if (InstallOurEventHandlers())
	if (InstallOurMenus())
	if (CreateMainWindow())
	if (LoadMacRom())
	if (LoadInitialImages())
#if UseActvCode
	if (ActvCodeInit())
#endif
#if EmLocalTalk
	if (InitLocalTalk())
#endif
	if (InitLocationDat())
#if MySoundEnabled
	if (MySound_Init())
#endif
	if (InitMyLowPriorityTasksEvent())
	if (InitEmulation())
	{
		return trueblnr;
	}
	return falseblnr;
}

#if dbglog_HAVE && 0
IMPORTPROC DoDumpTable(void);
#endif
#if dbglog_HAVE && 0
IMPORTPROC DumpRTC(void);
#endif

LOCALPROC UnInitOSGLU(void)
{
#if dbglog_HAVE && 0
	DoDumpTable();
#endif
#if dbglog_HAVE && 0
	DumpRTC();
#endif

	if (MacMsgDisplayed) {
		MacMsgDisplayOff();
	}

#if MayFullScreen
	UngrabMachine();
#endif

	UnInitMyLowPriorityTasksEvent();

#if MySoundEnabled
	MySound_Stop();
#endif

	CloseAglCurrentContext();
	CloseMainWindow();

#if MayFullScreen
	My_ShowMenuBar();
#endif

#if IncludePbufs
	UnInitPbufs();
#endif
	UnInitDrives();

	if (! gTrueBackgroundFlag) {
		CheckSavedMacMsg();
	}

	UnInstallOurEventHandlers();

#if dbglog_HAVE
	dbglog_close();
#endif

	UnInitMyApplInfo();

	ForceShowCursor();
}

LOCALPROC ZapOSGLUVars(void)
{
	InitDrives();
	ZapWinStateVars();
}

int main(void)
{
	ZapOSGLUVars();
	if (InitOSGLU()) {
		RunApplicationEventLoop();
	}
	UnInitOSGLU();

	return 0;
}


bool sparsebundle_read_plist(const char *plist, off_t *band_size,
	off_t *total_size);

typedef bool (*sparsebundle_op)(sparsebundle *sb, size_t band_index, char *buf,
	size_t nbyte, off_t offset);
bool sparsebundle_op_read(sparsebundle *sb, size_t band_index, char *buf,
	size_t nbyte, off_t offset);
bool sparsebundle_op_write(sparsebundle *sb, size_t band_index, char *buf,
	size_t nbyte, off_t offset);

ssize_t sparsebundle_do(sparsebundle *sb, sparsebundle_op op, void *buf,
	size_t nbyte, off_t offset);

int sparsebundle_open_band(sparsebundle *sb, off_t band_index, int flags,
	bool *noband);


bool sparsebundle_read_plist(const char *plist, off_t *band_size,
	off_t *total_size)
{
	NSFileManager *fileManager = [NSFileManager defaultManager];
	NSString *path = [fileManager stringWithFileSystemRepresentation: plist
		length: strlen(plist)];
	NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile: path];

	id value = [dict objectForKey: @"diskimage-bundle-type"];
	if (![@"com.apple.diskimage.sparsebundle" isEqual: value]) {
		return false;
	}

	off_t size = [[dict objectForKey: @"band-size"] longLongValue];
	if (size == 0) {
		return false;
	}
	if (band_size) {
		*band_size = size;
	}

	size = [[dict objectForKey: @"size"] longLongValue];
	if (size == 0) {
		return false;
	}
	if (total_size) {
		*total_size = size;
	}

	return true;
}

sparsebundle *sparsebundle_open(const char *path)
{
	char *plist;
	if (asprintf(&plist, "%s/%s", path, "Info.plist") == -1) {
		return NULL;
	}
	off_t band_size, total_size;
	bool ok = sparsebundle_read_plist(plist, &band_size, &total_size);
	free(plist);
	if (!ok) {
		return NULL;
	}

	sparsebundle *sb = malloc(sizeof(sparsebundle));
	if (!sb) {
		return NULL;
	}
	sb->path = malloc(strlen(path) + 1);
	strcpy(sb->path, path);
	sb->size = total_size;
	sb->band_size = band_size;
	return sb;
}

void sparsebundle_close(sparsebundle *sb)
{
	if (sb) {
		free(sb->path);
		free(sb);
	}
}

int sparsebundle_open_band(sparsebundle *sb, off_t band_index, int flags,
	bool *noband)
{
	if (noband) {
		*noband = false;
	}

	if (!sb) {
		return -1;
	}

	// Check if the band is in range.
	if (band_index < 0 || band_index * sb->band_size >= sb->size) {
		return -1;
	}

	char *path;
	if (asprintf(&path, "%s/bands/%llx", sb->path, band_index) == -1) {
		return -1;
	}
	int fd = open(path, flags);
	free(path);

	if (fd == -1 && errno == ENOENT && noband) {
		*noband = true;
	}
	return fd;
}

ssize_t sparsebundle_do(sparsebundle *sb, sparsebundle_op op, void *buf,
	size_t nbyte, off_t offset)
{
	if (!sb) {
		return -1;
	}

	if (offset < 0 || offset > sb->size) {
		return -1;
	}
	if (offset == sb->size) {
		return 0;
	}
	if (nbyte > sb->size - offset) {
		nbyte = sb->size - offset;
	}

	char *cbuf = buf;
	char *bufend = cbuf + nbyte;

	size_t band_index = offset / sb->band_size;
	offset = offset % sb->band_size;

	while (cbuf < bufend) {
		size_t len = bufend - cbuf;
		size_t avail = sb->band_size - offset;
		if (len > avail) {
			len = avail;
		}

		if (!op(sb, band_index, cbuf, len, offset)) {
			return -1;
		}

		cbuf += len;
		offset = 0;
		band_index += 1;
	}

	return nbyte;
}

bool sparsebundle_op_read(sparsebundle *sb, size_t band_index, char *buf,
	size_t nbyte, off_t offset)
{
	bool noband = false;
	int fd = sparsebundle_open_band(sb, band_index, O_RDONLY, &noband);

	if (fd == -1 && !noband) {
		return false;
	}

	if (fd != -1) {
		ssize_t did_read = pread(fd, buf, nbyte, offset);
		close(fd);
		if (did_read == -1) {
			return false;
		}
		buf += did_read;
		nbyte -= did_read;
	}
	if (nbyte) {
		memset(buf, 0, nbyte);
	}
	return true;
}

bool sparsebundle_op_write(sparsebundle *sb, size_t band_index, char *buf,
	size_t nbyte, off_t offset)
{
	int fd = sparsebundle_open_band(sb, band_index, O_WRONLY | O_CREAT, NULL);

	if (fd == -1) {
		return false;
	}

	ssize_t did_write = pwrite(fd, buf, nbyte, offset);
	close(fd);
	return did_write == nbyte;
}

ssize_t sparsebundle_read(sparsebundle *sb, void *buf, size_t nbyte,
	off_t offset)
{
	return sparsebundle_do(sb, &sparsebundle_op_read, buf, nbyte, offset);
}

ssize_t sparsebundle_write(sparsebundle *sb, void *buf, size_t nbyte,
	off_t offset)
{
	return sparsebundle_do(sb, &sparsebundle_op_write, buf, nbyte, offset);
}
