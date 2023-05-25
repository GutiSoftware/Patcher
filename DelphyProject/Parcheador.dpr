program  Parcheador;

uses
  Forms,
  Unit3 in 'Unit3.pas' {Form3},
  X_CRC32 in 'X_CRC32.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TForm3, Form3);
  Application.Run;
end.
