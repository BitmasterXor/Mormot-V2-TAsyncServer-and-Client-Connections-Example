unit Unit1;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.Samples.Spin,
  mormot.net.async, mormot.net.sock, mormot.core.base, mormot.core.log, mormot.core.rtti,
  Vcl.ComCtrls;

type
  TForm1 = class(TForm)
    Memo1: TMemo;
    SpinEdit1: TSpinEdit;
    Button1: TButton;
    ListView1: TListView;
    Button2: TButton;
    Button3: TButton;
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
  private
    { Private declarations }
    Server: TAsyncServer;
    procedure SendToSelectedClient(ClientID: Integer; const Msg: string);
    procedure SendToAllClients(const Msg: string);
    procedure LogMessage(const Msg: string);
  public
    { Public declarations }
  end;

  TConnection = class(TAsyncConnection)
  protected
    function OnRead: TPollAsyncSocketOnReadWrite; override;
    procedure AfterCreate; override;
    procedure OnClose; override;
  end;

var
  Form1: TForm1;

implementation

{$R *.dfm}

{ TConnection }

function TConnection.OnRead: TPollAsyncSocketOnReadWrite;
var
  Buffer: RawUtf8;
begin
  FastSetString(Buffer, frd.Buffer, frd.Len);
  Result := soContinue;
  TThread.Synchronize(nil, procedure
  begin
    Form1.LogMessage('Received Data: ' + Buffer + ' From Client ID: ' + inttostr(self.Handle));
  end);
  frd.Reset;
end;


procedure TForm1.SendToSelectedClient(ClientID: Integer; const Msg: string);
var
  Conn: TConnection;
  Buffer: TBytes;
  BufferLength: Integer;
begin
  if Assigned(Server) then
  begin
    // Find the connection with the given ClientID
    Conn := TConnection(Server.ConnectionFind(ClientID));
    if Assigned(Conn) then
    begin
      // Prepare the data
      Buffer := TEncoding.UTF8.GetBytes(Msg);
      BufferLength := Length(Buffer);

      // Send the data
      Conn.Send(Buffer, BufferLength);

      LogMessage('Sent "' + Msg + '" to client ID ' + IntToStr(ClientID));
    end
    else
    begin
      LogMessage('Client ID ' + IntToStr(ClientID) + ' not found.');
    end;
  end;
end;

procedure TForm1.SendToAllClients(const Msg: string);
var
  Conn: TConnection;
  Client: TAsyncConnection;
  Buffer: TBytes;
  BufferLength: Integer;
  I: Integer;
  ClientID: Integer;
begin
  if Assigned(Server) then
  begin
    // Prepare the data
    Buffer := TEncoding.UTF8.GetBytes(Msg);
    BufferLength := Length(Buffer);

    // Send the message to all clients
    for I := 1 to Server.ConnectionCount do
    begin
      ClientID := I;
      Client := Server.ConnectionFind(ClientID);
      if Assigned(Client) then
      begin
        Conn := TConnection(Client);
        Conn.Send(Buffer, BufferLength);  // Use the Send method
      end;
    end;

    LogMessage('Sent "' + Msg + '" to all clients.');
  end;
end;

procedure TConnection.AfterCreate;
var
  LI: TListItem;
begin
  inherited AfterCreate;
  TThread.Synchronize(nil, procedure
  begin
    LI := Form1.ListView1.Items.Add;
    LI.Caption := IntToStr(Self.Handle);  // Example for client ID, change as needed
    Form1.LogMessage('Client Connected: ' + IntToStr(Self.Handle));
  end);
end;

procedure TConnection.OnClose;
var
  LI: TListItem;
begin
  inherited;
  TThread.Synchronize(nil, procedure
  begin
    // Find and remove the list item for this connection
    LI := Form1.ListView1.FindCaption(0, IntToStr(Self.Handle), True, True, True);
    if Assigned(LI) then
    begin
      LI.Delete;
    end;
    Form1.LogMessage('Client Disconnected: ' + IntToStr(Self.Handle));
  end);
end;

{ TForm1 }

procedure TForm1.Button1Click(Sender: TObject);
begin
  if not Assigned(Server) then
  begin
    // Create and start the server
    Server := TAsyncServer.Create(
      IntToStr(SpinEdit1.Value),
      nil, nil,
      TConnection,
      'MyAsyncServer',
      TSynLog,
      [acoVerboseLog],
      5
    );

    Button1.Caption := 'Stop Listening';
    SpinEdit1.Enabled := False;
    LogMessage('Server started on port ' + SpinEdit1.Text);
  end
  else
  begin
    // Stop the server
    Server.Free;
    Server := nil;
    Button1.Caption := 'Start Listening';
    SpinEdit1.Enabled := True;
    LogMessage('Server stopped.');
  end;
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  SendToAllClients('Whatever Message You Wish To Send!');
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  SelectedItem: TListItem;
  ClientID: Integer;
begin
  if Assigned(Server) and (ListView1.Selected <> nil) then
  begin
    SelectedItem := ListView1.Selected;
    ClientID := StrToIntDef(SelectedItem.Caption, 0);
    SendToSelectedClient(ClientID, 'Whatever Message You Wish To Send!');
  end;
end;

procedure TForm1.LogMessage(const Msg: string);
begin
  Memo1.Lines.Add(Msg);
end;

end.
