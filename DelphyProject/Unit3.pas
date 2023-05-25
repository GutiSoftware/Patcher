unit Unit3;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, StrUtils, jpeg, ExtCtrls, ComCtrls;

type
 TTextSectionInfo = record
    Offset: Integer;
    Size: Integer;
    RVA: DWORD;
    VA: UInt64;
    end;
  IMAGE_OPTIONAL_HEADER64 = record
    Magic: Word;
    MajorLinkerVersion: Byte;
    MinorLinkerVersion: Byte;
    SizeOfCode: DWORD;
    SizeOfInitializedData: DWORD;
    SizeOfUninitializedData: DWORD;
    AddressOfEntryPoint: DWORD;
    BaseOfCode: DWORD;
    ImageBase: UInt64;
    SectionAlignment: DWORD;
    FileAlignment: DWORD;
    MajorOperatingSystemVersion: Word;
    MinorOperatingSystemVersion: Word;
    MajorImageVersion: Word;
    MinorImageVersion: Word;
    MajorSubsystemVersion: Word;
    MinorSubsystemVersion: Word;
    Win32VersionValue: DWORD;
    SizeOfImage: DWORD;
    SizeOfHeaders: DWORD;
    CheckSum: DWORD;
    Subsystem: Word;
    DllCharacteristics: Word;
    SizeOfStackReserve: UInt64;
    SizeOfStackCommit: UInt64;
    SizeOfHeapReserve: UInt64;
    SizeOfHeapCommit: UInt64;
    LoaderFlags: DWORD;
    NumberOfRvaAndSizes: DWORD;
    DataDirectory: array[0..IMAGE_NUMBEROF_DIRECTORY_ENTRIES - 1] of IMAGE_DATA_DIRECTORY;
  end;

  IMAGE_NT_HEADERS64 = record
    Signature: DWORD;
    FileHeader: IMAGE_FILE_HEADER;
    OptionalHeader: IMAGE_OPTIONAL_HEADER64;
  end;

  PImageNtHeaders64 = ^IMAGE_NT_HEADERS64;

  TForm3 = class(TForm)
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    ProcessFile: TButton;
    ButtonLoadFile: TButton;
    Image1: TImage;
    BtnCompareFilesClick: TButton;
    ProgressBar1: TProgressBar;
    OriginalFile: TLabel;
    ModifiedFile: TLabel;
    Label2: TLabel;
    PrrocessFileBack: TButton;
    Label1: TLabel;
    Label3: TLabel;
    Image2: TImage;
    RichEdit1: TRichEdit;
    StatusBar1: TStatusBar;
    procedure ProcessFileClick(Sender: TObject);
    procedure WriteByteToFileStream(AStream: TStream; AValue: Byte);
    procedure ButtonLoadFileClick(Sender: TObject);
    procedure BtnCompareFilesClickClick(Sender: TObject);
    procedure CreateTextFile(const OriginalExeFileName, ModifiedExeFileName: string; TextFile: TStringList);
    procedure PrrocessFileBackClick(Sender: TObject);
    procedure CompareFilesBinary(const FileName1, FileName2: string; TextFile: TStringList);
    function GetDllCharacteristicsOffset(const FileName: string): Integer;
    function IsFileContentValid: Boolean;
    function GetTextSectionInfo(const FileName: string): TTextSectionInfo;
    function GetTextSectionInfo32(const FileName: string): TTextSectionInfo;
    function GetTextSectionInfo64(const FileName: string): TTextSectionInfo;
    procedure FormShow(Sender: TObject);

    private
     IsPEFile: boolean;
     PeW: string;
    FTextSectionInfo: TTextSectionInfo;
       LoadedOrGeneratedTextFileName: string;
         FDllCharacteristicsOffset: Integer;
         procedure LoadTextFileToRichEdit(TextFile: TStringList; RichEdit: TRichEdit);
        // function ExtractCRC32FromLine(Line: string): Cardinal ;
    { Private declarations }
    procedure ModifyFile(const ExeFileName, ModifiedExeFileName: string; ProgressBar: TProgressBar);
    procedure ModifyFileBack(const ExeFileName, ModifiedExeFileName: string; ProgressBar: TProgressBar);

    function FilesHaveSameLength(const FileName1, FileName2: string): Boolean;
  //public

  public
    { Public declarations }
  end;

 var
  Form3: TForm3;

implementation
  uses X_CRC32;
  const
  IMAGE_NT_OPTIONAL_HDR32_MAGIC = $10B;
  IMAGE_NT_OPTIONAL_HDR64_MAGIC = $20B;

{$R *.dfm}



