unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.ComCtrls, Vcl.StdCtrls, Vcl.Samples.Spin,
  mormot.net.async, mormot.net.sock, mormot.core.base, mormot.core.log, mormot.core.rtti,
  Vcl.ExtCtrls;

type
  TConnection = class(TAsyncConnection)
  protected
    function OnRead: TPollAsyncSocketOnReadWrite; override;
    procedure AfterCreate; override;
    procedure OnClose; override;
  end;

  TClient = class(TAsyncClient)
  private
    LogFamily: TSynLogFamily;
  public
    constructor Create(Const aRemoteHost, aPort: RawUtf8); reintroduce;
    destructor Destroy; override;
  end;

  TForm1 = class(TForm)
    Edit1: TEdit;
    Label1: TLabel;
    SpinEdit1: TSpinEdit;
    Label2: TLabel;
    Button1: TButton;
    Memo1: TMemo;
    StatusBar1: TStatusBar;
    Edit2: TEdit;
    Button2: TButton;
    ConnectionChecker: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure ConnectionCheckerTimer(Sender: TObject);
  private
    { Private declarations }
    Client: TClient;
    ServerConnection: TConnection;
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

// TConnection methods

function TConnection.OnRead: TPollAsyncSocketOnReadWrite;
var
  Buffer: RawUtf8;
begin
  FastSetString(Buffer, frd.Buffer, frd.Len);
  Result := soContinue;
  form1.Memo1.Lines.Add('Received Data: ' + Buffer); // Update Memo1 with received data
  frd.Reset;
end;

procedure TConnection.AfterCreate;
begin
  inherited AfterCreate;
  Form1.ServerConnection := Self;
  form1.Memo1.Lines.Add('Connected to Server'); // Update Memo1
  form1.StatusBar1.Panels[0].Text := 'Connection Status: Connected!'; // Update StatusBar1
  form1.ConnectionChecker.Enabled:=false;
end;

procedure TConnection.OnClose;
begin
  inherited;
  form1.Memo1.Lines.Add('Disconnected from Server'); // Update Memo1
  form1.StatusBar1.Panels[0].Text := 'Connection Status: Disconnected!'; // Update StatusBar1
  form1.Button1.Enabled:=true;
end;

// TClient methods

constructor TClient.Create(const aRemoteHost, aPort: UTF8String);
begin
  LogFamily := TSynLog.Family;
  LogFamily.Level := LOG_VERBOSE;
  LogFamily.PerThreadLog := ptIdentifiedInOnFile;
  LogFamily.EchoToConsole := LOG_VERBOSE;

  inherited Create(aRemoteHost, aPort, 1, 10, nil, nil, TConnection,
    UTF8String(TClient.ClassName), LogFamily.SynLogClass, [acoVerboseLog], 1);
end;

destructor TClient.Destroy;
begin
  inherited Destroy;
end;

// TForm1 methods

procedure TForm1.Button1Click(Sender: TObject);
var
  IPAddress: RawUtf8;
  Port: RawUtf8;
begin
//clear out any previous messages!
self.Memo1.Clear;

  IPAddress := UTF8Encode(Edit1.Text);
  Port := UTF8Encode(IntToStr(SpinEdit1.Value));

  // Disable the button to prevent multiple connections
  Button1.Enabled := False;

  try
    // Create and connect the client
    Client := TClient.Create(IPAddress, Port);
    Memo1.Lines.Add('Connecting to ' + IPAddress + ':' + Port);
    self.ConnectionChecker.Enabled:=true;

  except
    on E: Exception do
    begin
      Memo1.Lines.Add('Connection failed: ' + E.Message);
      Button1.Enabled := True; // Re-enable the button if connection fails
      Exit;
    end;
  end;

end;

procedure TForm1.Button2Click(Sender: TObject);
begin
 Client.Clients.WriteString(ServerConnection, self.Edit2.Text)
end;

procedure TForm1.ConnectionCheckerTimer(Sender: TObject);
begin
  if (Client = nil) or (Client.Connection = nil) then
  begin
    Memo1.Lines.Add('Not connected.');

    // Clean up the client
    FreeAndNil(Client);

    // Re-enable the connect button
    Button1.Enabled := True;
    ConnectionChecker.Enabled:=false;
  end;
end;


procedure TForm1.FormCreate(Sender: TObject);
begin
  // Initialization if needed
end;

end.
