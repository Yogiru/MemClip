program MemClip;

{$mode objfpc}{$H+}
{$CODEPAGE UTF8}
{$APPTYPE GUI}
{$R MemClip.res}

uses
  Windows, SysUtils, ShellApi, Classes, ActiveX, Variants, Math;

const
  PROCESSES_LOOP_DELAY = 40;
  PID_BUF_COUNT = 1024;

  SystemFileCacheInformation = 21;
  SystemMemoryListInformation = 80;

  MemoryEmptyWorkingSets = 2;
  MemoryPurgeStandbyList = 4;
  MemoryPurgeLowPriorityStandbyList = 5;

  WM_TRAYICON = WM_USER + 1;
  WM_CLEANUP_DONE = WM_USER + 2;
  WM_GRAB_CLICK = WM_USER + 3;
  WM_OCRIDX_DONE = WM_APP + 6;
  WM_UPDATE_DONE = WM_APP + 7;

  NIM_ADD = 0;
  NIM_MODIFY = 1;
  NIM_DELETE = 2;

  NIF_MESSAGE = 1;
  NIF_ICON = 2;
  NIF_TIP = 4;

  IDM_CLEANNOW = 101;
  IDM_EXIT = 102;
  IDM_AUTOSTART = 103;
  IDM_CLIPWATCH = 104;
  IDM_AUTOPASTE = 105;
  IDM_GRABTOGGLE = 106;
  IDM_CLIPCLEAR = 107;
  IDM_INTERVAL_1M = 200;
  IDM_INTERVAL_5M = 201;
  IDM_INTERVAL_10M = 202;
  IDM_INTERVAL_30M = 203;
  IDM_INTERVAL_60M = 204;
  IDM_MANUAL = 205;
  IDM_HK_CLIP = 108;
  IDM_HK_GRAB = 109;
  IDM_ICONCACHE = 110;

  IDM_CLIPMERGE = 112;
  IDM_HK_PLAIN = 113;
  IDM_HK_OCR = 114;
  IDM_HISTORY = 115;
  IDM_SNIP = 116;
  IDM_HK_SNIP = 117;
  IDM_CTX_PASTE = 118;
  IDM_CTX_PLAIN = 119;
  IDM_CTX_PIN = 120;
  IDM_CTX_DEL = 121;
  IDM_CTX_SAVE = 137;
  IDM_UPDATE = 138;
  IDM_RADIO_BASE = 140;
  IDM_RADIO_MAX = 171;
  IDM_RADIO_STOP = 172;
  IDM_RADIO_VOLDN = 173;
  IDM_RADIO_VOLUP = 174;
  IDM_RADIO_EN = 175;

  RADIO_BUILTIN = 4;
  RADIO_MAX = 32;

  IDM_LANG_AUTO = 124;
  IDM_LANG_RU = 125;
  IDM_LANG_UK = 126;
  IDM_LANG_BE = 127;
  IDM_LANG_EN = 128;
  IDM_HK_SNIPWND = 129;
  IDM_HK_SNIPALL = 130;
  IDM_HK_SNIPLAST = 136;
  IDM_CLIPBASE = 1000;

  IDC_GRAB_EDIT = 1;
  IDC_GRAB_CANCEL = 2;
  IDC_GRAB_COPY = 3;
  IDC_VIEW_EDIT = 20;
  IDC_VIEW_LIST = 21;
  IDC_VIEW_PASTE = 22;
  IDC_VIEW_PLAINB = 23;
  IDC_VIEW_PIN = 24;
  IDC_VIEW_CLOSE = 2;
  VIEW_ITEM_H = 40;
  VIEW_REFRESH = WM_APP + 5;
  EM_SETCUEBANNER = $1501;

  HOTKEY_CLIPMENU = 1;
  HOTKEY_GRAB = 2;
  HOTKEY_PLAIN = 3;
  HOTKEY_OCR = 4;
  HOTKEY_SNIP = 5;
  HOTKEY_SNIPWND = 6;
  HOTKEY_SNIPALL = 7;
  HOTKEY_SNIPLAST = 8;

  APP_VERSION = '1.1.0';
  UPD_API_URL = 'https://api.github.com/repos/Yogiru/MemClip/releases/latest';

  RADIO_DEF_NAMES: array[0..RADIO_BUILTIN - 1] of string = (
    'Groove Salad (ambient)',
    'Drone Zone (ambient)',
    'Fluid (chill electronic)',
    'Radio Paradise (mix)');
  RADIO_DEF_URLS: array[0..RADIO_BUILTIN - 1] of string = (
    'https://ice1.somafm.com/groovesalad-128-mp3',
    'https://ice1.somafm.com/dronezone-128-mp3',
    'https://ice1.somafm.com/fluid-128-mp3',
    'https://stream.radioparadise.com/mp3-192');

  TIMER_EXIT = 2;
  TIMER_CLIPCAPTURE = 3;
  TIMER_HISTSAVE = 4;
  TIMER_MEMSTAT = 5;

  POPUP_WIDTH = 300;
  POPUP_HEIGHT = 34;

  WH_MOUSE_LL = 14;
  MOD_NOREPEAT = $4000;

  CLIP_HISTORY_MAX = 30;
  CLIP_HISTORY_TOTAL_MAX = 256;
  CLIP_MERGE_MS = 15000;
  CLIP_MAX_BYTES = 8 * 1024 * 1024;
  THUMB_SIZE = 32;
  MENU_LABEL_MAX = 60;

  CHILDID_SELF = 0;
  ROLE_SYSTEM_TITLEBAR = 1;

  CF_DIBV5 = 17;

  GRAB_WIN_W = 480;
  GRAB_WIN_H = 200;
  GRAB_BTN_W = 96;
  GRAB_BTN_H = 26;

  PNG_CLSID: TGUID = (D1: $557CF406; D2: $1A04; D3: $11D3;
    D4: ($9A, $73, $00, $00, $F8, $1E, $F3, $2E));

  REGFMT_COUNT = 6;
  REGFMT_IMG_MAX = 3;

  CLSID_CUIAutomation: TGUID = (D1: $FF48DBA4; D2: $60EF; D3: $4201;
    D4: ($AA, $87, $54, $10, $3E, $EF, $59, $4E));
  UIA_BoundingRectanglePropertyId = 30001;
  UIA_ProcessIdPropertyId = 30002;
  UIA_NamePropertyId = 30005;
  UIA_ValueValuePropertyId = 30045;
  UIA_LegacyIAccessibleNamePropertyId = 30092;
  UIA_LegacyIAccessibleValuePropertyId = 30093;

type
  TLang = (lgRussian, lgUkrainian, lgBelarusian, lgEnglish);

  TTextId = (
    txtAppName,
    txtCleanNow,
    txtInterval,
    txtExit,
    txtMinSuffix,
    txtMemoryUnit,
    txtTipBase,
    txtTipFree,
    txtTipPaused,
    txtTipInterval,
    txtPopupFormat,
    txtErrSyncEvent,
    txtErrRegMain,
    txtErrRegPopup,
    txtErrCreateMain,
    txtAutostart,
    txtAutoPaused,
    txtAutoStartAdded,
    txtAutoStartRemoved,
    txtRestarting,
    txtIntervalSet,
    txtIntervalMax,
    txtErrNotAdmin,
    txtManual,
    txtClipMenu,
    txtClipWatch,
    txtClipAutoPaste,
    txtClipClear,
    txtClipEmpty,
    txtClipCopied,
    txtClipCleared,
    txtClipWatchOn,
    txtClipWatchOff,
    txtGrabToggle,
    txtGrabEmpty,
    txtGrabOn,
    txtGrabOff,
    txtClipImage,
    txtClipFiles,
    txtGrabTitle,
    txtBtnCopy,
    txtBtnCancel,
    txtHkMenu,
    txtHkClip,
    txtHkPrompt,
    txtHkNeedMod,
    txtHkMouse,
    txtIconCache,
    txtIcoCacheDone,
    txtIcoCacheFail,
    txtClipMerge,
    txtHistoryWnd,
    txtSearchHint,
    txtBtnPaste,
    txtBtnPin,
    txtBtnUnpin,
    txtBtnPlain,
    txtPlainTitle,
    txtOcrTitle,
    txtOcrNoPack,
    txtOcrEmpty,
    txtUrlCopied,
    txtUrlNone,
    txtSnipTitle,
    txtSnipCopied,
    txtSnipSaved,
    txtSnipHint,
    txtGrpMem,
    txtGrpClip,
    txtGrpGrab,
    txtGrpSys,
    txtBtnDelete,
    txtLangMenu,
    txtLangAuto,
    txtTipUsed,
    txtEditTitle,
    txtBtnSave,
    txtBtnReset,
    txtSnipWnd,
    txtSnipAll,
    txtToolPen,
    txtToolLine,
    txtToolArrow,
    txtToolRect,
    txtToolText,
    txtToolBlur,
    txtBtnUndo,
    txtSnipHint2,
    txtSnipLast,
    txtSaveAs,
    txtSaveTitle,
    txtUpdate,
    txtUpdateNew,
    txtUpdateLatest,
    txtUpdateErr,
    txtRadio,
    txtRadioEnable,
    txtRadioStop,
    txtRadioOn,
    txtRadioFail,
    txtVolDn,
    txtVolUp
  );

  TClipKind = (ckText, ckImage, ckFiles);

  TClipFmt = record
    Fmt: UINT;
    FmtName: string;
    Data: TBytes;
  end;

  TClipEntry = record
    Kind: TClipKind;
    Text: WideString;
    OcrText: WideString;
    ImgW, ImgH: Integer;
    Pinned: Boolean;
    Time: QWord;
    StampUtc: TFileTime;
    Owner: WideString;
    Fmts: array of TClipFmt;
  end;

  POcrIdxJob = ^TOcrIdxJob;
  TOcrIdxJob = record
    Key: QWord;
    StampLo, StampHi: DWORD;
    Png: TBytes;
    Text: WideString;
  end;

  PUpdJob = ^TUpdJob;
  TUpdJob = record
    Ok: Boolean;
    Ver: string;
    Url: WideString;
  end;

  IMFPMediaPlayer = interface(IUnknown)
    ['{A714590A-58AF-430A-85BF-44F5EC838D85}']
    function Play: HResult; stdcall;
    function Pause: HResult; stdcall;
    function Stop: HResult; stdcall;
    function FrameStep: HResult; stdcall;
    function SetPosition(const guidPositionType: TGUID; pvPositionValue: Pointer): HResult; stdcall;
    function GetPosition(const guidPositionType: TGUID; pvPositionValue: Pointer): HResult; stdcall;
    function GetDuration(const guidPositionType: TGUID; pvDurationValue: Pointer): HResult; stdcall;
    function SetRate(flRate: Single): HResult; stdcall;
    function GetRate(out pflRate: Single): HResult; stdcall;
    function GetSupportedRates(fForwardDirection: BOOL; out pflSlowestRate, pflFastestRate: Single): HResult; stdcall;
    function GetState(out peState: Longint): HResult; stdcall;
    function CreateMediaItemFromURL(pwszURL: PWideChar; fSync: BOOL; dwUserData: DWORD_PTR; out ppMediaItem: Pointer): HResult; stdcall;
    function CreateMediaItemFromObject(pIUnknownObj: IUnknown; fSync: BOOL; dwUserData: DWORD_PTR; out ppMediaItem: Pointer): HResult; stdcall;
    function SetMediaItem(pIMFPMediaItem: Pointer): HResult; stdcall;
    function ClearMediaItem: HResult; stdcall;
    function GetMediaItem(out ppIMFPMediaItem: Pointer): HResult; stdcall;
    function GetVolume(out pflVolume: Single): HResult; stdcall;
    function SetVolume(flVolume: Single): HResult; stdcall;
    function GetBalance(out pflBalance: Single): HResult; stdcall;
    function SetBalance(flBalance: Single): HResult; stdcall;
    function GetMute(out pfMute: BOOL): HResult; stdcall;
    function SetMute(fMute: BOOL): HResult; stdcall;
    function GetNativeVideoSize(pszVideo, pszARVideo: Pointer): HResult; stdcall;
    function GetVideoSourceRect(pnrcSource: Pointer): HResult; stdcall;
    function UpdateVideo: HResult; stdcall;
    function SetVideoSourceRect(pnrcSource: Pointer): HResult; stdcall;
    function GetAspectRatioMode(out pdwAspectRatioMode: DWORD): HResult; stdcall;
    function SetAspectRatioMode(dwAspectRatioMode: DWORD): HResult; stdcall;
    function GetVideoWindow(out phwndVideo: HWND): HResult; stdcall;
    function SetVideoWindow(hwndVideo: HWND): HResult; stdcall;
    function GetBorderColor(out pClr: DWORD): HResult; stdcall;
    function SetBorderColor(Clr: DWORD): HResult; stdcall;
    function InsertEffect(pEffect: IUnknown; fOptional: BOOL): HResult; stdcall;
    function RemoveEffect(pEffect: IUnknown): HResult; stdcall;
    function RemoveAllEffects: HResult; stdcall;
    function Shutdown: HResult; stdcall;
  end;

  TMSLLHookStruct = record
    pt: TPoint;
    mouseData: DWORD;
    flags: DWORD;
    time: DWORD;
    dwExtraInfo: ULONG_PTR;
  end;
  PMSLLHookStruct = ^TMSLLHookStruct;

  IAccessible = interface(IDispatch)
    ['{618736E0-3C3D-11CF-810C-00AA00389B71}']
    function get_accParent(out pdispParent: IDispatch): HResult; stdcall;
    function get_accChildCount(out pcountChildren: Longint): HResult; stdcall;
    function get_accChild(varChild: OleVariant; out ppdispChild: IDispatch): HResult; stdcall;
    function get_accName(varChild: OleVariant; out pszName: WideString): HResult; stdcall;
    function get_accValue(varChild: OleVariant; out pszValue: WideString): HResult; stdcall;
    function get_accDescription(varChild: OleVariant; out pszDescription: WideString): HResult; stdcall;
    function get_accRole(varChild: OleVariant; out pvarRole: OleVariant): HResult; stdcall;
    function get_accState(varChild: OleVariant; out pvarState: OleVariant): HResult; stdcall;
    function get_accHelp(varChild: OleVariant; out pszHelp: WideString): HResult; stdcall;
    function get_accHelpTopic(out pszHelpFile: WideString; varChild: OleVariant; out pidTopic: Longint): HResult; stdcall;
    function get_accKeyboardShortcut(varChild: OleVariant; out pszKeyboardShortcut: WideString): HResult; stdcall;
    function get_accFocus(out pvarChild: OleVariant): HResult; stdcall;
    function get_accSelection(out pvarChildren: OleVariant): HResult; stdcall;
    function get_accDefaultAction(varChild: OleVariant; out pszDefaultAction: WideString): HResult; stdcall;
    function accSelect(flagsSelect: Longint; varChild: OleVariant): HResult; stdcall;
    function accLocation(out pxLeft: Longint; out pyTop: Longint; out pcxWidth: Longint; out pcyHeight: Longint; varChild: OleVariant): HResult; stdcall;
    function accNavigate(navDir: Longint; varStart: OleVariant; out pvarEndUpAt: OleVariant): HResult; stdcall;
    function accHitTest(xLeft: Longint; yTop: Longint; out pvarChild: OleVariant): HResult; stdcall;
    function accDoDefaultAction(varChild: OleVariant): HResult; stdcall;
    function put_accName(varChild: OleVariant; const szName: WideString): HResult; stdcall;
    function put_accValue(varChild: OleVariant; const szValue: WideString): HResult; stdcall;
  end;

  // UI Automation: only the vtable prefixes we actually call are declared
  IUIAutomationElement = interface;
  IUIAutomationTreeWalker = interface;

  IUIAutomation = interface(IUnknown)
    ['{30CBE57D-D9D0-452A-AB13-7AC5AC4825EE}']
    function CompareElements(el1, el2: IUIAutomationElement; out areSame: LongBool): HResult; stdcall;
    function CompareRuntimeIds(runtimeId1, runtimeId2: Pointer; out areSame: LongBool): HResult; stdcall;
    function GetRootElement(out root: IUIAutomationElement): HResult; stdcall;
    function ElementFromHandle(hwnd: Pointer; out element: IUIAutomationElement): HResult; stdcall;
    function ElementFromPoint(pt: TPoint; out element: IUIAutomationElement): HResult; stdcall;
    function GetFocusedElement(out element: IUIAutomationElement): HResult; stdcall;
    function GetRootElementBuildCache(cacheRequest: IUnknown; out root: IUIAutomationElement): HResult; stdcall;
    function ElementFromHandleBuildCache(hwnd: Pointer; cacheRequest: IUnknown; out element: IUIAutomationElement): HResult; stdcall;
    function ElementFromPointBuildCache(pt: TPoint; cacheRequest: IUnknown; out element: IUIAutomationElement): HResult; stdcall;
    function GetFocusedElementBuildCache(cacheRequest: IUnknown; out element: IUIAutomationElement): HResult; stdcall;
    function CreateTreeWalker(condition: IUnknown; out walker: IUIAutomationTreeWalker): HResult; stdcall;
    function get_ControlViewWalker(out walker: IUIAutomationTreeWalker): HResult; stdcall;
    function get_ContentViewWalker(out walker: IUIAutomationTreeWalker): HResult; stdcall;
    function get_RawViewWalker(out walker: IUIAutomationTreeWalker): HResult; stdcall;
  end;

  IUIAutomationTreeWalker = interface(IUnknown)
    ['{4042C624-389C-4AFC-A630-9DF854A541FC}']
    function GetParentElement(element: IUIAutomationElement; out parent: IUIAutomationElement): HResult; stdcall;
    function GetFirstChildElement(element: IUIAutomationElement; out first: IUIAutomationElement): HResult; stdcall;
    function GetLastChildElement(element: IUIAutomationElement; out last: IUIAutomationElement): HResult; stdcall;
    function GetNextSiblingElement(element: IUIAutomationElement; out next: IUIAutomationElement): HResult; stdcall;
    function GetPreviousSiblingElement(element: IUIAutomationElement; out previous: IUIAutomationElement): HResult; stdcall;
    function NormalizeElement(element: IUIAutomationElement; out normalized: IUIAutomationElement): HResult; stdcall;
    function GetParentElementBuildCache(element: IUIAutomationElement; cacheRequest: IUnknown; out parent: IUIAutomationElement): HResult; stdcall;
    function GetFirstChildElementBuildCache(element: IUIAutomationElement; cacheRequest: IUnknown; out first: IUIAutomationElement): HResult; stdcall;
    function GetLastChildElementBuildCache(element: IUIAutomationElement; cacheRequest: IUnknown; out last: IUIAutomationElement): HResult; stdcall;
    function GetNextSiblingElementBuildCache(element: IUIAutomationElement; cacheRequest: IUnknown; out next: IUIAutomationElement): HResult; stdcall;
    function GetPreviousSiblingElementBuildCache(element: IUIAutomationElement; cacheRequest: IUnknown; out previous: IUIAutomationElement): HResult; stdcall;
    function NormalizeElementBuildCache(element: IUIAutomationElement; cacheRequest: IUnknown; out normalized: IUIAutomationElement): HResult; stdcall;
    function get_Condition(out condition: IUnknown): HResult; stdcall;
  end;

  IUIAutomationElement = interface(IUnknown)
    ['{D22108AA-8AC5-49A5-837B-37BBB3D7591E}']
    function SetFocus: HResult; stdcall;
    function GetRuntimeId(out runtimeId: Pointer): HResult; stdcall;
    function FindFirst(scope: Integer; condition: IUnknown; out found: IUIAutomationElement): HResult; stdcall;
    function FindAll(scope: Integer; condition: IUnknown; out found: IUnknown): HResult; stdcall;
    function FindFirstBuildCache(scope: Integer; condition, cacheRequest: IUnknown; out found: IUIAutomationElement): HResult; stdcall;
    function FindAllBuildCache(scope: Integer; condition, cacheRequest: IUnknown; out found: IUnknown): HResult; stdcall;
    function BuildUpdatedCache(cacheRequest: IUnknown; out updatedElement: IUIAutomationElement): HResult; stdcall;
    function GetCurrentPropertyValue(propertyId: Integer; out retVal: OleVariant): HResult; stdcall;
  end;

  { --- WinRT (Windows.Media.Ocr) minimal COM interfaces ---
    Verified against SDK windows.media.ocr.idl / windows.foundation.idl /
    windows.graphics.imaging.idl; vtable order matches the IDL declarations. }
  HSTR = Pointer;

  IInspectable = interface(IUnknown)
    ['{AF86E2E0-B12D-4C6A-9C5A-D7AA65101E90}']
    function GetIids(out iidCount: ULONG; out iids: Pointer): HResult; stdcall;
    function GetRuntimeClassName(out clsName: HSTR): HResult; stdcall;
    function GetTrustLevel(out trustLevel: Longint): HResult; stdcall;
  end;

  IBuffer = interface(IInspectable)
    ['{905A0FE0-BC53-11DF-8C49-001E4FC686DA}']
    function get_Capacity(out value: UINT32): HResult; stdcall;
    function get_Length(out value: UINT32): HResult; stdcall;
    function put_Length(value: UINT32): HResult; stdcall;
  end;

  IBufferByteAccess = interface(IUnknown)
    ['{905A0FEF-BC53-11DF-8C49-001E4FC686DA}']
    function Buffer(out value: PByte): HResult; stdcall;
  end;

  ISoftwareBitmapStatics = interface(IInspectable)
    ['{DF0385DB-672F-4A9D-806E-C2442F343E86}']
    function Copy(source: IInspectable; out value: IInspectable): HResult; stdcall;
    function Convert(source: IInspectable; format: Longint; out value: IInspectable): HResult; stdcall;
    function ConvertWithAlpha(source: IInspectable; format, alpha: Longint; out value: IInspectable): HResult; stdcall;
    function CreateCopyFromBuffer(source: IInspectable; format: Longint; width, height: Longint; out value: IInspectable): HResult; stdcall;
    function CreateCopyWithAlphaFromBuffer(source: IInspectable; format, width, height, alpha: Longint; out value: IInspectable): HResult; stdcall;
    function CreateCopyFromSurfaceAsync(surface: IInspectable; out value: IInspectable): HResult; stdcall;
    function CreateCopyWithAlphaFromSurfaceAsync(surface: IInspectable; alpha: Longint; out value: IInspectable): HResult; stdcall;
  end;

  IAsyncInfo = interface(IInspectable)
    ['{00000036-0000-0000-C000-000000000046}']
    function get_Id(out id: UINT32): HResult; stdcall;
    function get_Status(out status: Longint): HResult; stdcall;
    function get_ErrorCode(out errorCode: HRESULT): HResult; stdcall;
    function Cancel: HResult; stdcall;
    function Close: HResult; stdcall;
  end;

  IAsyncOperationOcr = interface(IInspectable)
    procedure put_Completed(handler: IInspectable); stdcall;
    function get_Completed(out handler: IInspectable): HResult; stdcall;
    function GetResults(out results: IInspectable): HResult; stdcall;
  end;

  IOcrEngine = interface(IInspectable)
    ['{5A14BC41-5B76-3140-B680-8825562683AC}']
    function RecognizeAsync(bitmap: IInspectable; out res: IAsyncOperationOcr): HResult; stdcall;
    function get_RecognizerLanguage(out value: IInspectable): HResult; stdcall;
  end;

  IOcrEngineStatics = interface(IInspectable)
    ['{5BFFA85A-3384-3540-9940-699120D428A8}']
    function get_MaxImageDimension(out value: UINT32): HResult; stdcall;
    function get_AvailableRecognizerLanguages(out value: IInspectable): HResult; stdcall;
    function IsLanguageSupported(language: IInspectable; out res: Boolean): HResult; stdcall;
    function TryCreateFromLanguage(language: IInspectable; out res: IInspectable): HResult; stdcall;
    function TryCreateFromUserProfileLanguages(out res: IInspectable): HResult; stdcall;
  end;

  IOcrResult = interface(IInspectable)
    ['{9BD235B2-175B-3D6A-92E2-388C206E2F63}']
    function get_Lines(out value: IInspectable): HResult; stdcall;
    function get_TextAngle(out value: IInspectable): HResult; stdcall;
    function get_Text(out value: HSTR): HResult; stdcall;
  end;

  TNativeBuffer = class(TInterfacedObject, IInspectable, IBuffer, IBufferByteAccess)
  private
    FData: array of Byte;
    FLen: UINT32;
  public
    constructor Create(capacity: UINT32);
    function QueryInterface(constref iid: TGuid; out obj): HResult; stdcall;
    function GetIids(out iidCount: ULONG; out iids: Pointer): HResult; stdcall;
    function GetRuntimeClassName(out clsName: HSTR): HResult; stdcall;
    function GetTrustLevel(out trustLevel: Longint): HResult; stdcall;
    function get_Capacity(out value: UINT32): HResult; stdcall;
    function get_Length(out value: UINT32): HResult; stdcall;
    function put_Length(value: UINT32): HResult; stdcall;
    function Buffer(out value: PByte): HResult; stdcall;
    function DataPtr: PByte;
  end;

  TMemoryStatusEx = record
    dwLength: DWORD;
    dwMemoryLoad: DWORD;
    ullTotalPhys: ULONGLONG;
    ullAvailPhys: ULONGLONG;
    ullTotalPageFile: ULONGLONG;
    ullAvailPageFile: ULONGLONG;
    ullTotalVirtual: ULONGLONG;
    ullAvailVirtual: ULONGLONG;
    ullAvailExtendedVirtual: ULONGLONG;
  end;

  TSystemFileCacheInfo = record
    CurrentSize: SIZE_T;
    PeakSize: SIZE_T;
    PageFaultCount: ULONG;
    MinimumWorkingSet: SIZE_T;
    MaximumWorkingSet: SIZE_T;
    CurrentSizeIncludingTransitionInPages: SIZE_T;
    PeakSizeIncludingTransitionInPages: SIZE_T;
    TransitionRePurposeCount: ULONG;
    Flags: ULONG;
  end;

  NTSTATUS = LONG;

  TGdiplusStartupInput = record
    GdiplusVersion: UINT;
    DebugEventCallback: Pointer;
    SuppressBackgroundThread: LongBool;
    SuppressExternalCodecs: LongBool;
  end;

  TGdiplusStartupOutput = record
    NotificationHook: Pointer;
    NotificationUnhook: Pointer;
  end;

const
  Texts: array[TLang, TTextId] of string = (
    // Russian
    ('MemClip',
     'Очистить память сейчас',
     'Интервал очистки памяти',
     'Выход',
     'мин',
     'МБ',
     'MemClip',
     'MemClip: %d МБ свободно',
     'MemClip [вручную]',
     'MemClip: %d %s',
     '%d -> %d %s  (%s%d %s)',
     'Не удалось создать событие синхронизации.',
     'Не удалось зарегистрировать класс главного окна.',
     'Не удалось зарегистрировать класс всплывающего окна.',
     'Не удалось создать главное окно.',
     'Автозагрузка',
     'Автоочистка приостановлена',
     'Добавлено в автозагрузку',
     'Удалено из автозагрузки',
     'Уже запущено. Перезапуск...',
     'Интервал: %d %s',
     'Максимальный интервал: %d %s',
     'Требуются права администратора.',
     'Вручную',
     'История буфера',
     'Запоминать буфер (Ctrl+Alt+V)',
     'Вставлять сразу',
     'Очистить историю',
     '(история пуста)',
     'Скопировано: %s',
     'История буфера очищена',
     'Запись буфера включена',
     'Запись буфера выключена',
     'Захват текста (Ctrl+Alt+T, Ctrl+Колесо)',
     'Текст не найден',
     'Захват текста включён',
     'Захват текста выключен',
     '[Изображение]',
     '[Файлы] ',
     'Захват текста',
     'Копировать',
     'Отмена',
     'Горячие клавиши',
     'Меню истории',
     'Нажмите сочетание клавиш (Esc — отмена)',
     'Добавьте Ctrl, Alt, Shift или Win',
     'Ctrl+Колесо мыши — захват',
     'Очистить кэш иконок и миниатюр',
     'Кэш очищен',
     'Не удалось очистить кэш',
     'Склеивать копии',
     'Окно истории',
     'Поиск...',
     'Вставить',
     'Закрепить',
     'Открепить',
     'Как текст',
     'Вставка без форматирования',
     'OCR под курсором',
     'OCR недоступен: нет языковых пакетов Windows',
     'Текст не распознан',
     'Скопирован URL: %s',
     'URL не найден',
     'Скриншот области',
     'Скриншот %dx%d в буфере',
     'Скриншот сохранён: %s',
     'Протяните для выбора области. Отпускание — редактор разметки, +Alt — сразу в буфер, +Ctrl — OCR, +Shift — сохранить PNG. Esc — отмена',
     'Память (RAM)',
     'Буфер обмена',
     'Захват и скриншоты',
     'Система',
     'Удалить',
     'Язык',
     'Авто',
     'MemClip: %d%% занято',
     'Разметка скриншота',
     'Сохранить',
     'Сбросить',
     'Скриншот окна',
     'Скриншот экрана',
     'Карандаш',
     'Линия',
     'Стрелка',
     'Рамка',
     'Текст',
     'Размытие',
     'Назад',
     'Enter — редактор · Alt — в буфер · Ctrl — OCR · Shift — PNG · стрелки — подгонка · Esc — отмена',
     'Повтор последней области',
     'Сохранить как…',
     'Сохранить запись',
     'Проверить обновления',
     'Доступна версия %s — открыть страницу загрузки?',
     'У вас последняя версия',
     'Не удалось проверить обновления',
     'Радио',
     'Включить радио',
     'Стоп',
     'Радио: %s',
     'Не удалось запустить поток',
     'Тише',
     'Громче'),

    // Ukrainian
    ('MemClip',
     'Очистити пам''ять зараз',
     'Інтервал очищення пам''яті',
     'Вихід',
     'хв',
     'МБ',
     'MemClip',
     'MemClip: %d МБ вільно',
     'MemClip [вручну]',
     'MemClip: %d %s',
     '%d -> %d %s  (%s%d %s)',
     'Не вдалося створити подію синхронізації.',
     'Не вдалося зареєструвати клас головного вікна.',
     'Не вдалося зареєструвати клас спливаючого вікна.',
     'Не вдалося створити головне вікно.',
     'Автозапуск',
     'Автоочищення призупинено',
     'Додано до автозапуску',
     'Видалено з автозапуску',
     'Вже запущено. Перезапуск...',
     'Інтервал: %d %s',
     'Максимальний інтервал: %d %s',
     'Потрібні права адміністратора.',
     'Вручну',
     'Історія буфера',
     'Запам''ятовувати буфер (Ctrl+Alt+V)',
     'Вставляти одразу',
     'Очистити історію',
     '(історія порожня)',
     'Скопійовано: %s',
     'Історію буфера очищено',
     'Запис буфера увімкнено',
     'Запис буфера вимкнено',
     'Захоплення тексту (Ctrl+Alt+T, Ctrl+Коліщатко)',
     'Текст не знайдено',
     'Захоплення тексту увімкнено',
     'Захоплення тексту вимкнено',
     '[Зображення]',
     '[Файли] ',
     'Захоплення тексту',
     'Копіювати',
     'Скасувати',
     'Гарячі клавіші',
     'Меню історії',
     'Натисніть сполучення клавіш (Esc — скасувати)',
     'Додайте Ctrl, Alt, Shift або Win',
     'Ctrl+Коліщатко миші — захоплення',
     'Очистити кеш іконок і мініатюр',
     'Кеш очищено',
     'Не вдалося очистити кеш',
     'Склеювати копії',
     'Вікно історії',
     'Пошук...',
     'Вставити',
     'Закріпити',
     'Відкріпити',
     'Як текст',
     'Вставлення без форматування',
     'OCR під курсором',
     'OCR недоступний: немає мовних пакетів Windows',
     'Текст не розпізнано',
     'Скопійовано URL: %s',
     'URL не знайдено',
     'Скріншот області',
     'Скріншот %dx%d у буфері',
     'Скріншот збережено: %s',
     'Протягніть для вибору області. Відпускання — редактор розмітки, +Alt — одразу в буфер, +Ctrl — OCR, +Shift — зберегти PNG. Esc — скасувати',
     'Пам''ять (RAM)',
     'Буфер обміну',
     'Захоплення і скріншоти',
     'Система',
     'Видалити',
     'Мова',
     'Авто',
     'MemClip: %d%% зайнято',
     'Розмітка скріншота',
     'Зберегти',
     'Скинути',
     'Скріншот вікна',
     'Скріншот екрану',
     'Олівець',
     'Лінія',
     'Стрілка',
     'Рамка',
     'Текст',
     'Розмиття',
     'Назад',
     'Enter — редактор · Alt — у буфер · Ctrl — OCR · Shift — PNG · стрілки — підгонка · Esc — скасувати',
     'Повтор останньої області',
     'Зберегти як…',
     'Зберегти запис',
     'Перевірити оновлення',
     'Доступна версія %s — відкрити сторінку завантаження?',
     'У вас остання версія',
     'Не вдалося перевірити оновлення',
     'Радіо',
     'Увімкнути радіо',
     'Стоп',
     'Радіо: %s',
     'Не вдалося запустити потік',
     'Тихіше',
     'Гучніше'),

    // Belarusian
    ('MemClip',
     'Ачысціць памяць зараз',
     'Інтэрвал ачышчэння памяці',
     'Выхад',
     'хв',
     'МБ',
     'MemClip',
     'MemClip: %d МБ вольна',
     'MemClip [уручную]',
     'MemClip: %d %s',
     '%d -> %d %s  (%s%d %s)',
     'Не атрымалася стварыць падзею сінхранізацыі.',
     'Не атрымалася зарэгістраваць клас галоўнага акна.',
     'Не атрымалася зарэгістраваць клас усплыўнога акна.',
     'Не атрымалася стварыць галоўнае акно.',
     'Аўтазапуск',
     'Аўтаачыстка прыпынена',
     'Дададзена ў аўтазапуск',
     'Выдалена з аўтазапуску',
     'Ужо запушчана. Перазапуск...',
     'Інтэрвал: %d %s',
     'Максімальны інтэрвал: %d %s',
     'Патрэбны правы адміністратара.',
     'Уручную',
     'Гісторыя буфера',
     'Запамінаць буфер (Ctrl+Alt+V)',
     'Уставляць адразу',
     'Ачысціць гісторыю',
     '(гісторыя пустая)',
     'Скапіявана: %s',
     'Гісторыя буфера ачышчана',
     'Запіс буфера ўключаны',
     'Запіс буфера выключаны',
     'Захоп тэксту (Ctrl+Alt+T, Ctrl+Кола)',
     'Тэкст не знойдзены',
     'Захоп тэксту ўключаны',
     'Захоп тэксту выключаны',
     '[Выява]',
     '[Файлы] ',
     'Захоп тэксту',
     'Капіяваць',
     'Скасаваць',
     'Гарачыя клавішы',
     'Меню гісторыі',
     'Націсніце спалучэнне клавіш (Esc — адмяніць)',
     'Дадайце Ctrl, Alt, Shift або Win',
     'Ctrl+Коліка мышы — захопленне',
     'Ачысціць кэш значкоў і мініяцюр',
     'Кэш ачышчаны',
     'Не атрымалася ачысціць кэш',
     'Склейваць копіі',
     'Акно гісторыі',
     'Пошук...',
     'Уставіць',
     'Замацаваць',
     'Адмацаваць',
     'Як тэкст',
     'Устаўка без фарматавання',
     'OCR пад курсорам',
     'OCR недаступны: няма моўных пакетаў Windows',
     'Тэкст не распазнаны',
     'Скапіяваны URL: %s',
     'URL не знойдзены',
     'Скрыншот вобласці',
     'Скрыншот %dx%d у буферы',
     'Скрыншот захаваны: %s',
     'Працягніце для выбару вобласці. Адпусканне — рэдактар разметкі, +Alt — адразу ў буфер, +Ctrl — OCR, +Shift — захаваць PNG. Esc — адмена',
     'Памяць (RAM)',
     'Буфер абмену',
     'Захопленне і скрыншоты',
     'Сістэма',
     'Выдаліць',
     'Мова',
     'Аўта',
     'MemClip: %d%% занята',
     'Разметка скрыншота',
     'Захаваць',
     'Скінуць',
     'Скрыншот акна',
     'Скрыншот экрана',
     'Аловак',
     'Лінія',
     'Стрэлка',
     'Рамка',
     'Тэкст',
     'Размыццё',
     'Назад',
     'Enter — рэдактар · Alt — у буфер · Ctrl — OCR · Shift — PNG · стрэлкі — падгонка · Esc — адмена',
     'Паўтор апошняй вобласці',
     'Захаваць як…',
     'Захаваць запіс',
     'Праверыць абнаўленні',
     'Даступная версія %s — адкрыць старонку спампоўкі?',
     'У вас апошняя версія',
     'Не ўдалося праверыць абнаўленні',
     'Радыё',
     'Уключыць радыё',
     'Стоп',
     'Радыё: %s',
     'Не ўдалося запусціць паток',
     'Цішэй',
     'Гучней'),

    // English
    ('MemClip',
     'Clean memory now',
     'Memory cleanup interval',
     'Exit',
     'min',
     'MB',
     'MemClip',
     'MemClip: %d MB free',
     'MemClip [manual]',
     'MemClip: %d %s',
     '%d -> %d %s  (%s%d %s)',
     'Cannot create sync event.',
     'Cannot register main window class.',
     'Cannot register popup window class.',
     'Cannot create main window.',
     'Autostart',
     'Auto cleanup paused',
     'Added to autostart',
     'Removed from autostart',
     'Already running. Restarting...',
     'Interval: %d %s',
     'Max interval: %d %s',
     'Administrator rights are required.',
     'Manual',
     'Clipboard history',
     'Remember clipboard (Ctrl+Alt+V)',
     'Paste immediately',
     'Clear history',
     '(history empty)',
     'Copied: %s',
     'Clipboard history cleared',
     'Clipboard watch enabled',
     'Clipboard watch disabled',
     'Text grab (Ctrl+Alt+T, Ctrl+MMB)',
     'No text found',
     'Text grab enabled',
     'Text grab disabled',
     '[Image]',
     '[Files] ',
     'Text grab',
     'Copy',
     'Cancel',
     'Hotkeys',
     'History menu',
     'Press a key combination (Esc — cancel)',
     'Add Ctrl, Alt, Shift or Win',
     'Ctrl+MMB — grab',
     'Clear icon and thumbnail cache',
     'Cache cleared',
     'Failed to clear cache',
     'Merge sequential copies',
     'History window',
     'Search...',
     'Paste',
     'Pin',
     'Unpin',
     'As text',
     'Paste without formatting',
     'OCR under cursor',
     'OCR unavailable: no Windows language packs',
     'No text recognized',
     'Copied URL: %s',
     'URL not found',
     'Capture screen region',
     'Screenshot %dx%d in clipboard',
     'Screenshot saved: %s',
     'Drag to select a region. Release — annotate editor, +Alt — straight to clipboard, +Ctrl — OCR, +Shift — save PNG. Esc — cancel',
     'Memory (RAM)',
     'Clipboard',
     'Capture & screenshots',
     'System',
     'Delete',
     'Language',
     'Auto',
     'MemClip: %d%% used',
     'Annotate screenshot',
     'Save',
     'Reset',
     'Window screenshot',
     'Full screenshot',
     'Pencil',
     'Line',
     'Arrow',
     'Rect',
     'Text',
     'Blur',
     'Undo',
     'Enter — editor · Alt — to clipboard · Ctrl — OCR · Shift — PNG · arrows — nudge · Esc — cancel',
     'Repeat last region',
     'Save as…',
     'Save entry',
     'Check for updates',
     'Version %s is available — open the download page?',
     'You have the latest version',
     'Could not check for updates',
     'Radio',
     'Enable radio',
     'Stop',
     'Radio: %s',
     'Could not start the stream',
     'Quieter',
     'Louder')
  );

