program ocrtest;
{$mode objfpc}{$H+}
{$APPTYPE CONSOLE}
uses
  windows, sysutils;

type
  HSTR = Pointer;

  IInspectable = interface(IUnknown)
    ['{AF86E2E0-B12D-4C6A-9C5A-D7AA65101E90}']
    function GetIids(out iidCount: ULONG; out iids: Pointer): HResult; stdcall;
    function GetRuntimeClassName(out clsName: HSTR): HResult; stdcall;
    function GetTrustLevel(out trustLevel: Longint): HResult; stdcall;
  end;

  IMemoryBufferFactory = interface(IInspectable)
    ['{FBC4DD2B-245B-11E4-AF98-689423260CF8}']
    function Create(capacity: UINT32; out value: IInspectable): HResult; stdcall;
  end;

  IMemoryBuffer = interface(IInspectable)
    ['{FBC4DD2A-245B-11E4-AF98-689423260CF8}']
    function CreateReference(out reference: IInspectable): HResult; stdcall;
  end;

  IMemoryBufferReference = interface(IInspectable)
    ['{FBC4DD29-245B-11E4-AF98-689423260CF8}']
    function get_Capacity(out value: UINT32): HResult; stdcall;
    function add_Closed(handler: IInspectable; out cookie: Int64): HResult; stdcall;
    function remove_Closed(cookie: Int64): HResult; stdcall;
  end;

  IMemoryBufferByteAccess = interface(IUnknown)
    ['{5B0D3235-4DBA-4D44-865E-8F1D0E4FD04D}']
    function GetBuffer(out value: PByte; out capacity: UINT32): HResult; stdcall;
  end;

  IBuffer = interface(IInspectable)
    ['{905A0FE0-BC53-11DF-8C49-001E4FC686DA}']
    function get_Capacity(out value: UINT32): HResult; stdcall;
    function get_Length(out value: UINT32): HResult; stdcall;
    function put_Length(value: UINT32): HResult; stdcall;
  end;

  IClosable = interface(IInspectable)
    ['{30D5A829-7FA4-4026-83BB-D75BAE4EA99E}']
    function Close: HResult; stdcall;
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
    function RecognizeAsync(bitmap: IInspectable; out result: IAsyncOperationOcr): HResult; stdcall;
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

  ILanguageFactory = interface(IInspectable)
    ['{9B0252AC-0C27-44F8-B792-9793FB66C63E}']
    function CreateLanguage(languageTag: HSTR; out value: IInspectable): HResult; stdcall;
  end;

  IVectorViewX = interface(IInspectable)
    function get_Size(out size: UINT32): HResult; stdcall;
  end;

  IOcrResult = interface(IInspectable)
    ['{9BD235B2-175B-3D6A-92E2-388C206E2F63}']
    function get_Lines(out value: IInspectable): HResult; stdcall;
    function get_TextAngle(out value: IInspectable): HResult; stdcall;
    function get_Text(out value: HSTR): HResult; stdcall;
  end;

  IBufferByteAccess = interface(IUnknown)
    ['{905A0FEF-BC53-11DF-8C49-001E4FC686DA}']
    function Buffer(out value: PByte): HResult; stdcall;
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

function RoInitialize(initType: Longint): HRESULT; stdcall; external 'combase.dll';
function RoGetActivationFactory(activatableClassId: HSTR; const iid: TGUID; out factory): HRESULT; stdcall; external 'combase.dll';
function WindowsCreateString(sourceString: PWideChar; length: UINT32; out s: HSTR): HRESULT; stdcall; external 'combase.dll';
function WindowsDeleteString(s: HSTR): HRESULT; stdcall; external 'combase.dll';
function WindowsGetStringRawBuffer(s: HSTR; out length: UINT32): PWideChar; stdcall; external 'combase.dll';
function WindowsCreateStringReference(sourceString: PWideChar; length: UINT32; out hstringHeader; out s: HSTR): HRESULT; stdcall; external 'combase.dll';

var
  IID_IMemoryBufferFactory: TGUID = '{FBC4DD2B-245B-11E4-AF98-689423260CF8}';
  IID_ISoftwareBitmapStatics: TGUID = '{DF0385DB-672F-4A9D-806E-C2442F343E86}';
  IID_IOcrEngineStatics: TGUID = '{5BFFA85A-3384-3540-9940-699120D428A8}';
  IID_IBuffer: TGUID = '{905A0FE0-BC53-11DF-8C49-001E4FC686DA}';
  IID_IMemoryBufferByteAccess: TGUID = '{5B0D3235-4DBA-4D44-865E-8F1D0E4FD04D}';
  IID_IAsyncInfo: TGUID = '{00000036-0000-0000-C000-000000000046}';
  IID_IClosable: TGUID = '{30D5A829-7FA4-4026-83BB-D75BAE4EA99E}';
  IID_ILanguageFactory: TGUID = '{9B0252AC-0C27-44F8-B792-9793FB66C63E}';

function GetFactory(const clsName: WideString; const iid: TGUID; out fac): HResult;
var
  hs: HSTR;
begin
  hs := nil;
  WindowsCreateString(PWideChar(clsName), Length(clsName), hs);
  Result := RoGetActivationFactory(hs, iid, fac);
  WindowsDeleteString(hs);
end;