procedure TForm3.LoadTextFileToRichEdit(TextFile: TStringList; RichEdit: TRichEdit);
var
  I: Integer;
begin
  RichEdit.Lines.BeginUpdate;
  try
    RichEdit.Lines.Clear;

    for I := 0 to TextFile.Count - 1 do
    begin
      if Pos('CRC32:', TextFile.Strings[I]) > 0 then
    begin
      RichEdit1.SelAttributes.Color := clNavy;
      RichEdit1.SelAttributes.Style := [fsBold];
      RichEdit1.SelText := Copy(TextFile.Strings[I], 1, Pos('CRC32:', TextFile.Strings[I]) - 1);

      RichEdit1.SelAttributes.Color := clOlive;
      RichEdit1.SelAttributes.Style := [];
      RichEdit1.SelText := 'CRC32: ';

      RichEdit1.SelAttributes.Color := clOlive;
      RichEdit1.SelAttributes.Style := [fsBold];
      RichEdit1.SelText := Copy(TextFile.Strings[I], Pos('CRC32:', TextFile.Strings[I]) + 6, Length(TextFile.Strings[I])) + #13#10;
    end
    else if TextFile.Strings[I] = 'HexOffset --> [DLL Characteristics]' then
    begin
      RichEdit1.SelAttributes.Color := clPurple;
      RichEdit1.SelAttributes.Style := [fsBold];
      RichEdit1.SelText := 'HexOffset --> ';

      RichEdit1.SelAttributes.Color := clRed;
      RichEdit1.SelAttributes.Style := [fsBold];
      RichEdit1.SelText := '[DLL Characteristics]' + #13#10;
    end
    else if Pos('HexOffset', TextFile.Strings[I]) > 0 then
      begin
        RichEdit.SelAttributes.Color := clPurple;
        RichEdit.SelAttributes.Style := [fsBold];
        RichEdit.SelText := TextFile.Strings[I] + #13#10;
      end
    else
    begin
      RichEdit1.SelAttributes.Color := clNavy;
      RichEdit1.SelAttributes.Style := [];
      RichEdit1.SelText := TextFile.Strings[I] + #13#10;
    end;
    end;
  finally
    RichEdit.Lines.EndUpdate;
  end;
end;


procedure TForm3.CompareFilesBinary(const FileName1, FileName2: string; TextFile: TStringList);
const
  BufferSize = 4096;
var
  FileStream1, FileStream2: TFileStream;
  Buffer1, Buffer2: array[0..BufferSize-1] of Byte;
  BytesRead1, BytesRead2, I, FilePosition: Integer;
  InSection, PrevInSection: Boolean;
  RVA, VA: UInt64;
begin
  FileStream1 := TFileStream.Create(FileName1, fmOpenRead);
  FileStream2 := TFileStream.Create(FileName2, fmOpenRead);

  ProgressBar1.Max := FileStream1.Size;
  ProgressBar1.Position := 0;

  InSection := False;
  //PrevInSection := False;
  FilePosition := 0;
  try
    repeat
      BytesRead1 := FileStream1.Read(Buffer1, BufferSize);
      BytesRead2 := FileStream2.Read(Buffer2, BufferSize);

      if not CompareMem(@Buffer1, @Buffer2, BytesRead1) then
      begin
        for I := 0 to BytesRead1 - 1 do
        begin
          PrevInSection := InSection;
          if Buffer1[I] <> Buffer2[I] then
          begin
            if not InSection then
            begin
              if IsPEFile then
              begin
                // Calcular el RVA para el offset actual
                RVA := DWORD(Int64(FilePosition) + Int64(I) - Int64(FTextSectionInfo.Offset) + Int64(FTextSectionInfo.RVA));

                // Calcular el VA para el offset actual
                VA := UInt64(FTextSectionInfo.VA) + RVA - UInt64(FTextSectionInfo.RVA);

                if not PrevInSection then
                begin
                  if FilePosition + I = FDllCharacteristicsOffset then
                  begin
                    TextFile.Add('HexOffset/RVA/VA  (DLL Characteristics)  ' +PeW);
                    PeW := '';
                  end
                  else
                  begin
                    TextFile.Add('HexOffset/RVA/VA  '+PeW);
                     PeW := '';
                  end;
                  TextFile.Add(Format('%X/%X/%X', [FilePosition + I, RVA, VA]));
                  PeW := ''
                end;
              end
              else
              begin
                TextFile.Add('HexOffset');
                TextFile.Add(Format('%X/', [FilePosition + I]));
              end;

              TextFile.Add('HexOriginalBytes');
              TextFile.Strings[TextFile.Count - 1] := TextFile.Strings[TextFile.Count - 1] + #13#10 + IntToHex(Buffer1[I], 2);
              TextFile.Add('HexPatchesBytes');
              TextFile.Strings[TextFile.Count - 1] := TextFile.Strings[TextFile.Count - 1] + #13#10 + IntToHex(Buffer2[I], 2);
              InSection := True;
            end
            else
            begin
              TextFile.Strings[TextFile.Count - 2] := TextFile.Strings[TextFile.Count - 2] + ' ' + IntToHex(Buffer1[I], 2);
              TextFile.Strings[TextFile.Count - 1] := TextFile.Strings[TextFile.Count - 1] + ' ' + IntToHex(Buffer2[I], 2);
            end;
          end
          else
          begin
            if InSection then
            begin
              InSection := False;
            end;
          end;
        end;
      end;

       Inc(FilePosition, BytesRead1);
      ProgressBar1.Position := FilePosition;

    until (BytesRead1 <> BufferSize) or (BytesRead2 <> BufferSize);

  finally
    FileStream1.Free;
    FileStream2.Free;
  end;