const
  REGFMT_NAMES: array[0..REGFMT_COUNT - 1] of string = (
    'PNG', 'JFIF', 'GIF', 'image/png', 'HTML Format', 'Rich Text Format');

function NtSetSystemInformation(SystemInformationClass: DWORD; SystemInformation: Pointer; SystemInformationLength: ULONG): NTSTATUS; stdcall; external 'ntdll.dll' name 'NtSetSystemInformation';
function EmptyWorkingSet(hProcess: HANDLE): BOOL; stdcall; external 'psapi.dll' name 'EmptyWorkingSet';
function EnumProcesses(lpidProcess: PLongWord; cb: LongWord; out cbNeeded: DWORD): BOOL; stdcall; external 'psapi.dll' name 'EnumProcesses';
function GlobalMemoryStatusEx(var lpBuffer: TMemoryStatusEx): BOOL; stdcall; external 'kernel32' name 'GlobalMemoryStatusEx';

function TrackPopupMenuCmd(hMenu: HMENU; uFlags: UINT; x, y, nReserved: Integer; hWnd: HWND; prcRect: Pointer): UINT; stdcall; external 'user32.dll' name 'TrackPopupMenu';

type
  TMcOpenFileNameW = record
    lStructSize: DWORD;
    hwndOwner: HWND;
    hInstance: HINST;
    lpstrFilter: PWideChar;
    lpstrCustomFilter: PWideChar;
    nMaxCustFilter: DWORD;
    nFilterIndex: DWORD;
    lpstrFile: PWideChar;
    nMaxFile: DWORD;
    lpstrFileTitle: PWideChar;
    nMaxFileTitle: DWORD;
    lpstrInitialDir: PWideChar;
    lpstrTitle: PWideChar;
    Flags: DWORD;
    nFileOffset: Word;
    nFileExtension: Word;
    lpstrDefExt: PWideChar;
    lCustData: LPARAM;
    lpfnHook: Pointer;
    lpTemplateName: PWideChar;
  end;

function GetSaveFileNameMcW(var ofn: TMcOpenFileNameW): BOOL; stdcall; external 'comdlg32.dll' name 'GetSaveFileNameW';

function InternetOpenMcW(agent: PWideChar; accessType: DWORD; proxy, bypass: PWideChar;
  flags: DWORD): Pointer; stdcall; external 'wininet.dll' name 'InternetOpenW';
function InternetOpenUrlMcW(h: Pointer; url, headers: PWideChar; headersLen: DWORD;
  flags, ctx: DWORD_PTR): Pointer; stdcall; external 'wininet.dll' name 'InternetOpenUrlW';
function InternetReadFileMc(h: Pointer; buf: Pointer; num: DWORD;
  out read: DWORD): BOOL; stdcall; external 'wininet.dll' name 'InternetReadFile';
function InternetCloseHandleMc(h: Pointer): BOOL; stdcall; external 'wininet.dll' name 'InternetCloseHandle';

type
  TMfpCreateFn = function(pwszURL: PWideChar; fStartPlayback: BOOL;
    creationOptions: DWORD; pCallback: Pointer; hWnd: HWND;
    out ppMediaPlayer: IMFPMediaPlayer): HRESULT; stdcall;

function AddClipboardFormatListener(hwnd: HWND): BOOL; stdcall; external 'user32.dll' name 'AddClipboardFormatListener';
function RoInitialize(initType: Longint): HRESULT; stdcall; external 'combase.dll';
function RoGetActivationFactory(activatableClassId: HSTR; const iid: TGUID; out factory): HRESULT; stdcall; external 'combase.dll';
function WindowsCreateString(sourceString: PWideChar; length: UINT32; out s: HSTR): HRESULT; stdcall; external 'combase.dll';
function WindowsDeleteString(s: HSTR): HRESULT; stdcall; external 'combase.dll';
function WindowsGetStringRawBuffer(s: HSTR; out length: UINT32): PWideChar; stdcall; external 'combase.dll';
function RemoveClipboardFormatListener(hwnd: HWND): BOOL; stdcall; external 'user32.dll' name 'RemoveClipboardFormatListener';
function AccessibleObjectFromPoint(ptScreen: TPoint; out ppacc: IAccessible; var pvarChild: OleVariant): HResult; stdcall; external 'oleacc.dll' name 'AccessibleObjectFromPoint';
function WindowFromAccessibleObject(pacc: IAccessible; out phwnd: HWND): HResult; stdcall; external 'oleacc.dll' name 'WindowFromAccessibleObject';
function CreateStreamOnHGlobal(hGlobal: HGLOBAL; fDeleteOnRelease: LongBool; out stm: IStream): HResult; stdcall; external 'ole32.dll' name 'CreateStreamOnHGlobal';
function GdiplusStartup(out token: ULONG_PTR; const input: TGdiplusStartupInput; output: Pointer): Longint; stdcall; external 'gdiplus.dll' name 'GdiplusStartup';
procedure GdiplusShutdown(token: ULONG_PTR); stdcall; external 'gdiplus.dll' name 'GdiplusShutdown';
function GdipCreateBitmapFromStream(stream: IStream; out bitmap: Pointer): Longint; stdcall; external 'gdiplus.dll' name 'GdipCreateBitmapFromStream';
function GdipLoadImageFromFileICM(filename: PWideChar; out image: Pointer): Longint; stdcall; external 'gdiplus.dll' name 'GdipLoadImageFromFileICM';
function GdipSaveImageToStream(image: Pointer; stream: IStream; const clsidEncoder: TGUID; encoderParams: Pointer): Longint; stdcall; external 'gdiplus.dll' name 'GdipSaveImageToStream';
function GdipCreateHBITMAPFromBitmap(bitmap: Pointer; out hbmReturn: HBITMAP; background: DWORD): Longint; stdcall; external 'gdiplus.dll' name 'GdipCreateHBITMAPFromBitmap';
function GdipCreateBitmapFromHBITMAP(hbm: HBITMAP; hpal: HPALETTE; out bitmap: Pointer): Longint; stdcall; external 'gdiplus.dll' name 'GdipCreateBitmapFromHBITMAP';
function GdipSaveImageToFile(image: Pointer; filename: PWideChar; const clsidEncoder: TGUID; encoderParams: Pointer): Longint; stdcall; external 'gdiplus.dll' name 'GdipSaveImageToFile';
function GdipDisposeImage(image: Pointer): Longint; stdcall; external 'gdiplus.dll' name 'GdipDisposeImage';
function DuplicateTokenEx(hExistingToken: HANDLE; dwDesiredAccess: DWORD; lpTokenAttributes: PSecurityAttributes; ImpersonationLevel: DWORD; TokenType: DWORD; out phNewToken: HANDLE): BOOL; stdcall; external 'advapi32.dll' name 'DuplicateTokenEx';
function GetUserProfileDirectoryW(hToken: HANDLE; lpProfileDir: LPWSTR; var lpcchSize: DWORD): BOOL; stdcall; external 'userenv.dll' name 'GetUserProfileDirectoryW';

function MainWndProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall; forward;
function PopupWndProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall; forward;
procedure SaveConfig; forward;

var
  hMainWnd, hPopupWnd: HWND;
  hPopupFont: HFONT;
  hPopupBrush: HBRUSH;
  hGrabBrush, hGrabEditBrush, hSnipBrush: HBRUSH;
  AppIcon: HICON;
  hEvent: HANDLE;
  hThread: THandle;
  Paused, Exiting, ForceRun, AutostartEnabled: Boolean;
  RunOnce, DoInstall, DoUninstall, ParamAction, ReplacePrevious: Boolean;
  CfgAutostart, CfgIntervalCapped, ElevatedRetry: Boolean;
  CfgIntervalMin: Integer;
  CurrentInterval: DWORD;
  TaskbarCreatedMsg: UINT;
  InfoQueue: array of WideString;
  LastFreeBefore, LastFreeAfter: Integer;
  LastAutoClean: QWord;
  PopupText: WideString;
  nid: TNotifyIconDataW;
  MainClassName, PopupClassName, IconName: string;
  CurrentLang: TLang;
  // Clipboard history
  ClipHistory: array of TClipEntry;
  ClipWatchEnabled, AutoPaste, GrabEnabled: Boolean;
  ClipHistoryMax: Integer;
  ClipKeepDays: Integer;
  ClipMergeEnabled: Boolean;
  ClipExcludeProcs: WideString;
  LastForeWnd: HWND;
  fmtCVI, fmtExclude, fmtCanHist, fmtCanCloud: UINT;
  RegFmtIds: array[0..REGFMT_COUNT - 1] of UINT;
  // Mouse hook (text grab)
  hMouseHook: HHOOK;
  hHookThread: THandle;
  hHookThreadId: DWORD;
  hHookReady: HANDLE;
  MouseGrabDown: Integer;
  // Configurable hotkeys
  HotkeyClipMods, HotkeyClipVk: UINT;
  HotkeyGrabMods, HotkeyGrabVk: UINT;
  HotkeyPlainMods, HotkeyPlainVk: UINT;
  HotkeyOcrMods, HotkeyOcrVk: UINT;
  HotkeySnipMods, HotkeySnipVk: UINT;
  HotkeySnipWndMods, HotkeySnipWndVk: UINT;
  HotkeySnipAllMods, HotkeySnipAllVk: UINT;
  HotkeySnipLastMods, HotkeySnipLastVk: UINT;
  MemFreeMinMb: DWORD;
  LangSetting: string;
  // Grab window (text selection)
  hGrabWnd, hGrabEdit: HWND;
  OldGrabEditProc: LONG;
  GrabOrigText: WideString;
  // Hotkey capture window
  hHkWnd: HWND;
  HkOk, HkHint: Boolean;
  HkMods, HkVk: UINT;
  HkPrompt: WideString;
  GrabClassName, HkClassName: string;
  // GDI+
  GdipStarted: Boolean;
  GdipToken: ULONG_PTR;
  // History viewer window
  hViewWnd, hViewEdit, hViewList, hViewPinBtn: HWND;
  ViewIdx: array of Integer;
  ViewThumbs: array of HBITMAP;
  ViewerClsReg: Boolean;
  ViewerClassName: string;
  // OCR (WinRT)
  OcrChecked: Boolean;
  gOcrEngine: IOcrEngine;
  OcrCs: TRTLCriticalSection;
  OcrIdxPending: Longint;
  UpdateChecking: Boolean;
  gRadioPlayer: IMFPMediaPlayer;
  RadioEnabled: Boolean;
  hMfpDll: THandle;
  pfnMfpCreate: TMfpCreateFn;
  RadioStation: Integer;
  RadioVolume: Integer;
  RadioNames: array of WideString;
  RadioUrls: array of WideString;
  // Snip overlay (screenshot region)
  hSnipWnd: HWND;
  SnipClsReg: Boolean;
  SnipClassName: string;
  SnipOrgX, SnipOrgY: Integer;
  SnipStart, SnipCur: TPoint;
  SnipDragging: Boolean;
  SnipAdjusting: Boolean;   // выделение готово — можно двигать/подгонять
  SnipMoving: Boolean;      // drag внутри выделения
  SnipEdge: Integer;        // маска захваченных краёв: 1=L,2=T,4=R,8=B
  SnipAnchor: TPoint;
  SnipSel: TRect;           // выделение в режиме подгонки
  SnipLastScr: TRect;       // последняя снятая область (экранные коорд.)
  SnipLastOk: Boolean;
  // Screenshot annotation editor
  hEditWnd: HWND;
  EditClsReg: Boolean;
  EditClassName: string;
  EditBmp: HBITMAP;
  EditW, EditH: Integer;
  EditScale: Double;

constructor TNativeBuffer.Create(capacity: UINT32);
begin
  SetLength(FData, capacity);
  FLen := 0;
end;

function TNativeBuffer.QueryInterface(constref iid: TGuid; out obj): HResult; stdcall;
begin
  if GetInterface(iid, obj) then
    Result := S_OK
  else
    Result := E_NOINTERFACE;
end;

function TNativeBuffer.GetIids(out iidCount: ULONG; out iids: Pointer): HResult; stdcall;
begin
  iidCount := 0;
  iids := nil;
  Result := S_OK;
end;

function TNativeBuffer.GetRuntimeClassName(out clsName: HSTR): HResult; stdcall;
begin
  clsName := nil;
  Result := S_OK;
end;

function TNativeBuffer.GetTrustLevel(out trustLevel: Longint): HResult; stdcall;
begin
  trustLevel := 0;
  Result := S_OK;
end;

function TNativeBuffer.get_Capacity(out value: UINT32): HResult; stdcall;
begin
  value := Length(FData);
  Result := S_OK;
end;

function TNativeBuffer.get_Length(out value: UINT32): HResult; stdcall;
begin
  value := FLen;
  Result := S_OK;
end;

function TNativeBuffer.put_Length(value: UINT32): HResult; stdcall;
begin
  if value > UINT32(Length(FData)) then
    Exit(E_INVALIDARG);
  FLen := value;
  Result := S_OK;
end;

function TNativeBuffer.Buffer(out value: PByte): HResult; stdcall;
begin
  value := @FData[0];
  Result := S_OK;
end;

function TNativeBuffer.DataPtr: PByte;
begin
  Result := @FData[0];
end;

function AsWide(const s: string): WideString;
var
  len: Integer;
  src: PAnsiChar;
begin
  if s = '' then
  begin
    Result := '';
    Exit;
  end;
  src := PAnsiChar(s);
  len := MultiByteToWideChar(CP_UTF8, 0, src, Length(s), nil, 0);
  if len <= 0 then
  begin
    Result := '';
    Exit;
  end;
  SetLength(Result, len);
  MultiByteToWideChar(CP_UTF8, 0, src, Length(s), PWideChar(Result), len);
end;

function AsUTF8(const ws: WideString): string;
var
  len: Integer;
begin
  if ws = '' then
  begin
    Result := '';
    Exit;
  end;
  len := WideCharToMultiByte(CP_UTF8, 0, PWideChar(ws), Length(ws), nil, 0, nil, nil);
  if len <= 0 then
  begin
    Result := '';
    Exit;
  end;
  SetLength(Result, len);
  WideCharToMultiByte(CP_UTF8, 0, PWideChar(ws), Length(ws), PChar(Result), len, nil, nil);
end;

function TrimWide(const ws: WideString): WideString;
var
  a, b: Integer;
begin
  a := 1;
  b := Length(ws);
  while (a <= b) and (ws[a] <= ' ') do Inc(a);
  while (b >= a) and (ws[b] <= ' ') do Dec(b);
  if a > b then
    Result := ''
  else
    Result := Copy(ws, a, b - a + 1);
end;

function FirstLine(const ws: WideString; maxLen: Integer): WideString;
var
  i: Integer;
