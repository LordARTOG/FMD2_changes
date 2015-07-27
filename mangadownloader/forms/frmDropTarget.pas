unit frmDropTarget;

{$mode objfpc}{$H+}

interface

uses
  Classes, Windows, SysUtils, ActiveX, comobj, HTMLUtil, Forms, Controls,
  ExtCtrls, Menus, LCLType, DefaultTranslator, uBaseUnit;

type

  { TFormDropTarget }

  TFormDropTarget = class(TForm, IDropTarget)
    ImResize: TImage;
    ImDropIcon: TImage;
    miClose: TMenuItem;
    pmDropTarget: TPopupMenu;
    shBorder: TShape;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormMouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Integer);
    procedure FormMouseUp(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
    procedure FormShow(Sender: TObject);
    procedure ImResizeMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure miCloseClick(Sender: TObject);
  private
    { private declarations }
    md: Boolean;
    x0, y0: Integer;
    FCanDrop: Boolean;
    // IDropTarget
    function MakeFormatEtc(const Fmt: TClipFormat): TFormatEtc;
    function CursorEffect(const AllowedEffects: LongInt;
      const KeyState: Integer): LongInt;
    function CanDrop(const DataObj: IDataObject): Boolean;
    function GetTextFromObj(const DataObj: IDataObject;
      const Fmt: TClipFormat): String;
    function GetWideTextFromObj(const DataObj: IDataObject;
      const Fmt: TClipFormat): String;
    function GetURLsFromHTML(const S: String): String;
    function ParseDataObj(const DataObj: IDataObject;
      const Fmt: TClipboardFormat): String;
    function DragEnter(const dataObj: IDataObject; grfKeyState: DWORD;
      {%H-}pt: TPoint; var dwEffect: DWORD): HResult; stdcall;
    function {%H-}DragOver(grfKeyState: DWORD; {%H-}pt: TPoint;
      var dwEffect: DWORD): HResult; stdcall;
    function DragLeave: HResult; stdcall;
    function Drop(const dataObj: IDataObject; {%H-}grfKeyState: DWORD;
      {%H-}pt: TPoint; var {%H-}dwEffect: DWORD): HResult; stdcall;
  protected
    procedure CreateParams(var Params: TCreateParams); override;
  public
    { public declarations }
  end;

var
  FormDropTarget: TFormDropTarget;
  FAlphaBlendValue: Integer = 255;
  FWidth: Integer = 64;
  FHeight: Integer = 64;
  FLeft: Integer = -1;
  FTop: Integer = -1;
  OnDropChekout: procedure(S: String) of object;

implementation

uses
  frmMain;

var
  CF_HTML: TClipFormat;

{$R *.lfm}

{ TFormDropTarget }

procedure TFormDropTarget.FormCreate(Sender: TObject);
begin
  ShowWindow(Self.Handle, SW_HIDE);
  SetWindowLong(Self.Handle, GWL_EXSTYLE, getWindowLong(Self.Handle,
    GWL_EXSTYLE) or WS_EX_TOOLWINDOW);
  ShowWindow(Self.Handle, SW_SHOW);
  OleInitialize(nil);
  OleCheck(RegisterDragDrop(Handle, Self));
  AlphaBlend := True;
end;

procedure TFormDropTarget.FormClose(Sender: TObject;
  var CloseAction: TCloseAction);
begin
  MainForm.SaveDropTargetFormInformation;
  CloseAction := caFree;
end;

procedure TFormDropTarget.FormDestroy(Sender: TObject);
begin
  RevokeDragDrop(Handle);
  OleUninitialize;
  FormDropTarget := nil;
end;

procedure TFormDropTarget.FormMouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  if Button = mbLeft then
  begin
    md := True;
    x0 := X;
    y0 := Y;
  end;
end;

procedure TFormDropTarget.FormMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
begin
  if md then
  begin
    Left := Left - x0 + X;
    Top := Top - y0 + Y;
    FLeft := Left;
    FTop := Top;
  end;
end;

procedure TFormDropTarget.FormMouseUp(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
  md := False;
end;

procedure TFormDropTarget.FormShow(Sender: TObject);
begin
  AlphaBlendValue := FAlphaBlendValue;
  Width := FWidth;
  Height := FHeight;
  if FLeft = -1 then
    FLeft := Screen.WorkAreaWidth - Width - 15;
  if FTop = -1 then
    FTop := Screen.WorkAreaHeight - Height - 15;
  Left := FLeft;
  Top := FTop;
end;

procedure TFormDropTarget.ImResizeMouseMove(Sender: TObject;
  Shift: TShiftState; X, Y: Integer);
begin
  if md then
  begin
    Width := Width + X - x0;
    Height := Height + Y - y0;
    FWidth := Width;
    FHeight := Height;
  end;
end;

procedure TFormDropTarget.miCloseClick(Sender: TObject);
begin
  MainForm.ckDropTarget.Checked := False;
  Self.Close;
end;

function TFormDropTarget.MakeFormatEtc(const Fmt: TClipFormat): TFormatEtc;
begin
  Result.cfFormat := Fmt;
  Result.ptd := nil;
  Result.dwAspect := DVASPECT_CONTENT;
  Result.lindex := -1;
  Result.tymed := TYMED_HGLOBAL;
end;

function TFormDropTarget.CursorEffect(const AllowedEffects: LongInt;
  const KeyState: Integer): LongInt;
begin
  Result := DROPEFFECT_NONE;
  if FCanDrop then
  begin
    if (KeyState and MK_SHIFT = MK_SHIFT) and
      (DROPEFFECT_MOVE and AllowedEffects = DROPEFFECT_MOVE) then
      Result := DROPEFFECT_MOVE
    else if (DROPEFFECT_COPY and AllowedEffects = DROPEFFECT_COPY) then
      Result := DROPEFFECT_COPY;
  end;
end;

function TFormDropTarget.CanDrop(const DataObj: IDataObject): Boolean;
begin
  Result := DataObj.QueryGetData(MakeFormatEtc(CF_HTML)) = S_OK;
  if not Result then
    Result := DataObj.QueryGetData(MakeFormatEtc(CF_UNICODETEXT)) = S_OK;
  if not Result then
    Result := DataObj.QueryGetData(MakeFormatEtc(CF_TEXT)) = S_OK;
end;

function TFormDropTarget.GetTextFromObj(const DataObj: IDataObject;
  const Fmt: TClipFormat): String;
var
  Medium: TStgMedium;
  PText: PChar;
begin
  if DataObj.GetData(MakeFormatEtc(Fmt), Medium) = S_OK then
  begin
    Assert(Medium.tymed = MakeFormatEtc(Fmt).tymed);
    try
      PText := GlobalLock(Medium.hGlobal);
      try
        Result := PText;
      finally
        GlobalUnlock(Medium.hGlobal);
      end;
    finally
      ReleaseStgMedium(Medium);
    end;
  end
  else
    Result := '';
end;

function TFormDropTarget.GetWideTextFromObj(const DataObj: IDataObject;
  const Fmt: TClipFormat): String;
var
  Medium: TStgMedium;
  PwText: PWideChar;
begin
  if DataObj.GetData(MakeFormatEtc(Fmt), Medium) = S_OK then
  begin
    Assert(Medium.tymed = MakeFormatEtc(Fmt).tymed);
    try
      PwText := GlobalLock(Medium.hGlobal);
      try
        Result := PwText;
      finally
        GlobalUnlock(Medium.hGlobal);
      end;
    finally
      ReleaseStgMedium(Medium);
    end;
  end
  else
    Result := '';
end;

function TFormDropTarget.GetURLsFromHTML(const S: String): String;
var
  Parse, URls: TStringList;
  i: Integer;
  t: String;
begin
  Result := S;
  if S = '' then Exit;
  Parse:= TStringList.Create;
  try
    ParseHTML(S, Parse);
    if Parse.Count > 0 then
    begin
      URls := TStringList.Create;
      try
        for i := 0 to Parse.Count -1 do
        begin
          if LowerCase(GetTagName(Parse[i])) = 'a' then
          t := GetVal(Parse[i], 'href');
          if Pos('javascript', t) <> 1 then
            URls.Add(t);
        end;
        if URls.Count > 0 then
        begin
          RemoveDuplicateStrings(URls);
          Result := URls.Text;
        end;
      finally
        URls.Free;
      end;
    end;
  finally
    Parse.Free;
  end;
end;

function TFormDropTarget.ParseDataObj(const DataObj: IDataObject;
  const Fmt: TClipboardFormat): String;
begin
  if Fmt = CF_HTML then
    Result := GetURLsFromHTML(GetTextFromObj(DataObj, Fmt))
  else
  if Fmt = CF_UNICODETEXT then
    Result := GetWideTextFromObj(DataObj, Fmt)
  else
  if Fmt = CF_TEXT then
    Result := GetTextFromObj(DataObj, Fmt)
  else
    Result := '';
  Result := Trim(Result);
end;

function TFormDropTarget.DragEnter(const dataObj: IDataObject; grfKeyState: DWORD;
  pt: TPoint; var dwEffect: DWORD): HResult; stdcall;
begin
  FCanDrop := CanDrop(dataObj);
  dwEffect := CursorEffect(dwEffect, grfKeyState);
  Result := S_OK;
end;

function TFormDropTarget.DragOver(grfKeyState: DWORD; pt: TPoint;
  var dwEffect: DWORD): HResult; stdcall;
begin
  dwEffect := CursorEffect(dwEffect, grfKeyState);
  Result := S_OK;
end;

function TFormDropTarget.DragLeave: HResult; stdcall;
begin
  Result := S_OK;
end;

function TFormDropTarget.Drop(const dataObj: IDataObject; grfKeyState: DWORD;
  pt: TPoint; var dwEffect: DWORD): HResult; stdcall;
var
  Enum: IEnumFORMATETC;
  FmtEtc: TFORMATETC;
begin
  OleCheck(DataObj.EnumFormatEtc(DATADIR_GET, Enum));
  while Enum.Next(1, FmtEtc, nil) = S_OK do
    if (FmtEtc.CfFormat = CF_HTML) or
       (FmtEtc.CfFormat = CF_UNICODETEXT) or
       (FmtEtc.CfFormat = CF_TEXT) then
    begin
      if Assigned(OnDropChekout) then
        OnDropChekout(ParseDataObj(dataObj, FmtEtc.CfFormat));
      Break;
    end;
  Result := S_OK;
end;

procedure TFormDropTarget.CreateParams(var Params: TCreateParams);
begin
  inherited CreateParams(Params);
  Params.ExStyle := Params.ExStyle and WS_EX_TOOLWINDOW and (not WS_EX_APPWINDOW);
  Params.WndParent := GetDesktopWindow;
end;

initialization
  CF_HTML := RegisterClipboardFormat('HTML Format');

end.