end;

 //escribe un valor de byte en el archivo modificado
 procedure TForm3.WriteByteToFileStream(AStream: TStream; AValue: Byte);
begin
  AStream.Write(AValue, SizeOf(Byte));
end;
//Comprueba si dos archivos tienen la misma longitud
function TForm3.FilesHaveSameLength(const FileName1, FileName2: string): Boolean;
var
  FileStream1, FileStream2: TFileStream;
begin
  FileStream1 := TFileStream.Create(FileName1, fmOpenRead);
  FileStream2 := TFileStream.Create(FileName2, fmOpenRead);
  try
    Result := FileStream1.Size = FileStream2.Size;
  finally
    FileStream1.Free;
    FileStream2.Free;
  end;
end;

procedure TForm3.FormShow(Sender: TObject);
begin
BtnCompareFilesClick.SetFocus
end;

function TForm3.GetDllCharacteristicsOffset(const FileName: string): Integer;
var
  PEFile: TMemoryStream;
  FileStream: TFileStream;
  DOSHeader: PImageDosHeader;
  NTHeaders: PImageNtHeaders;
  OptionalHeader: PImageOptionalHeader;
 //  OptionalHeader: PImageOptionalHeader64;  <-(en delphi 2021)
begin
  Result := -1;
  PEFile := TMemoryStream.Create;
  try
    FileStream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
      PEFile.LoadFromStream(FileStream);
    finally
      FileStream.Free;
    end;

       DOSHeader := PEFile.Memory;
    NTHeaders := PImageNtHeaders(NativeUInt(PEFile.Memory) + DOSHeader._lfanew);
    OptionalHeader := @(NTHeaders.OptionalHeader);
    
    if (DOSHeader.e_magic = IMAGE_DOS_SIGNATURE) and (NTHeaders.Signature = IMAGE_NT_SIGNATURE) then
    begin
      Result := NativeUInt(@OptionalHeader.DllCharacteristics) - NativeUInt(PEFile.Memory);
    end;
  finally
    PEFile.Free;
  end;
end;

function TForm3.GetTextSectionInfo(const FileName: string): TTextSectionInfo;
var
  PEFile: TMemoryStream;
  FileStream: TFileStream;
  DOSHeader: PImageDosHeader;
  NTHeaders: PImageNtHeaders;
begin
  PEFile := TMemoryStream.Create;
  IsPEFile := False;
  
  try
    FileStream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
      PEFile.LoadFromStream(FileStream);
    finally
      FileStream.Free;
    end;

    DOSHeader := PEFile.Memory;
    NTHeaders := PImageNtHeaders(NativeUInt(PEFile.Memory) + DOSHeader._lfanew);

    if (DOSHeader.e_magic = IMAGE_DOS_SIGNATURE) and (NTHeaders.Signature = IMAGE_NT_SIGNATURE) then
    begin
      if NTHeaders.OptionalHeader.Magic = IMAGE_NT_OPTIONAL_HDR32_MAGIC then
      begin
        Result := GetTextSectionInfo32(FileName);
        IsPEFile := True;
        PeW := 'Win PE 32'
      end
      else if NTHeaders.OptionalHeader.Magic = IMAGE_NT_OPTIONAL_HDR64_MAGIC then
      begin
        Result := GetTextSectionInfo64(FileName);
        IsPEFile := True;
         PeW := 'Win PE 64'
      end;
    end;
  finally
    PEFile.Free;
  end;
end;

function TForm3.GetTextSectionInfo32(const FileName: string): TTextSectionInfo;
var
  PEFile: TMemoryStream;
  FileStream: TFileStream;
  DOSHeader: PImageDosHeader;
  NTHeaders: PImageNtHeaders;
  SectionHeader: PImageSectionHeader;
  I: Integer;
