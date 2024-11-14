unit Unit1;

interface

uses
Winapi.Windows,       // Provides Windows API functions, constants, and types.
system.Threading,     // Supports multithreading and asynchronous tasks.
Winapi.Messages,      // Allows handling of Windows messages and message-based communication.
system.SysUtils,      // Provides system utilities, string handling, and exception management.
system.Variants,      // Supports variant data types, used for flexible data storage.
system.Classes,       // Contains base classes for streams, file handling, and component classes.
Vcl.Graphics,         // Provides graphical objects like TBitmap and TCanvas for drawing.
Vcl.Controls,         // Defines common control elements used in VCL applications.
Vcl.Forms,            // Provides the base class TForm for creating and managing forms.
Vcl.Dialogs,          // Contains standard dialog boxes (e.g., Open, Save, Color Dialogs).
Vcl.ComCtrls,         // Defines advanced controls like TStatusBar, TProgressBar, TTreeView.
Vcl.StdCtrls,         // Contains standard controls like TButton, TEdit, TLabel.
Vcl.Samples.Spin,     // Provides TSpinEdit, a control for integer input with increment/decrement buttons.
system.NetEncoding,   // Supports encoding and decoding (e.g., base64 encoding).
mormot.net.async,     // Asynchronous network functionality from the mORMot framework.
mormot.net.sock,      // Provides socket-related networking functions for mORMot.
mormot.core.base,     // Core definitions and base classes from the mORMot framework.
mormot.core.log,      // Logging functionality from the mORMot framework.
mormot.core.rtti,     // Supports runtime type information (RTTI) handling.
Vcl.ExtCtrls;         // Contains extended controls, like TTimer, TPanel, and TImage.


type
  // TConnection handles individual client connections
  TConnection = class(TAsyncConnection)
  protected
    function OnRead: TPollAsyncSocketOnReadWrite; override;
    // Handles reading data from the connection
    procedure AfterCreate; override; // Called after connection creation
    procedure OnClose; override; // Handles closing the connection
  end;

  // TClient is used to establish a connection with a server
  TClient = class(TAsyncClient)
  private
    LogFamily: TSynLogFamily; // Log family for managing logging
  public
    constructor Create(Const aRemoteHost, aPort: RawUtf8); reintroduce;
    // Initializes the client
    destructor Destroy; override; // Cleans up resources on destruction
  end;

  // TForm1 represents the main application form
  TForm1 = class(TForm)
    Edit1: TEdit; // Input for server IP address
    Label1: TLabel; // Label for IP address input
    SpinEdit1: TSpinEdit; // Input for server port number
    Label2: TLabel; // Label for port number input
    Button1: TButton; // Button to initiate a connection
    Memo1: TMemo; // Display area for messages
    StatusBar1: TStatusBar; // Status bar to show connection state
    Edit2: TEdit; // Input for message to send
    Button2: TButton;
    ConnectionChecker: TTimer; // Button to send message
    procedure Button1Click(Sender: TObject); // Event for connection initiation
    procedure Button2Click(Sender: TObject);
    procedure ConnectionCheckerTimer(Sender: TObject);
    // Event for sending message

  private
    Client: TClient; // Client object for server communication
    ServerConnection: TConnection; // Represents the server connection
  public
  end;

var
  Form1: TForm1; // Global variable for the form

implementation

{$R *.dfm}

// Captures the current screen and converts it to bytes for sending
function CaptureScreenToBytes: TBytes;
var
  ScreenDC: HDC; // Device context for capturing the screen
  ScreenBitmap: TBitmap; // Bitmap to store the screen capture
  MemoryStream: TMemoryStream; // Memory stream to save the bitmap
begin
  ScreenDC := GetDC(0); // Capture device context for entire screen
  try
    ScreenBitmap := TBitmap.Create;
    try
      ScreenBitmap.Width := Screen.Width; // Match bitmap size to screen
      ScreenBitmap.Height := Screen.Height;

      // Capture screen contents into the bitmap
      BitBlt(ScreenBitmap.Canvas.Handle, 0, 0, Screen.Width, Screen.Height,
        ScreenDC, 0, 0, SRCCOPY);

      // Save bitmap to memory stream
      MemoryStream := TMemoryStream.Create;
      try
        ScreenBitmap.SaveToStream(MemoryStream);

        // Convert memory stream content to byte array
        MemoryStream.Position := 0;
        SetLength(Result, MemoryStream.Size);
        MemoryStream.ReadBuffer(Result[0], MemoryStream.Size);
      finally
        MemoryStream.Free; // Free memory stream
      end;
    finally
      ScreenBitmap.Free; // Free bitmap
    end;
  finally
    ReleaseDC(0, ScreenDC); // Release device context
  end;
