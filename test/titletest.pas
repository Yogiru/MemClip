program titletest;
{$mode objfpc}{$H+}
uses Windows, SysUtils;

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

function TP(hWnd: HWND; uMsg: UINT; wParam: WPARAM; lParam: LPARAM): LRESULT; stdcall;
begin
  Result := DefWindowProcW(hWnd, uMsg, wParam, lParam);
end;

var
  wc: WNDCLASSW;
  w: HWND;
  buf: array[0..255] of WideChar;
  i, n: Integer;
begin
  FillChar(wc, SizeOf(wc), 0);
  wc.lpfnWndProc := @TP;
  wc.hInstance := HInstance;
  wc.lpszClassName := 'TTCls';
  RegisterClassW(wc);
  w := CreateWindowExW(0, PWideChar(AsWide('TTCls')),
    PWideChar(AsWide('Окно истории')),
    WS_POPUP, 0, 0, 10, 10, 0, 0, HInstance, nil);
  n := GetWindowTextW(w, buf, 256);
  Write('len=', n, ' hex=');
  for i := 0 to n - 1 do
    Write(IntToHex(Word(buf[i]), 4), ' ');
  WriteLn;
  DestroyWindow(w);
end.