begin
  Result.Offset := -1;
  Result.Size := -1;
  Result.RVA := 0;
  Result.VA := 0;
  PEFile := TMemoryStream.Create;
  try
    FileStream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
      PEFile.LoadFromStream(FileStream);
    finally
      FileStream.Free;
    end;

    DOSHeader := PEFile.Memory;
    NTHeaders := PImageNtHeaders(NativeUInt(PEFile.Memory) + DOSHeader._lfanew);

    if (DOSHeader.e_magic = IMAGE_DOS_SIGNATURE) and (NTHeaders.Signature = IMAGE_NT_SIGNATURE) then
    begin
      SectionHeader := PImageSectionHeader(NativeUInt(NTHeaders) + SizeOf(IMAGE_NT_HEADERS));
      for I := 0 to NTHeaders.FileHeader.NumberOfSections - 1 do
      begin
        if (NTHeaders.OptionalHeader.AddressOfEntryPoint >= SectionHeader.VirtualAddress) and
           (NTHeaders.OptionalHeader.AddressOfEntryPoint < SectionHeader.VirtualAddress + SectionHeader.Misc.VirtualSize) then
        begin
          Result.Offset := SectionHeader.PointerToRawData;
          Result.Size := SectionHeader.SizeOfRawData;
          Result.RVA := SectionHeader.VirtualAddress;
          Result.VA := NTHeaders.OptionalHeader.ImageBase + Result.RVA;
          Break;
        end;
        Inc(SectionHeader);
      end;
    end;
  finally
    PEFile.Free;
  end;
end;

function TForm3.GetTextSectionInfo64(const FileName: string): TTextSectionInfo;
var
  PEFile: TMemoryStream;
  FileStream: TFileStream;
  DOSHeader: PImageDosHeader;
  NTHeaders64: PImageNtHeaders64;
  SectionHeader: PImageSectionHeader;
  I: Integer;
begin
  Result.Offset := -1;
  Result.Size := -1;
  Result.RVA := 0;
  Result.VA := 0;
  PEFile := TMemoryStream.Create;
  try
    FileStream := TFileStream.Create(FileName, fmOpenRead or fmShareDenyNone);
    try
      PEFile.LoadFromStream(FileStream);
    finally
      FileStream.Free;
    end;

    DOSHeader := PEFile.Memory;
    NTHeaders64 := PImageNtHeaders64(NativeUInt(PEFile.Memory) + DOSHeader._lfanew);

    if (DOSHeader.e_magic = IMAGE_DOS_SIGNATURE) and (NTHeaders64.Signature = IMAGE_NT_SIGNATURE) then
    begin
      SectionHeader := PImageSectionHeader(NativeUInt(NTHeaders64) + SizeOf(IMAGE_NT_HEADERS64));
      for I := 0 to NTHeaders64.FileHeader.NumberOfSections - 1 do
      begin
        if (NTHeaders64.OptionalHeader.AddressOfEntryPoint >= SectionHeader.VirtualAddress) and
           (NTHeaders64.OptionalHeader.AddressOfEntryPoint < SectionHeader.VirtualAddress + SectionHeader.Misc.VirtualSize) then
        begin
          Result.Offset := SectionHeader.PointerToRawData;
          Result.Size := SectionHeader.SizeOfRawData;
          Result.RVA := SectionHeader.VirtualAddress;
          Result.VA := NTHeaders64.OptionalHeader.ImageBase + UInt64(Result.RVA);
          Break
                  end;
        Inc(SectionHeader);
      end;
    end;
  finally
    PEFile.Free;
  end;
end;


//// Extrae el número de una cadena y devuelve el valor predeterminado si no hay número en la cadena
function ExtractNumber(const Line: string; DefaultValue: Integer = 0): string;
var
  I: Integer;
begin
  Result := '';
  for I := 1 to Length(Line) do
  begin
    if Pos(Line[I], '0123456789') > 0 then
      Result := Result + Line[I]
    else
      Break;
  end;

  if Result = '' then
    Result := IntToStr(DefaultValue);
end;
//Compara dos archivos y crea un archivo de texto con las diferencias entre ellos.
procedure TForm3.CreateTextFile(const OriginalExeFileName, ModifiedExeFileName: string; TextFile: TStringList);
var
  CRC32Original, CRC32Modified: Cardinal;
  //I: Integer;