function PixelsToOcrText(bits: PByte; w, h: Integer): WideString;
var
  nbuf: TNativeBuffer;
  langFac: ILanguageFactory;
  lang: IInspectable;
  sbFac: ISoftwareBitmapStatics;
  sb: IInspectable;
  ocrFac: IOcrEngineStatics;
  eng: IOcrEngine;
  op: IAsyncOperationOcr;
  ainfo: IAsyncInfo;
  res: IInspectable;
  ores: IOcrResult;
  hr: HRESULT;
  status, tries: Longint;
  hs: HSTR;
  slen: UINT32;
  avail: IInspectable;
  availCount: UINT32;
begin
  Result := '';
  nbuf := TNativeBuffer.Create(w * h * 4);
  Move(bits^, nbuf.DataPtr^, w * h * 4);
  nbuf.put_Length(w * h * 4);

  hr := GetFactory('Windows.Graphics.Imaging.SoftwareBitmap', IID_ISoftwareBitmapStatics, sbFac);
  writeln('sb factory hr=', IntToHex(hr, 8));
  if hr <> 0 then Exit;
  hr := sbFac.CreateCopyFromBuffer(nbuf as IBuffer, 87 {BGRA8}, w, h, sb);
  writeln('CreateCopyFromBuffer hr=', IntToHex(hr, 8));
  if hr <> 0 then Exit;

  hr := GetFactory('Windows.Media.Ocr.OcrEngine', IID_IOcrEngineStatics, ocrFac);
  writeln('ocr factory hr=', IntToHex(hr, 8));
  if hr <> 0 then Exit;
  hr := ocrFac.get_AvailableRecognizerLanguages(avail);
  if hr = 0 then
  begin
    IVectorViewX(avail).get_Size(availCount);
    writeln('available recognizer langs: ', availCount);
  end;
  hr := ocrFac.TryCreateFromUserProfileLanguages(IInspectable(eng));
  writeln('engine(user profile) hr=', IntToHex(hr, 8), ' eng=', Pointer(eng) <> nil);
  if (hr = 0) and (eng = nil) then
  begin
    hr := GetFactory('Windows.Globalization.Language', IID_ILanguageFactory, langFac);
    writeln('lang factory hr=', IntToHex(hr, 8));
    if hr = 0 then
    begin
      WindowsCreateString('en-US', 5, hs);
      hr := langFac.CreateLanguage(hs, lang);
      WindowsDeleteString(hs);
      writeln('CreateLanguage hr=', IntToHex(hr, 8));
      hr := ocrFac.TryCreateFromLanguage(lang, IInspectable(eng));
      writeln('engine(en-US) hr=', IntToHex(hr, 8), ' eng=', Pointer(eng) <> nil);
    end;
  end;
  if (hr <> 0) or (eng = nil) then Exit;

  hr := eng.RecognizeAsync(sb, op);
  writeln('RecognizeAsync hr=', IntToHex(hr, 8));
  if hr <> 0 then Exit;

  op.QueryInterface(IID_IAsyncInfo, ainfo);
  tries := 0;
  repeat
    ainfo.get_Status(status);
    if status <> 0 then Break;
    Sleep(100);
    Inc(tries);
  until tries > 300;
  writeln('status=', status);
  if status <> 1 then Exit;

  hr := op.GetResults(res);
  writeln('GetResults hr=', IntToHex(hr, 8), ' res=', Pointer(res) <> nil);
  if hr <> 0 then Exit;
  ores := IOcrResult(res);
  ores.get_Text(hs);
  Result := WindowsGetStringRawBuffer(hs, slen);
end;

var
  w, h: Integer;
  dc, memdc: HDC;
  bmp, old: HBITMAP;
  bi: BITMAPINFO;
  pb: Pointer;
  bits: PByte;
  rc: TRect;
  s: WideString;
begin
  writeln('RoInit: ', IntToHex(RoInitialize(0), 8));

  w := 500; h := 120;
  FillChar(bi, sizeof(bi), 0);
  bi.bmiHeader.biSize := sizeof(BITMAPINFOHEADER);
  bi.bmiHeader.biWidth := w;
  bi.bmiHeader.biHeight := -h;
  bi.bmiHeader.biPlanes := 1;
  bi.bmiHeader.biBitCount := 32;
  bi.bmiHeader.biCompression := BI_RGB;
  dc := GetDC(0);
  pb := nil;
  bmp := CreateDIBSection(dc, bi, DIB_RGB_COLORS, pb, 0, 0);
  bits := PByte(pb);
  memdc := CreateCompatibleDC(dc);
  old := SelectObject(memdc, bmp);
  rc.Left := 0; rc.Top := 0; rc.Right := w; rc.Bottom := h;
  FillRect(memdc, rc, GetStockObject(WHITE_BRUSH));
  SelectObject(memdc, GetStockObject(DEFAULT_GUI_FONT));
  rc.Left := 10; rc.Top := 30; rc.Right := w - 10; rc.Bottom := h - 10;
  DrawTextW(memdc, PWideChar(WideString('Hello World OCR Test 12345')), -1, rc, DT_LEFT or DT_SINGLELINE);
  SelectObject(memdc, old);

  s := PixelsToOcrText(bits, w, h);
  writeln('OCR RESULT: [', s, ']');

  DeleteObject(bmp);
  DeleteDC(memdc);
  ReleaseDC(0, dc);
end.