end;

// TConnection Methods

// Handles incoming data for the connection
function TConnection.OnRead: TPollAsyncSocketOnReadWrite;
var
  Buffer: RawUtf8; // Stores incoming data
  SL: TStringList; // Splits data using delimiters
  Stream: TMemoryStream; // For processing incoming data
  Base64String: string; // Base64 representation of data
  BufferBytes: TBytes; // Byte array for the buffer data
  BufferLength: Integer; // Length of the buffer
  TemporaryINTHolder: Integer; // Temp variable for data processing
  MemoryStream: TMemoryStream; // Stream for additional data handling
  Bitmap: TBitmap; // Bitmap for image handling
begin
//==============================================================================
//                                 IMPORTANT NOTE
// Small text messages can typically be received by mORMot sockets in a single
// packet, allowing us to use FastSetString(Buffer, frd.Buffer, frd.Len) for
// simple data extraction.
//                                 -------------
// However, if you need to receive larger data packets, refer to the Server
// Example provided with this client. This example demonstrates how to send the
// expected buffer size so that the client knows precisely how much data to
// anticipate and process.
//==============================================================================


  FastSetString(Buffer, frd.Buffer, frd.Len); // Read incoming data to buffer
  Result := soContinue; // Indicate more processing can continue

  // Split data in buffer using delimiter '|'
  SL := TStringList.Create;
  try
    SL.Delimiter := '|';
    SL.StrictDelimiter := True;
    SL.DelimitedText := Buffer;

    // Check if data is a message or image
    if SL[0] = 'MSG' then
    begin
      Form1.Memo1.Lines.Add('Server Says: ' + SL[1]); // Display message
      Result := soDone; // Processing complete
    end;

    if SL[0] = 'image' then
    begin
      Form1.Memo1.Lines.Add('Sending Desktop Screenshot To Server!');
      BufferBytes := Bytesof('image|') + CaptureScreenToBytes;

      BufferLength := Length(BufferBytes); // Set byte array length

      // Prepare to send image data
      MemoryStream := TMemoryStream.Create;
      Bitmap := TBitmap.Create;
      try
        MemoryStream.WriteBuffer(BufferBytes[0], Length(BufferBytes));
        // Write data
        MemoryStream.Position := 0; // Reset stream position

        TemporaryINTHolder := 4; // Size of length field
        Self.Send(@BufferLength, TemporaryINTHolder); // Send length
        Self.Send(@BufferBytes[0], BufferLength); // Send data

        Result := soDone; // Processing complete
      finally
        MemoryStream.Free; // Free memory stream
        Bitmap.Free; // Free bitmap
      end;
    end;

  finally
    SL.Free; // Free string list after use
  end;

  frd.Reset; // Reset read buffer for next read
end;

// Executes after the connection is established
procedure TConnection.AfterCreate;
var
  MessageToSend: RawUtf8; // Message to send after connection creation
  Buffer: TBytes; // Byte array for message
  BufferLength: Integer; // Message buffer length
begin
  inherited AfterCreate; // Call base implementation
  // Update UI to show connected state
  Form1.Button1.Enabled := false;
  Form1.Button1.Caption := 'Connected!';
  Form1.Edit1.Enabled := false;
  Form1.SpinEdit1.Enabled := false;
  Form1.Edit2.Enabled := True;
  Form1.Button2.Enabled := True;
  Form1.Memo1.Lines.Add('Connected to Server');
  Form1.StatusBar1.Panels[0].Text := 'Connection Status: Connected!';

  MessageToSend := 'NewCon|'; // Example message for new connection
  Buffer := TEncoding.UTF8.GetBytes(MessageToSend);
  BufferLength := Length(Buffer);

  // Send non-empty buffer
  if BufferLength > 0 then
  begin
    var
    TemporaryINTHolder: Integer := 4; // Size of length field | as I understand it this is also the value that the server will use as the Defaultrecievebuffer size...
    //In mormot V2 sockets recieve a fSendBufferSize: integer; which is a "SendBufferSize" or DEFAULT sendbuffersize and this should be retrieved at first connection Start
    //I belive this is important because it allows the server to have a base default value on "SendBufferSize" which will allow us to calculate and ensure entire buffer packets
    //are fully recieved on the server endpoint. (Ex: client sends BufferSIZE first... then sends All the actual Data we are attempting to send) Server Knows EXACTILY how much data
    //is expected to be recieved and processed...
    Self.Send(@BufferLength, TemporaryINTHolder); // Send message length
    Send(Buffer, BufferLength); // Send message itself
  end;