begin
  // Calcular el CRC32 de los archivos original y modificado
  CRC32Original := CRC32File(OriginalExeFileName);
  CRC32Modified := CRC32File(ModifiedExeFileName);

  // Limpiar RichEdit1 antes de agregar contenido
  RichEdit1.Clear;
  TextFile.Add(ExtractFileName(OriginalExeFileName) + ' CRC32: ' + IntToHex(CRC32Original, 8));
  TextFile.Add(ExtractFileName(ModifiedExeFileName) + ' CRC32: ' + IntToHex(CRC32Modified, 8));

  // Obtener el offset de DllCharacteristics y almacenarlo en la variable
  FDllCharacteristicsOffset := GetDllCharacteristicsOffset(OriginalExeFileName);

  // Obtener la información de la sección .text y almacenarla en FTextSectionInfo
  FTextSectionInfo := GetTextSectionInfo(OriginalExeFileName);

  // Llama al procedimiento modificado CompareFilesBinary con TextFile como tercer parámetro
  CompareFilesBinary(OriginalExeFileName, ModifiedExeFileName, TextFile);

  // Agregar las líneas de TextFile a RichEdit1
  LoadTextFileToRichEdit(TextFile, RichEdit1);

  // Restablecer ProgressBar1
  ProgressBar1.Position := 0;
end;


//Ejecuta la comparación de dos archivos
procedure TForm3.BtnCompareFilesClickClick(Sender: TObject);
var
  OriginalFileName, ModifiedFileName, OutputFileName: string;
  TextFile: TStringList;
  SaveResult: Boolean;
  //TextSectionInfo: TTextSectionInfo;
begin
  OriginalFile.Visible := True;
  OriginalFile.Caption := 'Original file: ';
  OpenDialog1.FileName := '';
  OpenDialog1.Title := 'Select the original file:';

  if OpenDialog1.Execute then
  begin
    OriginalFileName := OpenDialog1.FileName;
    OriginalFile.Caption := 'Original file: ' + ExtractFileName(OriginalFileName);
    ModifiedFile.Visible := True;
    ModifiedFile.Caption := 'Modified file: ';
    OpenDialog1.FileName := '';
    OpenDialog1.Title := 'Select the modified file:';

    while True do
    begin
      if OpenDialog1.Execute then
      begin
        ModifiedFileName := OpenDialog1.FileName;
        if OriginalFileName = ModifiedFileName then
        begin
          MessageDlg('There can be no differences if you choose the same file. Please select a different file.', mtWarning, [mbOK], 0);
        end
        else
        begin
          ModifiedFile.Caption := 'Modified file: ' +  ExtractFileName(ModifiedFileName);
          Application.ProcessMessages;
          Break;
        end;
      end
      else
        Exit;
    end;

    if FilesHaveSameLength(OriginalFileName, ModifiedFileName) then
    begin
      TextFile := TStringList.Create;
      label2.Visible := True;
      Application.ProcessMessages;
      try
        CreateTextFile(OriginalFileName, ModifiedFileName, TextFile);
        label2.Visible := False;
        SaveDialog1.FileName := ChangeFileExt(ExtractFileName(OriginalFileName), '.txt');
        SaveDialog1.InitialDir := ExtractFilePath(OriginalFileName);
        SaveDialog1.Title := 'Save changes file:';

        repeat
          if SaveDialog1.Execute then
          begin
            OutputFileName := SaveDialog1.FileName;
            SaveResult := not FileExists(OutputFileName) or
                          (MessageDlg('The file already exists. Do you want to overwrite it?', mtConfirmation, [mbYes, mbNo], 0) = mrYes);
            if SaveResult then
            begin
              TextFile.SaveToFile(OutputFileName);
              LoadedOrGeneratedTextFileName := ExtractFileName(OutputFileName);

              ShowMessage('The text file was created successfully! ' + OutputFileName);
            end;
          end
          else
            SaveResult := True;
        until SaveResult;

      finally
        TextFile.Free;
      end;
    end
    else
    begin
      ShowMessage('The files do not have the same length. Please select two files with the same length.');
      OriginalFile.Caption := 'Original file: ';
      ModifiedFile.Caption := 'Modified file: ';
    end;
  end;
  processFile.Enabled := true;
  prrocessFileBack.Enabled := true;

end;

//Carga un fichero de texto previamente creado con diferencias entre dos archivos
procedure TForm3.ButtonLoadFileClick(Sender: TObject);
var
  TextFile: TStringList;
  //I: Integer;
