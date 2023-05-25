{$O+} // Optimization must be ON

unit X_CRC32;

interface

uses Types, SysUtils, Classes;

// Internas

function SZCRC32UpdateStream(Stream: TStream; CurCrc: DWORD): DWORD;
procedure SZCRC32MakeTable;
function SZCRC32Update(P: Pointer; ByteCount: LongInt; CurCrc : DWORD): DWORD;

 {   *************
                   Externas  para usar
                                         ***********}
// Calcula el CRC de un PChar
function CRC32Str(P: Pchar; longitud: LongInt): DWORD;
// Calcula el CRC de un fichero
function CRC32File(const FileName: string): Cardinal;



implementation

const
  CRC32BASE: DWORD = $FFFFFFFF;

Var
  CRC32Table: array[0..255] of DWORD;

procedure SZCRC32MakeTable;
// Making the 32-bit CRC table
var
  i,j: integer;
  r: DWORD;
begin
  for i:= 0 to 255 do
  begin
    r := i;
    for j:=1 to 8 do
      if (r and 1) = 1 then
        r := (r shr 1) xor DWORD($EDB88320)
      else
        r := (r shr 1);

      CRC32Table[i] := r
  end;
end;

function SZCRC32Update(P: Pointer; ByteCount: LongInt; CurCrc : DWORD): DWORD;
// Updating existed 32-bit CRC with new calaculated
var
  CRCValue: DWORD;
  i: LongInt;
  b: ^Byte;
begin
  b := p;
  CRCValue := CurCrc;
  for i := 1 to ByteCount do
  begin
    CRCvalue := (CRCvalue shr 8) xor
                CRC32Table[b^ xor byte(CRCvalue and $FF)];
    inc(b);
  end;
  Result := CRCValue;
end;

function CRC32Str(P: PChar; longitud: LongInt): DWORD;
// PKzip compatible - results with inverted bits
begin
  Result := not DWORD(SZCRC32Update(P, longitud, CRC32BASE));
end;

function CRC32File(const FileName: string): Cardinal;
// Calculates the 32-bit CRC of a file
// PKZip compatible
var
  FileStream: TFileStream;
begin
  FileStream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := not DWORD(SZCRC32UpdateStream(FileStream, CRC32BASE));
  finally
    FileStream.Free;
  end;
end;

function SZCRC32UpdateStream(Stream: TStream; CurCrc: DWORD): DWORD;
const
  CRC32BUFSIZE = 2048;
var
  BufArray: array[0..(CRC32BUFSIZE-1)] of Byte;
  Res: LongInt;
  CRC32: DWORD;
begin
  CRC32 := CurCrc;
  repeat
    Res := Stream.Read(BufArray, CRC32BUFSIZE);
    CRC32 := SZCRC32Update(@BufArray, Res, CRC32);
  until (Res <> LongInt(CRC32BUFSIZE));
  Result := CRC32;
end;

initialization
  SZCRC32MakeTable;
end.