begin
  i := 1;
  while (i <= Length(ws)) and (ws[i] <> #13) and (ws[i] <> #10) do Inc(i);
  Result := Copy(ws, 1, i - 1);
  if Length(Result) > maxLen then
    Result := Copy(Result, 1, maxLen) + '...';
end;

function IsElevated: Boolean;
var
  hToken: HANDLE;
  elev: TTokenElevation;
  retLen: DWORD;
begin
  Result := False;
  if not OpenProcessToken(GetCurrentProcess, TOKEN_QUERY, hToken) then
    Exit;
  try
    if GetTokenInformation(hToken, TokenElevation, @elev, SizeOf(elev), retLen) then
      Result := elev.TokenIsElevated <> 0;
  finally
    CloseHandle(hToken);
  end;
end;

function RunSchtasks(const args: string): DWORD;
var
  sei: SHELLEXECUTEINFOW;
begin
  Result := DWORD(-1);
  FillChar(sei, SizeOf(sei), 0);
  sei.cbSize := SizeOf(sei);
  sei.fMask := SEE_MASK_NOCLOSEPROCESS;
  sei.lpVerb := PWideChar(AsWide('open'));
  sei.lpFile := PWideChar(AsWide('schtasks.exe'));
  sei.lpParameters := PWideChar(AsWide(args));
  sei.nShow := SW_HIDE;
  if ShellExecuteExW(@sei) and (sei.hProcess <> 0) then
  begin
    WaitForSingleObject(sei.hProcess, 15000);
    GetExitCodeProcess(sei.hProcess, Result);
    CloseHandle(sei.hProcess);
  end;
end;

procedure RelaunchElevated;
var
  sei: SHELLEXECUTEINFOW;
  params: string;
  i: Integer;
begin
  params := '';
  for i := 1 to ParamCount do
    params := params + ' "' + ParamStr(i) + '"';
  params := params + ' -elev';
  FillChar(sei, SizeOf(sei), 0);
  sei.cbSize := SizeOf(sei);
  sei.fMask := SEE_MASK_NOCLOSEPROCESS;
  sei.lpVerb := PWideChar(AsWide('runas'));
  sei.lpFile := PWideChar(AsWide(ParamStr(0)));
  sei.lpParameters := PWideChar(AsWide(params));
  sei.nShow := SW_SHOWNORMAL;
  ShellExecuteExW(@sei);
end;

function GetAutostartEnabled: Boolean;
begin
  Result := RunSchtasks('/query /tn "MemClip"') = 0;
end;

procedure RemoveLegacyRunEntry;
var
  RegKey: HKEY;
  wsKey, wsName: WideString;
begin
  wsKey := AsWide('Software\Microsoft\Windows\CurrentVersion\Run');
  wsName := AsWide('MemClip');
  if RegOpenKeyExW(HKEY_CURRENT_USER, PWideChar(wsKey), 0, KEY_SET_VALUE, RegKey) = ERROR_SUCCESS then
  begin
    RegDeleteValueW(RegKey, PWideChar(wsName));
    RegCloseKey(RegKey);
  end;
end;

procedure SetAutostart(Enable: Boolean; const ExtraParam: string = '');
var
  args: string;
begin
  if Enable then
  begin
    args := '/create /tn "MemClip" /sc onlogon /rl highest /f /tr "' +
      '\' + '"' + ParamStr(0) + '\' + '"' + ExtraParam + '"';
    RunSchtasks(args);
  end
  else
    RunSchtasks('/delete /tn "MemClip" /f');
  RemoveLegacyRunEntry;
  AutostartEnabled := GetAutostartEnabled;
end;

function DetectLanguage: TLang;
var
  LangCode: LANGID;
begin
  LangCode := GetUserDefaultLangID and $3FF;
  case LangCode of
    LANG_RUSSIAN: Result := lgRussian;
    LANG_UKRAINIAN: Result := lgUkrainian;
    LANG_BELARUSIAN: Result := lgBelarusian;
    LANG_ENGLISH: Result := lgEnglish;
  else
    Result := lgRussian;
  end;
end;

function GetText(id: TTextId): string;
begin
  Result := Texts[CurrentLang, id];
end;

procedure ApplyLangSetting;
begin
  if LangSetting = 'ru' then
    CurrentLang := lgRussian
  else if LangSetting = 'uk' then
    CurrentLang := lgUkrainian
  else if LangSetting = 'be' then
    CurrentLang := lgBelarusian
  else if LangSetting = 'en' then
    CurrentLang := lgEnglish
  else
    CurrentLang := DetectLanguage;
end;

procedure SetLangChoice(const s: string);
begin
  LangSetting := s;
  ApplyLangSetting;
  SaveConfig;
end;

function GetIntervalLabel(minutes: Integer): string;
begin
  Result := Format('%d %s', [minutes, GetText(txtMinSuffix)]);
end;

procedure ParseCommandLine;
var
  i, n: Integer;
  p, digits: string;
begin
  for i := 1 to ParamCount do
  begin
    p := LowerCase(ParamStr(i));
    while (Length(p) > 0) and (p[1] in ['-', '/']) do
      p := Copy(p, 2, MaxInt);
    if p = 'clean' then
      RunOnce := True
    else if p = 'install' then
      DoInstall := True
    else if p = 'uninstall' then
      DoUninstall := True
    else if p = 'elev' then
      ElevatedRetry := True
    else if (Length(p) > 0) and (p[1] = 'a') then
    begin
      CfgAutostart := True;
      digits := Copy(p, 2, MaxInt);
      if digits <> '' then
      begin
        n := StrToIntDef(digits, 0);
        if n < 1 then
          n := 1;
        if n > 120 then
        begin
          n := 120;
          CfgIntervalCapped := True;
        end;
        CfgIntervalMin := n;
      end;
    end;
  end;
  ParamAction := RunOnce or DoInstall or DoUninstall;
end;

function FindPreviousInstance: HWND;
var
  h: HWND;
  pid, myPid: DWORD;
begin
  Result := 0;
  myPid := GetCurrentProcessId;
  h := FindWindowExA(0, 0, PChar(MainClassName), nil);
  while h <> 0 do
  begin
    GetWindowThreadProcessId(h, pid);
    if pid <> myPid then
    begin
      Result := h;
      Exit;
    end;
    h := FindWindowExA(0, h, PChar(MainClassName), nil);
  end;
end;

function GetFreeMemoryMB: Integer;
var
  memInfo: TMemoryStatusEx;
begin
  memInfo.dwLength := SizeOf(memInfo);
  if GlobalMemoryStatusEx(memInfo) then
    Result := memInfo.ullAvailPhys div (1024 * 1024)
  else
    Result := 0;
end;

function SetPrivilege(const Name: string): Boolean;
var
  hToken: HANDLE;
  tkp: TOKEN_PRIVILEGES;
  prev: TOKEN_PRIVILEGES;
  luid: TLargeInteger;
  returnLen: DWORD;
begin
  Result := False;
  if not OpenProcessToken(GetCurrentProcess, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, hToken) then
    Exit;
  try
    if not LookupPrivilegeValue(nil, PChar(Name), luid) then
      Exit;
    tkp.PrivilegeCount := 1;
    tkp.Privileges[0].Luid := luid;
    tkp.Privileges[0].Attributes := SE_PRIVILEGE_ENABLED;
    if AdjustTokenPrivileges(hToken, LongBool(False), tkp, SizeOf(tkp), prev, returnLen) then
      Result := GetLastError = ERROR_SUCCESS;
  finally
    CloseHandle(hToken);
  end;
end;

function EmptyAllWorkingSets: Boolean;
var
  cmd: DWORD;
  status: NTSTATUS;
begin
  Result := False;
  if not SetPrivilege('SeProfileSingleProcessPrivilege') then
    Exit;
  cmd := MemoryEmptyWorkingSets;
  status := NtSetSystemInformation(SystemMemoryListInformation, @cmd, SizeOf(cmd));
  Result := status >= 0;
end;

function PurgeStandbyLists: Boolean;
var
  cmd: DWORD;
  status: NTSTATUS;
begin
  Result := False;
  if not SetPrivilege('SeIncreaseQuotaPrivilege') then
    Exit;
  cmd := MemoryPurgeStandbyList;
  status := NtSetSystemInformation(SystemMemoryListInformation, @cmd, SizeOf(cmd));
  Result := status >= 0;
  cmd := MemoryPurgeLowPriorityStandbyList;
  NtSetSystemInformation(SystemMemoryListInformation, @cmd, SizeOf(cmd));
end;

function FlushSystemFileCache: Boolean;
var
  info: TSystemFileCacheInfo;
  status: NTSTATUS;
begin
  Result := False;
  if not SetPrivilege('SeIncreaseQuotaPrivilege') then
    Exit;
  FillChar(info, SizeOf(info), 0);
  info.MinimumWorkingSet := High(SIZE_T);
  info.MaximumWorkingSet := High(SIZE_T);
  status := NtSetSystemInformation(SystemFileCacheInformation, @info, SizeOf(info));
  Result := status >= 0;
end;

procedure TrimProcesses(out Trimmed: Integer);
var
  pids: array[0..PID_BUF_COUNT - 1] of DWORD;
  cbNeeded, cProcesses, i: DWORD;
  hProcess: HANDLE;
begin
  Trimmed := 0;
  if not EnumProcesses(@pids[0], SizeOf(pids), cbNeeded) then
    Exit;
  cProcesses := cbNeeded div SizeOf(DWORD);
  for i := 0 to cProcesses - 1 do
  begin
    if pids[i] = 0 then
      Continue;
    hProcess := OpenProcess(PROCESS_SET_QUOTA, LongBool(False), pids[i]);
    if hProcess = 0 then
      Continue;
    if EmptyWorkingSet(hProcess) then
      Inc(Trimmed);
    CloseHandle(hProcess);
    Sleep(PROCESSES_LOOP_DELAY);
  end;
end;

procedure DoCleanup;
var
  usedSystemWide: Boolean;
  trimmed: Integer;
begin
  usedSystemWide := EmptyAllWorkingSets;
  if not usedSystemWide then
    TrimProcesses(trimmed)
  else
    trimmed := 0;
  PurgeStandbyLists;
  FlushSystemFileCache;
end;

function CleanupThread(p: Pointer): PtrInt;
var
  freeBefore, freeAfter: Integer;
  waitResult: DWORD;
begin
  while not Exiting do
  begin
    if Paused then
    begin
      WaitForSingleObject(hEvent, INFINITE);
      Continue;
    end;

    if not ForceRun then
    begin
      while not Exiting and not Paused and not ForceRun do
      begin
        waitResult := WaitForSingleObject(hEvent, CurrentInterval);
        if waitResult = WAIT_TIMEOUT then
          Break;
      end;
      if Exiting then
        Break;
      if Paused then
        Continue;
    end;

    ForceRun := False;

    freeBefore := GetFreeMemoryMB;
    DoCleanup;
    freeAfter := GetFreeMemoryMB;
    if freeAfter >= freeBefore then
      PostMessage(hMainWnd, WM_CLEANUP_DONE, WPARAM(freeBefore), LPARAM(freeAfter));
  end;
  Result := 0;
end;

{ ==================== Clipboard history ==================== }

function HistFilePath: string;
begin
  Result := ExtractFilePath(ParamStr(0)) + 'MemClip.dat';
end;

function SameBytes(const a, b: TBytes): Boolean;
var
  n: Integer;
begin
  Result := False;
  if Length(a) <> Length(b) then
    Exit;
  n := Length(a);
  if n = 0 then
    Exit(True);
  Result := CompareMem(@a[0], @b[0], n);
end;

procedure AddFmtBytes(var e: TClipEntry; fmt: UINT; const fmtName: string; const data: TBytes);
var
  n: Integer;
begin
  if Length(data) = 0 then
    Exit;
  n := Length(e.Fmts);
  SetLength(e.Fmts, n + 1);
  e.Fmts[n].Fmt := fmt;
  e.Fmts[n].FmtName := fmtName;
  e.Fmts[n].Data := data;
end;

function GrabFmtData(fmt: UINT): TBytes;
var
  h: HANDLE;
  p: Pointer;
  sz: DWORD;
begin
  Result := nil;
  h := GetClipboardData(fmt);
  if h = 0 then
    Exit;
  sz := GlobalSize(h);
  if (sz = 0) or (sz > CLIP_MAX_BYTES) then
    Exit;
  p := GlobalLock(h);
  if p = nil then
    Exit;
  SetLength(Result, sz);
  Move(p^, Result[0], sz);
  GlobalUnlock(h);
end;

function AddClipboardFmt(var e: TClipEntry; fmt: UINT; const fmtName: string): Boolean;
var
  d: TBytes;
begin
  d := GrabFmtData(fmt);
  Result := Length(d) > 0;
  if Result then
    AddFmtBytes(e, fmt, fmtName, d);
end;

procedure EntryCalcImgSize(var e: TClipEntry);
var
  i: Integer;
begin
  e.ImgW := 0;
  e.ImgH := 0;
  for i := 0 to High(e.Fmts) do
    if ((e.Fmts[i].Fmt = CF_DIB) or (e.Fmts[i].Fmt = CF_DIBV5)) and
       (Length(e.Fmts[i].Data) >= 12) then
    begin
      e.ImgW := PLongInt(@e.Fmts[i].Data[4])^;
      e.ImgH := PLongInt(@e.Fmts[i].Data[8])^;
      if e.ImgH < 0 then
        e.ImgH := -e.ImgH;
      if (e.ImgW <= 0) or (e.ImgW > 65535) then
        e.ImgW := 0;
      if (e.ImgH <= 0) or (e.ImgH > 65535) then
        e.ImgH := 0;
      Exit;
    end;
end;

function SameClipEntry(const a, b: TClipEntry): Boolean;
var
  i: Integer;
begin
  Result := False;
  if (a.Kind <> b.Kind) or (a.Text <> b.Text) or
     (Length(a.Fmts) <> Length(b.Fmts)) then
    Exit;
  for i := 0 to High(a.Fmts) do
    if (a.Fmts[i].Fmt <> b.Fmts[i].Fmt) or
       (a.Fmts[i].FmtName <> b.Fmts[i].FmtName) or
       not SameBytes(a.Fmts[i].Data, b.Fmts[i].Data) then
      Exit;
  Result := True;
end;

function FindClipDup(const e: TClipEntry): Integer;
var
  i: Integer;
begin
  for i := 0 to High(ClipHistory) do
    if SameClipEntry(ClipHistory[i], e) then
      Exit(i);
  Result := -1;
end;

function CountPinned: Integer;
begin
  Result := 0;
  while (Result < Length(ClipHistory)) and ClipHistory[Result].Pinned do
    Inc(Result);
end;

procedure QueueOcrIndex(idx: Integer); forward;

procedure EntrySetTextFmt(var e: TClipEntry);
var
  j: Integer;
  n: DWORD;
begin
  n := DWORD(Length(e.Text) + 1) * SizeOf(WideChar);
  for j := 0 to High(e.Fmts) do
    if e.Fmts[j].Fmt = CF_UNICODETEXT then
    begin
      SetLength(e.Fmts[j].Data, n);
      Move(PWideChar(e.Text)^, e.Fmts[j].Data[0], n);
      Exit;
    end;
end;

procedure ClipAdd(const e: TClipEntry);
var
  i, j, p: Integer;
  m: TClipEntry;
begin
  p := CountPinned;
  if ClipMergeEnabled and (e.Kind = ckText) and (p < Length(ClipHistory)) and
     (ClipHistory[p].Kind = ckText) and (e.Text <> '') and
     (ClipHistory[p].Text <> '') and (e.Text <> ClipHistory[p].Text) and
     (GetTickCount64 - ClipHistory[p].Time < CLIP_MERGE_MS) then
  begin
    ClipHistory[p].Text := ClipHistory[p].Text + #13#10 + e.Text;
    EntrySetTextFmt(ClipHistory[p]);
    ClipHistory[p].Time := e.Time;
    if hMainWnd <> 0 then
      SetTimer(hMainWnd, TIMER_HISTSAVE, 5000, nil);
    if hViewWnd <> 0 then
      PostMessage(hViewWnd, VIEW_REFRESH, 0, 0);
    Exit;
  end;
  i := FindClipDup(e);
  if (i >= 0) and (i < p) then
    Exit;
  if i >= 0 then
  begin
    m := ClipHistory[i];
    for j := i downto p + 1 do
      ClipHistory[j] := ClipHistory[j - 1];
    ClipHistory[p] := m;
  end
  else
  begin
    SetLength(ClipHistory, Length(ClipHistory) + 1);
    for j := High(ClipHistory) downto p + 1 do
      ClipHistory[j] := ClipHistory[j - 1];
    ClipHistory[p] := e;
    while Length(ClipHistory) - CountPinned > ClipHistoryMax do
      SetLength(ClipHistory, Length(ClipHistory) - 1);
    if ClipHistory[p].Kind = ckImage then
      QueueOcrIndex(p);
  end;
  if hMainWnd <> 0 then
    SetTimer(hMainWnd, TIMER_HISTSAVE, 5000, nil);
  if hViewWnd <> 0 then
    PostMessage(hViewWnd, VIEW_REFRESH, 0, 0);
end;

procedure RemoveClipEntry(idx: Integer);
var
  i: Integer;
begin
  if (idx < 0) or (idx >= Length(ClipHistory)) then
    Exit;
  for i := idx to High(ClipHistory) - 1 do
    ClipHistory[i] := ClipHistory[i + 1];
  SetLength(ClipHistory, Length(ClipHistory) - 1);
  for i := 0 to High(ViewThumbs) do
    if ViewThumbs[i] <> 0 then
    begin
      DeleteObject(ViewThumbs[i]);
      ViewThumbs[i] := 0;
    end;
  if hMainWnd <> 0 then
    SetTimer(hMainWnd, TIMER_HISTSAVE, 2000, nil);
  if hViewWnd <> 0 then
    PostMessage(hViewWnd, VIEW_REFRESH, 0, 0);
end;

procedure TogglePin(idx: Integer);
var
  i, p, len: Integer;
  m: TClipEntry;
begin
  len := Length(ClipHistory);
  if (idx < 0) or (idx >= len) then
    Exit;
  m := ClipHistory[idx];
  if not m.Pinned then
  begin
    p := CountPinned;
    m.Pinned := True;
    for i := idx downto p + 1 do
      ClipHistory[i] := ClipHistory[i - 1];
    ClipHistory[p] := m;
  end
  else
  begin
    m.Pinned := False;
    p := CountPinned;
    for i := idx + 1 to p - 1 do
      ClipHistory[i - 1] := ClipHistory[i];
    ClipHistory[p - 1] := m;
  end;
  if hMainWnd <> 0 then
    SetTimer(hMainWnd, TIMER_HISTSAVE, 2000, nil);
  if hViewWnd <> 0 then
    PostMessage(hViewWnd, VIEW_REFRESH, 0, 0);
end;

procedure ClipShouldIgnoreInit;
var
  i: Integer;
begin
  if fmtCVI <> 0 then
    Exit;
  fmtCVI := RegisterClipboardFormatW('Clipboard Viewer Ignore');
  fmtExclude := RegisterClipboardFormatW('ExcludeClipboardContentFromMonitorProcessing');
  fmtCanHist := RegisterClipboardFormatW('CanIncludeInClipboardHistory');
  fmtCanCloud := RegisterClipboardFormatW('CanUploadToCloudClipboard');
  for i := 0 to REGFMT_COUNT - 1 do
    RegFmtIds[i] := RegisterClipboardFormatW(PWideChar(AsWide(REGFMT_NAMES[i])));
end;

function ClipShouldIgnore: Boolean;
var
  fmt: UINT;
  h: HANDLE;
  p: Pointer;
  v: DWORD;
begin
  Result := False;
  ClipShouldIgnoreInit;
  fmt := 0;
  repeat
    fmt := EnumClipboardFormats(fmt);
    if fmt = 0 then
      Break;
    if (fmt = fmtCVI) or (fmt = fmtExclude) then
    begin
      if GetClipboardData(fmt) <> 0 then
        Exit(True);
    end
    else if (fmt = fmtCanHist) or (fmt = fmtCanCloud) then
    begin
      h := GetClipboardData(fmt);
      if h <> 0 then
      begin
        p := GlobalLock(h);
        if p <> nil then
        begin
          v := PDWORD(p)^;
          GlobalUnlock(h);
          if v = 0 then
            Exit(True);
        end;
      end;
    end;
  until False;
end;

function ClipOwnerProcName: WideString;
var
  hw: HWND;
  pid: DWORD;
  hp: HANDLE;
  buf: array[0..519] of WideChar;
  n: DWORD;
  name: WideString;
  i: Integer;
begin
  Result := '';
  hw := GetClipboardOwner;
  if hw = 0 then
    hw := GetForegroundWindow;
  if hw = 0 then
    Exit;
  pid := 0;
  GetWindowThreadProcessId(hw, @pid);
  if pid = 0 then
    Exit;
  hp := OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid);
  if hp = 0 then
    Exit;
  try
    n := Length(buf);
    if not QueryFullProcessImageNameW(hp, 0, buf, @n) or (n = 0) then
      Exit;
  finally
    CloseHandle(hp);
  end;
  buf[n] := #0;
  name := WideString(PWideChar(@buf[0]));
  i := Length(name);
  while (i > 0) and (name[i] <> '\') do
    Dec(i);
  Result := Copy(name, i + 1, MaxInt);
end;

function ClipOwnerProcExcluded: Boolean;
begin
  Result := (ClipExcludeProcs <> '') and
    (Pos(';' + WideLowerCase(ClipOwnerProcName) + ';', ';' + ClipExcludeProcs + ';') > 0);
end;

function OpenClipRetry: Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to 4 do
  begin
    if OpenClipboard(hMainWnd) then
      Exit(True);
    Sleep(40);
  end;
end;

procedure SetClipDataBytes(fmt: UINT; const d: TBytes);
var
  h: HGLOBAL;
  p: Pointer;
begin
  if (fmt = 0) or (Length(d) = 0) then
    Exit;
  h := GlobalAlloc(GMEM_MOVEABLE, Length(d));
  if h = 0 then
    Exit;
  p := GlobalLock(h);
  if p <> nil then
  begin
    Move(d[0], p^, Length(d));
    GlobalUnlock(h);
  end;
  if SetClipboardData(fmt, h) = 0 then
    GlobalFree(h);
end;

procedure SetRegClipData(const name: string; const d: TBytes);
begin
  SetClipDataBytes(RegisterClipboardFormatW(PWideChar(AsWide(name))), d);
end;

function EnsureGdiPlus: Boolean;
var
  si: TGdiplusStartupInput;
  so: TGdiplusStartupOutput;
begin
  if GdipStarted then
    Exit(True);
  FillChar(si, SizeOf(si), 0);
  FillChar(so, SizeOf(so), 0);
  si.GdiplusVersion := 1;
  si.SuppressBackgroundThread := True;
  GdipStarted := GdiplusStartup(GdipToken, si, @so) = 0;
  Result := GdipStarted;
end;

function StreamFromBytes(const d: TBytes): IStream;
var
  h: HGLOBAL;
  p: Pointer;
begin
  Result := nil;
  if Length(d) = 0 then
    Exit;
  h := GlobalAlloc(GMEM_MOVEABLE, Length(d));
  if h = 0 then
    Exit;
  p := GlobalLock(h);
  if p <> nil then
    Move(d[0], p^, Length(d));
  GlobalUnlock(h);
  if CreateStreamOnHGlobal(h, True, Result) <> S_OK then
  begin
    GlobalFree(h);
    Result := nil;
  end;
end;

function StreamToBytes(stm: IStream): TBytes;
var
  pos: QWord;
  cb: ULONG;
  n, i: Integer;
begin
  Result := nil;
  if (stm = nil) or (stm.Seek(0, STREAM_SEEK_CUR, pos) <> S_OK) or (pos = 0) then
    Exit;
  n := Integer(pos);
  SetLength(Result, n);
  cb := 0;
  if (stm.Seek(0, STREAM_SEEK_SET, pos) <> S_OK) or
     (stm.Read(@Result[0], n, @cb) <> S_OK) then
  begin
    Result := nil;
    Exit;
  end;
  SetLength(Result, Integer(cb));
  // trim trailing zeros: PNG always ends with an IEND chunk
  for i := 8 to Length(Result) - 8 do
    if PDWORD(@Result[i])^ = $444E4549 then
    begin
      SetLength(Result, i + 8);
      Break;
    end;
end;

function DibToBmpFile(const dib: TBytes): TBytes;
var
  biSize, bitCount, comp, clrUsed, imgSize, palBytes, offBits: DWORD;
  w, h: DWORD;
begin
  Result := nil;
  if Length(dib) < 40 then
    Exit;
  biSize := PDWORD(@dib[0])^;
  if (biSize < 40) or (DWORD(Length(dib)) < biSize) then
    Exit;
  w := PDWORD(@dib[4])^;
  h := DWORD(Abs(PInteger(@dib[8])^));
  bitCount := PWORD(@dib[14])^;
  comp := PDWORD(@dib[16])^;
  imgSize := PDWORD(@dib[20])^;
  clrUsed := PDWORD(@dib[32])^;
  palBytes := 0;
  if bitCount <= 8 then
  begin
    if clrUsed = 0 then
      clrUsed := DWORD(1) shl bitCount;
    palBytes := clrUsed * 4;
  end
  else if comp = BI_BITFIELDS then
    palBytes := 12 + clrUsed * 4;
  if DWORD(Length(dib)) < biSize + palBytes then
    Exit;
  if imgSize = 0 then
    imgSize := ((w * bitCount + 31) div 32) * 4 * h;
  if biSize + palBytes + imgSize > DWORD(Length(dib)) then
    imgSize := DWORD(Length(dib)) - biSize - palBytes;
  if imgSize = 0 then
    Exit;
  offBits := 14 + biSize + palBytes;
  SetLength(Result, offBits + imgSize);
  PWORD(@Result[0])^ := $4D42;
  PDWORD(@Result[2])^ := offBits + imgSize;
  PDWORD(@Result[6])^ := 0;
  PDWORD(@Result[10])^ := offBits;
  Move(dib[0], Result[14], biSize + palBytes);
  Move(dib[biSize + palBytes], Result[offBits], imgSize);
end;

function PngFromDib(const dib: TBytes): TBytes;
var
  bmp: TBytes;
  stmIn, stmOut: IStream;
  img: Pointer;
  hOut: HGLOBAL;
begin
  Result := nil;
  bmp := DibToBmpFile(dib);
  if (Length(bmp) = 0) or not EnsureGdiPlus then
    Exit;
  stmIn := StreamFromBytes(bmp);
  if stmIn = nil then
    Exit;
  img := nil;
  if GdipCreateBitmapFromStream(stmIn, img) <> 0 then
    Exit;
  hOut := GlobalAlloc(GMEM_MOVEABLE, 65536);
  if (hOut <> 0) and (CreateStreamOnHGlobal(hOut, True, stmOut) = S_OK) then
  begin
    if GdipSaveImageToStream(img, stmOut, PNG_CLSID, nil) = 0 then
      Result := StreamToBytes(stmOut);
    stmOut := nil;
  end
  else if hOut <> 0 then
    GlobalFree(hOut);
  GdipDisposeImage(img);
end;

procedure SetFileImageFormats(const path: WideString);
var
  img: Pointer;
  hbm: HBITMAP;
  stmOut: IStream;
  hOut: HGLOBAL;
  png: TBytes;
begin
  if not EnsureGdiPlus then
    Exit;
  img := nil;
  if GdipLoadImageFromFileICM(PWideChar(path), img) <> 0 then
    Exit;
  hOut := GlobalAlloc(GMEM_MOVEABLE, 65536);
  if (hOut <> 0) and (CreateStreamOnHGlobal(hOut, True, stmOut) = S_OK) then
  begin
    if GdipSaveImageToStream(img, stmOut, PNG_CLSID, nil) = 0 then
    begin
      png := StreamToBytes(stmOut);
      if Length(png) > 0 then
        SetRegClipData('PNG', png);
    end;
    stmOut := nil;
  end
  else if hOut <> 0 then
    GlobalFree(hOut);
  if GdipCreateHBITMAPFromBitmap(img, hbm, 0) = 0 then
    if SetClipboardData(CF_BITMAP, hbm) = 0 then
      DeleteObject(hbm);
  GdipDisposeImage(img);
end;

function FirstDropPath(const d: TBytes): WideString;
var
  ofs: DWORD;
begin
  Result := '';
  if Length(d) < 20 then
    Exit;
  ofs := PDWORD(@d[0])^;
  if (ofs = 0) or (ofs >= DWORD(Length(d))) then
    Exit;
  if PDWORD(@d[16])^ <> 0 then
    Result := PWideChar(@d[ofs])
  else
    Result := WideString(AnsiString(PAnsiChar(@d[ofs])));
end;

function IsImageFilePath(const path: WideString): Boolean;
const
  IMG_EXTS: array[0..7] of WideString =
    ('.png', '.jpg', '.jpeg', '.jfif', '.gif', '.bmp', '.tif', '.tiff');
var
  e: WideString;
  i: Integer;
begin
  Result := False;
  e := WideLowerCase(path);
  for i := 0 to High(IMG_EXTS) do
    if (Length(e) > Length(IMG_EXTS[i])) and
       (Copy(e, Length(e) - Length(IMG_EXTS[i]) + 1, Length(IMG_EXTS[i])) = IMG_EXTS[i]) then
      Exit(True);
end;

function EntryDibBytes(const e: TClipEntry): TBytes;
var
  i: Integer;
begin
  for i := 0 to High(e.Fmts) do
    if (e.Fmts[i].Fmt = CF_DIBV5) and (e.Fmts[i].Data <> nil) then
      Exit(e.Fmts[i].Data);
  for i := 0 to High(e.Fmts) do
    if (e.Fmts[i].Fmt = CF_DIB) and (e.Fmts[i].Data <> nil) then
      Exit(e.Fmts[i].Data);
  Result := nil;
end;

function EntryHasPngFmt(const e: TClipEntry): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to High(e.Fmts) do
    if (CompareText(e.Fmts[i].FmtName, 'PNG') = 0) or
       (CompareText(e.Fmts[i].FmtName, 'image/png') = 0) then
      Exit(True);
end;

procedure CaptureClipboard;
var
  h: HANDLE;
  hDropFiles: HDROP;
  hemf: HENHMETAFILE;
  sz, cnt, i: DWORD;
  data: TBytes;
  ws, oneName, names: WideString;
  buf: array[0..519] of WideChar;
  e: TClipEntry;
  hasImg, hasFiles: Boolean;
begin
  if ClipOwnerProcExcluded then
    Exit;
  if not OpenClipRetry then
    Exit;
  try
    if ClipShouldIgnore then
      Exit;

    e.Kind := ckText;
    e.Text := '';
    e.ImgW := 0;
    e.ImgH := 0;
    e.Pinned := False;
    e.Time := GetTickCount64;
    GetSystemTimeAsFileTime(e.StampUtc);
    e.Owner := ClipOwnerProcName;
    e.Fmts := nil;
    hasImg := False;
    hasFiles := False;

    // Text (Windows synthesizes CF_UNICODETEXT from CF_TEXT)
    if IsClipboardFormatAvailable(CF_UNICODETEXT) then
    begin
      data := GrabFmtData(CF_UNICODETEXT);
      if Length(data) > 0 then
      begin
        ws := PWideChar(@data[0]);
        if ws <> '' then
        begin
          e.Text := ws;
          AddFmtBytes(e, CF_UNICODETEXT, '', data);
        end;
      end;
    end;

    // Raster images (system synthesizes CF_DIB/CF_DIBV5 from CF_BITMAP)
    if IsClipboardFormatAvailable(CF_DIB) then
      hasImg := AddClipboardFmt(e, CF_DIB, '') or hasImg;
    if IsClipboardFormatAvailable(CF_DIBV5) then
      hasImg := AddClipboardFmt(e, CF_DIBV5, '') or hasImg;

    // Vector image
    if IsClipboardFormatAvailable(CF_ENHMETAFILE) then
    begin
      hemf := GetClipboardData(CF_ENHMETAFILE);
      if hemf <> 0 then
      begin
        sz := GetEnhMetaFileBits(hemf, 0, nil);
        if (sz > 0) and (sz <= CLIP_MAX_BYTES) then
        begin
          SetLength(data, sz);
          if GetEnhMetaFileBits(hemf, sz, @data[0]) = sz then
          begin
            AddFmtBytes(e, CF_ENHMETAFILE, '', data);
            hasImg := True;
          end;
        end;
      end;
    end;

    // File list
    if IsClipboardFormatAvailable(CF_HDROP) then
    begin
      data := GrabFmtData(CF_HDROP);
      if Length(data) > 0 then
      begin
        AddFmtBytes(e, CF_HDROP, '', data);
        hasFiles := True;
        h := GetClipboardData(CF_HDROP);
        if h <> 0 then
        begin
          hDropFiles := HDROP(h);
          cnt := DragQueryFileW(hDropFiles, $FFFFFFFF, nil, 0);
          names := '';
          i := 0;
          while (i < cnt) and (i < 4) do
          begin
            if DragQueryFileW(hDropFiles, i, buf, 519) > 0 then
            begin
              oneName := PWideChar(@buf[0]);
              if names <> '' then
                names := names + '; ';
              names := names + oneName;
            end;
            Inc(i);
          end;
          if cnt > 4 then
            names := names + ' ...';
          if names <> '' then
            e.Text := names;
        end;
      end;
    end;

    // Registered formats: PNG/JFIF/GIF/image/png (images), HTML Format/RTF (rich text)
    for i := 0 to REGFMT_COUNT - 1 do
      if (RegFmtIds[i] <> 0) and IsClipboardFormatAvailable(RegFmtIds[i]) then
      begin
        if AddClipboardFmt(e, RegFmtIds[i], REGFMT_NAMES[i]) and (i <= REGFMT_IMG_MAX) then
          hasImg := True;
      end;

    if Length(e.Fmts) = 0 then
      Exit;
    if hasFiles then
      e.Kind := ckFiles
    else if hasImg then
      e.Kind := ckImage
    else
      e.Kind := ckText;
    if e.Kind = ckImage then
      EntryCalcImgSize(e);
    ClipAdd(e);
  finally
    CloseClipboard;
  end;
end;

function ClipMenuLabel(const e: TClipEntry): WideString;
var
  s: WideString;
  i: Integer;
begin
  case e.Kind of
    ckText:
      begin
        s := e.Text;
        for i := 1 to Length(s) do
          if s[i] < ' ' then
            s[i] := ' ';
        s := TrimWide(s);
        if Length(s) > MENU_LABEL_MAX then
          s := Copy(s, 1, MENU_LABEL_MAX) + '...';
        Result := s;
      end;
    ckImage:
      begin
        Result := AsWide(GetText(txtClipImage));
        if (e.ImgW > 0) and (e.ImgH > 0) then
          Result := Result + AsWide(' ' + IntToStr(e.ImgW) + 'x' + IntToStr(e.ImgH));
      end;
    ckFiles:
      begin
        s := TrimWide(e.Text);
        if Length(s) > MENU_LABEL_MAX then
          s := Copy(s, 1, MENU_LABEL_MAX) + '...';
        Result := AsWide(GetText(txtClipFiles)) + s;
      end;
  else
    Result := '';
  end;
end;

function ScaleToThumb(src: HBITMAP; maxDim: Integer): HBITMAP;
var
  bm: BITMAP;
  sw, sh, tw, th: Integer;
  dc, hdcSrc: HDC;
  hbmp, oldSrc, oldDst: HBITMAP;
begin
  Result := 0;
  FillChar(bm, SizeOf(bm), 0);
  if GetObjectW(src, SizeOf(bm), @bm) = 0 then
    Exit;
  sw := bm.bmWidth;
  sh := bm.bmHeight;
  if (sw <= 0) or (sh <= 0) then
    Exit;
  if sw >= sh then
  begin
    tw := maxDim;
    th := Round(sh * maxDim / sw);
  end
  else
  begin
    th := maxDim;
    tw := Round(sw * maxDim / sh);
  end;
  if tw < 1 then tw := 1;
  if th < 1 then th := 1;
  dc := GetDC(0);
  hbmp := CreateCompatibleBitmap(dc, tw, th);
  ReleaseDC(0, dc);
  if hbmp = 0 then
    Exit;
  hdcSrc := CreateCompatibleDC(0);
  dc := CreateCompatibleDC(0);
  oldDst := SelectObject(dc, hbmp);
  oldSrc := SelectObject(hdcSrc, src);
  PatBlt(dc, 0, 0, tw, th, WHITENESS);
  SetStretchBltMode(dc, HALFTONE);
  StretchBlt(dc, 0, 0, tw, th, hdcSrc, 0, 0, sw, sh, SRCCOPY);
  SelectObject(dc, oldDst);
  SelectObject(hdcSrc, oldSrc);
  DeleteDC(dc);
  DeleteDC(hdcSrc);
  Result := hbmp;
end;

function EntryThumbHbm(const e: TClipEntry): HBITMAP;
var
  i: Integer;
  img: Pointer;
  hbm: HBITMAP;
  stm: IStream;
  bytes: TBytes;
  isImgFmt: Boolean;
begin
  Result := 0;
  if not EnsureGdiPlus then
    Exit;
  for i := 0 to High(e.Fmts) do
  begin
    isImgFmt := (e.Fmts[i].FmtName = 'PNG') or (e.Fmts[i].FmtName = 'image/png') or
                (e.Fmts[i].FmtName = 'JFIF') or (e.Fmts[i].FmtName = 'GIF');
    if isImgFmt then
      bytes := e.Fmts[i].Data
    else if (e.Fmts[i].Fmt = CF_DIB) or (e.Fmts[i].Fmt = CF_DIBV5) then
      bytes := DibToBmpFile(e.Fmts[i].Data)
    else
      Continue;
    if Length(bytes) = 0 then
      Continue;
    stm := StreamFromBytes(bytes);
    if stm = nil then
      Continue;
    img := nil;
    if GdipCreateBitmapFromStream(stm, img) = 0 then
    begin
      hbm := 0;
      if GdipCreateHBITMAPFromBitmap(img, hbm, 0) = 0 then
      begin
        Result := ScaleToThumb(hbm, THUMB_SIZE);
        DeleteObject(hbm);
      end;
      GdipDisposeImage(img);
    end;
    if Result <> 0 then
      Exit;
  end;
end;

procedure BuildClipMenu(menu: HMENU; thumbs: TList);
var
  i, p: Integer;
  hb: HBITMAP;
  lbl: WideString;
  mii: MENUITEMINFOW;
begin
  p := CountPinned;
  if Length(ClipHistory) = 0 then
    AppendMenuW(menu, MF_STRING or MF_GRAYED, 0, PWideChar(AsWide(GetText(txtClipEmpty))))
  else
    for i := 0 to High(ClipHistory) do
    begin
      if (i = p) and (p > 0) then
        AppendMenuW(menu, MF_SEPARATOR, 0, nil);
      lbl := ClipMenuLabel(ClipHistory[i]);
      if ClipHistory[i].Pinned then
        lbl := WideChar($2605) + ' ' + lbl;
      AppendMenuW(menu, MF_STRING, IDM_CLIPBASE + i, PWideChar(lbl));
      hb := EntryThumbHbm(ClipHistory[i]);
      if hb <> 0 then
      begin
        thumbs.Add(Pointer(hb));
        FillChar(mii, SizeOf(mii), 0);
        mii.cbSize := SizeOf(mii);
        mii.fMask := MIIM_BITMAP;
        mii.hbmpItem := hb;
        SetMenuItemInfoW(menu, IDM_CLIPBASE + i, False, @mii);
      end;
    end;
  AppendMenuW(menu, MF_SEPARATOR, 0, nil);
  AppendMenuW(menu, MF_STRING, IDM_HISTORY, PWideChar(AsWide(GetText(txtHistoryWnd))));
  AppendMenuW(menu, MF_STRING, IDM_CLIPCLEAR, PWideChar(AsWide(GetText(txtClipClear))));
end;

procedure FreeThumbs(thumbs: TList);
var
  i: Integer;
begin
  for i := 0 to thumbs.Count - 1 do
    DeleteObject(HBITMAP(thumbs[i]));
  thumbs.Free;
end;

procedure RestoreClipEntry(const e: TClipEntry);
var
  i: Integer;
  fmt: UINT;
  hemf: HENHMETAFILE;
  data: TBytes;
  path: WideString;
begin
  if Length(e.Fmts) = 0 then
    Exit;
  if not OpenClipRetry then
    Exit;
  try
    EmptyClipboard;
    for i := 0 to High(e.Fmts) do
    begin
      fmt := e.Fmts[i].Fmt;
      if e.Fmts[i].FmtName <> '' then
        fmt := RegisterClipboardFormatW(PWideChar(AsWide(e.Fmts[i].FmtName)));
      if (fmt = 0) or (Length(e.Fmts[i].Data) = 0) then
        Continue;
      if fmt = CF_ENHMETAFILE then
      begin
        hemf := SetEnhMetaFileBits(Length(e.Fmts[i].Data), @e.Fmts[i].Data[0]);
        if hemf <> 0 then
          SetClipboardData(CF_ENHMETAFILE, hemf);
        Continue;
      end;
      SetClipDataBytes(fmt, e.Fmts[i].Data);
    end;
    if e.Kind = ckImage then
    begin
      // Supply PNG too: browsers/messengers refuse plain DIB
      if (not EntryHasPngFmt(e)) and (not IsClipboardFormatAvailable(RegFmtIds[0])) then
      begin
        data := EntryDibBytes(e);
        if Length(data) > 0 then
        begin
          data := PngFromDib(data);
          if Length(data) > 0 then
            SetRegClipData('PNG', data);
        end;
      end;
    end
    else if e.Kind = ckFiles then
    begin
      // Single image file: put the image itself on the clipboard as well
      for i := 0 to High(e.Fmts) do
        if e.Fmts[i].Fmt = CF_HDROP then
        begin
          path := FirstDropPath(e.Fmts[i].Data);
          if IsImageFilePath(path) then
            SetFileImageFormats(path);
          Break;
        end;
    end;
  finally
    CloseClipboard;
  end;
end;

procedure SendCtrlV;
var
  inp: array[0..3] of TINPUT;
begin
  FillChar(inp, SizeOf(inp), 0);
  inp[0]._Type := INPUT_KEYBOARD;
  inp[0].ki.wVk := VK_CONTROL;
  inp[1]._Type := INPUT_KEYBOARD;
  inp[1].ki.wVk := Ord('V');
  inp[2]._Type := INPUT_KEYBOARD;
  inp[2].ki.wVk := Ord('V');
  inp[2].ki.dwFlags := KEYEVENTF_KEYUP;
  inp[3]._Type := INPUT_KEYBOARD;
  inp[3].ki.wVk := VK_CONTROL;
  inp[3].ki.dwFlags := KEYEVENTF_KEYUP;
  SendInput(4, @inp[0], SizeOf(TINPUT));
end;

procedure QueueInfo(const msg: string); forward;
procedure QueueInfoW(const msg: WideString); forward;
procedure SetClipboardText(const s: WideString); forward;
procedure ShowSnipEditor(bmp: HBITMAP; w, h: Integer); forward;

procedure RestoreAndMaybePaste(idx: Integer);
var
  lbl: WideString;
begin
  if (idx < 0) or (idx > High(ClipHistory)) then
    Exit;
  lbl := ClipMenuLabel(ClipHistory[idx]);
  RestoreClipEntry(ClipHistory[idx]);
  if AutoPaste and (LastForeWnd <> 0) and IsWindow(LastForeWnd) then
  begin
    SetForegroundWindow(LastForeWnd);
    Sleep(60);
    SendCtrlV;
  end
  else
    QueueInfo(Format(GetText(txtClipCopied), [AsUTF8(lbl)]));
end;

procedure RestoreAndMaybePastePlain(idx: Integer);
begin
  if (idx < 0) or (idx > High(ClipHistory)) then
    Exit;
  if ClipHistory[idx].Text = '' then
    Exit;
  SetClipboardText(ClipHistory[idx].Text);
  if AutoPaste and (LastForeWnd <> 0) and IsWindow(LastForeWnd) then
  begin
    SetForegroundWindow(LastForeWnd);
    Sleep(60);
    SendCtrlV;
  end
  else
    QueueInfo(Format(GetText(txtClipCopied), [AsUTF8(ClipMenuLabel(ClipHistory[idx]))]));
end;

procedure PastePlainFromClipboard;
var
  h: HANDLE;
  s: WideString;
begin
  if not IsClipboardFormatAvailable(CF_UNICODETEXT) then
    Exit;
  if not OpenClipRetry then
    Exit;
  s := '';
  h := GetClipboardData(CF_UNICODETEXT);
  if h <> 0 then
    s := PWideChar(GlobalLock(h));
  if h <> 0 then
    GlobalUnlock(h);
  CloseClipboard;
  if s = '' then
    Exit;
  SetClipboardText(s);
  SendCtrlV;
end;

procedure ShowClipHistoryMenu(x, y: Integer);
var
  menu: HMENU;
  thumbs: TList;
begin
  menu := CreatePopupMenu;
  thumbs := TList.Create;
  BuildClipMenu(menu, thumbs);

  LastForeWnd := GetForegroundWindow;
  SetForegroundWindow(hMainWnd);
  TrackPopupMenu(menu, TPM_RIGHTBUTTON, x, y, 0, hMainWnd, nil);
  PostMessage(hMainWnd, WM_NULL, 0, 0);
  DestroyMenu(menu);
  FreeThumbs(thumbs);
end;

procedure SetClipboardText(const s: WideString);
var
  h: HGLOBAL;
  p: Pointer;
  n: DWORD;
begin
  if s = '' then
    Exit;
  if not OpenClipRetry then
    Exit;
  EmptyClipboard;
  n := DWORD(Length(s) + 1) * SizeOf(WideChar);
  h := GlobalAlloc(GMEM_MOVEABLE, n);
  if h <> 0 then
  begin
    p := GlobalLock(h);
    Move(PWideChar(s)^, p^, n);
    GlobalUnlock(h);
    if SetClipboardData(CF_UNICODETEXT, h) = 0 then
      GlobalFree(h);
  end;
  CloseClipboard;
end;

procedure ToggleClipWatch;
begin
  ClipWatchEnabled := not ClipWatchEnabled;
  if ClipWatchEnabled then
  begin
    AddClipboardFormatListener(hMainWnd);
    QueueInfo(GetText(txtClipWatchOn));
  end
  else
  begin
    RemoveClipboardFormatListener(hMainWnd);
    QueueInfo(GetText(txtClipWatchOff));
  end;
  SaveConfig;
end;

{ --- History viewer window: search, thumbnails, pinning --- }

function ViewThumbFor(entryIdx: Integer): HBITMAP;
begin
  if (entryIdx < 0) or (entryIdx > High(ClipHistory)) or
     (entryIdx > High(ViewThumbs)) then
    Exit(0);
  if ViewThumbs[entryIdx] = 0 then
    ViewThumbs[entryIdx] := EntryThumbHbm(ClipHistory[entryIdx]);
  Result := ViewThumbs[entryIdx];
end;

procedure ViewRebuildFilter;
var
  i, n: Integer;
  flt: WideString;
  sel: Integer;
begin
  if hViewWnd = 0 then
    Exit;
  n := GetWindowTextLengthW(hViewEdit);
  flt := '';
  if n > 0 then
  begin
    SetLength(flt, n);
    GetWindowTextW(hViewEdit, PWideChar(flt), n + 1);
  end;
  flt := WideLowerCase(flt);
  SetLength(ViewThumbs, Length(ClipHistory));
  SetLength(ViewIdx, 0);
  for i := 0 to High(ClipHistory) do
    if (flt = '') or
       (Pos(flt, WideLowerCase(ClipHistory[i].Text)) > 0) or
       (Pos(flt, WideLowerCase(ClipHistory[i].OcrText)) > 0) or
       (Pos(flt, WideLowerCase(ClipMenuLabel(ClipHistory[i]))) > 0) then
    begin
      SetLength(ViewIdx, Length(ViewIdx) + 1);
      ViewIdx[High(ViewIdx)] := i;
    end;
  SendMessageW(hViewList, LB_SETCOUNT, Length(ViewIdx), 0);
  sel := -1;
  if Length(ViewIdx) > 0 then
    sel := 0;
  SendMessageW(hViewList, LB_SETCURSEL, sel, 0);
  InvalidateRect(hViewList, nil, True);
end;

function ViewSelEntry: Integer;
var
  lbIdx: Integer;
begin
  Result := -1;
  if hViewWnd = 0 then
    Exit;
  lbIdx := SendMessageW(hViewList, LB_GETCURSEL, 0, 0);
  if (lbIdx >= 0) and (lbIdx < Length(ViewIdx)) then
    Result := ViewIdx[lbIdx];
end;

function EntryPngBytes(const e: TClipEntry): TBytes;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to High(e.Fmts) do
    if ((CompareText(e.Fmts[i].FmtName, 'PNG') = 0) or
        (CompareText(e.Fmts[i].FmtName, 'image/png') = 0)) and
       (Length(e.Fmts[i].Data) > 0) then
    begin
      Result := e.Fmts[i].Data;
      Exit;
    end;
  for i := 0 to High(e.Fmts) do
    if ((e.Fmts[i].Fmt = CF_DIB) or (e.Fmts[i].Fmt = CF_DIBV5)) and
       (Length(e.Fmts[i].Data) > 0) then
    begin
      Result := PngFromDib(e.Fmts[i].Data);
      Exit;
    end;
end;

procedure EntrySaveAs(idx: Integer; owner: HWND);
const
  OFN_OVERWRITEPROMPT_MC = $00000002;
  OFN_PATHMUSTEXIST_MC = $00000800;
var
  data: TBytes;
  s, filter, ext: WideString;
  n, k: Integer;
  fn: array[0..MAX_PATH] of WideChar;
  ofn: TMcOpenFileNameW;
  hf: THandle;
  fs: THandleStream;
begin
  if (idx < 0) or (idx >= Length(ClipHistory)) then
    Exit;
  if ClipHistory[idx].Kind = ckImage then
  begin
    data := EntryPngBytes(ClipHistory[idx]);
    if Length(data) = 0 then
      Exit;
    ext := 'png';
    filter := WideString('PNG files (*.png)'#0'*.png'#0);
  end
  else
  begin
    s := ClipHistory[idx].Text;
    if s = '' then
      Exit;
    SetLength(data, 3 + Length(s) * 3);
    data[0] := $EF;
    data[1] := $BB;
    data[2] := $BF;
    n := WideCharToMultiByte(65001, 0, PWideChar(s), Length(s),
      PAnsiChar(@data[3]), Length(data) - 3, nil, nil);
    if n <= 0 then
      Exit;
    SetLength(data, 3 + n);
    ext := 'txt';
    filter := WideString('Text files (*.txt)'#0'*.txt'#0);
  end;
  s := AsWide('clip_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.') + ext;
  FillChar(fn, SizeOf(fn), 0);
  k := Length(s);
  if k > MAX_PATH - 1 then
    k := MAX_PATH - 1;
  Move(PWideChar(s)^, fn[0], k * SizeOf(WideChar));
  FillChar(ofn, SizeOf(ofn), 0);
  ofn.lStructSize := SizeOf(ofn);
  ofn.hwndOwner := owner;
  ofn.lpstrFile := @fn[0];
  ofn.nMaxFile := MAX_PATH;
  ofn.lpstrFilter := PWideChar(filter);
  ofn.lpstrTitle := PWideChar(AsWide(GetText(txtSaveTitle)));
  ofn.lpstrDefExt := PWideChar(ext);
  ofn.Flags := OFN_OVERWRITEPROMPT_MC or OFN_PATHMUSTEXIST_MC;
  if not GetSaveFileNameMcW(ofn) then
    Exit;
  hf := CreateFileW(@fn[0], GENERIC_WRITE, 0, nil, CREATE_ALWAYS,
    FILE_ATTRIBUTE_NORMAL, 0);
  if hf = INVALID_HANDLE_VALUE then
    Exit;
  fs := THandleStream.Create(hf);
  try
    fs.WriteBuffer(data[0], Length(data));
  finally
    fs.Free;
  end;
  CloseHandle(hf);
end;

procedure ViewUpdatePinBtn;
var
  i: Integer;
begin
  i := ViewSelEntry;
  if (i >= 0) and ClipHistory[i].Pinned then
    SetWindowTextW(hViewPinBtn, PWideChar(AsWide(GetText(txtBtnUnpin))))
  else
    SetWindowTextW(hViewPinBtn, PWideChar(AsWide(GetText(txtBtnPin))));
end;

procedure ViewLayout(w, h: Integer);
var
  bw: Integer;
begin
  MoveWindow(hViewEdit, 8, 8, w - 16, 24, True);
  MoveWindow(hViewList, 8, 40, w - 16, h - 88, True);
  bw := (w - 16 - 24) div 4;
  MoveWindow(GetDlgItem(hViewWnd, IDC_VIEW_PASTE), 8, h - 40, bw, 28, True);
  MoveWindow(GetDlgItem(hViewWnd, IDC_VIEW_PLAINB), 8 + bw + 8, h - 40, bw, 28, True);
  MoveWindow(hViewPinBtn, 8 + (bw + 8) * 2, h - 40, bw, 28, True);
  MoveWindow(GetDlgItem(hViewWnd, IDC_VIEW_CLOSE), 8 + (bw + 8) * 3, h - 40, bw, 28, True);
end;

function EntryMetaSuffix(const e: TClipEntry): WideString;
var
  ft: TFileTime;
  st: TSystemTime;
  tm: WideString;
begin
  Result := '';
  tm := '';
  if (e.StampUtc.dwLowDateTime <> 0) or (e.StampUtc.dwHighDateTime <> 0) then
    if FileTimeToLocalFileTime(e.StampUtc, ft) and FileTimeToSystemTime(ft, st) then
      tm := AsWide(Format('%.2d:%.2d', [st.wHour, st.wMinute]));
  if (tm <> '') or (e.Owner <> '') then
  begin
    Result := '   ·   ';
    if tm <> '' then
      Result := Result + tm;
    if e.Owner <> '' then
    begin
      if tm <> '' then
        Result := Result + ' · ';
      Result := Result + e.Owner;
    end;
  end;
end;

procedure ViewDrawItem(dis: PDRAWITEMSTRUCT);
var
  i, tx: Integer;
  hb: HBITMAP;
  memdc: HDC;
  hbOld: HGDIOBJ;
  rcT: TRect;
  lbl: WideString;
begin
  i := dis^.itemID;
  if (i < 0) or (i >= Length(ViewIdx)) then
    Exit;
  if (dis^.itemState and ODS_SELECTED) <> 0 then
  begin
    FillRect(dis^.hDC, dis^.rcItem, GetSysColorBrush(COLOR_HIGHLIGHT));
    SetTextColor(dis^.hDC, GetSysColor(COLOR_HIGHLIGHTTEXT));
  end
  else
  begin
    FillRect(dis^.hDC, dis^.rcItem, GetSysColorBrush(COLOR_WINDOW));
    SetTextColor(dis^.hDC, GetSysColor(COLOR_WINDOWTEXT));
  end;
  SetBkMode(dis^.hDC, TRANSPARENT);
  tx := dis^.rcItem.Left + 8;
  hb := ViewThumbFor(ViewIdx[i]);
  if hb <> 0 then
  begin
    memdc := CreateCompatibleDC(dis^.hDC);
    hbOld := SelectObject(memdc, hb);
    BitBlt(dis^.hDC, tx, dis^.rcItem.Top + (VIEW_ITEM_H - THUMB_SIZE) div 2,
      THUMB_SIZE, THUMB_SIZE, memdc, 0, 0, SRCCOPY);
    SelectObject(memdc, hbOld);
    DeleteDC(memdc);
    tx := tx + THUMB_SIZE + 8;
  end;
  lbl := ClipMenuLabel(ClipHistory[ViewIdx[i]]);
  if ClipHistory[ViewIdx[i]].Pinned then
    lbl := WideChar($2605) + ' ' + lbl;
  lbl := lbl + EntryMetaSuffix(ClipHistory[ViewIdx[i]]);
  rcT := dis^.rcItem;
  rcT.Left := tx;
  rcT.Right := rcT.Right - 8;
  DrawTextW(dis^.hDC, PWideChar(lbl), -1, rcT,
    DT_LEFT or DT_VCENTER or DT_SINGLELINE or DT_END_ELLIPSIS or DT_NOPREFIX);
end;

function ViewerWndProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  rc: TRect;
  sel: Integer;
  ws: WideString;
  ptScreen, ptC: TPoint;
  ctxMenu: HMENU;
  cmd: Integer;
begin
  Result := 0;
  case uMsg of
    WM_CREATE:
      begin
        hViewWnd := hWnd;
        hViewEdit := CreateWindowExW(WS_EX_CLIENTEDGE,
          PWideChar(WideString('EDIT')), nil,
          WS_CHILD or WS_VISIBLE or WS_TABSTOP or ES_AUTOHSCROLL,
          8, 8, 100, 24, hWnd, HMENU(IDC_VIEW_EDIT), HInstance, nil);
        ws := AsWide(GetText(txtSearchHint));
        SendMessageW(hViewEdit, EM_SETCUEBANNER, 1, PtrInt(Pointer(PWideChar(ws))));
        hViewList := CreateWindowExW(WS_EX_CLIENTEDGE,
          PWideChar(WideString('LISTBOX')), nil,
          WS_CHILD or WS_VISIBLE or WS_TABSTOP or WS_VSCROLL or
          LBS_OWNERDRAWFIXED or LBS_NODATA or LBS_NOTIFY or LBS_NOINTEGRALHEIGHT or
          LBS_WANTKEYBOARDINPUT,
          8, 40, 100, 100, hWnd, HMENU(IDC_VIEW_LIST), HInstance, nil);
        CreateWindowW(PWideChar(WideString('BUTTON')), PWideChar(AsWide(GetText(txtBtnPaste))),
          WS_CHILD or WS_VISIBLE or WS_TABSTOP or BS_DEFPUSHBUTTON,
          8, 100, 110, 28, hWnd, HMENU(IDC_VIEW_PASTE), HInstance, nil);
        CreateWindowW(PWideChar(WideString('BUTTON')), PWideChar(AsWide(GetText(txtBtnPlain))),
          WS_CHILD or WS_VISIBLE or WS_TABSTOP,
          126, 100, 110, 28, hWnd, HMENU(IDC_VIEW_PLAINB), HInstance, nil);
        hViewPinBtn := CreateWindowW(PWideChar(WideString('BUTTON')), PWideChar(AsWide(GetText(txtBtnPin))),
          WS_CHILD or WS_VISIBLE or WS_TABSTOP,
          244, 100, 110, 28, hWnd, HMENU(IDC_VIEW_PIN), HInstance, nil);
        CreateWindowW(PWideChar(WideString('BUTTON')), PWideChar(AsWide(GetText(txtBtnCancel))),
          WS_CHILD or WS_VISIBLE or WS_TABSTOP,
          362, 100, 110, 28, hWnd, HMENU(IDC_VIEW_CLOSE), HInstance, nil);
        SendMessageW(hViewEdit, WM_SETFONT, hPopupFont, 1);
        SendMessageW(hViewList, WM_SETFONT, hPopupFont, 1);
        SendMessageW(GetDlgItem(hWnd, IDC_VIEW_PASTE), WM_SETFONT, hPopupFont, 1);
        SendMessageW(GetDlgItem(hWnd, IDC_VIEW_PLAINB), WM_SETFONT, hPopupFont, 1);
        SendMessageW(hViewPinBtn, WM_SETFONT, hPopupFont, 1);
        SendMessageW(GetDlgItem(hWnd, IDC_VIEW_CLOSE), WM_SETFONT, hPopupFont, 1);
        ViewRebuildFilter;
        ViewUpdatePinBtn;
      end;
    WM_SIZE:
      ViewLayout(LoWord(lParam), HiWord(lParam));
    WM_MEASUREITEM:
      PMEASUREITEMSTRUCT(lParam)^.itemHeight := VIEW_ITEM_H;
    WM_DRAWITEM:
      ViewDrawItem(PDRAWITEMSTRUCT(lParam));
    VIEW_REFRESH:
      begin
        ViewRebuildFilter;
        ViewUpdatePinBtn;
      end;
    WM_VKEYTOITEM:
      if wParam = VK_DELETE then
      begin
        sel := ViewSelEntry;
        if sel >= 0 then
          RemoveClipEntry(sel);
        Result := -2;
      end
      else
        Result := -1;
    WM_CONTEXTMENU:
      begin
        ptScreen.X := SmallInt(Word(lParam));
        ptScreen.Y := SmallInt(Word(lParam shr 16));
        if (wParam = THandle(hViewList)) and (ptScreen.X <> -1) then
        begin
          ptC := ptScreen;
          ScreenToClient(hViewList, ptC);
          sel := SendMessageW(hViewList, LB_ITEMFROMPOINT, 0,
            MakeLParam(Word(ptC.X), Word(ptC.Y)));
          if HiWord(sel) = 0 then
          begin
            SendMessageW(hViewList, LB_SETCURSEL, sel, 0);
            ViewUpdatePinBtn;
          end;
          sel := ViewSelEntry;
          if sel < 0 then
            Exit;
          ctxMenu := CreatePopupMenu;
          AppendMenuW(ctxMenu, MF_STRING, IDM_CTX_PASTE,
            PWideChar(AsWide(GetText(txtBtnPaste))));
          AppendMenuW(ctxMenu, MF_STRING, IDM_CTX_PLAIN,
            PWideChar(AsWide(GetText(txtBtnPlain))));
          if ClipHistory[sel].Pinned then
            AppendMenuW(ctxMenu, MF_STRING, IDM_CTX_PIN,
              PWideChar(AsWide(GetText(txtBtnUnpin))))
          else
            AppendMenuW(ctxMenu, MF_STRING, IDM_CTX_PIN,
              PWideChar(AsWide(GetText(txtBtnPin))));
          AppendMenuW(ctxMenu, MF_STRING, IDM_CTX_SAVE,
            PWideChar(AsWide(GetText(txtSaveAs))));
          AppendMenuW(ctxMenu, MF_SEPARATOR, 0, nil);
          AppendMenuW(ctxMenu, MF_STRING, IDM_CTX_DEL,
            PWideChar(AsWide(GetText(txtBtnDelete))));
          cmd := TrackPopupMenuCmd(ctxMenu, TPM_RETURNCMD or TPM_RIGHTBUTTON,
            ptScreen.X, ptScreen.Y, 0, hWnd, nil);
          DestroyMenu(ctxMenu);
          case cmd of
            IDM_CTX_PASTE:
              begin
                DestroyWindow(hWnd);
                RestoreAndMaybePaste(sel);
              end;
            IDM_CTX_PLAIN:
              begin
                DestroyWindow(hWnd);
                RestoreAndMaybePastePlain(sel);
              end;
            IDM_CTX_PIN:
              begin
                TogglePin(sel);
                ViewRebuildFilter;
                ViewUpdatePinBtn;
              end;
            IDM_CTX_SAVE:
              EntrySaveAs(sel, hWnd);
            IDM_CTX_DEL:
              RemoveClipEntry(sel);
          end;
        end;
      end;
    WM_COMMAND:
      case wParam and $FFFF of
        IDC_VIEW_EDIT:
          if (wParam shr 16) = EN_CHANGE then
            ViewRebuildFilter;
        IDC_VIEW_LIST:
          if (wParam shr 16) = LBN_DBLCLK then
          begin
            sel := ViewSelEntry;
            if sel >= 0 then
            begin
              DestroyWindow(hWnd);
              RestoreAndMaybePaste(sel);
            end;
          end
          else if (wParam shr 16) = LBN_SELCHANGE then
            ViewUpdatePinBtn;
        IDC_VIEW_PASTE:
          begin
            sel := ViewSelEntry;
            if sel >= 0 then
            begin
              DestroyWindow(hWnd);
              RestoreAndMaybePaste(sel);
            end;
          end;
        IDC_VIEW_PLAINB:
          begin
            sel := ViewSelEntry;
            if sel >= 0 then
            begin
              DestroyWindow(hWnd);
              RestoreAndMaybePastePlain(sel);
            end;
          end;
        IDC_VIEW_PIN:
          begin
            sel := ViewSelEntry;
            if sel >= 0 then
            begin
              TogglePin(sel);
              ViewRebuildFilter;
              ViewUpdatePinBtn;
            end;
          end;
        IDC_VIEW_CLOSE:
          DestroyWindow(hWnd);
      end;
    WM_CLOSE:
      DestroyWindow(hWnd);
    WM_DESTROY:
      begin
        for sel := 0 to High(ViewThumbs) do
          if ViewThumbs[sel] <> 0 then
            DeleteObject(ViewThumbs[sel]);
        ViewThumbs := nil;
        ViewIdx := nil;
        hViewWnd := 0;
        hViewEdit := 0;
        hViewList := 0;
        hViewPinBtn := 0;
      end;
    else
      Result := DefWindowProcW(hWnd, uMsg, wParam, lParam);
  end;
end;

procedure ShowClipViewer;
var
  wc: WNDCLASSW;
  msg: TMsg;
  sw, sh: Integer;
begin
  if hViewWnd <> 0 then
  begin
    SetForegroundWindow(hViewWnd);
    Exit;
  end;
  if not ViewerClsReg then
  begin
    FillChar(wc, SizeOf(wc), 0);
    wc.lpfnWndProc := @ViewerWndProc;
    wc.hInstance := HInstance;
    wc.hCursor := LoadCursor(0, IDC_ARROW);
    wc.hbrBackground := COLOR_BTNFACE + 1;
    wc.lpszClassName := PWideChar(AsWide(ViewerClassName));
    if RegisterClassW(wc) <> 0 then
      ViewerClsReg := True
    else
      Exit;
  end;
  LastForeWnd := GetForegroundWindow;
  sw := GetSystemMetrics(SM_CXSCREEN);
  sh := GetSystemMetrics(SM_CYSCREEN);
  hViewWnd := CreateWindowExW(WS_EX_TOPMOST,
    PWideChar(AsWide(ViewerClassName)), PWideChar(AsWide(GetText(txtHistoryWnd))),
    WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_THICKFRAME,
    (sw - 560) div 2, (sh - 440) div 2, 560, 440,
    0, 0, HInstance, nil);
  if hViewWnd = 0 then
    Exit;
  ShowWindow(hViewWnd, SW_SHOW);
  UpdateWindow(hViewWnd);
  SetForegroundWindow(hViewWnd);
  SetFocus(hViewEdit);
  while hViewWnd <> 0 do
  begin
    if Integer(GetMessage(msg, 0, 0, 0)) <= 0 then
      Break;
    if not IsDialogMessageW(hViewWnd, msg) then
    begin
      TranslateMessage(msg);
      DispatchMessage(msg);
    end;
  end;
end;

procedure SaveHistory;
var
  fs: TFileStream;
  i, j, n: Integer;
  b: Byte;
  u, un: UTF8String;
begin
  try
    fs := TFileStream.Create(HistFilePath, fmCreate);
    try
      n := Length(ClipHistory);
      fs.WriteBuffer('MCL4', 4);
      fs.WriteDWord(4);
      fs.WriteDWord(n);
      for i := 0 to n - 1 do
      begin
        b := Byte(ClipHistory[i].Kind);
        fs.WriteBuffer(b, 1);
        if ClipHistory[i].Pinned then
          b := 1
        else
          b := 0;
        fs.WriteBuffer(b, 1);
        fs.WriteBuffer(ClipHistory[i].StampUtc, 8);
        u := AsUTF8(ClipHistory[i].Owner);
        fs.WriteDWord(Length(u));
        if Length(u) > 0 then
          fs.WriteBuffer(u[1], Length(u));
        u := AsUTF8(ClipHistory[i].Text);
        fs.WriteDWord(Length(u));
        if Length(u) > 0 then
          fs.WriteBuffer(u[1], Length(u));
        fs.WriteDWord(Length(ClipHistory[i].Fmts));
        for j := 0 to High(ClipHistory[i].Fmts) do
        begin
          fs.WriteDWord(ClipHistory[i].Fmts[j].Fmt);
          un := ClipHistory[i].Fmts[j].FmtName;
          fs.WriteDWord(Length(un));
          if Length(un) > 0 then
            fs.WriteBuffer(un[1], Length(un));
          fs.WriteDWord(Length(ClipHistory[i].Fmts[j].Data));
          if Length(ClipHistory[i].Fmts[j].Data) > 0 then
            fs.WriteBuffer(ClipHistory[i].Fmts[j].Data[0], Length(ClipHistory[i].Fmts[j].Data));
        end;
      end;
    finally
      fs.Free;
    end;
  except
  end;
end;

procedure PurgeOldHistory;
var
  i, j: Integer;
  nowFt: TFileTime;
  cut64, ft64: Int64;
  pruned: Boolean;
begin
  if ClipKeepDays <= 0 then
    Exit;
  GetSystemTimeAsFileTime(nowFt);
  cut64 := (Int64(nowFt.dwHighDateTime) shl 32) or nowFt.dwLowDateTime;
  cut64 := cut64 - Int64(ClipKeepDays) * 864000000000;
  pruned := False;
  i := 0;
  while i <= High(ClipHistory) do
  begin
    ft64 := (Int64(ClipHistory[i].StampUtc.dwHighDateTime) shl 32) or
      ClipHistory[i].StampUtc.dwLowDateTime;
    if (not ClipHistory[i].Pinned) and (ft64 <> 0) and (ft64 < cut64) then
    begin
      for j := i to High(ClipHistory) - 1 do
        ClipHistory[j] := ClipHistory[j + 1];
      SetLength(ClipHistory, Length(ClipHistory) - 1);
      pruned := True;
    end
    else
      Inc(i);
  end;
  if pruned and (hMainWnd <> 0) then
    SetTimer(hMainWnd, TIMER_HISTSAVE, 2000, nil);
end;

procedure LoadHistory;
var
  fs: TFileStream;
  magic: array[0..3] of AnsiChar;
  n, i, j, fc, ver: Integer;
  tlen, dlen, nlen: DWORD;
  b: Byte;
  u: UTF8String;
  e: TClipEntry;
begin
  if not FileExists(HistFilePath) then
    Exit;
  try
    fs := TFileStream.Create(HistFilePath, fmOpenRead or fmShareDenyWrite);
    try
      if fs.Size < 12 then
        Exit;
      fs.ReadBuffer(magic, 4);
      if magic = 'MCL2' then
        ver := 2
      else if magic = 'MCL3' then
        ver := 3
      else if magic = 'MCL4' then
        ver := 4
      else
        Exit;
      if DWORD(fs.ReadDWord) <> ver then
        Exit;
      n := Integer(fs.ReadDWord);
      if n > CLIP_HISTORY_TOTAL_MAX then
        n := CLIP_HISTORY_TOTAL_MAX;
      for i := 0 to n - 1 do
      begin
        if fs.Position + 9 > fs.Size then
          Break;
        fs.ReadBuffer(b, 1);
        if b > 2 then
          Break;
        e.Kind := TClipKind(b);
        e.Pinned := False;
        if ver >= 3 then
        begin
          fs.ReadBuffer(b, 1);
          e.Pinned := (b and 1) <> 0;
        end;
        FillChar(e.StampUtc, 8, 0);
        e.Owner := '';
        if ver >= 4 then
        begin
          fs.ReadBuffer(e.StampUtc, 8);
          nlen := fs.ReadDWord;
          if (nlen > 1024) or (fs.Position + nlen > fs.Size) then
            Break;
          SetLength(u, nlen);
          if nlen > 0 then
            fs.ReadBuffer(u[1], nlen);
          e.Owner := AsWide(u);
        end;
        e.Text := '';
        e.ImgW := 0;
        e.ImgH := 0;
        e.Time := 0;
        e.Fmts := nil;
        tlen := fs.ReadDWord;
        if (tlen > CLIP_MAX_BYTES) or (fs.Position + tlen > fs.Size) then
          Break;
        SetLength(u, tlen);
        if tlen > 0 then
          fs.ReadBuffer(u[1], tlen);
        e.Text := AsWide(u);
        fc := Integer(fs.ReadDWord);
        if (fc < 0) or (fc > 32) then
          Break;
        SetLength(e.Fmts, fc);
        for j := 0 to fc - 1 do
        begin
          if fs.Position + 12 > fs.Size then
            Break;
          e.Fmts[j].Fmt := fs.ReadDWord;
          nlen := fs.ReadDWord;
          if (nlen > 256) or (fs.Position + nlen > fs.Size) then
            Break;
          SetLength(u, nlen);
          if nlen > 0 then
            fs.ReadBuffer(u[1], nlen);
          e.Fmts[j].FmtName := u;
          dlen := fs.ReadDWord;
          if (dlen > CLIP_MAX_BYTES) or (fs.Position + dlen > fs.Size) then
            Break;
          SetLength(e.Fmts[j].Data, dlen);
          if dlen > 0 then
            fs.ReadBuffer(e.Fmts[j].Data[0], dlen);
        end;
        if e.Kind = ckImage then
          EntryCalcImgSize(e);
        SetLength(ClipHistory, Length(ClipHistory) + 1);
        ClipHistory[High(ClipHistory)] := e;
      end;
    finally
      fs.Free;
    end;
    PurgeOldHistory;
  except
  end;
end;

{ ==================== Text grab (Textify) ==================== }

function ChildIdIsSelf(const vt: OleVariant): Boolean;
begin
  try
    Result := Integer(vt) = CHILDID_SELF;
  except
    Result := False;
  end;
end;

function AccTextOf(acc: IAccessible; const vt: OleVariant): WideString;
var
  name, value, descr: WideString;
  roleVar, selfVar: OleVariant;
  role: Integer;
begin
  Result := '';
  name := '';
  value := '';
  descr := '';
  if acc.get_accName(vt, name) = S_OK then
    Result := name;
  if (acc.get_accValue(vt, value) = S_OK) and (value <> '') and (value <> name) then
  begin
    if Result <> '' then
      Result := Result + ' ';
    Result := Result + value;
  end;
  role := -1;
  selfVar := CHILDID_SELF;
  if acc.get_accRole(selfVar, roleVar) = S_OK then
    try
      role := Integer(roleVar);
    except
      role := -1;
    end;
  if role <> ROLE_SYSTEM_TITLEBAR then
  begin
    if (acc.get_accDescription(vt, descr) = S_OK) and (descr <> '') and
       (descr <> name) and (descr <> value) then
    begin
      if Result <> '' then
        Result := Result + ' ';
      Result := Result + descr;
    end;
  end;
  Result := TrimWide(Result);
end;

function GrabTextMSAA(pt: TPoint): WideString;
var
  acc, accParent: IAccessible;
  vt: OleVariant;
  h, h2: HWND;
  pid, pid2: DWORD;
  depth: Integer;
  s: WideString;
  pDisp: IDispatch;
begin
  Result := '';
  vt := Unassigned;
  if (AccessibleObjectFromPoint(pt, acc, vt) <> S_OK) or (acc = nil) then
    Exit;
  // Chromium sometimes returns the right element only on a second query
  acc := nil;
  vt := Unassigned;
  if (AccessibleObjectFromPoint(pt, acc, vt) <> S_OK) or (acc = nil) then
    Exit;
  pid := 0;
  if WindowFromAccessibleObject(acc, h) = S_OK then
    GetWindowThreadProcessId(h, pid);
  depth := 0;
  repeat
    s := AccTextOf(acc, vt);
    if s <> '' then
      Exit(s);
    if not ChildIdIsSelf(vt) then
      vt := CHILDID_SELF
    else
    begin
      if acc.get_accParent(pDisp) <> S_OK then
        Break;
      if pDisp = nil then
        Break;
      accParent := nil;
      if pDisp.QueryInterface(IAccessible, accParent) <> S_OK then
        Break;
      if WindowFromAccessibleObject(accParent, h2) <> S_OK then
        Break;
      GetWindowThreadProcessId(h2, pid2);
      if (pid <> 0) and (pid2 <> pid) then
        Break;
      acc := accParent;
      vt := CHILDID_SELF;
    end;
    Inc(depth);
  until depth >= 8;
end;

function UiaPropStr(el: IUIAutomationElement; propId: Integer): WideString;
var
  v: OleVariant;
begin
  Result := '';
  v := Unassigned;
  if el.GetCurrentPropertyValue(propId, v) = S_OK then
    try
      Result := TrimWide(WideString(v));
    except
      Result := '';
    end;
end;

function UiaPropInt(el: IUIAutomationElement; propId: Integer): Integer;
var
  v: OleVariant;
begin
  Result := 0;
  v := Unassigned;
  if el.GetCurrentPropertyValue(propId, v) = S_OK then
    try
      Result := Integer(v);
    except
      Result := 0;
    end;
end;

function UiaElText(el: IUIAutomationElement): WideString;
var
  name, value: WideString;
begin
  name := UiaPropStr(el, UIA_NamePropertyId);
  value := UiaPropStr(el, UIA_ValueValuePropertyId);
  Result := name;
  if (value <> '') and (value <> name) then
  begin
    if Result <> '' then
      Result := Result + ' ';
    Result := Result + value;
  end;
  if Result = '' then
  begin
    name := UiaPropStr(el, UIA_LegacyIAccessibleNamePropertyId);
    value := UiaPropStr(el, UIA_LegacyIAccessibleValuePropertyId);
    Result := name;
    if (value <> '') and (value <> name) then
    begin
      if Result <> '' then
        Result := Result + ' ';
      Result := Result + value;
    end;
  end;
  Result := TrimWide(Result);
end;

function GrabTextUIA(pt: TPoint): WideString;
var
  uia: IUIAutomation;
  el, elParent: IUIAutomationElement;
  walker: IUIAutomationTreeWalker;
  pid, pid2, depth: Integer;
begin
  Result := '';
  if CoCreateInstance(CLSID_CUIAutomation, nil, CLSCTX_ALL,
     IUIAutomation, uia) <> S_OK then
    Exit;
  if (uia = nil) or (uia.ElementFromPoint(pt, el) <> S_OK) or (el = nil) then
    Exit;
  // Chromium/Electron builds the AX tree lazily: re-query after it wakes up
  Sleep(60);
  el := nil;
  if (uia.ElementFromPoint(pt, el) <> S_OK) or (el = nil) then
    Exit;
  pid := UiaPropInt(el, UIA_ProcessIdPropertyId);
  walker := nil;
  depth := 0;
  repeat
    Result := UiaElText(el);
    if Result <> '' then
      Exit;
    if (walker = nil) and (uia.get_RawViewWalker(walker) <> S_OK) then
      Break;
    if walker = nil then
      Break;
    elParent := nil;
    if walker.GetParentElement(el, elParent) <> S_OK then
      Break;
    if elParent = nil then
      Break;
    pid2 := UiaPropInt(elParent, UIA_ProcessIdPropertyId);
    if (pid <> 0) and (pid2 <> 0) and (pid2 <> pid) then
      Break;
    el := elParent;
    Inc(depth);
  until depth >= 8;
end;

function GrabTextFallback(pt: TPoint): WideString;
var
  h, hRoot: HWND;
  buf: array[0..4095] of WideChar;
  res: DWORD_PTR;
begin
  Result := '';
  h := WindowFromPoint(pt);
  if h = 0 then
    Exit;
  FillChar(buf, SizeOf(buf), 0);
  res := 0;
  if SendMessageTimeoutW(h, WM_GETTEXT, 4096, LPARAM(@buf[0]),
     SMTO_ABORTIFHUNG, 300, res) <> 0 then
    Result := PWideChar(@buf[0]);
  if Result = '' then
  begin
    FillChar(buf, SizeOf(buf), 0);
    if GetWindowTextW(h, buf, 4096) > 0 then
      Result := PWideChar(@buf[0]);
  end;
  if Result = '' then
  begin
    hRoot := GetAncestor(h, GA_ROOT);
    if (hRoot <> 0) and (hRoot <> h) then
    begin
      FillChar(buf, SizeOf(buf), 0);
      if GetWindowTextW(hRoot, buf, 4096) > 0 then
        Result := PWideChar(@buf[0]);
    end;
  end;
end;

{ --- OCR via Windows.Media.Ocr (WinRT) --- }

const
  IID_ISB_STATICS: TGUID = '{DF0385DB-672F-4A9D-806E-C2442F343E86}';
  IID_OCR_STATICS: TGUID = '{5BFFA85A-3384-3540-9940-699120D428A8}';
  IID_ASYNC_INFO: TGUID = '{00000036-0000-0000-C000-000000000046}';
  BITMAP_PF_BGRA8 = 87;

function WinRtFactory(const clsName: WideString; const iid: TGUID; out fac): HResult;
var
  hs: HSTR;
begin
  hs := nil;
  WindowsCreateString(PWideChar(clsName), UINT32(Length(clsName)), hs);
  Result := RoGetActivationFactory(hs, iid, fac);
  WindowsDeleteString(hs);
end;

function OcrEnsureEngine: Boolean;
var
  fac: IOcrEngineStatics;
  eng: IInspectable;
begin
  if not OcrChecked then
  begin
    OcrChecked := True;
    gOcrEngine := nil;
    if WinRtFactory('Windows.Media.Ocr.OcrEngine', IID_OCR_STATICS, fac) = S_OK then
      if (fac.TryCreateFromUserProfileLanguages(eng) = S_OK) and (eng <> nil) then
        gOcrEngine := IOcrEngine(eng);
  end;
  Result := gOcrEngine <> nil;
end;

function OcrPixelsToText(bits: PByte; w, h: Integer): WideString;
var
  sbFac: ISoftwareBitmapStatics;
  sb: IInspectable;
  op: IAsyncOperationOcr;
  ainfo: IAsyncInfo;
  res: IInspectable;
  ores: IOcrResult;
  nbuf: TNativeBuffer;
  bufIf: IBuffer;
  status, tries: Longint;
  hs: HSTR;
  slen: UINT32;
begin
  Result := '';
  EnterCriticalSection(OcrCs);
  try
    if WinRtFactory('Windows.Graphics.Imaging.SoftwareBitmap', IID_ISB_STATICS, sbFac) <> S_OK then
      Exit;
    nbuf := TNativeBuffer.Create(w * h * 4);
    Move(bits^, nbuf.DataPtr^, w * h * 4);
    bufIf := nbuf as IBuffer;
    bufIf.put_Length(w * h * 4);
    if sbFac.CreateCopyFromBuffer(bufIf, BITMAP_PF_BGRA8, w, h, sb) <> S_OK then
      Exit;
    if gOcrEngine.RecognizeAsync(sb, op) <> S_OK then
      Exit;
    ainfo := nil;
    op.QueryInterface(IID_ASYNC_INFO, ainfo);
    if ainfo = nil then
      Exit;
    tries := 0;
    status := 0;
    repeat
      ainfo.get_Status(status);
      if status <> 0 then
        Break;
      Sleep(50);
      Inc(tries);
    until tries > 200;
    if status <> 1 then
      Exit;
    if op.GetResults(res) <> S_OK then
      Exit;
    ores := IOcrResult(res);
    hs := nil;
    if ores.get_Text(hs) = S_OK then
      Result := WindowsGetStringRawBuffer(hs, slen);
  finally
    LeaveCriticalSection(OcrCs);
  end;
end;

function PngToBgra(const png: TBytes; out w, h: Integer): TBytes;
var
  stmIn: IStream;
  img: Pointer;
  hbm: HBITMAP;
  bm: BITMAP;
  bi: BITMAPINFO;
  sdc: HDC;
begin
  Result := nil;
  w := 0;
  h := 0;
  if (Length(png) = 0) or not EnsureGdiPlus then
    Exit;
  stmIn := StreamFromBytes(png);
  if stmIn = nil then
    Exit;
  img := nil;
  if GdipCreateBitmapFromStream(stmIn, img) <> 0 then
    Exit;
  hbm := 0;
  if GdipCreateHBITMAPFromBitmap(img, hbm, 0) = 0 then
  begin
    FillChar(bm, SizeOf(bm), 0);
    if (hbm <> 0) and (GetObjectW(hbm, SizeOf(bm), @bm) <> 0) then
    begin
      w := bm.bmWidth;
      h := bm.bmHeight;
      if (w > 0) and (h > 0) and (Int64(w) * h < 40000000) then
      begin
        SetLength(Result, w * h * 4);
        FillChar(bi.bmiHeader, SizeOf(bi.bmiHeader), 0);
        bi.bmiHeader.biSize := SizeOf(BITMAPINFOHEADER);
        bi.bmiHeader.biWidth := w;
        bi.bmiHeader.biHeight := -h;
        bi.bmiHeader.biPlanes := 1;
        bi.bmiHeader.biBitCount := 32;
        bi.bmiHeader.biCompression := BI_RGB;
        sdc := GetDC(0);
        if GetDIBits(sdc, hbm, 0, h, @Result[0], bi, DIB_RGB_COLORS) <> h then
          Result := nil;
        ReleaseDC(0, sdc);
      end;
    end;
    if hbm <> 0 then
      DeleteObject(hbm);
  end;
  GdipDisposeImage(img);
end;

function OcrIdxThread(param: Pointer): Longint;
var
  job: POcrIdxJob;
  w, h: Integer;
  px: TBytes;
begin
  Result := 0;
  job := POcrIdxJob(param);
  try
    RoInitialize(1);
    px := PngToBgra(job^.Png, w, h);
    if (Length(px) > 0) and OcrEnsureEngine then
      job^.Text := OcrPixelsToText(@px[0], w, h);
  except
  end;
  if not ((hMainWnd <> 0) and PostMessage(hMainWnd, WM_OCRIDX_DONE, 0, LPARAM(job))) then
    Dispose(job);
end;

procedure QueueOcrIndex(idx: Integer);
var
  job: POcrIdxJob;
  tid: DWORD;
begin
  if (idx < 0) or (idx > High(ClipHistory)) then
    Exit;
  if ClipHistory[idx].Kind <> ckImage then
    Exit;
  if InterlockedIncrement(OcrIdxPending) > 3 then
  begin
    InterlockedDecrement(OcrIdxPending);
    Exit;
  end;
  New(job);
  job^.Key := ClipHistory[idx].Time;
  job^.StampLo := ClipHistory[idx].StampUtc.dwLowDateTime;
  job^.StampHi := ClipHistory[idx].StampUtc.dwHighDateTime;
  job^.Png := EntryPngBytes(ClipHistory[idx]);
  job^.Text := '';
  if (Length(job^.Png) = 0) or
     (THandle(BeginThread(nil, 0, @OcrIdxThread, job, 0, tid)) = 0) then
  begin
    Dispose(job);
    InterlockedDecrement(OcrIdxPending);
  end;
end;

function JsonStrValue(const js, key: string): string;
var
  p, e: Integer;
begin
  Result := '';
  p := Pos('"' + key + '"', js);
  if p = 0 then
    Exit;
  p := Pos(':', js, p);
  if p = 0 then
    Exit;
  p := Pos('"', js, p);
  if p = 0 then
    Exit;
  e := Pos('"', js, p + 1);
  if e = 0 then
    Exit;
  Result := Copy(js, p + 1, e - p - 1);
end;

function VersionNewer(const tag, cur: string): Boolean;
var
  a, b: string;
  pa, pb, na, nb: Integer;
begin
  a := tag;
  b := cur;
  if (Length(a) > 0) and ((a[1] = 'v') or (a[1] = 'V')) then
    Delete(a, 1, 1);
  Result := False;
  while (a <> '') or (b <> '') do
  begin
    pa := Pos('.', a);
    pb := Pos('.', b);
    if pa = 0 then
      na := StrToIntDef(a, 0)
    else
      na := StrToIntDef(Copy(a, 1, pa - 1), 0);
    if pb = 0 then
      nb := StrToIntDef(b, 0)
    else
      nb := StrToIntDef(Copy(b, 1, pb - 1), 0);
    if na > nb then
      Exit(True)
    else if na < nb then
      Exit;
    if pa = 0 then
      a := ''
    else
      a := Copy(a, pa + 1, MaxInt);
    if pb = 0 then
      b := ''
    else
      b := Copy(b, pb + 1, MaxInt);
  end;
end;

function UpdThread(param: Pointer): Longint;
const
  IF_SECURE = $00800000;
  IF_RELOAD = $80000000;
  IF_NO_CACHE = $04000000;
var
  job: PUpdJob;
  hi, hu: Pointer;
  buf: array[0..8191] of AnsiChar;
  rd: DWORD;
  js: AnsiString;
  u: string;
begin
  Result := 0;
  job := PUpdJob(param);
  hi := nil;
  hu := nil;
  js := '';
  try
    hi := InternetOpenMcW(PWideChar(WideString('MemClip/' + APP_VERSION)),
      0, nil, nil, 0);
    if hi <> nil then
      hu := InternetOpenUrlMcW(hi, PWideChar(WideString(UPD_API_URL)), nil, 0,
        IF_SECURE or IF_RELOAD or IF_NO_CACHE, 0);
    if hu <> nil then
      repeat
        rd := 0;
        if not InternetReadFileMc(hu, @buf[0], SizeOf(buf), rd) then
          Break;
        if rd > 0 then
          js := js + Copy(PAnsiChar(@buf[0]), 1, rd);
      until (rd = 0) or (Length(js) > 1048576);
    job^.Ver := JsonStrValue(string(js), 'tag_name');
    u := JsonStrValue(string(js), 'html_url');
    job^.Url := WideString(u);
    job^.Ok := (job^.Ver <> '') and (u <> '');
  except
    job^.Ok := False;
  end;
  if hu <> nil then
    InternetCloseHandleMc(hu);
  if hi <> nil then
    InternetCloseHandleMc(hi);
  if (hMainWnd = 0) or not PostMessage(hMainWnd, WM_UPDATE_DONE, 0, LPARAM(job)) then
    Dispose(job);
end;

procedure CheckUpdates;
var
  job: PUpdJob;
  tid: DWORD;
begin
  if UpdateChecking then
    Exit;
  UpdateChecking := True;
  New(job);
  job^.Ok := False;
  job^.Ver := '';
  job^.Url := '';
  if THandle(BeginThread(nil, 0, @UpdThread, job, 0, tid)) = 0 then
  begin
    Dispose(job);
    UpdateChecking := False;
    QueueInfo(GetText(txtUpdateErr));
  end;
end;

{ ==================== Online radio (DirectShow) ==================== }

function RadioStationCount: Integer;
begin
  Result := Length(RadioNames);
end;

procedure RadioApplyVolume;
begin
  if gRadioPlayer <> nil then
    gRadioPlayer.SetVolume(RadioVolume / 100);
end;

procedure RadioStop;
begin
  if gRadioPlayer <> nil then
  begin
    gRadioPlayer.Stop;
    gRadioPlayer.Shutdown;
    gRadioPlayer := nil;
  end;
  RadioStation := -1;
end;

procedure RadioPlay(idx: Integer);
var
  hr: HRESULT;
begin
  if (idx < 0) or (idx >= RadioStationCount) then
    Exit;
  RadioStop;
  if hMfpDll = 0 then
  begin
    hMfpDll := LoadLibraryW('mfplay.dll');
    if hMfpDll <> 0 then
      Pointer(pfnMfpCreate) := GetProcAddress(hMfpDll, 'MFPCreateMediaPlayer');
  end;
  if not Assigned(pfnMfpCreate) then
  begin
    QueueInfo(GetText(txtRadioFail));
    Exit;
  end;
  hr := pfnMfpCreate(PWideChar(RadioUrls[idx]), True, 0, nil,
    hMainWnd, gRadioPlayer);
  if (hr = S_OK) and (gRadioPlayer <> nil) then
  begin
    RadioStation := idx;
    RadioApplyVolume;
    QueueInfo(Format(GetText(txtRadioOn), [AsUTF8(RadioNames[idx])]));
  end
  else
    QueueInfo(GetText(txtRadioFail));
end;

procedure RadioVolStep(delta: Integer);
begin
  RadioVolume := RadioVolume + delta;
  if RadioVolume < 0 then
    RadioVolume := 0;
  if RadioVolume > 100 then
    RadioVolume := 100;
  RadioApplyVolume;
  SaveConfig;
end;

procedure LoadRadioCfg(const p: PWideChar);
var
  i, cnt, bar: Integer;
  buf: array[0..2047] of WideChar;
  s, key: WideString;
begin
  RadioEnabled := GetPrivateProfileIntW(PWideChar(WideString('radio')),
    PWideChar(WideString('enabled')), 0, p) <> 0;
  RadioVolume := GetPrivateProfileIntW(PWideChar(WideString('radio')),
    PWideChar(WideString('volume')), 70, p);
  if RadioVolume < 0 then
    RadioVolume := 0;
  if RadioVolume > 100 then
    RadioVolume := 100;
  if not RadioEnabled then
    Exit;
  SetLength(RadioNames, RADIO_BUILTIN);
  SetLength(RadioUrls, RADIO_BUILTIN);
  for i := 0 to RADIO_BUILTIN - 1 do
  begin
    RadioNames[i] := AsWide(RADIO_DEF_NAMES[i]);
    RadioUrls[i] := AsWide(RADIO_DEF_URLS[i]);
  end;
  cnt := RADIO_BUILTIN;
  for i := 1 to RADIO_MAX do
  begin
    key := AsWide('station' + IntToStr(i));
    GetPrivateProfileStringW(PWideChar(WideString('radio')),
      PWideChar(key), nil, @buf[0], SizeOf(buf) div 2, p);
    s := WideString(PWideChar(@buf[0]));
    if s = '' then
      Continue;
    bar := Pos('|', s);
    if (bar <= 1) or (bar >= Length(s)) then
      Continue;
    SetLength(RadioNames, cnt + 1);
    SetLength(RadioUrls, cnt + 1);
    RadioNames[cnt] := Copy(s, 1, bar - 1);
    RadioUrls[cnt] := Copy(s, bar + 1, Length(s) - bar);
    Inc(cnt);
  end;
end;

function UiaElementRect(pt: TPoint; out rc: TRect): Boolean;
var
  uia: IUIAutomation;
  el: IUIAutomationElement;
  v: OleVariant;
begin
  Result := False;
  if CoCreateInstance(CLSID_CUIAutomation, nil, CLSCTX_ALL, IUIAutomation, uia) <> S_OK then
    Exit;
  if (uia.ElementFromPoint(pt, el) <> S_OK) or (el = nil) then
    Exit;
  if el.GetCurrentPropertyValue(UIA_BoundingRectanglePropertyId, v) <> S_OK then
    Exit;
  if not VarIsArray(v) then
    Exit;
  rc.Left := Round(Double(v[0]));
  rc.Top := Round(Double(v[1]));
  rc.Right := rc.Left + Round(Double(v[2]));
  rc.Bottom := rc.Top + Round(Double(v[3]));
  Result := (rc.Right > rc.Left) and (rc.Bottom > rc.Top);
end;

function GrabTextOcr(pt: TPoint): WideString;
var
  rc: TRect;
  w, h: Integer;
  sdc, memdc: HDC;
  bmp, old: HBITMAP;
  bi: BITMAPINFO;
  pb: Pointer;
begin
  Result := '';
  if not OcrEnsureEngine then
  begin
    QueueInfo(GetText(txtOcrNoPack));
    Exit;
  end;
  if not UiaElementRect(pt, rc) then
    if not GetWindowRect(WindowFromPoint(pt), rc) then
      Exit;
  w := rc.Right - rc.Left;
  h := rc.Bottom - rc.Top;
  if (w < 4) or (h < 4) then
    Exit;
  if w > 4000 then
    w := 4000;
  if h > 4000 then
    h := 4000;
  FillChar(bi, SizeOf(bi), 0);
  bi.bmiHeader.biSize := SizeOf(BITMAPINFOHEADER);
  bi.bmiHeader.biWidth := w;
  bi.bmiHeader.biHeight := -h;
  bi.bmiHeader.biPlanes := 1;
  bi.bmiHeader.biBitCount := 32;
  bi.bmiHeader.biCompression := BI_RGB;
  sdc := GetDC(0);
  memdc := CreateCompatibleDC(sdc);
  pb := nil;
  bmp := CreateDIBSection(sdc, bi, DIB_RGB_COLORS, pb, 0, 0);
  if (bmp = 0) or (pb = nil) then
  begin
    DeleteDC(memdc);
    ReleaseDC(0, sdc);
    Exit;
  end;
  old := SelectObject(memdc, bmp);
  BitBlt(memdc, 0, 0, w, h, sdc, rc.Left, rc.Top, SRCCOPY);
  SelectObject(memdc, old);
  Result := OcrPixelsToText(PByte(pb), w, h);
  DeleteObject(bmp);
  DeleteDC(memdc);
  ReleaseDC(0, sdc);
end;

function IsUrlEndChar(c: WideChar): Boolean;
begin
  Result := (c <= ' ') or (c = '"') or (c = '''') or (c = '<') or (c = '>');
end;

function IsUrlTailChar(c: WideChar): Boolean;
begin
  Result := (c = '.') or (c = ',') or (c = ';') or (c = '!') or (c = ':') or
            (c = '?') or (c = ')') or (c = ']') or (c = '}') or (c = '"') or (c = '''');
end;

function ExtractUrl(const s: WideString): WideString;
const
  SCHEMES: array[0..3] of string = ('https://', 'http://', 'ftp://', 'www.');
var
  i, st, en, posi: Integer;
  ls: WideString;
begin
  Result := '';
  ls := WideLowerCase(s);
  st := 0;
  for i := 0 to High(SCHEMES) do
  begin
    posi := Pos(SCHEMES[i], ls);
    if (posi > 0) and ((st = 0) or (posi < st)) then
      st := posi;
  end;
  if st = 0 then
    Exit;
  en := st;
  while (en <= Length(s)) and not IsUrlEndChar(s[en]) do
    Inc(en);
  Result := Copy(s, st, en - st);
  while (Result <> '') and IsUrlTailChar(Result[Length(Result)]) do
    SetLength(Result, Length(Result) - 1);
end;

{ --- Grab window: captured text, user selects what to copy --- }

function GrabEditProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
begin
  Result := 0;
  if uMsg = WM_KEYDOWN then
  begin
    if wParam = VK_RETURN then
    begin
      PostMessage(GetParent(hWnd), WM_COMMAND, IDC_GRAB_COPY, 0);
      Exit;
    end;
    if wParam = VK_ESCAPE then
    begin
      PostMessage(GetParent(hWnd), WM_COMMAND, IDC_GRAB_CANCEL, 0);
      Exit;
    end;
  end;
  Result := CallWindowProcW(WNDPROC(OldGrabEditProc), hWnd, uMsg, wParam, lParam);
end;

procedure GrabCopyAndClose(hWnd: HWND);
var
  a, b: DWORD;
  n: Integer;
  buf, sel: WideString;
begin
  a := 0;
  b := 0;
  SendMessageW(hGrabEdit, EM_GETSEL, WPARAM(@a), LPARAM(@b));
  n := SendMessageW(hGrabEdit, WM_GETTEXTLENGTH, 0, 0);
  SetLength(buf, n + 1);
  SendMessageW(hGrabEdit, WM_GETTEXT, n + 1, LPARAM(PWideChar(buf)));
  SetLength(buf, StrLen(PWideChar(buf)));
  if (b > a) and (b <= DWORD(Length(buf))) then
    sel := Copy(buf, a + 1, b - a)
  else
    sel := GrabOrigText;
  if sel = '' then
    Exit;
  SetClipboardText(sel);
  QueueInfo(Format(GetText(txtClipCopied), [AsUTF8(FirstLine(sel, 60))]));
  DestroyWindow(hWnd);
end;

function GrabWndProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  rc: TRect;
begin
  Result := 0;
  case uMsg of
    WM_CREATE:
      begin
        GetClientRect(hWnd, rc);
        hGrabEdit := CreateWindowExW(WS_EX_CLIENTEDGE, PWideChar(WideString('EDIT')), '',
          WS_CHILD or WS_VISIBLE or WS_TABSTOP or ES_MULTILINE or ES_AUTOVSCROLL or WS_VSCROLL,
          6, 6, rc.Right - 12, rc.Bottom - 46, hWnd, HMENU(IDC_GRAB_EDIT), HInstance, nil);
        SendMessageW(hGrabEdit, WM_SETFONT, DWORD(hPopupFont), 1);
        CreateWindowExW(0, PWideChar(WideString('BUTTON')), PWideChar(AsWide(GetText(txtBtnCopy))),
          WS_CHILD or WS_VISIBLE or WS_TABSTOP or BS_DEFPUSHBUTTON,
          rc.Right - 6 - 2 * GRAB_BTN_W - 8, rc.Bottom - GRAB_BTN_H - 8,
          GRAB_BTN_W, GRAB_BTN_H, hWnd, HMENU(IDC_GRAB_COPY), HInstance, nil);
        CreateWindowExW(0, PWideChar(WideString('BUTTON')), PWideChar(AsWide(GetText(txtBtnCancel))),
          WS_CHILD or WS_VISIBLE or WS_TABSTOP or BS_PUSHBUTTON,
          rc.Right - 6 - GRAB_BTN_W, rc.Bottom - GRAB_BTN_H - 8,
          GRAB_BTN_W, GRAB_BTN_H, hWnd, HMENU(IDC_GRAB_CANCEL), HInstance, nil);
        SendMessageW(GetDlgItem(hWnd, IDC_GRAB_COPY), WM_SETFONT, DWORD(hPopupFont), 1);
        SendMessageW(GetDlgItem(hWnd, IDC_GRAB_CANCEL), WM_SETFONT, DWORD(hPopupFont), 1);
        SendMessageW(hGrabEdit, EM_SETMARGINS, EC_LEFTMARGIN or EC_RIGHTMARGIN, (8 shl 16) or 8);
        OldGrabEditProc := SetWindowLongW(hGrabEdit, GWL_WNDPROC, LONG(@GrabEditProc));
      end;
    WM_SIZE:
      begin
        GetClientRect(hWnd, rc);
        MoveWindow(hGrabEdit, 6, 6, rc.Right - 12, rc.Bottom - 46, True);
        MoveWindow(GetDlgItem(hWnd, IDC_GRAB_COPY), rc.Right - 6 - 2 * GRAB_BTN_W - 8,
          rc.Bottom - GRAB_BTN_H - 8, GRAB_BTN_W, GRAB_BTN_H, True);
        MoveWindow(GetDlgItem(hWnd, IDC_GRAB_CANCEL), rc.Right - 6 - GRAB_BTN_W,
          rc.Bottom - GRAB_BTN_H - 8, GRAB_BTN_W, GRAB_BTN_H, True);
      end;
    WM_CTLCOLOREDIT:
      begin
        SetBkColor(HDC(wParam), RGB(255, 247, 234));
        Result := LRESULT(hGrabEditBrush);
      end;
    WM_CTLCOLORBTN:
      Result := LRESULT(hGrabBrush);
    WM_COMMAND:
      case wParam and $FFFF of
        IDC_GRAB_COPY: GrabCopyAndClose(hWnd);
        IDC_GRAB_CANCEL: DestroyWindow(hWnd);
      end;
    WM_CLOSE:
      DestroyWindow(hWnd);
    WM_DESTROY:
      begin
        hGrabWnd := 0;
        hGrabEdit := 0;
        PostThreadMessage(GetCurrentThreadId, WM_NULL, 0, 0);
      end;
    else
      Result := DefWindowProcW(hWnd, uMsg, wParam, lParam);
  end;
end;

function ToCrLf(const s: WideString): WideString;
var
  i: Integer;
begin
  Result := '';
  i := 1;
  while i <= Length(s) do
  begin
    if s[i] = WideChar(13) then
    begin
      Result := Result + WideChar(13) + WideChar(10);
      if (i < Length(s)) and (s[i + 1] = WideChar(10)) then
        Inc(i);
    end
    else if s[i] = WideChar(10) then
      Result := Result + WideChar(13) + WideChar(10)
    else
      Result := Result + s[i];
    Inc(i);
  end;
end;

procedure ShowGrabDialog(const txt: WideString);
var
  pt: TPoint;
  work: TRect;
  x, y: Integer;
  s: WideString;
  msg: TMsg;
begin
  if hGrabWnd <> 0 then
    Exit;
  s := ToCrLf(txt);
  GrabOrigText := s;
  s := WideChar(13) + WideChar(10) + s;
  GetCursorPos(pt);
  SystemParametersInfo(SPI_GETWORKAREA, 0, @work, 0);
  x := pt.x - GRAB_WIN_W div 2;
  y := pt.y + 14;
  if x < work.Left then
    x := work.Left;
  if x + GRAB_WIN_W > work.Right then
    x := work.Right - GRAB_WIN_W;
  if y + GRAB_WIN_H > work.Bottom then
    y := pt.y - GRAB_WIN_H - 14;
  if y < work.Top then
    y := work.Top;
  hGrabWnd := CreateWindowExW(WS_EX_TOPMOST or WS_EX_TOOLWINDOW,
    PWideChar(WideString(GrabClassName)), PWideChar(AsWide(GetText(txtGrabTitle))),
    WS_POPUP or WS_CAPTION or WS_SYSMENU or WS_THICKFRAME,
    x, y, GRAB_WIN_W, GRAB_WIN_H, 0, 0, HInstance, nil);
  if hGrabWnd = 0 then
    Exit;
  SetWindowTextW(hGrabEdit, PWideChar(s));
  SendMessageW(hGrabEdit, EM_SETSEL, 2, -1);
  ShowWindow(hGrabWnd, SW_SHOW);
  UpdateWindow(hGrabWnd);
  SetForegroundWindow(hGrabWnd);
  SetFocus(hGrabEdit);
  while hGrabWnd <> 0 do
  begin
    if Integer(GetMessage(msg, 0, 0, 0)) <= 0 then
      Break;
    if not IsDialogMessageW(hGrabWnd, msg) then
    begin
      TranslateMessage(msg);
      DispatchMessage(msg);
    end;
  end;
end;

procedure DoGrabAtCursor(mode: WPARAM);
var
  pt: TPoint;
  s, url: WideString;
  h: HWND;
begin
  GetCursorPos(pt);
  h := WindowFromPoint(pt);
  if (h = hMainWnd) or (h = hPopupWnd) or (h = hGrabWnd) then
    Exit;
  if mode = 3 then
  begin
    s := GrabTextOcr(pt);
    s := TrimWide(s);
    if s = '' then
      QueueInfo(GetText(txtOcrEmpty))
    else
      ShowGrabDialog(s);
    Exit;
  end;
  s := GrabTextUIA(pt);
  if s = '' then
    s := GrabTextMSAA(pt);
  if s = '' then
    s := GrabTextFallback(pt);
  s := TrimWide(s);
  if mode = 2 then
  begin
    url := ExtractUrl(s);
    if url <> '' then
    begin
      SetClipboardText(url);
      QueueInfo(Format(GetText(txtUrlCopied), [AsUTF8(url)]));
    end
    else
      QueueInfo(GetText(txtUrlNone));
    Exit;
  end;
  if s = '' then
    QueueInfo(GetText(txtGrabEmpty))
  else
    ShowGrabDialog(s);
end;

{ ==================== Screen snip ==================== }

function SnipSelRect: TRect;
begin
  if SnipAdjusting then
    Result := SnipSel
  else
  begin
    Result.Left := Min(SnipStart.X, SnipCur.X);
    Result.Top := Min(SnipStart.Y, SnipCur.Y);
    Result.Right := Max(SnipStart.X, SnipCur.X);
    Result.Bottom := Max(SnipStart.Y, SnipCur.Y);
  end;
end;

const
  SNIP_EDGE_M = 6;

function SnipHitEdge(const rc: TRect; x, y: Integer): Integer;
begin
  Result := 0;
  if (y >= rc.Top - SNIP_EDGE_M) and (y <= rc.Bottom + SNIP_EDGE_M) then
  begin
    if Abs(x - rc.Left) <= SNIP_EDGE_M then Result := Result or 1;
    if Abs(x - rc.Right) <= SNIP_EDGE_M then Result := Result or 4;
  end;
  if (x >= rc.Left - SNIP_EDGE_M) and (x <= rc.Right + SNIP_EDGE_M) then
  begin
    if Abs(y - rc.Top) <= SNIP_EDGE_M then Result := Result or 2;
    if Abs(y - rc.Bottom) <= SNIP_EDGE_M then Result := Result or 8;
  end;
end;

function SnipModeFromKeys: Integer;
begin
  if GetKeyState(VK_CONTROL) < 0 then
    Result := 1
  else if GetKeyState(VK_SHIFT) < 0 then
    Result := 2
  else if GetKeyState(VK_MENU) < 0 then
    Result := 0
  else
    Result := 3;
end;

procedure SnipApplyRgn(hWnd: HWND);
var
  vw, vh: Integer;
  rgn, hole: HRGN;
  rc: TRect;
begin
  vw := GetSystemMetrics(SM_CXVIRTUALSCREEN);
  vh := GetSystemMetrics(SM_CYVIRTUALSCREEN);
  rc := SnipSelRect;
  rgn := CreateRectRgn(0, 0, vw, vh);
  if (rc.Right - rc.Left > 4) and (rc.Bottom - rc.Top > 4) then
  begin
    hole := CreateRectRgn(rc.Left + 2, rc.Top + 2, rc.Right - 2, rc.Bottom - 2);
    CombineRgn(rgn, rgn, hole, RGN_DIFF);
    DeleteObject(hole);
  end;
  SetWindowRgn(hWnd, rgn, True);
  InvalidateRect(hWnd, nil, True);
end;

procedure SnipCommitBitmap(bmp: HBITMAP; w, h: Integer; doSave: Boolean);
var
  png: TBytes;
  img: Pointer;
  stmOut: IStream;
  hOut: HGLOBAL;
  dir, fn: WideString;
begin
  png := nil;
  if EnsureGdiPlus then
  begin
    img := nil;
    if GdipCreateBitmapFromHBITMAP(bmp, 0, img) = 0 then
    begin
      hOut := GlobalAlloc(GMEM_MOVEABLE, 65536);
      if (hOut <> 0) and (CreateStreamOnHGlobal(hOut, True, stmOut) = S_OK) then
      begin
        if GdipSaveImageToStream(img, stmOut, PNG_CLSID, nil) = 0 then
          png := StreamToBytes(stmOut);
        stmOut := nil;
      end
      else if hOut <> 0 then
        GlobalFree(hOut);
      if doSave then
      begin
        dir := AsWide(ExtractFilePath(ParamStr(0))) + 'screenshots';
        CreateDirectoryW(PWideChar(dir), nil);
        fn := dir + '\clip_' + AsWide(FormatDateTime('yyyymmdd_hhnnss', Now)) + '.png';
        if GdipSaveImageToFile(img, PWideChar(fn), PNG_CLSID, nil) = 0 then
          QueueInfo(Format(GetText(txtSnipSaved), [AsUTF8(fn)]));
      end;
      GdipDisposeImage(img);
    end;
  end;
  if OpenClipRetry then
  begin
    EmptyClipboard;
    if SetClipboardData(CF_BITMAP, bmp) = 0 then
      DeleteObject(bmp);
    if Length(png) > 0 then
      SetRegClipData('PNG', png);
    CloseClipboard;
    QueueInfo(Format(GetText(txtSnipCopied), [w, h]));
  end
  else
    DeleteObject(bmp);
end;

procedure SnipFinish(const rScr: TRect; mode: Integer);
var
  sdc, mdc: HDC;
  bmp: HBITMAP;
  old: HGDIOBJ;
  bi: TBitmapInfo;
  pb: Pointer;
  w, h: Integer;
  s: WideString;
begin
  w := rScr.Right - rScr.Left;
  h := rScr.Bottom - rScr.Top;
  if (w < 4) or (h < 4) then
    Exit;
  SnipLastScr := rScr;
  SnipLastOk := True;
  Sleep(120);
  sdc := GetDC(0);
  mdc := CreateCompatibleDC(sdc);
  FillChar(bi, SizeOf(bi), 0);
  bi.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
  bi.bmiHeader.biWidth := w;
  bi.bmiHeader.biHeight := -h;
  bi.bmiHeader.biPlanes := 1;
  bi.bmiHeader.biBitCount := 32;
  bi.bmiHeader.biCompression := BI_RGB;
  pb := nil;
  bmp := CreateDIBSection(sdc, bi, DIB_RGB_COLORS, pb, 0, 0);
  if bmp = 0 then
  begin
    DeleteDC(mdc);
    ReleaseDC(0, sdc);
    Exit;
  end;
  old := SelectObject(mdc, bmp);
  BitBlt(mdc, 0, 0, w, h, sdc, rScr.Left, rScr.Top, SRCCOPY);
  SelectObject(mdc, old);
  DeleteDC(mdc);
  ReleaseDC(0, sdc);
  if mode = 1 then
  begin
    s := OcrPixelsToText(pb, w, h);
    DeleteObject(bmp);
    if TrimWide(s) = '' then
      QueueInfo(GetText(txtOcrEmpty))
    else
      ShowGrabDialog(s);
    Exit;
  end;
  if mode = 3 then
  begin
    ShowSnipEditor(bmp, w, h);
    Exit;
  end;
  SnipCommitBitmap(bmp, w, h, mode = 2);
end;

function SnipWndProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  rc, rcText: TRect;
  ps: TPaintStruct;
  dc: HDC;
  sz: WideString;
  mode, i, dx, dy: Integer;
begin
  Result := 0;
  case uMsg of
    WM_ERASEBKGND:
      Result := 1;
    WM_SETCURSOR:
      begin
        SetCursor(LoadCursor(0, IDC_CROSS));
        Result := 1;
      end;
    WM_LBUTTONDOWN:
      begin
        rc.TopLeft.X := SmallInt(Word(lParam));
        rc.TopLeft.Y := SmallInt(Word(lParam shr 16));
        if SnipAdjusting then
        begin
          SnipEdge := SnipHitEdge(SnipSel, rc.Left, rc.Top);
          if SnipEdge <> 0 then
            SetCapture(hWnd)
          else if PtInRect(SnipSel, rc.TopLeft) then
          begin
            SnipMoving := True;
            SnipAnchor := rc.TopLeft;
            SetCapture(hWnd);
          end
          else
          begin
            SnipAdjusting := False;
            SnipDragging := True;
            SnipStart := rc.TopLeft;
            SnipCur := SnipStart;
            SetCapture(hWnd);
          end;
        end
        else
        begin
          SetCapture(hWnd);
          SnipDragging := True;
          SnipStart := rc.TopLeft;
          SnipCur := SnipStart;
        end;
        InvalidateRect(hWnd, nil, True);
      end;
    WM_MOUSEMOVE:
      begin
        rc.TopLeft.X := SmallInt(Word(lParam));
        rc.TopLeft.Y := SmallInt(Word(lParam shr 16));
        if SnipDragging then
        begin
          SnipCur := rc.TopLeft;
          SnipApplyRgn(hWnd);
        end
        else if SnipMoving then
        begin
          OffsetRect(SnipSel, rc.Left - SnipAnchor.X, rc.Top - SnipAnchor.Y);
          SnipAnchor := rc.TopLeft;
          SnipApplyRgn(hWnd);
        end
        else if SnipEdge <> 0 then
        begin
          if (SnipEdge and 1) <> 0 then
            SnipSel.Left := Min(rc.Left, SnipSel.Right - 4);
          if (SnipEdge and 4) <> 0 then
            SnipSel.Right := Max(rc.Left, SnipSel.Left + 4);
          if (SnipEdge and 2) <> 0 then
            SnipSel.Top := Min(rc.Top, SnipSel.Bottom - 4);
          if (SnipEdge and 8) <> 0 then
            SnipSel.Bottom := Max(rc.Top, SnipSel.Top + 4);
          SnipApplyRgn(hWnd);
        end;
      end;
    WM_LBUTTONUP:
      begin
        if SnipMoving or (SnipEdge <> 0) then
        begin
          SnipMoving := False;
          SnipEdge := 0;
          ReleaseCapture;
          InvalidateRect(hWnd, nil, True);
        end
        else if SnipDragging then
        begin
          ReleaseCapture;
          SnipDragging := False;
          SnipSel := SnipSelRect;
          if (SnipSel.Right - SnipSel.Left > 4) and
             (SnipSel.Bottom - SnipSel.Top > 4) then
          begin
            SnipAdjusting := True;
            SnipApplyRgn(hWnd);
          end
          else
            DestroyWindow(hWnd);
        end;
      end;
    WM_RBUTTONDOWN:
      DestroyWindow(hWnd);
    WM_KEYDOWN:
      if wParam = VK_ESCAPE then
        DestroyWindow(hWnd)
      else if (wParam = VK_RETURN) and SnipAdjusting then
      begin
        mode := SnipModeFromKeys;
        rc := SnipSel;
        OffsetRect(rc, SnipOrgX, SnipOrgY);
        DestroyWindow(hWnd);
        SnipFinish(rc, mode);
      end
      else if (wParam >= VK_LEFT) and (wParam <= VK_DOWN) then
      begin
        i := 1;
        if GetKeyState(VK_SHIFT) < 0 then
          i := 10;
        case wParam of
          VK_LEFT:  begin dx := -i; dy := 0; end;
          VK_RIGHT: begin dx := i;  dy := 0; end;
          VK_UP:    begin dx := 0;  dy := -i; end;
        else        begin dx := 0;  dy := i;  end;
        end;
        if SnipAdjusting then
        begin
          OffsetRect(SnipSel, dx, dy);
          SnipApplyRgn(hWnd);
        end
        else if SnipDragging then
        begin
          Inc(SnipCur.X, dx);
          Inc(SnipCur.Y, dy);
          SnipApplyRgn(hWnd);
        end;
      end;
    WM_PAINT:
      begin
        dc := BeginPaint(hWnd, ps);
        GetClientRect(hWnd, rc);
        FillRect(dc, rc, hSnipBrush);
        if SnipDragging or SnipAdjusting then
        begin
          rc := SnipSelRect;
          if (rc.Right - rc.Left > 4) and (rc.Bottom - rc.Top > 4) then
          begin
            FillRect(dc, rc, GetStockObject(WHITE_BRUSH));
            sz := AsWide(IntToStr(rc.Right - rc.Left) + ' x ' + IntToStr(rc.Bottom - rc.Top));
            SetTextColor(dc, RGB(255, 255, 255));
            SetBkMode(dc, TRANSPARENT);
            SelectObject(dc, hPopupFont);
            rcText := rc;
            if rcText.Top >= 22 then
            begin
              rcText.Bottom := rcText.Top - 4;
              rcText.Top := rcText.Bottom - 18;
            end
            else
            begin
              rcText.Top := rcText.Bottom + 4;
              rcText.Bottom := rcText.Top + 18;
            end;
            DrawTextW(dc, PWideChar(sz), -1, rcText,
              DT_LEFT or DT_SINGLELINE or DT_NOPREFIX);
          end;
          if SnipAdjusting then
          begin
            sz := AsWide(GetText(txtSnipHint2));
            SetTextColor(dc, RGB(255, 255, 255));
            SetBkMode(dc, TRANSPARENT);
            SelectObject(dc, hPopupFont);
            GetClientRect(hWnd, rcText);
            rcText.Top := 24;
            DrawTextW(dc, PWideChar(sz), -1, rcText,
              DT_CENTER or DT_SINGLELINE or DT_NOPREFIX);
          end;
        end
        else
        begin
          sz := AsWide(GetText(txtSnipHint));
          SetTextColor(dc, RGB(255, 255, 255));
          SetBkMode(dc, TRANSPARENT);
          SelectObject(dc, hPopupFont);
          rcText := rc;
          rcText.Top := 24;
          DrawTextW(dc, PWideChar(sz), -1, rcText,
            DT_CENTER or DT_SINGLELINE or DT_NOPREFIX);
        end;
        EndPaint(hWnd, ps);
      end;
    WM_DESTROY:
      hSnipWnd := 0;
  else
    Result := DefWindowProcW(hWnd, uMsg, wParam, lParam);
  end;
end;

procedure ShowSnip;
var
  wc: TWndClassW;
  vx, vy, vw, vh: Integer;
  msg: TMsg;
begin
  if hSnipWnd <> 0 then
    Exit;
  LastForeWnd := GetForegroundWindow;
  if not SnipClsReg then
  begin
    SnipClsReg := True;
    SnipClassName := 'MemClipSnip';
    FillChar(wc, SizeOf(wc), 0);
    wc.lpfnWndProc := @SnipWndProc;
    wc.hInstance := HInstance;
    wc.hCursor := LoadCursor(0, IDC_CROSS);
    wc.hbrBackground := 0;
    wc.lpszClassName := PWideChar(SnipClassName);
    RegisterClassW(wc);
  end;
  vx := GetSystemMetrics(SM_XVIRTUALSCREEN);
  vy := GetSystemMetrics(SM_YVIRTUALSCREEN);
  vw := GetSystemMetrics(SM_CXVIRTUALSCREEN);
  vh := GetSystemMetrics(SM_CYVIRTUALSCREEN);
  if (vw <= 0) or (vh <= 0) then
  begin
    vx := 0; vy := 0;
    vw := GetSystemMetrics(SM_CXSCREEN);
    vh := GetSystemMetrics(SM_CYSCREEN);
  end;
  SnipOrgX := vx;
  SnipOrgY := vy;
  SnipDragging := False;
  SnipAdjusting := False;
  SnipMoving := False;
  SnipEdge := 0;
  hSnipWnd := CreateWindowExW(WS_EX_TOPMOST or WS_EX_TOOLWINDOW or WS_EX_LAYERED,
    PWideChar(SnipClassName), PWideChar(AsWide(GetText(txtSnipTitle))),
    WS_POPUP, vx, vy, vw, vh, 0, 0, HInstance, nil);
  if hSnipWnd = 0 then
    Exit;
  SetLayeredWindowAttributes(hSnipWnd, 0, 150, LWA_ALPHA);
  ShowWindow(hSnipWnd, SW_SHOW);
  SetForegroundWindow(hSnipWnd);
  SetFocus(hSnipWnd);
  while IsWindow(hSnipWnd) and GetMessage(msg, 0, 0, 0) do
  begin
    TranslateMessage(msg);
    DispatchMessage(msg);
  end;
  if IsWindow(hSnipWnd) then
    DestroyWindow(hSnipWnd);
  hSnipWnd := 0;
end;

{ ==================== Screenshot annotation editor ==================== }
{ Alt при отпускании выделения: мини-редактор в духе Lightshot —
  карандаш/линия/стрелка/рамка/текст/размытие, палитра, Ctrl+Z,
  «Сбросить» возвращает исходник, «Копировать»/«Сохранить» коммитят. }

const
  IDC_ED_OK = 700;
  IDC_ED_SAVE = 701;
  IDC_ED_RESET = 702;
  IDC_ED_CANCEL = 703;
  IDC_ED_UNDO = 704;
  IDC_ED_INPUT = 705;
  IDC_ED_TOOLS = 710;   // 710..715 — инструменты
  IDC_ED_COLS = 720;    // 720..725 — цвета
  EDIT_TB_H = 36;       // высота панели инструментов
  EDIT_BTN_ROW = 40;    // кнопки снизу
  TOOL_COUNT = 6;
  COLOR_COUNT = 6;
  TOOL_BTN_W = 78;
  EDIT_FONT_PX = 18;    // размер текстового шейпа в px исходника
  EDIT_BLUR_SZ = 8;     // блок пикселизации
  BS_PUSHLIKE_ST = $00001000;

  EDIT_COLORS: array[0..COLOR_COUNT - 1] of COLORREF =
    ($001E1EE5, $000091F0, $001ECDF5,
     $0046AA37, $00E6732D, $00191919);
  TOOL_TEXTS: array[0..TOOL_COUNT - 1] of TTextId =
    (txtToolPen, txtToolLine, txtToolArrow,
     txtToolRect, txtToolText, txtToolBlur);

type
  TEditTool = (etPen, etLine, etArrow, etRect, etText, etBlur);
  TEditShape = record
    Tool: TEditTool;
    Color: COLORREF;
    A, B: TPoint;              // линия/стрелка/рамка/текст (коорд. исходника)
    Pts: array of TPoint;      // карандаш
    Text: WideString;          // текст
  end;
  TEditUndo = record
    Blur: Boolean;             // True — откатить снапшот битмапа
    Bmp: HBITMAP;
  end;

var
  hEdOk, hEdSave, hEdReset, hEdCancel, hEdUndo: HWND;
  hEdTool: array[0..TOOL_COUNT - 1] of HWND;
  hEdCol: array[0..COLOR_COUNT - 1] of HWND;
  hEditInput: HWND;
  OldEditInputProc: LONG;
  EditTool: TEditTool;
  EditColorIdx: Integer;
  EditShapes: array of TEditShape;
  EditUndoLog: array of TEditUndo;
  EditCur: TEditShape;
  EditHasCur: Boolean;
  EditTextAnchor: TPoint;
  EditOrig: HBITMAP;
  EditViewW, EditViewH: Integer;  // размеры области изображения на экране
  EditOffX: Integer;              // горизонтальный отступ (центрирование)

function EditCurColor: COLORREF;
begin
  Result := EDIT_COLORS[EditColorIdx];
end;

procedure EditPushUndoShape;
begin
  SetLength(EditUndoLog, Length(EditUndoLog) + 1);
  EditUndoLog[High(EditUndoLog)].Blur := False;
  EditUndoLog[High(EditUndoLog)].Bmp := 0;
end;

procedure EditAddShape(const s: TEditShape);
begin
  SetLength(EditShapes, Length(EditShapes) + 1);
  EditShapes[High(EditShapes)] := s;
  EditPushUndoShape;
end;

function EditCopyBmp(src: HBITMAP): HBITMAP;
var
  sdc, d1, d2: HDC;
  o1, o2: HGDIOBJ;
begin
  Result := 0;
  sdc := GetDC(0);
  Result := CreateCompatibleBitmap(sdc, EditW, EditH);
  if Result = 0 then
  begin
    ReleaseDC(0, sdc);
    Exit;
  end;
  d1 := CreateCompatibleDC(sdc);
  d2 := CreateCompatibleDC(sdc);
  o1 := SelectObject(d1, Result);
  o2 := SelectObject(d2, src);
  BitBlt(d1, 0, 0, EditW, EditH, d2, 0, 0, SRCCOPY);
  SelectObject(d1, o1);
  SelectObject(d2, o2);
  DeleteDC(d1);
  DeleteDC(d2);
  ReleaseDC(0, sdc);
end;

procedure EditApplyBlur(const r: TRect);
var
  sdc: HDC;
  bi: TBitmapInfo;
  buf: TBytes;
  x0, y0, x1, y1, bx, by, px, py, cnt: Integer;
  sr, sg, sb: LongWord;
  p: PCardinal;
  snap: HBITMAP;
begin
  x0 := Max(0, r.Left);
  y0 := Max(0, r.Top);
  x1 := Min(EditW, r.Right);
  y1 := Min(EditH, r.Bottom);
  if (x1 - x0 < 4) or (y1 - y0 < 4) then
    Exit;
  snap := EditCopyBmp(EditBmp);
  if snap = 0 then
    Exit;
  sdc := GetDC(0);
  FillChar(bi, SizeOf(bi), 0);
  bi.bmiHeader.biSize := SizeOf(TBitmapInfoHeader);
  bi.bmiHeader.biWidth := EditW;
  bi.bmiHeader.biHeight := -EditH;
  bi.bmiHeader.biPlanes := 1;
  bi.bmiHeader.biBitCount := 32;
  bi.bmiHeader.biCompression := BI_RGB;
  SetLength(buf, EditW * EditH * 4);
  if GetDIBits(sdc, EditBmp, 0, EditH, @buf[0], bi, DIB_RGB_COLORS) = EditH then
  begin
    by := y0;
    while by < y1 do
    begin
      bx := x0;
      while bx < x1 do
      begin
        sr := 0;
        sg := 0;
        sb := 0;
        cnt := 0;
        for py := by to Min(by + EDIT_BLUR_SZ, y1) - 1 do
          for px := bx to Min(bx + EDIT_BLUR_SZ, x1) - 1 do
          begin
            p := PCardinal(@buf[(py * EditW + px) * 4]);
            sb := sb + (p^ and $FF);
            sg := sg + ((p^ shr 8) and $FF);
            sr := sr + ((p^ shr 16) and $FF);
            Inc(cnt);
          end;
        if cnt > 0 then
        begin
          sb := sb div cnt;
          sg := sg div cnt;
          sr := sr div cnt;
          for py := by to Min(by + EDIT_BLUR_SZ, y1) - 1 do
            for px := bx to Min(bx + EDIT_BLUR_SZ, x1) - 1 do
            begin
              p := PCardinal(@buf[(py * EditW + px) * 4]);
              p^ := (p^ and $FF000000) or (sr shl 16) or (sg shl 8) or sb;
            end;
        end;
        Inc(bx, EDIT_BLUR_SZ);
      end;
      Inc(by, EDIT_BLUR_SZ);
    end;
    SetDIBits(sdc, EditBmp, 0, EditH, @buf[0], bi, DIB_RGB_COLORS);
    SetLength(EditUndoLog, Length(EditUndoLog) + 1);
    EditUndoLog[High(EditUndoLog)].Blur := True;
    EditUndoLog[High(EditUndoLog)].Bmp := snap;
  end
  else
    DeleteObject(snap);
  ReleaseDC(0, sdc);
end;

procedure EditDoUndo(hWnd: HWND);
begin
  if Length(EditUndoLog) = 0 then
    Exit;
  if EditUndoLog[High(EditUndoLog)].Blur then
  begin
    if EditBmp <> 0 then
      DeleteObject(EditBmp);
    EditBmp := EditUndoLog[High(EditUndoLog)].Bmp;
  end
  else
    SetLength(EditShapes, Length(EditShapes) - 1);
  SetLength(EditUndoLog, Length(EditUndoLog) - 1);
  InvalidateRect(hWnd, nil, False);
end;

procedure EditShapeDraw(dc: HDC; const s: TEditShape; scale: Double; offY: Integer);
var
  hp: HPEN;
  oldp, oldf: HGDIOBJ;
  i, x1, y1, x2, y2, fw: Integer;
  ang, len: Double;
  fnt: HFONT;
begin
  if s.Tool = etText then
  begin
    if s.Text = '' then
      Exit;
    fnt := CreateFontW(-Max(8, Round(EDIT_FONT_PX * scale)), 0, 0, 0,
      FW_BOLD, 0, 0, 0, DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
      CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, DEFAULT_PITCH or FF_DONTCARE,
      'Segoe UI');
    oldf := SelectObject(dc, fnt);
    SetBkMode(dc, TRANSPARENT);
    SetTextColor(dc, s.Color);
    TextOutW(dc, Round(s.A.X * scale), offY + Round(s.A.Y * scale),
      PWideChar(s.Text), Length(s.Text));
    SelectObject(dc, oldf);
    DeleteObject(fnt);
    Exit;
  end;
  fw := Max(2, Round(3 * scale));
  hp := CreatePen(PS_SOLID, fw, s.Color);
  oldp := SelectObject(dc, hp);
  case s.Tool of
    etPen:
      if Length(s.Pts) > 0 then
      begin
        MoveToEx(dc, Round(s.Pts[0].X * scale),
          offY + Round(s.Pts[0].Y * scale), nil);
        for i := 1 to High(s.Pts) do
          LineTo(dc, Round(s.Pts[i].X * scale),
            offY + Round(s.Pts[i].Y * scale));
      end;
    etLine, etArrow:
      begin
        x1 := Round(s.A.X * scale);
        y1 := offY + Round(s.A.Y * scale);
        x2 := Round(s.B.X * scale);
        y2 := offY + Round(s.B.Y * scale);
        MoveToEx(dc, x1, y1, nil);
        LineTo(dc, x2, y2);
        if s.Tool = etArrow then
        begin
          ang := ArcTan2(y2 - y1, x2 - x1);
          len := Max(12.0, Min(28.0,
            Sqrt(Sqr(Int64(x2 - x1)) + Sqr(Int64(y2 - y1))) / 3));
          MoveToEx(dc, x2, y2, nil);
          LineTo(dc, x2 - Round(len * Cos(ang - 0.45)),
            y2 - Round(len * Sin(ang - 0.45)));
          MoveToEx(dc, x2, y2, nil);
          LineTo(dc, x2 - Round(len * Cos(ang + 0.45)),
            y2 - Round(len * Sin(ang + 0.45)));
        end;
      end;
    etRect, etBlur:
      begin
        SelectObject(dc, GetStockObject(NULL_BRUSH));
        Rectangle(dc, Round(Min(s.A.X, s.B.X) * scale),
          offY + Round(Min(s.A.Y, s.B.Y) * scale),
          Round(Max(s.A.X, s.B.X) * scale),
          offY + Round(Max(s.A.Y, s.B.Y) * scale));
      end;
  end;
  SelectObject(dc, oldp);
  DeleteObject(hp);
end;

procedure EditRender(outBmp: HBITMAP; w, h: Integer);
var
  sdc, dc, srcdc: HDC;
  old, oldSrc: HGDIOBJ;
  i: Integer;
begin
  sdc := GetDC(0);
  srcdc := CreateCompatibleDC(sdc);
  dc := CreateCompatibleDC(sdc);
  oldSrc := SelectObject(srcdc, EditBmp);
  old := SelectObject(dc, outBmp);
  BitBlt(dc, 0, 0, w, h, srcdc, 0, 0, SRCCOPY);
  SelectObject(srcdc, oldSrc);
  for i := 0 to High(EditShapes) do
    EditShapeDraw(dc, EditShapes[i], 1.0, 0);
  SelectObject(dc, old);
  DeleteDC(dc);
  DeleteDC(srcdc);
  ReleaseDC(0, sdc);
end;

procedure EditCommit(doSave: Boolean);
var
  sdc, dc: HDC;
  outBmp: HBITMAP;
begin
  sdc := GetDC(0);
  dc := CreateCompatibleDC(sdc);
  outBmp := CreateCompatibleBitmap(sdc, EditW, EditH);
  ReleaseDC(0, sdc);
  DeleteDC(dc);
  if outBmp <> 0 then
  begin
    EditRender(outBmp, EditW, EditH);
    SnipCommitBitmap(outBmp, EditW, EditH, doSave);
  end;
end;

function EditPtToImg(x, y: Integer): TPoint;
begin
  Result.X := Round((x - EditOffX) / EditScale);
  Result.Y := Round((y - EDIT_TB_H) / EditScale);
  if Result.X < 0 then Result.X := 0;
  if Result.X >= EditW then Result.X := EditW - 1;
  if Result.Y < 0 then Result.Y := 0;
  if Result.Y >= EditH then Result.Y := EditH - 1;
end;

procedure EditCloseInput(commit: Boolean);
var
  ws: WideString;
  n: Integer;
  sh: TEditShape;
  inp: HWND;
begin
  if hEditInput = 0 then
    Exit;
  inp := hEditInput;
  if commit then
  begin
    n := GetWindowTextLengthW(inp);
    SetLength(ws, n);
    if n > 0 then
      GetWindowTextW(inp, PWideChar(ws), n + 1);
    if ws <> '' then
    begin
      FillChar(sh, SizeOf(sh), 0);
      sh.Tool := etText;
      sh.Color := EditCurColor;
      sh.A := EditTextAnchor;
      sh.Text := ws;
      EditAddShape(sh);
      InvalidateRect(hEditWnd, nil, False);
    end;
  end;
  hEditInput := 0;
  DestroyWindow(inp);
end;

function EditInputProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
begin
  if uMsg = WM_KEYDOWN then
  begin
    if wParam = VK_RETURN then
    begin
      EditCloseInput(True);
      Exit(0);
    end;
    if wParam = VK_ESCAPE then
    begin
      EditCloseInput(False);
      Exit(0);
    end;
  end;
  Result := CallWindowProcW(WNDPROC(OldEditInputProc), hWnd, uMsg, wParam, lParam);
end;

procedure EditOpenTextInput(hWnd: HWND; imgPt: TPoint);
var
  x, y: Integer;
begin
  EditCloseInput(True);
  EditTextAnchor := imgPt;
  x := EditOffX + Round(imgPt.X * EditScale);
  y := EDIT_TB_H + Round(imgPt.Y * EditScale);
  hEditInput := CreateWindowExW(WS_EX_CLIENTEDGE, PWideChar(WideString('EDIT')), '',
    WS_CHILD or WS_VISIBLE or ES_AUTOHSCROLL,
    x, y, 180, 26, hWnd, HMENU(IDC_ED_INPUT), HInstance, nil);
  if hEditInput = 0 then
    Exit;
  SendMessage(hEditInput, WM_SETFONT, hPopupFont, 1);
  OldEditInputProc := SetWindowLongW(hEditInput, GWL_WNDPROC,
    LONG(@EditInputProc));
  SetFocus(hEditInput);
end;

procedure EditSelectTool(hWnd: HWND; idx: Integer);
var
  j: Integer;
begin
  if (idx < 0) or (idx >= TOOL_COUNT) then
    Exit;
  EditCloseInput(True);
  EditTool := TEditTool(idx);
  for j := 0 to TOOL_COUNT - 1 do
    SendMessageW(hEdTool[j], BM_SETCHECK, Ord(j = idx), 0);
end;

procedure EditReset(hWnd: HWND);
begin
  EditCloseInput(False);
  SetLength(EditShapes, 0);
  while Length(EditUndoLog) > 0 do
  begin
    if EditUndoLog[High(EditUndoLog)].Bmp <> 0 then
      DeleteObject(EditUndoLog[High(EditUndoLog)].Bmp);
    SetLength(EditUndoLog, Length(EditUndoLog) - 1);
  end;
  if (EditBmp <> 0) and (EditOrig <> 0) then
  begin
    DeleteObject(EditBmp);
    EditBmp := EditCopyBmp(EditOrig);
  end;
  EditHasCur := False;
  InvalidateRect(hWnd, nil, False);
end;

function EditWndProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  rc, rcImg: TRect;
  ps: TPaintStruct;
  dc, mdc: HDC;
  old: HGDIOBJ;
  pt: TPoint;
  i, dw, dh, cid: Integer;
  dis: PDRAWITEMSTRUCT;
  br: HBRUSH;
  sh: TEditShape;
begin
  Result := 0;
  case uMsg of
    WM_CREATE:
      begin
        dw := EditViewW;
        dh := EditViewH;
        for i := 0 to TOOL_COUNT - 1 do
        begin
          hEdTool[i] := CreateWindowExW(0, PWideChar(WideString('BUTTON')),
            PWideChar(AsWide(GetText(TOOL_TEXTS[i]))),
            WS_CHILD or WS_VISIBLE or WS_TABSTOP or
            BS_PUSHLIKE_ST or BS_AUTOCHECKBOX,
            6 + i * (TOOL_BTN_W + 4), 4, TOOL_BTN_W, 26,
            hWnd, HMENU(IDC_ED_TOOLS + i), HInstance, nil);
          SendMessage(hEdTool[i], WM_SETFONT, hPopupFont, 1);
        end;
        for i := 0 to COLOR_COUNT - 1 do
        begin
          hEdCol[i] := CreateWindowExW(0, PWideChar(WideString('BUTTON')), '',
            WS_CHILD or WS_VISIBLE or BS_OWNERDRAW,
            6 + TOOL_COUNT * (TOOL_BTN_W + 4) + 10 + i * 28, 6, 24, 22,
            hWnd, HMENU(IDC_ED_COLS + i), HInstance, nil);
        end;
        hEdOk := CreateWindowExW(0, PWideChar(WideString('BUTTON')), PWideChar(AsWide(GetText(txtBtnCopy))),
          WS_CHILD or WS_VISIBLE or WS_TABSTOP or BS_PUSHBUTTON,
          8, EDIT_TB_H + dh + 6, 96, 28, hWnd, HMENU(IDC_ED_OK), HInstance, nil);
        hEdSave := CreateWindowExW(0, PWideChar(WideString('BUTTON')), PWideChar(AsWide(GetText(txtBtnSave))),
          WS_CHILD or WS_VISIBLE or WS_TABSTOP or BS_PUSHBUTTON,
          110, EDIT_TB_H + dh + 6, 96, 28, hWnd, HMENU(IDC_ED_SAVE), HInstance, nil);
        hEdUndo := CreateWindowExW(0, PWideChar(WideString('BUTTON')), PWideChar(AsWide(GetText(txtBtnUndo))),
          WS_CHILD or WS_VISIBLE or WS_TABSTOP or BS_PUSHBUTTON,
          212, EDIT_TB_H + dh + 6, 96, 28, hWnd, HMENU(IDC_ED_UNDO), HInstance, nil);
        hEdReset := CreateWindowExW(0, PWideChar(WideString('BUTTON')), PWideChar(AsWide(GetText(txtBtnReset))),
          WS_CHILD or WS_VISIBLE or WS_TABSTOP or BS_PUSHBUTTON,
          314, EDIT_TB_H + dh + 6, 96, 28, hWnd, HMENU(IDC_ED_RESET), HInstance, nil);
        hEdCancel := CreateWindowExW(0, PWideChar(WideString('BUTTON')), PWideChar(AsWide(GetText(txtBtnCancel))),
          WS_CHILD or WS_VISIBLE or WS_TABSTOP or BS_PUSHBUTTON,
          dw - 104, EDIT_TB_H + dh + 6, 96, 28, hWnd, HMENU(IDC_ED_CANCEL), HInstance, nil);
        SendMessage(hEdOk, WM_SETFONT, hPopupFont, 1);
        SendMessage(hEdSave, WM_SETFONT, hPopupFont, 1);
        SendMessage(hEdUndo, WM_SETFONT, hPopupFont, 1);
        SendMessage(hEdReset, WM_SETFONT, hPopupFont, 1);
        SendMessage(hEdCancel, WM_SETFONT, hPopupFont, 1);
        EditSelectTool(hWnd, Ord(EditTool));
        hEditWnd := hWnd;
      end;
    WM_DRAWITEM:
      begin
        dis := PDRAWITEMSTRUCT(lParam);
        if (dis^.CtlType = ODT_BUTTON) and
           (dis^.CtlID >= IDC_ED_COLS) and
           (dis^.CtlID < IDC_ED_COLS + COLOR_COUNT) then
        begin
          cid := dis^.CtlID - IDC_ED_COLS;
          br := CreateSolidBrush(EDIT_COLORS[cid]);
          FillRect(dis^.hDC, dis^.rcItem, br);
          DeleteObject(br);
          if cid = EditColorIdx then
          begin
            br := GetStockObject(BLACK_BRUSH);
            FrameRect(dis^.hDC, dis^.rcItem, br);
            rc := dis^.rcItem;
            InflateRect(rc, -1, -1);
            FrameRect(dis^.hDC, rc, br);
          end
          else
            FrameRect(dis^.hDC, dis^.rcItem,
              GetSysColorBrush(COLOR_GRAYTEXT));
          if (dis^.itemState and ODS_SELECTED) <> 0 then
            DrawEdge(dis^.hDC, dis^.rcItem, EDGE_SUNKEN, BF_RECT);
        end
        else
          Result := DefWindowProcW(hWnd, uMsg, wParam, lParam);
      end;
    WM_PAINT:
      begin
        dc := BeginPaint(hWnd, ps);
        GetClientRect(hWnd, rc);
        dw := Round(EditW * EditScale);
        dh := EditViewH;
        mdc := CreateCompatibleDC(dc);
        old := SelectObject(mdc, EditBmp);
        SetStretchBltMode(dc, HALFTONE);
        SetBrushOrgEx(dc, 0, 0, nil);
        StretchBlt(dc, EditOffX, EDIT_TB_H, dw, dh, mdc, 0, 0, EditW, EditH, SRCCOPY);
        SelectObject(mdc, old);
        DeleteDC(mdc);
        SetViewportOrgEx(dc, EditOffX, 0, nil);
        for i := 0 to High(EditShapes) do
          EditShapeDraw(dc, EditShapes[i], EditScale, EDIT_TB_H);
        if EditHasCur then
          EditShapeDraw(dc, EditCur, EditScale, EDIT_TB_H);
        SetViewportOrgEx(dc, 0, 0, nil);
        rcImg := Rect(0, EDIT_TB_H, EditOffX, EDIT_TB_H + dh);
        if rcImg.Right > 0 then
          FillRect(dc, rcImg, GetSysColorBrush(COLOR_BTNFACE));
        rcImg := Rect(EditOffX + dw, EDIT_TB_H, rc.Right, EDIT_TB_H + dh);
        if rcImg.Left < rcImg.Right then
          FillRect(dc, rcImg, GetSysColorBrush(COLOR_BTNFACE));
        rcImg := Rect(0, EDIT_TB_H + dh, rc.Right, rc.Bottom);
        if rcImg.Top < rc.Bottom then
          FillRect(dc, rcImg, GetSysColorBrush(COLOR_BTNFACE));
        EndPaint(hWnd, ps);
      end;
    WM_LBUTTONDOWN:
      begin
        pt.X := SmallInt(LongInt(lParam and $FFFF));
        pt.Y := SmallInt(LongInt(lParam shr 16));
        if (pt.Y >= EDIT_TB_H) and
           (pt.Y < EDIT_TB_H + Round(EditH * EditScale)) and
           (pt.X >= EditOffX) and
           (pt.X < EditOffX + Round(EditW * EditScale)) then
        begin
          if EditTool = etText then
            EditOpenTextInput(hWnd, EditPtToImg(pt.X, pt.Y))
          else
          begin
            EditCloseInput(True);
            FillChar(EditCur, SizeOf(EditCur), 0);
            EditCur.Tool := EditTool;
            EditCur.Color := EditCurColor;
            EditCur.A := EditPtToImg(pt.X, pt.Y);
            EditCur.B := EditCur.A;
            if EditTool = etPen then
            begin
              SetLength(EditCur.Pts, 1);
              EditCur.Pts[0] := EditCur.A;
            end;
            EditHasCur := True;
            SetCapture(hWnd);
          end;
        end;
      end;
    WM_MOUSEMOVE:
      if EditHasCur then
      begin
        pt.X := SmallInt(LongInt(lParam and $FFFF));
        pt.Y := SmallInt(LongInt(lParam shr 16));
        pt := EditPtToImg(pt.X, pt.Y);
        if EditCur.Tool = etPen then
        begin
          if (Abs(pt.X - EditCur.Pts[High(EditCur.Pts)].X) > 1) or
             (Abs(pt.Y - EditCur.Pts[High(EditCur.Pts)].Y) > 1) then
          begin
            SetLength(EditCur.Pts, Length(EditCur.Pts) + 1);
            EditCur.Pts[High(EditCur.Pts)] := pt;
          end;
        end
        else
          EditCur.B := pt;
        InvalidateRect(hWnd, nil, False);
      end;
    WM_LBUTTONUP:
      if EditHasCur then
      begin
        EditHasCur := False;
        ReleaseCapture;
        pt.X := SmallInt(LongInt(lParam and $FFFF));
        pt.Y := SmallInt(LongInt(lParam shr 16));
        pt := EditPtToImg(pt.X, pt.Y);
        case EditCur.Tool of
          etPen:
            if Length(EditCur.Pts) > 1 then
              EditAddShape(EditCur);
          etLine, etArrow, etRect:
            begin
              EditCur.B := pt;
              if (Abs(EditCur.B.X - EditCur.A.X) > 3) or
                 (Abs(EditCur.B.Y - EditCur.A.Y) > 3) then
                EditAddShape(EditCur);
            end;
          etBlur:
            begin
              EditCur.B := pt;
              EditApplyBlur(Rect(Min(EditCur.A.X, EditCur.B.X),
                Min(EditCur.A.Y, EditCur.B.Y),
                Max(EditCur.A.X, EditCur.B.X),
                Max(EditCur.A.Y, EditCur.B.Y)));
            end;
        end;
        SetLength(EditCur.Pts, 0);
        InvalidateRect(hWnd, nil, False);
      end;
    WM_COMMAND:
      begin
        cid := wParam and $FFFF;
        if (cid >= IDC_ED_TOOLS) and (cid < IDC_ED_TOOLS + TOOL_COUNT) then
          EditSelectTool(hWnd, cid - IDC_ED_TOOLS)
        else if (cid >= IDC_ED_COLS) and (cid < IDC_ED_COLS + COLOR_COUNT) then
        begin
          EditColorIdx := cid - IDC_ED_COLS;
          for i := 0 to COLOR_COUNT - 1 do
            InvalidateRect(hEdCol[i], nil, False);
        end
        else if (cid = IDC_ED_INPUT) and ((wParam shr 16) = EN_KILLFOCUS) then
          EditCloseInput(True)
        else
          case cid of
            IDC_ED_OK:
              begin
                EditCloseInput(True);
                EditCommit(False);
                DestroyWindow(hWnd);
                if AutoPaste and (LastForeWnd <> 0) and IsWindow(LastForeWnd) then
                begin
                  SetForegroundWindow(LastForeWnd);
                  Sleep(60);
                  SendCtrlV;
                end;
              end;
            IDC_ED_SAVE:
              begin
                EditCloseInput(True);
                EditCommit(True);
                DestroyWindow(hWnd);
              end;
            IDC_ED_UNDO:
              EditDoUndo(hWnd);
            IDC_ED_RESET:
              EditReset(hWnd);
            IDC_ED_CANCEL:
              DestroyWindow(hWnd);
          end;
      end;
    WM_KEYDOWN:
      begin
        if wParam = VK_ESCAPE then
          DestroyWindow(hWnd)
        else if (wParam = Ord('Z')) and (GetKeyState(VK_CONTROL) < 0) then
          EditDoUndo(hWnd);
      end;
    WM_DESTROY:
      begin
        hEditWnd := 0;
        hEdOk := 0;
        hEdSave := 0;
        hEdReset := 0;
        hEdCancel := 0;
        hEdUndo := 0;
        hEditInput := 0;
        if EditBmp <> 0 then
        begin
          DeleteObject(EditBmp);
          EditBmp := 0;
        end;
        if EditOrig <> 0 then
        begin
          DeleteObject(EditOrig);
          EditOrig := 0;
        end;
        while Length(EditUndoLog) > 0 do
        begin
          if EditUndoLog[High(EditUndoLog)].Bmp <> 0 then
            DeleteObject(EditUndoLog[High(EditUndoLog)].Bmp);
          SetLength(EditUndoLog, Length(EditUndoLog) - 1);
        end;
        SetLength(EditShapes, 0);
        EditHasCur := False;
      end;
  else
    Result := DefWindowProcW(hWnd, uMsg, wParam, lParam);
  end;
end;

procedure ShowSnipEditor(bmp: HBITMAP; w, h: Integer);
var
  wc: TWndClassW;
  sw, sh, dw, dh, minW: Integer;
  msg: TMsg;
  rc: TRect;
  exStyle: DWORD;
begin
  if not EditClsReg then
  begin
    EditClsReg := True;
    EditClassName := 'MemClipEdit';
    FillChar(wc, SizeOf(wc), 0);
    wc.style := CS_HREDRAW or CS_VREDRAW;
    wc.lpfnWndProc := @EditWndProc;
    wc.hInstance := HInstance;
    wc.hCursor := LoadCursor(0, IDC_CROSS);
    wc.hbrBackground := HBRUSH(COLOR_BTNFACE + 1);
    wc.lpszClassName := PWideChar(EditClassName);
    RegisterClassW(wc);
  end;
  EditBmp := bmp;
  EditW := w;
  EditH := h;
  EditOrig := 0;
  SetLength(EditShapes, 0);
  SetLength(EditUndoLog, 0);
  EditHasCur := False;
  EditTool := etPen;
  EditColorIdx := 0;
  hEditInput := 0;
  sw := GetSystemMetrics(SM_CXSCREEN);
  sh := GetSystemMetrics(SM_CYSCREEN);
  EditScale := 1.0;
  if w > sw - 80 then
    EditScale := Min(EditScale, (sw - 80) / w);
  if h > sh - 200 then
    EditScale := Min(EditScale, (sh - 200) / h);
  if EditScale <= 0 then
    EditScale := 0.1;
  dw := Round(w * EditScale);
  dh := Round(h * EditScale);
  minW := 6 + TOOL_COUNT * (TOOL_BTN_W + 4) + 10 + COLOR_COUNT * 28 + 10;
  if dw < minW then
    dw := minW;
  EditViewW := dw;
  EditViewH := dh;
  EditOffX := (dw - Round(w * EditScale)) div 2;
  exStyle := WS_EX_TOPMOST or WS_EX_TOOLWINDOW;
  rc := Rect(0, 0, dw, EDIT_TB_H + dh + EDIT_BTN_ROW);
  AdjustWindowRectEx(rc, WS_POPUP or WS_CAPTION, False, exStyle);
  hEditWnd := CreateWindowExW(exStyle, PWideChar(EditClassName),
    PWideChar(AsWide(GetText(txtEditTitle))),
    WS_POPUP or WS_CAPTION or WS_VISIBLE,
    (sw - (rc.Right - rc.Left)) div 2,
    (sh - (rc.Bottom - rc.Top)) div 2,
    rc.Right - rc.Left, rc.Bottom - rc.Top, 0, 0, HInstance, nil);
  if hEditWnd = 0 then
  begin
    DeleteObject(bmp);
    Exit;
  end;
  EditOrig := EditCopyBmp(EditBmp);
  SetForegroundWindow(hEditWnd);
  SetFocus(hEditWnd);
  while IsWindow(hEditWnd) and GetMessage(msg, 0, 0, 0) do
    DispatchMessage(msg);
  if IsWindow(hEditWnd) then
    DestroyWindow(hEditWnd);
  hEditWnd := 0;
end;


procedure SnipWindow;
var
  r: TRect;
  w: HWND;
begin
  w := GetForegroundWindow;
  if GetWindowRect(w, r) then
  begin
    LastForeWnd := w;
    if GetKeyState(VK_SHIFT) < 0 then
      SnipFinish(r, 0)
    else
      SnipFinish(r, 3);
  end;
end;

procedure SnipAll;
var
  r: TRect;
begin
  LastForeWnd := GetForegroundWindow;
  r.Left := GetSystemMetrics(SM_XVIRTUALSCREEN);
  r.Top := GetSystemMetrics(SM_YVIRTUALSCREEN);
  r.Right := r.Left + GetSystemMetrics(SM_CXVIRTUALSCREEN);
  r.Bottom := r.Top + GetSystemMetrics(SM_CYVIRTUALSCREEN);
  if GetKeyState(VK_SHIFT) < 0 then
    SnipFinish(r, 0)
  else
    SnipFinish(r, 3);
end;

{ ==================== Mouse hook ==================== }

function MouseHookProc(nCode: Longint; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  handled: Boolean;
begin
  handled := False;
  if (nCode = HC_ACTION) and GrabEnabled and (hSnipWnd = 0) and (hEditWnd = 0) then
  begin
    if GetKeyState(VK_CONTROL) < 0 then
    begin
      if wParam = WM_MBUTTONDOWN then
      begin
        if GetKeyState(VK_MENU) < 0 then
          MouseGrabDown := 2
        else
          MouseGrabDown := 1;
        handled := True;
      end
      else if (wParam = WM_MBUTTONUP) and (MouseGrabDown in [1, 2]) then
      begin
        PostMessage(hMainWnd, WM_GRAB_CLICK, MouseGrabDown, 0);
        MouseGrabDown := 0;
        handled := True;
      end;
    end
    else if GetKeyState(VK_MENU) < 0 then
    begin
      if wParam = WM_MBUTTONDOWN then
      begin
        MouseGrabDown := 3;
        handled := True;
      end
      else if (wParam = WM_MBUTTONUP) and (MouseGrabDown = 3) then
      begin
        PostMessage(hMainWnd, WM_GRAB_CLICK, MouseGrabDown, 0);
        MouseGrabDown := 0;
        handled := True;
      end;
    end
    else
      MouseGrabDown := 0;
  end;
  if handled then
    Result := 1
  else
    Result := CallNextHookEx(hMouseHook, nCode, wParam, lParam);
end;

function MouseHookThread(p: Pointer): PtrInt;
var
  msg: TMsg;
begin
  PeekMessage(msg, 0, WM_USER, WM_USER, PM_NOREMOVE);
  SetEvent(hHookReady);
  hMouseHook := SetWindowsHookEx(WH_MOUSE_LL, @MouseHookProc, HInstance, 0);
  if hMouseHook <> 0 then
    while GetMessage(msg, 0, 0, 0) do
    begin
      if (msg.hwnd = 0) and (msg.message = WM_APP) then
        Break;
      TranslateMessage(msg);
      DispatchMessage(msg);
    end;
  if hMouseHook <> 0 then
  begin
    UnhookWindowsHookEx(hMouseHook);
    hMouseHook := 0;
  end;
  Result := 0;
end;

procedure StartMouseHook;
var
  tid: DWORD;
begin
  if hHookThread <> 0 then
    Exit;
  if hHookReady = 0 then
    hHookReady := CreateEvent(nil, LongBool(True), LongBool(False), nil);
  ResetEvent(hHookReady);
  hHookThread := BeginThread(nil, 0, @MouseHookThread, nil, 0, tid);
  hHookThreadId := tid;
  if hHookThread <> 0 then
    WaitForSingleObject(hHookReady, 5000);
end;

procedure StopMouseHook;
begin
  if hHookThread = 0 then
    Exit;
  PostThreadMessage(hHookThreadId, WM_APP, 0, 0);
  WaitForSingleObject(hHookThread, 5000);
  CloseHandle(hHookThread);
  hHookThread := 0;
  hHookThreadId := 0;
  MouseGrabDown := 0;
end;

procedure ToggleGrab;
begin
  GrabEnabled := not GrabEnabled;
  if GrabEnabled then
  begin
    RegisterHotKey(hMainWnd, HOTKEY_GRAB, HotkeyGrabMods or MOD_NOREPEAT, HotkeyGrabVk);
    RegisterHotKey(hMainWnd, HOTKEY_OCR, HotkeyOcrMods or MOD_NOREPEAT, HotkeyOcrVk);
    StartMouseHook;
    QueueInfo(GetText(txtGrabOn));
  end
  else
  begin
    UnregisterHotKey(hMainWnd, HOTKEY_GRAB);
    UnregisterHotKey(hMainWnd, HOTKEY_OCR);
    StopMouseHook;
    QueueInfo(GetText(txtGrabOff));
  end;
  SaveConfig;
end;

{ ==================== Hotkeys ==================== }

function VKText(vk: UINT): WideString;
begin
  case vk of
    Ord('0')..Ord('9'), Ord('A')..Ord('Z'):
      Result := WideChar(vk);
    VK_NUMPAD0..VK_NUMPAD9:
      Result := AsWide('Num ' + IntToStr(vk - VK_NUMPAD0));
    VK_F1..VK_F24:
      Result := AsWide('F' + IntToStr(vk - VK_F1 + 1));
    VK_SPACE: Result := 'Space';
    VK_RETURN: Result := 'Enter';
    VK_TAB: Result := 'Tab';
    VK_DELETE: Result := 'Delete';
    VK_INSERT: Result := 'Insert';
    VK_HOME: Result := 'Home';
    VK_END: Result := 'End';
    VK_PRIOR: Result := 'PgUp';
    VK_NEXT: Result := 'PgDn';
    VK_LEFT: Result := 'Left';
    VK_RIGHT: Result := 'Right';
    VK_UP: Result := 'Up';
    VK_DOWN: Result := 'Down';
    VK_MULTIPLY: Result := 'Num *';
    VK_ADD: Result := 'Num +';
    VK_SUBTRACT: Result := 'Num -';
    VK_DIVIDE: Result := 'Num /';
    VK_DECIMAL: Result := 'Num .';
    VK_OEM_1: Result := ';';
    VK_OEM_PLUS: Result := '=';
    VK_OEM_COMMA: Result := ',';
    VK_OEM_MINUS: Result := '-';
    VK_OEM_PERIOD: Result := '.';
    VK_OEM_2: Result := '/';
    VK_OEM_3: Result := '`';
    VK_OEM_4: Result := '[';
    VK_OEM_5: Result := '\';
    VK_OEM_6: Result := ']';
    VK_OEM_7: Result := '''';
  else
    Result := AsWide('VK ' + IntToStr(vk));
  end;
end;

function HotkeyText(mods, vk: UINT): WideString;
begin
  Result := '';
  if mods and MOD_CONTROL <> 0 then
    Result := Result + 'Ctrl+';
  if mods and MOD_ALT <> 0 then
    Result := Result + 'Alt+';
  if mods and MOD_SHIFT <> 0 then
    Result := Result + 'Shift+';
  if mods and MOD_WIN <> 0 then
    Result := Result + 'Win+';
  Result := Result + VKText(vk);
end;

procedure ApplyHotkeys;
begin
  if hMainWnd = 0 then
    Exit;
  UnregisterHotKey(hMainWnd, HOTKEY_CLIPMENU);
  UnregisterHotKey(hMainWnd, HOTKEY_GRAB);
  UnregisterHotKey(hMainWnd, HOTKEY_PLAIN);
  UnregisterHotKey(hMainWnd, HOTKEY_OCR);
  UnregisterHotKey(hMainWnd, HOTKEY_SNIP);
  UnregisterHotKey(hMainWnd, HOTKEY_SNIPWND);
  UnregisterHotKey(hMainWnd, HOTKEY_SNIPALL);
  UnregisterHotKey(hMainWnd, HOTKEY_SNIPLAST);
  RegisterHotKey(hMainWnd, HOTKEY_CLIPMENU, HotkeyClipMods or MOD_NOREPEAT, HotkeyClipVk);
  RegisterHotKey(hMainWnd, HOTKEY_PLAIN, HotkeyPlainMods or MOD_NOREPEAT, HotkeyPlainVk);
  RegisterHotKey(hMainWnd, HOTKEY_SNIP, HotkeySnipMods or MOD_NOREPEAT, HotkeySnipVk);
  RegisterHotKey(hMainWnd, HOTKEY_SNIPWND, HotkeySnipWndMods or MOD_NOREPEAT, HotkeySnipWndVk);
  RegisterHotKey(hMainWnd, HOTKEY_SNIPALL, HotkeySnipAllMods or MOD_NOREPEAT, HotkeySnipAllVk);
  RegisterHotKey(hMainWnd, HOTKEY_SNIPLAST, HotkeySnipLastMods or MOD_NOREPEAT, HotkeySnipLastVk);
  if GrabEnabled then
  begin
    RegisterHotKey(hMainWnd, HOTKEY_GRAB, HotkeyGrabMods or MOD_NOREPEAT, HotkeyGrabVk);
    RegisterHotKey(hMainWnd, HOTKEY_OCR, HotkeyOcrMods or MOD_NOREPEAT, HotkeyOcrVk);
  end;
end;

function IniPath: WideString;
begin
  Result := AsWide(ExtractFilePath(ParamStr(0)) + 'MemClip.ini');
end;

procedure LoadConfig;
var
  p: PWideChar;
  n: DWORD;
  buf: array[0..1023] of WideChar;
begin
  p := PWideChar(IniPath);
  FillChar(buf, SizeOf(buf), 0);
  HotkeyClipMods := GetPrivateProfileIntW(PWideChar(WideString('hotkeys')),
    PWideChar(WideString('clip_mods')), MOD_CONTROL or MOD_ALT, p);
  HotkeyClipVk := GetPrivateProfileIntW(PWideChar(WideString('hotkeys')),
    PWideChar(WideString('clip_vk')), Ord('V'), p);
  HotkeyGrabMods := GetPrivateProfileIntW(PWideChar(WideString('hotkeys')),
    PWideChar(WideString('grab_mods')), MOD_CONTROL or MOD_ALT, p);
  HotkeyGrabVk := GetPrivateProfileIntW(PWideChar(WideString('hotkeys')),
    PWideChar(WideString('grab_vk')), Ord('T'), p);
  HotkeyPlainMods := GetPrivateProfileIntW(PWideChar(WideString('hotkeys')),
    PWideChar(WideString('plain_mods')), MOD_CONTROL or MOD_ALT, p);
  HotkeyPlainVk := GetPrivateProfileIntW(PWideChar(WideString('hotkeys')),
    PWideChar(WideString('plain_vk')), Ord('B'), p);
  HotkeyOcrMods := GetPrivateProfileIntW(PWideChar(WideString('hotkeys')),
    PWideChar(WideString('ocr_mods')), MOD_CONTROL or MOD_ALT, p);
  HotkeyOcrVk := GetPrivateProfileIntW(PWideChar(WideString('hotkeys')),
    PWideChar(WideString('ocr_vk')), Ord('O'), p);
  HotkeySnipMods := GetPrivateProfileIntW(PWideChar(WideString('hotkeys')),
    PWideChar(WideString('snip_mods')), MOD_CONTROL or MOD_ALT, p);
  HotkeySnipVk := GetPrivateProfileIntW(PWideChar(WideString('hotkeys')),
    PWideChar(WideString('snip_vk')), Ord('S'), p);
  HotkeySnipWndMods := GetPrivateProfileIntW(PWideChar(WideString('hotkeys')),
    PWideChar(WideString('snipwnd_mods')), MOD_CONTROL or MOD_ALT, p);
  HotkeySnipWndVk := GetPrivateProfileIntW(PWideChar(WideString('hotkeys')),
    PWideChar(WideString('snipwnd_vk')), Ord('A'), p);
  HotkeySnipAllMods := GetPrivateProfileIntW(PWideChar(WideString('hotkeys')),
    PWideChar(WideString('snipall_mods')), MOD_CONTROL or MOD_ALT, p);
  HotkeySnipAllVk := GetPrivateProfileIntW(PWideChar(WideString('hotkeys')),
    PWideChar(WideString('snipall_vk')), Ord('F'), p);
  HotkeySnipLastMods := GetPrivateProfileIntW(PWideChar(WideString('hotkeys')),
    PWideChar(WideString('sniplast_mods')), MOD_CONTROL or MOD_ALT or MOD_SHIFT, p);
  HotkeySnipLastVk := GetPrivateProfileIntW(PWideChar(WideString('hotkeys')),
    PWideChar(WideString('sniplast_vk')), Ord('S'), p);
  n := DWORD(GetPrivateProfileIntW(PWideChar(WideString('main')),
    PWideChar(WideString('interval_min')), -1, p));
  if n <> DWORD(-1) then
  begin
    if n = 0 then
      Paused := True
    else
    begin
      Paused := False;
      CurrentInterval := n * 60000;
    end;
  end;
  ClipWatchEnabled := GetPrivateProfileIntW(PWideChar(WideString('main')),
    PWideChar(WideString('watch_clipboard')), 1, p) <> 0;
  AutoPaste := GetPrivateProfileIntW(PWideChar(WideString('main')),
    PWideChar(WideString('auto_paste')), 1, p) <> 0;
  GrabEnabled := GetPrivateProfileIntW(PWideChar(WideString('main')),
    PWideChar(WideString('grab_enabled')), 1, p) <> 0;
  MemFreeMinMb := GetPrivateProfileIntW(PWideChar(WideString('main')),
    PWideChar(WideString('mem_free_min_mb')), 0, p);
  n := GetPrivateProfileStringW(PWideChar(WideString('main')),
    PWideChar(WideString('lang')), nil, buf, Length(buf), p);
  if n > 0 then
    buf[n] := #0;
  LangSetting := LowerCase(String(PWideChar(@buf[0])));
  ClipMergeEnabled := GetPrivateProfileIntW(PWideChar(WideString('clipboard')),
    PWideChar(WideString('merge')), 0, p) <> 0;
  ClipHistoryMax := GetPrivateProfileIntW(PWideChar(WideString('clipboard')),
    PWideChar(WideString('max')), CLIP_HISTORY_MAX, p);
  if ClipHistoryMax < 5 then
    ClipHistoryMax := 5;
  if ClipHistoryMax > CLIP_HISTORY_TOTAL_MAX then
    ClipHistoryMax := CLIP_HISTORY_TOTAL_MAX;
  ClipKeepDays := GetPrivateProfileIntW(PWideChar(WideString('clipboard')),
    PWideChar(WideString('keep_days')), 0, p);
  if ClipKeepDays < 0 then
    ClipKeepDays := 0;
  if ClipKeepDays > 3650 then
    ClipKeepDays := 3650;
  n := GetPrivateProfileStringW(PWideChar(WideString('clipboard')),
    PWideChar(WideString('exclude')), nil, buf, Length(buf), p);
  if n > 0 then
    buf[n] := #0;
  ClipExcludeProcs := WideLowerCase(WideString(PWideChar(@buf[0])));
  LoadRadioCfg(p);
end;

procedure SaveConfig;
var
  p: PWideChar;
begin
  p := PWideChar(IniPath);
  WritePrivateProfileStringW(PWideChar(WideString('hotkeys')), PWideChar(WideString('clip_mods')),
    PWideChar(AsWide(IntToStr(HotkeyClipMods))), p);
  WritePrivateProfileStringW(PWideChar(WideString('hotkeys')), PWideChar(WideString('clip_vk')),
    PWideChar(AsWide(IntToStr(HotkeyClipVk))), p);
  WritePrivateProfileStringW(PWideChar(WideString('hotkeys')), PWideChar(WideString('grab_mods')),
    PWideChar(AsWide(IntToStr(HotkeyGrabMods))), p);
  WritePrivateProfileStringW(PWideChar(WideString('hotkeys')), PWideChar(WideString('grab_vk')),
    PWideChar(AsWide(IntToStr(HotkeyGrabVk))), p);
  WritePrivateProfileStringW(PWideChar(WideString('hotkeys')), PWideChar(WideString('plain_mods')),
    PWideChar(AsWide(IntToStr(HotkeyPlainMods))), p);
  WritePrivateProfileStringW(PWideChar(WideString('hotkeys')), PWideChar(WideString('plain_vk')),
    PWideChar(AsWide(IntToStr(HotkeyPlainVk))), p);
  WritePrivateProfileStringW(PWideChar(WideString('hotkeys')), PWideChar(WideString('ocr_mods')),
    PWideChar(AsWide(IntToStr(HotkeyOcrMods))), p);
  WritePrivateProfileStringW(PWideChar(WideString('hotkeys')), PWideChar(WideString('ocr_vk')),
    PWideChar(AsWide(IntToStr(HotkeyOcrVk))), p);
  WritePrivateProfileStringW(PWideChar(WideString('hotkeys')), PWideChar(WideString('snip_mods')),
    PWideChar(AsWide(IntToStr(HotkeySnipMods))), p);
  WritePrivateProfileStringW(PWideChar(WideString('hotkeys')), PWideChar(WideString('snip_vk')),
    PWideChar(AsWide(IntToStr(HotkeySnipVk))), p);
  WritePrivateProfileStringW(PWideChar(WideString('hotkeys')), PWideChar(WideString('snipwnd_mods')),
    PWideChar(AsWide(IntToStr(HotkeySnipWndMods))), p);
  WritePrivateProfileStringW(PWideChar(WideString('hotkeys')), PWideChar(WideString('snipwnd_vk')),
    PWideChar(AsWide(IntToStr(HotkeySnipWndVk))), p);
  WritePrivateProfileStringW(PWideChar(WideString('hotkeys')), PWideChar(WideString('snipall_mods')),
    PWideChar(AsWide(IntToStr(HotkeySnipAllMods))), p);
  WritePrivateProfileStringW(PWideChar(WideString('hotkeys')), PWideChar(WideString('snipall_vk')),
    PWideChar(AsWide(IntToStr(HotkeySnipAllVk))), p);
  WritePrivateProfileStringW(PWideChar(WideString('hotkeys')), PWideChar(WideString('sniplast_mods')),
    PWideChar(AsWide(IntToStr(HotkeySnipLastMods))), p);
  WritePrivateProfileStringW(PWideChar(WideString('hotkeys')), PWideChar(WideString('sniplast_vk')),
    PWideChar(AsWide(IntToStr(HotkeySnipLastVk))), p);
  if Paused then
    WritePrivateProfileStringW(PWideChar(WideString('main')), PWideChar(WideString('interval_min')),
      '0', p)
  else
    WritePrivateProfileStringW(PWideChar(WideString('main')), PWideChar(WideString('interval_min')),
      PWideChar(AsWide(IntToStr(CurrentInterval div 60000))), p);
  WritePrivateProfileStringW(PWideChar(WideString('main')), PWideChar(WideString('watch_clipboard')),
    PWideChar(AsWide(IntToStr(Ord(ClipWatchEnabled)))), p);
  WritePrivateProfileStringW(PWideChar(WideString('main')), PWideChar(WideString('auto_paste')),
    PWideChar(AsWide(IntToStr(Ord(AutoPaste)))), p);
  WritePrivateProfileStringW(PWideChar(WideString('main')), PWideChar(WideString('grab_enabled')),
    PWideChar(AsWide(IntToStr(Ord(GrabEnabled)))), p);
  WritePrivateProfileStringW(PWideChar(WideString('main')), PWideChar(WideString('mem_free_min_mb')),
    PWideChar(AsWide(IntToStr(MemFreeMinMb))), p);
  WritePrivateProfileStringW(PWideChar(WideString('main')), PWideChar(WideString('lang')),
    PWideChar(WideString(LangSetting)), p);
  if ClipMergeEnabled then
    WritePrivateProfileStringW(PWideChar(WideString('clipboard')), PWideChar(WideString('merge')),
      '1', p)
  else
    WritePrivateProfileStringW(PWideChar(WideString('clipboard')), PWideChar(WideString('merge')),
      '0', p);
  WritePrivateProfileStringW(PWideChar(WideString('clipboard')), PWideChar(WideString('exclude')),
    PWideChar(ClipExcludeProcs), p);
  WritePrivateProfileStringW(PWideChar(WideString('clipboard')), PWideChar(WideString('max')),
    PWideChar(AsWide(IntToStr(ClipHistoryMax))), p);
  WritePrivateProfileStringW(PWideChar(WideString('clipboard')), PWideChar(WideString('keep_days')),
    PWideChar(AsWide(IntToStr(ClipKeepDays))), p);
  WritePrivateProfileStringW(PWideChar(WideString('radio')), PWideChar(WideString('enabled')),
    PWideChar(AsWide(IntToStr(Ord(RadioEnabled)))), p);
  WritePrivateProfileStringW(PWideChar(WideString('radio')), PWideChar(WideString('volume')),
    PWideChar(AsWide(IntToStr(RadioVolume))), p);
end;

function HkWndProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  ps: TPaintStruct;
  dc: HDC;
  rc: TRect;
  m: UINT;
  t: WideString;
begin
  Result := 0;
  case uMsg of
    WM_KEYDOWN, WM_SYSKEYDOWN:
      case wParam of
        VK_CONTROL, VK_LCONTROL, VK_RCONTROL,
        VK_MENU, VK_LMENU, VK_RMENU,
        VK_SHIFT, VK_LSHIFT, VK_RSHIFT,
        VK_LWIN, VK_RWIN:
          ;
        VK_ESCAPE:
          DestroyWindow(hWnd);
      else
        m := 0;
        if GetKeyState(VK_CONTROL) < 0 then
          m := m or MOD_CONTROL;
        if GetKeyState(VK_MENU) < 0 then
          m := m or MOD_ALT;
        if GetKeyState(VK_SHIFT) < 0 then
          m := m or MOD_SHIFT;
        if (GetKeyState(VK_LWIN) < 0) or (GetKeyState(VK_RWIN) < 0) then
          m := m or MOD_WIN;
        if m = 0 then
        begin
          HkHint := True;
          InvalidateRect(hWnd, nil, True);
        end
        else
        begin
          HkOk := True;
          HkMods := m;
          HkVk := wParam;
          DestroyWindow(hWnd);
        end;
      end;
    WM_PAINT:
      begin
        dc := BeginPaint(hWnd, ps);
        try
          GetClientRect(hWnd, rc);
          t := HkPrompt;
          if HkHint then
            t := t + #13#10 + AsWide(GetText(txtHkNeedMod));
          SetBkMode(dc, TRANSPARENT);
          DrawTextW(dc, PWideChar(t), -1, rc,
            DT_CENTER or DT_VCENTER or DT_WORDBREAK or DT_NOPREFIX);
        finally
          EndPaint(hWnd, ps);
        end;
      end;
    WM_CLOSE:
      DestroyWindow(hWnd);
    WM_DESTROY:
      begin
        hHkWnd := 0;
        PostThreadMessage(GetCurrentThreadId, WM_NULL, 0, 0);
      end;
    else
      Result := DefWindowProcW(hWnd, uMsg, wParam, lParam);
  end;
end;

function ShowHotkeyDialog(const prompt: WideString; out mods, vk: UINT): Boolean;
var
  msg: TMsg;
  work: TRect;
  x, y: Integer;
begin
  Result := False;
  if hHkWnd <> 0 then
    Exit;
  HkPrompt := prompt;
  HkHint := False;
  HkOk := False;
  SystemParametersInfo(SPI_GETWORKAREA, 0, @work, 0);
  x := work.Left + (work.Right - work.Left - 380) div 2;
  y := work.Top + (work.Bottom - work.Top - 140) div 2;
  hHkWnd := CreateWindowExW(WS_EX_TOPMOST or WS_EX_TOOLWINDOW,
    PWideChar(WideString(HkClassName)), 'MemClip',
    WS_POPUP or WS_CAPTION or WS_SYSMENU, x, y, 380, 140, 0, 0, HInstance, nil);
  if hHkWnd = 0 then
    Exit;
  ShowWindow(hHkWnd, SW_SHOW);
  UpdateWindow(hHkWnd);
  SetForegroundWindow(hHkWnd);
  SetFocus(hHkWnd);
  while hHkWnd <> 0 do
  begin
    if Integer(GetMessage(msg, 0, 0, 0)) <= 0 then
      Break;
    TranslateMessage(msg);
    DispatchMessage(msg);
  end;
  if HkOk then
  begin
    mods := HkMods;
    vk := HkVk;
    Result := True;
  end;
end;

{ ==================== Tray / popup ==================== }

procedure SetTrayTip(const s: string);
var
  ws: WideString;
  len: Integer;
  maxChars: Integer;
begin
  if hMainWnd = 0 then
    Exit;
  ws := AsWide(s);
  maxChars := SizeOf(nid.szTip) div SizeOf(WideChar) - 1;
  len := Length(ws);
  if len > maxChars then
    len := maxChars;
  FillChar(nid.szTip[0], SizeOf(nid.szTip), 0);
  if len > 0 then
    MoveMemory(@nid.szTip[0], PWideChar(ws), len * SizeOf(WideChar));
  Shell_NotifyIconW(NIM_MODIFY, @nid);
end;

procedure UpdateTrayTip;
begin
  SetTrayTip(Format(GetText(txtTipFree), [LastFreeAfter]));
end;

procedure MemStatTick;
var
  ms: TMemoryStatusEx;
  tip: string;
begin
  FillChar(ms, SizeOf(ms), 0);
  ms.dwLength := SizeOf(ms);
  if not GlobalMemoryStatusEx(ms) then
    Exit;
  tip := Format(GetText(txtTipUsed), [ms.dwMemoryLoad]) + ' - ' +
    IntToStr(ms.ullAvailPhys div 1048576) + ' ' + GetText(txtMemoryUnit);
  if Paused then
    tip := tip + ' [' + GetText(txtManual) + ']';
  SetTrayTip(tip);
  if (MemFreeMinMb > 0) and (ms.ullAvailPhys < UInt64(MemFreeMinMb) * 1048576) and
     (GetTickCount64 - LastAutoClean > 60000) then
  begin
    LastAutoClean := GetTickCount64;
    ForceRun := True;
    SetEvent(hEvent);
  end;
  if ClipKeepDays > 0 then
    PurgeOldHistory;
end;

procedure DoShowPopup(const ws: WideString);
var
  work: TRect;
  x, y: Integer;
begin
  if hPopupWnd = 0 then
    Exit;
  PopupText := ws;
  InvalidateRect(hPopupWnd, nil, True);

  if SystemParametersInfo(SPI_GETWORKAREA, 0, @work, 0) then
  begin
    x := work.Right - POPUP_WIDTH - 10;
    y := work.Bottom - POPUP_HEIGHT - 10;
  end
  else
  begin
    x := 100;
    y := 100;
  end;

  SetWindowPos(hPopupWnd, HWND_TOPMOST, x, y, POPUP_WIDTH, POPUP_HEIGHT,
    SWP_SHOWWINDOW or SWP_NOACTIVATE);
  SetTimer(hPopupWnd, 1, 3000, nil);
end;

procedure ShowPopup(freeBefore, freeAfter: Integer);
var
  diff: Integer;
  sign: string;
begin
  diff := freeAfter - freeBefore;
  if diff >= 0 then
    sign := '+'
  else
    sign := '';
  DoShowPopup(AsWide(Format(GetText(txtPopupFormat),
    [freeBefore, freeAfter, GetText(txtMemoryUnit), sign, diff, GetText(txtMemoryUnit)])));
end;

procedure ShowNextInfo;
var
  i: Integer;
begin
  if Length(InfoQueue) = 0 then
    Exit;
  DoShowPopup(InfoQueue[0]);
  for i := 0 to High(InfoQueue) - 1 do
    InfoQueue[i] := InfoQueue[i + 1];
  InfoQueue[High(InfoQueue)] := '';
  SetLength(InfoQueue, Length(InfoQueue) - 1);
end;

procedure QueueInfoW(const msg: WideString);
var
  n: Integer;
begin
  n := Length(InfoQueue);
  SetLength(InfoQueue, n + 1);
  InfoQueue[n] := msg;
  if (hPopupWnd <> 0) and not IsWindowVisible(hPopupWnd) then
    ShowNextInfo;
end;

procedure QueueInfo(const msg: string);
begin
  QueueInfoW(AsWide(msg));
end;

procedure ShowInfo(const msg: string);
begin
  QueueInfo(msg);
end;

procedure InitTrayIcon;
var
  ws: WideString;
  len: Integer;
  maxChars: Integer;
begin
  FillChar(nid, SizeOf(nid), 0);
  nid.cbSize := SizeOf(TNotifyIconDataW);
  nid.hWnd := hMainWnd;
  nid.uID := 1;
  nid.uFlags := NIF_ICON or NIF_MESSAGE or NIF_TIP;
  nid.uCallbackMessage := WM_TRAYICON;
  if AppIcon = 0 then
    AppIcon := LoadIcon(0, IDI_APPLICATION);
  nid.hIcon := AppIcon;
  ws := AsWide(GetText(txtTipBase));
  maxChars := SizeOf(nid.szTip) div SizeOf(WideChar) - 1;
  len := Length(ws);
  if len > maxChars then
    len := maxChars;
  if len > 0 then
    MoveMemory(@nid.szTip[0], PWideChar(ws), len * SizeOf(WideChar));
  Shell_NotifyIconW(NIM_ADD, @nid);
end;

function WinDirPath: WideString;
var
  buf: array[0..MAX_PATH] of WideChar;
begin
  if GetWindowsDirectoryW(@buf[0], MAX_PATH) = 0 then
    buf[0] := #0;
  Result := PWideChar(@buf[0]);
end;

function DeleteCacheGlob(const dir, mask: WideString): Integer;
var
  fd: WIN32_FIND_DATAW;
  h: HANDLE;
begin
  Result := 0;
  h := FindFirstFileW(PWideChar(dir + mask), fd);
  if h <> INVALID_HANDLE_VALUE then
  begin
    repeat
      if (fd.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) = 0 then
        if not DeleteFileW(PWideChar(dir + PWideChar(@fd.cFileName[0]))) then
          Inc(Result);
    until not FindNextFileW(h, fd);
    Windows.FindClose(h);
  end;
end;

function DeleteShellCache(const localAppData, glob, extraFile: WideString): Integer;
var
  dir: WideString;
begin
  dir := localAppData + '\Microsoft\Windows\Explorer\';
  Result := DeleteCacheGlob(dir, glob);
  if (extraFile <> '') and FileExists(localAppData + '\' + extraFile) then
    if not DeleteFileW(PWideChar(localAppData + '\' + extraFile)) then
      Inc(Result);
end;

procedure ClearShellCache;
var
  hShell: HWND;
  pid, cch: DWORD;
  hProc, hTok, hPri: THandle;
  prof: array[0..MAX_PATH] of WideChar;
  profile, explorerExe: WideString;
  si: TStartupInfoW;
  pi: TProcessInformation;

  function DeleteBoth: Integer;
  var
    dir: WideString;
  begin
    dir := profile + '\AppData\Local';
    Result := DeleteShellCache(dir, 'iconcache*.db', 'IconCache.db') +
      DeleteShellCache(dir, 'thumbcache*.db', '');
  end;

begin
  hShell := GetShellWindow;
  if hShell = 0 then
  begin
    QueueInfo(GetText(txtIcoCacheFail));
    Exit;
  end;
  pid := 0;
  GetWindowThreadProcessId(hShell, @pid);
  hProc := OpenProcess(PROCESS_QUERY_INFORMATION or PROCESS_TERMINATE, False, pid);
  hTok := 0;
  hPri := 0;
  cch := MAX_PATH;
  if (hProc <> 0) and
     OpenProcessToken(hProc, TOKEN_QUERY or TOKEN_DUPLICATE or TOKEN_ASSIGN_PRIMARY, @hTok) and
     DuplicateTokenEx(hTok, TOKEN_ALL_ACCESS, nil, 2, 1, hPri) and
     GetUserProfileDirectoryW(hPri, @prof[0], cch) then
  begin
    profile := prof;
    if DeleteBoth = 0 then
      QueueInfo(GetText(txtIcoCacheDone))
    else if TerminateProcess(hProc, 0) then
    begin
      // shell was holding the files: restart Explorer as the interactive user
      Sleep(700);
      DeleteBoth;
      FillChar(si, SizeOf(si), 0);
      si.cb := SizeOf(si);
      FillChar(pi, SizeOf(pi), 0);
      explorerExe := WinDirPath + '\explorer.exe';
      if CreateProcessAsUserW(hPri, PWideChar(explorerExe),
         nil, nil, nil, False, 0, nil, nil, @si, @pi) then
      begin
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
        QueueInfo(GetText(txtIcoCacheDone));
      end
      else
        QueueInfo(GetText(txtIcoCacheFail));
    end
    else
      QueueInfo(GetText(txtIcoCacheFail));
  end
  else
    QueueInfo(GetText(txtIcoCacheFail));
  if hPri <> 0 then
    CloseHandle(hPri);
  if hTok <> 0 then
    CloseHandle(hTok);
  if hProc <> 0 then
    CloseHandle(hProc);
end;

procedure ShowTrayMenu(x, y: Integer);
var
  TrayMenu, IntervalMenu, HkMenu, LangMenu, RadioMenu: HMENU;
  uFlags: UINT;
  sManual, sClean, sAutostart, sInterval, sExit: string;
  sClipWatch, sClipAutoPaste, sGrabToggle: string;
  hk1, hk2, hk3, hk4, hk5, hk6, hk7, hk8: WideString;
  i: Integer;

  procedure AddIntervalItem(id: UINT; const labelText: string; intervalMs: DWORD);
  begin
    uFlags := MF_STRING;
    if CurrentInterval = intervalMs then
      uFlags := uFlags or MF_CHECKED;
    AppendMenuW(IntervalMenu, uFlags, id, PWideChar(AsWide(labelText)));
  end;

  procedure AddGroupHeader(id: TTextId);
  begin
    AppendMenuW(TrayMenu, MF_STRING or MF_GRAYED or MF_DISABLED, 0,
      PWideChar(AsWide('— ') + AsWide(GetText(id)) + AsWide(' —')));
  end;

begin
  sManual := GetText(txtManual);
  sClean := GetText(txtCleanNow);
  sAutostart := GetText(txtAutostart);
  sInterval := GetText(txtInterval);
  sExit := GetText(txtExit);
  sClipWatch := GetText(txtClipWatch);
  sClipAutoPaste := GetText(txtClipAutoPaste);
  sGrabToggle := GetText(txtGrabToggle);

  TrayMenu := CreatePopupMenu;
  IntervalMenu := CreatePopupMenu;
  HkMenu := CreatePopupMenu;
  LangMenu := CreatePopupMenu;

  { --- Память --- }
  AddGroupHeader(txtGrpMem);
  AppendMenuW(TrayMenu, MF_STRING, IDM_CLEANNOW, PWideChar(AsWide(sClean)));

  uFlags := MF_STRING;
  if Paused then
    uFlags := uFlags or MF_CHECKED;
  AppendMenuW(IntervalMenu, uFlags, IDM_MANUAL, PWideChar(AsWide(sManual)));
  AppendMenuW(IntervalMenu, MF_SEPARATOR, 0, nil);
  AddIntervalItem(IDM_INTERVAL_1M, GetIntervalLabel(1), 60000);
  AddIntervalItem(IDM_INTERVAL_5M, GetIntervalLabel(5), 300000);
  AddIntervalItem(IDM_INTERVAL_10M, GetIntervalLabel(10), 600000);
  AddIntervalItem(IDM_INTERVAL_30M, GetIntervalLabel(30), 1800000);
  AddIntervalItem(IDM_INTERVAL_60M, GetIntervalLabel(60), 3600000);
  AppendMenuW(TrayMenu, MF_POPUP, UINT(IntervalMenu), PWideChar(AsWide(sInterval)));

  AppendMenuW(TrayMenu, MF_SEPARATOR, 0, nil);

  { --- Буфер обмена --- }
  AddGroupHeader(txtGrpClip);
  AppendMenuW(TrayMenu, MF_STRING, IDM_HISTORY,
    PWideChar(AsWide(GetText(txtHistoryWnd)) + '   ' + HotkeyText(HotkeyClipMods, HotkeyClipVk)));

  uFlags := MF_STRING;
  if ClipWatchEnabled then
    uFlags := uFlags or MF_CHECKED;
  AppendMenuW(TrayMenu, uFlags, IDM_CLIPWATCH, PWideChar(AsWide(sClipWatch)));

  AppendMenuW(TrayMenu, MF_STRING, IDM_CLIPCLEAR, PWideChar(AsWide(GetText(txtClipClear))));

  uFlags := MF_STRING;
  if AutoPaste then
    uFlags := uFlags or MF_CHECKED;
  AppendMenuW(TrayMenu, uFlags, IDM_AUTOPASTE, PWideChar(AsWide(sClipAutoPaste)));

  uFlags := MF_STRING;
  if ClipMergeEnabled then
    uFlags := uFlags or MF_CHECKED;
  AppendMenuW(TrayMenu, uFlags, IDM_CLIPMERGE, PWideChar(AsWide(GetText(txtClipMerge))));

  AppendMenuW(TrayMenu, MF_SEPARATOR, 0, nil);

  { --- Захват --- }
  AddGroupHeader(txtGrpGrab);

  uFlags := MF_STRING;
  if GrabEnabled then
    uFlags := uFlags or MF_CHECKED;
  AppendMenuW(TrayMenu, uFlags, IDM_GRABTOGGLE, PWideChar(AsWide(sGrabToggle)));

  AppendMenuW(TrayMenu, MF_STRING, IDM_SNIP,
    PWideChar(AsWide(GetText(txtSnipTitle)) + '   ' + HotkeyText(HotkeySnipMods, HotkeySnipVk)));

  AppendMenuW(TrayMenu, MF_SEPARATOR, 0, nil);

  { --- Система --- }
  AddGroupHeader(txtGrpSys);
  AppendMenuW(TrayMenu, MF_STRING, IDM_ICONCACHE, PWideChar(AsWide(GetText(txtIconCache))));
  AppendMenuW(TrayMenu, MF_STRING, IDM_UPDATE, PWideChar(AsWide(GetText(txtUpdate))));
  RadioMenu := CreatePopupMenu;
  uFlags := MF_STRING;
  if RadioEnabled then
    uFlags := uFlags or MF_CHECKED;
  AppendMenuW(RadioMenu, uFlags, IDM_RADIO_EN, PWideChar(AsWide(GetText(txtRadioEnable))));
  if RadioEnabled then
  begin
    AppendMenuW(RadioMenu, MF_SEPARATOR, 0, nil);
    for i := 0 to RadioStationCount - 1 do
    begin
      uFlags := MF_STRING;
      if RadioStation = i then
        uFlags := uFlags or MF_CHECKED;
      AppendMenuW(RadioMenu, uFlags, IDM_RADIO_BASE + i, PWideChar(RadioNames[i]));
    end;
    AppendMenuW(RadioMenu, MF_SEPARATOR, 0, nil);
    AppendMenuW(RadioMenu, MF_STRING, IDM_RADIO_STOP, PWideChar(AsWide(GetText(txtRadioStop))));
    AppendMenuW(RadioMenu, MF_SEPARATOR, 0, nil);
    AppendMenuW(RadioMenu, MF_STRING, IDM_RADIO_VOLDN, PWideChar(AsWide(GetText(txtVolDn))));
    AppendMenuW(RadioMenu, MF_STRING, IDM_RADIO_VOLUP, PWideChar(AsWide(GetText(txtVolUp))));
  end;
  AppendMenuW(TrayMenu, MF_POPUP, UINT(RadioMenu), PWideChar(AsWide(GetText(txtRadio))));

  hk1 := AsWide(GetText(txtHkClip)) + '   ' + HotkeyText(HotkeyClipMods, HotkeyClipVk);
  hk2 := AsWide(GetText(txtGrabTitle)) + '   ' + HotkeyText(HotkeyGrabMods, HotkeyGrabVk);
  hk3 := AsWide(GetText(txtPlainTitle)) + '   ' + HotkeyText(HotkeyPlainMods, HotkeyPlainVk);
  hk4 := AsWide(GetText(txtOcrTitle)) + '   ' + HotkeyText(HotkeyOcrMods, HotkeyOcrVk);
  hk5 := AsWide(GetText(txtSnipTitle)) + '   ' + HotkeyText(HotkeySnipMods, HotkeySnipVk);
  hk6 := AsWide(GetText(txtSnipWnd)) + '   ' + HotkeyText(HotkeySnipWndMods, HotkeySnipWndVk);
  hk7 := AsWide(GetText(txtSnipAll)) + '   ' + HotkeyText(HotkeySnipAllMods, HotkeySnipAllVk);
  hk8 := AsWide(GetText(txtSnipLast)) + '   ' + HotkeyText(HotkeySnipLastMods, HotkeySnipLastVk);
  AppendMenuW(HkMenu, MF_STRING, IDM_HK_CLIP, PWideChar(hk1));
  AppendMenuW(HkMenu, MF_STRING, IDM_HK_GRAB, PWideChar(hk2));
  AppendMenuW(HkMenu, MF_STRING, IDM_HK_PLAIN, PWideChar(hk3));
  AppendMenuW(HkMenu, MF_STRING, IDM_HK_OCR, PWideChar(hk4));
  AppendMenuW(HkMenu, MF_STRING, IDM_HK_SNIP, PWideChar(hk5));
  AppendMenuW(HkMenu, MF_STRING, IDM_HK_SNIPWND, PWideChar(hk6));
  AppendMenuW(HkMenu, MF_STRING, IDM_HK_SNIPALL, PWideChar(hk7));
  AppendMenuW(HkMenu, MF_STRING, IDM_HK_SNIPLAST, PWideChar(hk8));
  AppendMenuW(HkMenu, MF_SEPARATOR, 0, nil);
  AppendMenuW(HkMenu, MF_STRING or MF_GRAYED, 0, PWideChar(AsWide(GetText(txtHkMouse))));
  AppendMenuW(TrayMenu, MF_POPUP, UINT(HkMenu), PWideChar(AsWide(GetText(txtHkMenu))));

  uFlags := MF_STRING;
  if LangSetting = 'auto' then
    uFlags := uFlags or MF_CHECKED;
  AppendMenuW(LangMenu, uFlags, IDM_LANG_AUTO, PWideChar(AsWide(GetText(txtLangAuto))));
  uFlags := MF_STRING;
  if LangSetting = 'ru' then
    uFlags := uFlags or MF_CHECKED;
  AppendMenuW(LangMenu, uFlags, IDM_LANG_RU, 'Русский');
  uFlags := MF_STRING;
  if LangSetting = 'uk' then
    uFlags := uFlags or MF_CHECKED;
  AppendMenuW(LangMenu, uFlags, IDM_LANG_UK, 'Українська');
  uFlags := MF_STRING;
  if LangSetting = 'be' then
    uFlags := uFlags or MF_CHECKED;
  AppendMenuW(LangMenu, uFlags, IDM_LANG_BE, 'Беларуская');
  uFlags := MF_STRING;
  if LangSetting = 'en' then
    uFlags := uFlags or MF_CHECKED;
  AppendMenuW(LangMenu, uFlags, IDM_LANG_EN, 'English');
  AppendMenuW(TrayMenu, MF_POPUP, UINT(LangMenu), PWideChar(AsWide(GetText(txtLangMenu))));

  uFlags := MF_STRING;
  if AutostartEnabled then
    uFlags := uFlags or MF_CHECKED;
  AppendMenuW(TrayMenu, uFlags, IDM_AUTOSTART, PWideChar(AsWide(sAutostart)));

  AppendMenuW(TrayMenu, MF_SEPARATOR, 0, nil);

  AppendMenuW(TrayMenu, MF_STRING, IDM_EXIT, PWideChar(AsWide(sExit)));

  LastForeWnd := GetForegroundWindow;
  SetForegroundWindow(hMainWnd);
  TrackPopupMenu(TrayMenu, TPM_RIGHTALIGN or TPM_BOTTOMALIGN, x, y, 0, hMainWnd, nil);
  PostMessage(hMainWnd, WM_NULL, 0, 0);

  DestroyMenu(IntervalMenu);
  DestroyMenu(HkMenu);
  DestroyMenu(LangMenu);
  DestroyMenu(TrayMenu);
end;

procedure SetManualMode;
begin
  Paused := True;
  SetTrayTip(GetText(txtTipPaused));
  ShowInfo(GetText(txtAutoPaused));
  SetEvent(hEvent);
  SaveConfig;
end;

procedure ToggleAutostart;
begin
  AutostartEnabled := not AutostartEnabled;
  SetAutostart(AutostartEnabled);
  if AutostartEnabled then
    ShowInfo(GetText(txtAutoStartAdded))
  else
    ShowInfo(GetText(txtAutoStartRemoved));
end;

procedure SetInterval(IntervalMs: DWORD);
begin
  Paused := False;
  CurrentInterval := IntervalMs;
  SetTrayTip(Format(GetText(txtTipInterval), [IntervalMs div 60000, GetText(txtMinSuffix)]));
  QueueInfo(Format(GetText(txtIntervalSet), [IntervalMs div 60000, GetText(txtMinSuffix)]));
  SetEvent(hEvent);
  SaveConfig;
end;

function MainWndProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  pt: TPoint;
  tid: DWORD;
  msgCaption, msgText: string;
  cmdId: UINT;
  hkM, hkV: UINT;
  i: Integer;
  job: POcrIdxJob;
  ujob: PUpdJob;
begin
  Result := 0;
  if (TaskbarCreatedMsg <> 0) and (uMsg = TaskbarCreatedMsg) then
  begin
    if not ParamAction then
      Shell_NotifyIconW(NIM_ADD, @nid);
    Exit;
  end;
  case uMsg of
    WM_CREATE:
      begin
        hMainWnd := hWnd;
        if not ParamAction then
        begin
          InitTrayIcon;
          if Paused then
            SetTrayTip(GetText(txtTipPaused))
          else
            SetTrayTip(Format(GetText(txtTipInterval),
              [CurrentInterval div 60000, GetText(txtMinSuffix)]));
        end;
        hEvent := CreateEvent(nil, LongBool(False), LongBool(False), nil);
        if hEvent = 0 then
        begin
          msgText := GetText(txtErrSyncEvent);
          msgCaption := GetText(txtAppName);
          MessageBoxW(0, PWideChar(AsWide(msgText)), PWideChar(AsWide(msgCaption)), MB_OK or MB_ICONERROR);
          Halt(0);
        end;
        if ClipWatchEnabled then
          AddClipboardFormatListener(hWnd);
        ClipShouldIgnoreInit;
        ApplyHotkeys;
        if GrabEnabled then
          StartMouseHook;
        hThread := BeginThread(nil, 0, @CleanupThread, nil, 0, tid);
        SetTimer(hWnd, TIMER_MEMSTAT, 4000, nil);
      end;
    WM_TRAYICON:
      case lParam of
        WM_RBUTTONUP:
          begin
            GetCursorPos(pt);
            ShowTrayMenu(pt.x, pt.y);
          end;
        WM_LBUTTONUP:
          begin
            GetCursorPos(pt);
            ShowClipHistoryMenu(pt.x, pt.y);
          end;
        WM_LBUTTONDBLCLK:
          begin
            ForceRun := True;
            SetEvent(hEvent);
          end;
      end;
    WM_HOTKEY:
      case wParam of
        HOTKEY_CLIPMENU:
          ShowClipViewer;
        HOTKEY_GRAB:
          DoGrabAtCursor(0);
        HOTKEY_PLAIN:
          PastePlainFromClipboard;
        HOTKEY_OCR:
          DoGrabAtCursor(3);
        HOTKEY_SNIP:
          ShowSnip;
        HOTKEY_SNIPWND:
          SnipWindow;
        HOTKEY_SNIPALL:
          SnipAll;
        HOTKEY_SNIPLAST:
          if SnipLastOk then
            SnipFinish(SnipLastScr, 0);
      end;
    WM_CLIPBOARDUPDATE:
      if ClipWatchEnabled then
        SetTimer(hWnd, TIMER_CLIPCAPTURE, 300, nil);
    WM_GRAB_CLICK:
      DoGrabAtCursor(wParam);
    WM_OCRIDX_DONE:
      begin
        job := POcrIdxJob(lParam);
        if job <> nil then
        begin
          InterlockedDecrement(OcrIdxPending);
          for i := 0 to High(ClipHistory) do
            if (ClipHistory[i].Time = job^.Key) and
               (ClipHistory[i].StampUtc.dwLowDateTime = job^.StampLo) and
               (ClipHistory[i].StampUtc.dwHighDateTime = job^.StampHi) then
            begin
              ClipHistory[i].OcrText := job^.Text;
              Break;
            end;
          Dispose(job);
          if hViewWnd <> 0 then
            PostMessage(hViewWnd, VIEW_REFRESH, 0, 0);
        end;
      end;
    WM_UPDATE_DONE:
      begin
        UpdateChecking := False;
        ujob := PUpdJob(lParam);
        if ujob <> nil then
        begin
          if ujob^.Ok and VersionNewer(ujob^.Ver, APP_VERSION) then
          begin
            if MessageBoxW(hWnd,
               PWideChar(AsWide(Format(GetText(txtUpdateNew), [ujob^.Ver]))),
               PWideChar(AsWide('MemClip ' + APP_VERSION)),
               MB_YESNO or MB_ICONINFORMATION) = IDYES then
              ShellExecuteW(0, 'open', PWideChar(ujob^.Url), nil, nil, SW_SHOW);
          end
          else if ujob^.Ok then
            QueueInfo(GetText(txtUpdateLatest))
          else
            QueueInfo(GetText(txtUpdateErr));
          Dispose(ujob);
        end;
      end;
    WM_COMMAND:
      begin
        cmdId := wParam and $FFFF;
        case cmdId of
          IDM_MANUAL: SetManualMode;
          IDM_HISTORY: ShowClipViewer;
          IDM_AUTOSTART: ToggleAutostart;
          IDM_CLIPWATCH: ToggleClipWatch;
          IDM_AUTOPASTE:
            begin
              AutoPaste := not AutoPaste;
              SaveConfig;
            end;
          IDM_GRABTOGGLE: ToggleGrab;
          IDM_CLIPCLEAR:
            begin
              SetLength(ClipHistory, 0);
              if hViewWnd <> 0 then
                PostMessage(hViewWnd, VIEW_REFRESH, 0, 0);
              QueueInfo(GetText(txtClipCleared));
              SetTimer(hWnd, TIMER_HISTSAVE, 1000, nil);
            end;
          IDM_CLEANNOW:
            begin
              ForceRun := True;
              SetEvent(hEvent);
            end;
          IDM_ICONCACHE: ClearShellCache;
          IDM_SNIP: ShowSnip;
          IDM_UPDATE:
            CheckUpdates;
          IDM_RADIO_EN:
            begin
              RadioEnabled := not RadioEnabled;
              if not RadioEnabled then
              begin
                RadioStop;
                SetLength(RadioNames, 0);
                SetLength(RadioUrls, 0);
              end;
              SaveConfig;
              if RadioEnabled then
                LoadRadioCfg(PWideChar(IniPath));
            end;
          IDM_RADIO_STOP:
            RadioStop;
          IDM_RADIO_VOLDN:
            RadioVolStep(-10);
          IDM_RADIO_VOLUP:
            RadioVolStep(10);
          IDM_RADIO_BASE..IDM_RADIO_MAX:
            RadioPlay((wParam and $FFFF) - IDM_RADIO_BASE);
          IDM_LANG_AUTO: SetLangChoice('auto');
          IDM_LANG_RU: SetLangChoice('ru');
          IDM_LANG_UK: SetLangChoice('uk');
          IDM_LANG_BE: SetLangChoice('be');
          IDM_LANG_EN: SetLangChoice('en');
          IDM_CLIPMERGE:
            begin
              ClipMergeEnabled := not ClipMergeEnabled;
              SaveConfig;
            end;
          IDM_HK_PLAIN:
            if ShowHotkeyDialog(AsWide(GetText(txtHkPrompt)), hkM, hkV) then
            begin
              HotkeyPlainMods := hkM;
              HotkeyPlainVk := hkV;
              ApplyHotkeys;
              SaveConfig;
              QueueInfoW(HotkeyText(hkM, hkV));
            end;
          IDM_HK_OCR:
            if ShowHotkeyDialog(AsWide(GetText(txtHkPrompt)), hkM, hkV) then
            begin
              HotkeyOcrMods := hkM;
              HotkeyOcrVk := hkV;
              ApplyHotkeys;
              SaveConfig;
              QueueInfoW(HotkeyText(hkM, hkV));
            end;
          IDM_HK_CLIP:
            if ShowHotkeyDialog(AsWide(GetText(txtHkPrompt)), hkM, hkV) then
            begin
              HotkeyClipMods := hkM;
              HotkeyClipVk := hkV;
              ApplyHotkeys;
              SaveConfig;
              QueueInfoW(HotkeyText(hkM, hkV));
            end;
          IDM_HK_GRAB:
            if ShowHotkeyDialog(AsWide(GetText(txtHkPrompt)), hkM, hkV) then
            begin
              HotkeyGrabMods := hkM;
              HotkeyGrabVk := hkV;
              ApplyHotkeys;
              SaveConfig;
              QueueInfoW(HotkeyText(hkM, hkV));
            end;
          IDM_HK_SNIP:
            if ShowHotkeyDialog(AsWide(GetText(txtHkPrompt)), hkM, hkV) then
            begin
              HotkeySnipMods := hkM;
              HotkeySnipVk := hkV;
              ApplyHotkeys;
              SaveConfig;
              QueueInfoW(HotkeyText(hkM, hkV));
            end;
          IDM_HK_SNIPWND:
            if ShowHotkeyDialog(AsWide(GetText(txtHkPrompt)), hkM, hkV) then
            begin
              HotkeySnipWndMods := hkM;
              HotkeySnipWndVk := hkV;
              ApplyHotkeys;
              SaveConfig;
              QueueInfoW(HotkeyText(hkM, hkV));
            end;
          IDM_HK_SNIPALL:
            if ShowHotkeyDialog(AsWide(GetText(txtHkPrompt)), hkM, hkV) then
            begin
              HotkeySnipAllMods := hkM;
              HotkeySnipAllVk := hkV;
              ApplyHotkeys;
              SaveConfig;
              QueueInfoW(HotkeyText(hkM, hkV));
            end;
          IDM_HK_SNIPLAST:
            if ShowHotkeyDialog(AsWide(GetText(txtHkPrompt)), hkM, hkV) then
            begin
              HotkeySnipLastMods := hkM;
              HotkeySnipLastVk := hkV;
              ApplyHotkeys;
              SaveConfig;
              QueueInfoW(HotkeyText(hkM, hkV));
            end;
          IDM_EXIT: DestroyWindow(hWnd);
          IDM_INTERVAL_1M: SetInterval(60000);
          IDM_INTERVAL_5M: SetInterval(300000);
          IDM_INTERVAL_10M: SetInterval(600000);
          IDM_INTERVAL_30M: SetInterval(1800000);
          IDM_INTERVAL_60M: SetInterval(3600000);
        else
          if (cmdId >= IDM_CLIPBASE) and (cmdId < IDM_CLIPBASE + CLIP_HISTORY_TOTAL_MAX) then
          begin
            if GetKeyState(VK_SHIFT) < 0 then
              TogglePin(cmdId - IDM_CLIPBASE)
            else if GetKeyState(VK_CONTROL) < 0 then
              RestoreAndMaybePastePlain(cmdId - IDM_CLIPBASE)
            else
              RestoreAndMaybePaste(cmdId - IDM_CLIPBASE);
          end;
        end;
      end;
    WM_TIMER:
      if wParam = TIMER_EXIT then
        DestroyWindow(hWnd)
      else if wParam = TIMER_CLIPCAPTURE then
      begin
        KillTimer(hWnd, TIMER_CLIPCAPTURE);
        CaptureClipboard;
      end
      else if wParam = TIMER_HISTSAVE then
      begin
        KillTimer(hWnd, TIMER_HISTSAVE);
        SaveHistory;
      end
      else if wParam = TIMER_MEMSTAT then
        MemStatTick;
    WM_CLEANUP_DONE:
      begin
        LastFreeBefore := Integer(wParam);
        LastFreeAfter := Integer(lParam);
        UpdateTrayTip;
        ShowPopup(LastFreeBefore, LastFreeAfter);
        if RunOnce then
          SetTimer(hMainWnd, TIMER_EXIT, 3200, nil);
      end;
    WM_DESTROY:
      begin
        Exiting := True;
        RadioStop;
        SetEvent(hEvent);
        if hGrabWnd <> 0 then
          DestroyWindow(hGrabWnd);
        if hHkWnd <> 0 then
          DestroyWindow(hHkWnd);
        if hViewWnd <> 0 then
          DestroyWindow(hViewWnd);
        if hThread <> 0 then
        begin
          WaitForSingleObject(hThread, 5000);
          CloseHandle(hThread);
        end;
        StopMouseHook;
        if hHookReady <> 0 then
        begin
          CloseHandle(hHookReady);
          hHookReady := 0;
        end;
        UnregisterHotKey(hWnd, HOTKEY_CLIPMENU);
        UnregisterHotKey(hWnd, HOTKEY_GRAB);
        UnregisterHotKey(hWnd, HOTKEY_PLAIN);
        UnregisterHotKey(hWnd, HOTKEY_OCR);
        UnregisterHotKey(hWnd, HOTKEY_SNIP);
        UnregisterHotKey(hWnd, HOTKEY_SNIPWND);
        UnregisterHotKey(hWnd, HOTKEY_SNIPALL);
        RemoveClipboardFormatListener(hWnd);
        if GdipStarted then
          GdiplusShutdown(GdipToken);
        SaveHistory;
        Shell_NotifyIconW(NIM_DELETE, @nid);
        PostQuitMessage(0);
      end;
    else
      Result := DefWindowProc(hWnd, uMsg, wParam, lParam);
  end;
end;

function PopupWndProc(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
var
  ps: TPaintStruct;
  dc: HDC;
  rc: TRect;
  hOldFont: HFONT;
begin
  Result := 0;
  case uMsg of
    WM_PAINT:
      begin
        dc := BeginPaint(hWnd, ps);
        try
          GetClientRect(hWnd, rc);
          FillRect(dc, rc, hPopupBrush);

          if PopupText <> '' then
          begin
            hOldFont := HFONT(SelectObject(dc, hPopupFont));
            SetBkMode(dc, TRANSPARENT);
            SetTextColor(dc, RGB(255, 255, 255));
            DrawTextW(dc, PWideChar(PopupText), -1, rc,
              DT_CENTER or DT_VCENTER or DT_SINGLELINE or DT_NOPREFIX);
            SelectObject(dc, hOldFont);
          end;
        finally
          EndPaint(hWnd, ps);
        end;
      end;
    WM_ERASEBKGND:
      begin
        GetClientRect(hWnd, rc);
        FillRect(HDC(wParam), rc, hPopupBrush);
        Result := 1;
      end;
    WM_TIMER:
      if wParam = 1 then
      begin
        if Length(InfoQueue) > 0 then
          ShowNextInfo
        else
        begin
          ShowWindow(hWnd, SW_HIDE);
          KillTimer(hWnd, 1);
        end;
      end;
    WM_LBUTTONUP:
      begin
        if Length(InfoQueue) > 0 then
          ShowNextInfo
        else
          ShowWindow(hWnd, SW_HIDE);
      end;
    else
      Result := DefWindowProc(hWnd, uMsg, wParam, lParam);
  end;
end;

var
  wc: WNDCLASSA;
  wcw: WNDCLASSW;
  Msg: TMsg;
  mutex: HANDLE;
  hPrev: HWND;
  msgCaption, msgText, autostartParam: string;
begin
  DefaultSystemCodePage := CP_UTF8;
  CurrentLang := DetectLanguage;
  ParseCommandLine;
  ClipWatchEnabled := True;
  AutoPaste := True;
  GrabEnabled := True;
  ClipHistoryMax := CLIP_HISTORY_MAX;
  MemFreeMinMb := 0;
  LangSetting := 'auto';

  if not IsElevated then
  begin
    if ElevatedRetry then
    begin
      msgText := GetText(txtErrNotAdmin);
      msgCaption := GetText(txtAppName);
      MessageBoxW(0, PWideChar(AsWide(msgText)), PWideChar(AsWide(msgCaption)), MB_OK or MB_ICONERROR);
      Halt(0);
    end;
    RelaunchElevated;
    Halt(0);
  end;

  CoInitialize(nil);
  RoInitialize(0);
  InitializeCriticalSection(OcrCs);
  AutostartEnabled := GetAutostartEnabled;
  TaskbarCreatedMsg := RegisterWindowMessageA('TaskbarCreated');

  mutex := CreateMutex(nil, LongBool(True), 'memclip_pas');
  ReplacePrevious := (GetLastError = ERROR_ALREADY_EXISTS) and not ParamAction;

  MainClassName := 'MemClipMain';
  PopupClassName := 'MemClipPopup';
  GrabClassName := 'MemClipGrab';
  HkClassName := 'MemClipHotkey';
  ViewerClassName := 'MemClipViewer';
  IconName := 'MAINICON';
  CurrentInterval := 300000;
  LoadConfig;
  ApplyLangSetting;

  AppIcon := HICON(LoadImage(HInstance, PChar(IconName), IMAGE_ICON, 16, 16, LR_DEFAULTCOLOR));
  if AppIcon = 0 then
    AppIcon := LoadIcon(0, IDI_APPLICATION);

  hPopupBrush := CreateSolidBrush(RGB(30, 30, 30));
  hPopupFont := HFONT(GetStockObject(DEFAULT_GUI_FONT));
  hGrabBrush := CreateSolidBrush(RGB(255, 206, 163));
  hSnipBrush := CreateSolidBrush(RGB(0, 0, 0));
  hGrabEditBrush := CreateSolidBrush(RGB(255, 247, 234));

  FillChar(wc, SizeOf(wc), 0);
  wc.lpfnWndProc := @MainWndProc;
  wc.hInstance := HInstance;
  wc.hCursor := LoadCursor(0, IDC_ARROW);
  wc.lpszClassName := PChar(MainClassName);
  if RegisterClassA(wc) = 0 then
  begin
    msgText := GetText(txtErrRegMain);
    msgCaption := GetText(txtAppName);
    MessageBoxW(0, PWideChar(AsWide(msgText)), PWideChar(AsWide(msgCaption)), MB_OK or MB_ICONERROR);
    Halt(0);
  end;

  FillChar(wc, SizeOf(wc), 0);
  wc.style := CS_HREDRAW or CS_VREDRAW;
  wc.lpfnWndProc := @PopupWndProc;
  wc.hInstance := HInstance;
  wc.hCursor := LoadCursor(0, IDC_ARROW);
  wc.lpszClassName := PChar(PopupClassName);
  if RegisterClassA(wc) = 0 then
  begin
    msgText := GetText(txtErrRegPopup);
    msgCaption := GetText(txtAppName);
    MessageBoxW(0, PWideChar(AsWide(msgText)), PWideChar(AsWide(msgCaption)), MB_OK or MB_ICONERROR);
    Halt(0);
  end;

  FillChar(wcw, SizeOf(wcw), 0);
  wcw.lpfnWndProc := @GrabWndProc;
  wcw.hInstance := HInstance;
  wcw.hCursor := LoadCursor(0, IDC_ARROW);
  wcw.hbrBackground := hGrabBrush;
  wcw.lpszClassName := PWideChar(WideString(GrabClassName));
  RegisterClassW(wcw);

  FillChar(wcw, SizeOf(wcw), 0);
  wcw.lpfnWndProc := @HkWndProc;
  wcw.hInstance := HInstance;
  wcw.hCursor := LoadCursor(0, IDC_ARROW);
  wcw.hbrBackground := HBRUSH(COLOR_BTNFACE + 1);
  wcw.lpszClassName := PWideChar(WideString(HkClassName));
  RegisterClassW(wcw);

  hMainWnd := CreateWindowEx(0, PChar(MainClassName), PChar('MemClip'), WS_POPUP,
    0, 0, 0, 0, 0, 0, HInstance, nil);
  if hMainWnd = 0 then
  begin
    msgText := GetText(txtErrCreateMain);
    msgCaption := GetText(txtAppName);
    MessageBoxW(0, PWideChar(AsWide(msgText)), PWideChar(AsWide(msgCaption)), MB_OK or MB_ICONERROR);
    Halt(0);
  end;

  hPopupWnd := CreateWindowEx(
    WS_EX_LAYERED or WS_EX_TOOLWINDOW or WS_EX_NOACTIVATE,
    PChar(PopupClassName),
    PChar(''),
    WS_POPUP,
    0, 0, POPUP_WIDTH, POPUP_HEIGHT,
    0, 0, HInstance, nil);
  if hPopupWnd <> 0 then
    SetLayeredWindowAttributes(hPopupWnd, 0, 200, LWA_ALPHA);

  if DoInstall then
  begin
    SetAutostart(True);
    ShowInfo(GetText(txtAutoStartAdded));
    SetTimer(hMainWnd, TIMER_EXIT, 3200, nil);
  end;

  if DoUninstall then
  begin
    SetAutostart(False);
    ShowInfo(GetText(txtAutoStartRemoved));
    SetTimer(hMainWnd, TIMER_EXIT, 3200, nil);
  end;

  if RunOnce then
  begin
    ForceRun := True;
    SetEvent(hEvent);
  end;

  if CfgAutostart then
  begin
    if CfgIntervalMin > 0 then
      autostartParam := ' -a' + IntToStr(CfgIntervalMin)
    else
      autostartParam := ' -a';
    SetAutostart(True, autostartParam);
  end;

  if CfgIntervalMin > 0 then
  begin
    CurrentInterval := DWORD(CfgIntervalMin) * 60000;
    SetTrayTip(Format(GetText(txtTipInterval), [CfgIntervalMin, GetText(txtMinSuffix)]));
    SetEvent(hEvent);
  end;

  if ReplacePrevious then
  begin
    ShowInfo(GetText(txtRestarting));
    hPrev := FindPreviousInstance;
    if hPrev <> 0 then
      PostMessage(hPrev, WM_CLOSE, 0, 0);
    WaitForSingleObject(mutex, 15000);
  end;

  LoadHistory;

  if CfgAutostart then
    QueueInfo(GetText(txtAutoStartAdded));
  if CfgIntervalMin > 0 then
  begin
    if CfgIntervalCapped then
      QueueInfo(Format(GetText(txtIntervalMax), [CfgIntervalMin, GetText(txtMinSuffix)]))
    else
      QueueInfo(Format(GetText(txtIntervalSet), [CfgIntervalMin, GetText(txtMinSuffix)]));
  end;

  while GetMessage(Msg, 0, 0, 0) do
  begin
    TranslateMessage(Msg);
    DispatchMessage(Msg);
  end;

  if hPopupBrush <> 0 then
    DeleteObject(hPopupBrush);
  if hGrabBrush <> 0 then
    DeleteObject(hGrabBrush);
  if hGrabEditBrush <> 0 then
    DeleteObject(hGrabEditBrush);
  if hPopupFont <> 0 then
    DeleteObject(hPopupFont);
  if AppIcon <> 0 then
    DestroyIcon(AppIcon);
  Windows.UnregisterClass(PChar(PopupClassName), HInstance);
  Windows.UnregisterClass(PChar(MainClassName), HInstance);
  Windows.UnregisterClassW(PWideChar(WideString(GrabClassName)), HInstance);
  Windows.UnregisterClassW(PWideChar(WideString(HkClassName)), HInstance);
  CoUninitialize;
  CloseHandle(mutex);
end.