begin
  OriginalFile.Visible := False;
  ModifiedFile.Visible := False;
  OpenDialog1.FileName := '';
  OpenDialog1.Title := 'Open changes file:';

  if OpenDialog1.Execute then
  begin
    LoadedOrGeneratedTextFileName := OpenDialog1.FileName;
    TextFile := TStringList.Create;
    try
      TextFile.LoadFromFile(LoadedOrGeneratedTextFileName);

     LoadTextFileToRichEdit(TextFile, RichEdit1);
      if not IsFileContentValid then
      begin
        ShowMessage('The file is not valid. Please select a file with correct content.');
        ProcessFile.Enabled := False;
        PrrocessFileBack.Enabled := False;
        Exit;
      end;
     ProcessFile.Enabled := True;
      PrrocessFileBack.Enabled := True;
    finally
      TextFile.Free;
    end;
  end;
end;




//Modifica un archivo aplicando las diferencias almacenadas en un fichero de texto.
procedure TForm3.ModifyFile(const ExeFileName, ModifiedExeFileName: string; ProgressBar: TProgressBar);

var
  FileStream, ModifiedFileStream: TFileStream;
  I, K: Integer;
  HexBytesToFind, HexBytesToChange: TStringList;
  HexByteToFind, HexByteToChange: string;
  Found: Boolean;
  Offset: Integer;
  CurrentByte: Byte;
  TotalSteps, CurrentStep: Integer;