end;

// Cleans up when connection closes
procedure TConnection.OnClose;
begin
  inherited; // Call base OnClose
  Form1.Memo1.Lines.Add('Disconnected from Server');
  Form1.StatusBar1.Panels[0].Text := 'Connection Status: Disconnected!';
  Form1.Button1.Enabled := True;
  Form1.Button1.Caption := 'Connect';
  Form1.Edit1.Enabled := True;
  Form1.SpinEdit1.Enabled := True;
  Form1.Edit2.Enabled := false;
  Form1.Button2.Enabled := false;
  Form1.Memo1.Lines.Clear; // Clear past messages
end;

// Initializes client with server IP and port
constructor TClient.Create(const aRemoteHost, aPort: UTF8String);
begin
//Mormot has a built in logging functionality im enabling it here in Verbose mode however,
//if you truly wanted to you could simply disable it entirely if you didnt truly need it in your application.
  LogFamily := TSynLog.Family;
  LogFamily.Level := LOG_VERBOSE;
  LogFamily.PerThreadLog := ptIdentifiedInOnFile;
  LogFamily.EchoToConsole := LOG_VERBOSE;

  // Initialize base class with server details... This creates the client socket and attempts to allow it to connect to the specified Remote Server...
  inherited Create(aRemoteHost, aPort, 1, 10, nil, nil, TConnection,
    UTF8String(TClient.ClassName), LogFamily.SynLogClass, [acoVerboseLog], 1)
end;

// Cleans up resources when the Client socket is destroyed from memory.
destructor TClient.Destroy;
begin
  inherited Destroy;// Inherited from the mormot TAsyncConnections.Destroy Destructor...
end;


// Connects to the server when Button1 is clicked
procedure TForm1.Button1Click(Sender: TObject);
begin
  Form1.Button1.Enabled := false;
  Client := TClient.Create(Utf8Encode(Form1.Edit1.Text),
    Utf8Encode(Form1.SpinEdit1.Text));
  Memo1.Lines.Add('Attempting Connection to Server...');
  Form1.ConnectionChecker.Enabled := True;
end;

// Sends message when Button2 is clicked
procedure TForm1.Button2Click(Sender: TObject);
var
  MessageToSend: UTF8String; // Message text
  Buffer: TBytes; // Byte array for message
  BufferLength: Integer; // Length of the message buffer
begin
  MessageToSend := 'MSG|' + Form1.Edit2.Text;
  Buffer := TEncoding.UTF8.GetBytes(MessageToSend);
  BufferLength := Length(Buffer);

  // Send non-empty buffer
  if BufferLength > 0 then
  begin
    var
    TemporaryINTHolder: Integer := 4; // Size of length field
    Form1.Client.connection[0].send(@BufferLength, TemporaryINTHolder); // Send length
    Form1.Client.connection[0].send(Buffer, BufferLength); // Send message
    Form1.Memo1.Lines.Add('You Said: ' + Form1.Edit2.Text); // Log message
    Form1.Edit2.Clear;
  end;
end;

//Timer used to check if the client socket is actually able to establish a connection after the user clicks the connect button...
procedure TForm1.ConnectionCheckerTimer(Sender: TObject);
begin
//Timer by default is set to 6000ms which is 6 Secconds... (so if the client is unable to successfully establish a TCP connection within 6 secconds we inform user of connection failure)
  Self.ConnectionChecker.Enabled := false;
  if Self.Client.connection = nil then
  begin
    Form1.Button1.Enabled := True;
    Form1.Memo1.Lines.Add('Server Unreachable!');
  end;
end;

end.