begin
  FileStream := TFileStream.Create(ExeFileName, fmOpenRead);
  ModifiedFileStream := TFileStream.Create(ModifiedExeFileName, fmCreate);

  // Establecer el número total de pasos y el paso actual para la barra de progreso
  TotalSteps := RichEdit1.Lines.Count;
 // CurrentStep := 0;

  ProgressBar1.Max := TotalSteps;
  ProgressBar1.Position := 0;

  try
    ModifiedFileStream.CopyFrom(FileStream, FileStream.Size);
    FileStream.Position := 0;

    HexBytesToFind := TStringList.Create;
    HexBytesToChange := TStringList.Create;
    try
      I := 3;
      while I < RichEdit1.Lines.Count do
      begin
        Offset := StrToInt('$' + Copy(RichEdit1.Lines[I], 1, Pos('/', RichEdit1.Lines[I]) - 1));


        Inc(I, 2);
        HexBytesToFind.DelimitedText := RichEdit1.Lines[I];
        Inc(I, 2);
        HexBytesToChange.DelimitedText := RichEdit1.Lines[I];

        if HexBytesToFind.Count <> HexBytesToChange.Count then
        begin
          ShowMessage('The number of expected bytes does not match those to be changed at the offset ' + IntToHex(Offset, 4) + #13#10 + 'Check the file!!');
        end;

        FileStream.Position := Offset;
        Found := True;

        for K := 0 to HexBytesToFind.Count - 1 do
        begin
          HexByteToFind := HexBytesToFind[K];
          FileStream.Read(CurrentByte, SizeOf(Byte));
          if CurrentByte <> StrToInt('$' + HexByteToFind) then
          begin
            Found := False;
            Break;
          end;
        end;

        if Found then
        begin
          ModifiedFileStream.Position := Offset;
          for K := 0 to HexBytesToChange.Count - 1 do
          begin
            HexByteToChange := HexBytesToChange[K];
            WriteByteToFileStream(ModifiedFileStream, StrToInt('$' + HexByteToChange));
          end;
        end
        else
        begin
          ShowMessage('Warning: byte pattern not found at the offset ' + IntToHex(Offset, 4) + '. The file may be incorrect.');
        end;

        Inc(I, 2);

        // Actualizar ProgressBar1
        CurrentStep := I;
        ProgressBar1.Position := CurrentStep;

      end;

    finally
      HexBytesToFind.Free;
      HexBytesToChange.Free;
    end;
  finally
    FileStream.Free;
    ModifiedFileStream.Free;
  end;

  // Restablecer ProgressBar1
  ProgressBar1.Position := 0;

end;

procedure TForm3.ModifyFileBack(const ExeFileName, ModifiedExeFileName: string; ProgressBar: TProgressBar);

var
  FileStream, ModifiedFileStream: TFileStream;
  I, K: Integer;
  HexBytesToFind, HexBytesToChange: TStringList;
  HexByteToFind, HexByteToChange: string;
  Found: Boolean;
  Offset: Integer;
  CurrentByte: Byte;
  TotalSteps, CurrentStep: Integer;
begin
  FileStream := TFileStream.Create(ExeFileName, fmOpenRead);
  ModifiedFileStream := TFileStream.Create(ModifiedExeFileName, fmCreate);

  // Establecer el número total de pasos y el paso actual para la barra de progreso
  TotalSteps := RichEdit1.Lines.Count;
//  CurrentStep := 0;

  ProgressBar1.Max := TotalSteps;
  ProgressBar1.Position := 0;

  try
    ModifiedFileStream.CopyFrom(FileStream, FileStream.Size);
    FileStream.Position := 0;

    HexBytesToFind := TStringList.Create;
    HexBytesToChange := TStringList.Create;
    try
      I := 3;
      while I < RichEdit1.Lines.Count do
      begin
        Offset := StrToInt('$' + Copy(RichEdit1.Lines[I], 1, Pos('/', RichEdit1.Lines[I]) - 1));


        Inc(I, 2);
        HexBytesToChange.DelimitedText := RichEdit1.Lines[I]; // Intercambiar HexBytesToChange y HexBytesToFind
        Inc(I, 2);
        HexBytesToFind.DelimitedText := RichEdit1.Lines[I]; // Intercambiar HexBytesToChange y HexBytesToFind

        if HexBytesToFind.Count <> HexBytesToChange.Count then
        begin
          ShowMessage('The number of expected bytes does not match those to be changed at the offset ' + IntToHex(Offset, 4) + #13#10 + 'Check the file!!');
        end;

        FileStream.Position := Offset;
        Found := True;

        for K := 0 to HexBytesToFind.Count - 1 do
        begin
          HexByteToFind := HexBytesToFind[K];
          FileStream.Read(CurrentByte, SizeOf(Byte));
          if CurrentByte <> StrToInt('$' + HexByteToFind) then
          begin
            Found := False;
            Break;
          end;
        end;

        if Found then
        begin
          ModifiedFileStream.Position := Offset;
          for K := 0 to HexBytesToChange.Count - 1 do
          begin
            HexByteToChange := HexBytesToChange[K];
            WriteByteToFileStream(ModifiedFileStream, StrToInt('$' + HexByteToChange));
          end;
        end
        else
        begin
          ShowMessage('Warning: byte pattern not found at the offset ' + IntToHex(Offset, 4) + '. The file may be incorrect.');
        end;

        Inc(I, 2);

        // Actualizar ProgressBar1
        CurrentStep := I;
        ProgressBar1.Position := CurrentStep;

      end;

    finally
      HexBytesToFind.Free;
      HexBytesToChange.Free;
    end;
  finally
    FileStream.Free;
    ModifiedFileStream.Free;
  end;

  // Restablecer ProgressBar1
  ProgressBar1.Position := 0;

end;



 //Aplica las diferencias almacenadas en un fichero de texto a un archivo y guarda el archivo modificado
procedure TForm3.ProcessFileClick(Sender: TObject);
var
  OriginalFileName, ModifiedFileName, ModifiedExeFileName: string;
  CRC32Original, CRC32FromMemo: Cardinal;
  SaveResult: Boolean;
begin
  OriginalFile.Visible := True;
  OriginalFile.Caption := 'Original file: ';
  OriginalFileName := Copy(RichEdit1.Lines[0], 1, Pos(' ', RichEdit1.Lines[0]) - 1); // Extrae el nombre del archivo antes del CRC32
  ModifiedFileName := Copy(RichEdit1.Lines[1], 1, Pos(' ', RichEdit1.Lines[1]) - 1); // Extrae el nombre del archivo antes del CRC32

  // Establecer el nombre propuesto en SaveDialog1
  SaveDialog1.FileName := ExtractFileName(ModifiedFileName);
  SaveDialog1.InitialDir := ExtractFilePath(OriginalFileName);

  // Muestra el cuadro de diálogo OpenDialog1 para seleccionar el archivo original
  OpenDialog1.InitialDir := SaveDialog1.InitialDir;
  // Establece el nombre del archivo propuesto en OpenDialog1
  OpenDialog1.FileName := OriginalFileName;
  OpenDialog1.Title := 'Select the original file:';
  if OpenDialog1.Execute then
  begin
    OriginalFileName := OpenDialog1.FileName;
    OriginalFile.Caption := 'Original file: ' + ExtractFileName(OriginalFileName);
    ModifiedFile.Visible := True;
    ModifiedFile.Caption := 'Modified file: ';

    // Calcular el CRC32 del archivo original seleccionado
    CRC32Original := CRC32File(OriginalFileName);
    // Extraer el CRC32 del campo cero de RichEdit1
   CRC32FromMemo := StrToInt('$' + Copy(RichEdit1.Lines[0], Pos(':', RichEdit1.Lines[0]) + 3, 9));


    // Verificar si el CRC32 coincide
    if CRC32Original <> CRC32FromMemo then
    begin
      ShowMessage('The CRC32 of the original file does not match that of the chosen file.');
      Exit;
    end;
       SaveDialog1.Title := 'Save modified file as:';
  repeat
    if SaveDialog1.Execute then
    begin
      ModifiedExeFileName := SaveDialog1.FileName;
      SaveResult := not FileExists(ModifiedExeFileName) or
                    (MessageDlg('The file already exists. Do you want to overwrite it?', mtConfirmation, [mbYes, mbNo], 0) = mrYes);
      if SaveResult then
      begin
        ModifiedFile.Caption := 'Modified file: ' +  ExtractFileName(ModifiedFileName);
        Application.ProcessMessages;

        if not FileExists(OriginalFileName) then
        begin
          ShowMessage('The original file cannot be found: ' + OriginalFileName);
          Exit;
        end;

        ModifyFile(OriginalFileName, ModifiedExeFileName, ProgressBar1);

        ShowMessage('The modified file has been saved successfully.');
      end;
    end
    else
      SaveResult := True;
  until SaveResult;
end;
 end;

procedure TForm3.PrrocessFileBackClick(Sender: TObject);
var
  OriginalFileName, ModifiedFileName, ModifiedExeFileName: string;
  CRC32Modified, CRC32FromMemo: Cardinal;
  SaveResult: Boolean;
begin
  OriginalFile.Visible := True;
  OriginalFile.Caption := 'Modified file: ';
  OriginalFileName := Copy(RichEdit1.Lines[0], 1, Pos(' ', RichEdit1.Lines[0]) - 1); // Extrae el nombre del archivo antes del CRC32
  ModifiedFileName := Copy(RichEdit1.Lines[1], 1, Pos(' ', RichEdit1.Lines[1]) - 1); // Extrae el nombre del archivo antes del CRC32

  // Establecer el nombre propuesto en SaveDialog1
  SaveDialog1.FileName := ExtractFileName(OriginalFileName);
  SaveDialog1.InitialDir := ExtractFilePath(ModifiedFileName);

  // Muestra el cuadro de diálogo OpenDialog1 para seleccionar el archivo modificado
  OpenDialog1.InitialDir := SaveDialog1.InitialDir;
  OpenDialog1.FileName := ModifiedFileName; // Establece el nombre del archivo propuesto en OpenDialog1
  OpenDialog1.Title := 'Select the modified file:';
  if OpenDialog1.Execute then
  begin
    ModifiedFileName := OpenDialog1.FileName;
    OriginalFile.Caption := 'Modified file: ' + ExtractFileName(ModifiedFileName);
    ModifiedFile.Visible := True;
    ModifiedFile.Caption := 'Original file: ';

    // Calcular el CRC32 del archivo modificado seleccionado
    CRC32Modified := CRC32File(ModifiedFileName);
    // Extraer el CRC32 del campo uno de RichEdit1
    CRC32FromMemo := StrToInt('$' + Copy(RichEdit1.Lines[1], Pos(':', RichEdit1.Lines[1]) + 3, 9));

    // Verificar si el CRC32 coincide
    if CRC32Modified <> CRC32FromMemo then
    begin
      ShowMessage('The CRC32 of the modified file does not match that of the chosen file.');
      Exit;
    end;

    SaveDialog1.Title := 'Save original file as:';
    repeat
      if SaveDialog1.Execute then
      begin
        ModifiedExeFileName := SaveDialog1.FileName;
        SaveResult := not FileExists(ModifiedExeFileName) or
                      (MessageDlg('The file already exists. Do you want to overwrite it?', mtConfirmation, [mbYes, mbNo], 0) = mrYes);
        if SaveResult then
        begin
          ModifiedFile.Caption := 'Original file: ' + ExtractFileName(OriginalFileName);
          Application.ProcessMessages;

          if not FileExists(ModifiedFileName) then
          begin
            ShowMessage('The modified file cannot be found: ' + ModifiedFileName);
            Exit;
          end;

          ModifyFileBack(ModifiedFileName, ModifiedExeFileName, ProgressBar1);

          ShowMessage('The original file has been restored successfully.');
        end;
      end
      else
        SaveResult := True;
    until SaveResult;
  end;
end;

// Comprobar los dos primeros campos de Memo1 para un valor CRC32 válido
function TForm3.IsFileContentValid: Boolean;
var
  I: Integer;
  CRC32FromRichEdit: Cardinal;
  IsValid: Boolean;
begin
  Result := False;

  for I := 0 to 1 do
  begin
    IsValid := TryStrToInt('$' + Copy(RichEdit1.Lines[I], Pos(':', RichEdit1.Lines[I]) + 3, 9), Integer(CRC32FromRichEdit));
    if IsValid then
    begin
      if I = 1 then
        Result := True;
    end
    else
    begin
      Result := False;
      Break;
    end;
  end;
end;



end.


