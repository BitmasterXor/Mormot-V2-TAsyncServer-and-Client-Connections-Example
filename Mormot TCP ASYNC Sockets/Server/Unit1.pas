unit Unit1;

interface

uses
// Windows API units
  Winapi.Windows,        // Provides definitions for Windows API functions, constants, and types.
  Winapi.Messages,       // Includes constants and functions for handling Windows messages.

  // System units
  System.SysUtils,       // Contains utility functions for system tasks, file operations, and exception handling.
  System.Variants,       // Supports variant types for variables of different types.
  System.Classes,        // Provides classes for working with streams, file handling, and other fundamental tasks.

  // VCL units
  Vcl.Graphics,          // Classes for graphics drawing and handling in VCL applications.
  Vcl.Controls,          // Base classes for visual controls in VCL applications.
  Vcl.Forms,             // Classes for creating and managing forms.
  Vcl.Dialogs,           // Provides classes for dialogs and message boxes.
  Vcl.StdCtrls,          // Standard VCL controls such as buttons, labels, and edit boxes.
  Vcl.Samples.Spin,      // Spin edit controls for numeric input.

  // mORMot library units
  mormot.net.async,      // Asynchronous networking and communication components from mORMot.
  mormot.net.sock,       // Networking components for sockets from mORMot.
  mormot.core.base,      // Core base functionalities of the mORMot framework.
  mormot.core.os,        // Operating system related functionalities of mORMot.
  mormot.core.log,       // Logging functionalities of mORMot.
  mormot.core.rtti,      // Runtime Type Information (RTTI) functionalities of mORMot.

  // Additional VCL units
  Vcl.ComCtrls,          // Provides components for common controls like status bars, tree views, and list views.
  Vcl.Menus,             // Classes for creating and managing menus.
  System.NetEncoding,    // Provides classes for encoding and decoding network data, such as Base64.
  Vcl.Imaging.jpeg,      // Classes for handling JPEG images.
  Vcl.ExtCtrls,          // Contains additional controls like timers, image controls, and more.
  acPNG;                 // Support for PNG images.


{$POINTERMATH ON} // Enables pointer arithmetic in Delphi code, allowing arithmetic operations on pointer types. (Needed for Mormot Receiving Buffers)

type
  TForm1 = class(TForm)
    Memo1: TMemo; // Memo control for displaying messages
    SpinEdit1: TSpinEdit; // SpinEdit control for selecting port number
    Button1: TButton; // Button to start/stop server
    ListView1: TListView; // ListView to display connected clients
    Button2: TButton; // Button to send a message to all clients
    Button3: TButton; // Button to send a message to selected client
    Image1: TImage; //image display for transfered Remote Desktops
    Edit1: TEdit;
    MENU: TPopupMenu;
    C1: TMenuItem; // Image control to display images from clients
    procedure Button1Click(Sender: TObject); // Start/stop the server
    procedure Button2Click(Sender: TObject); // Send message to all clients
    procedure Button3Click(Sender: TObject); // Send message to selected client
    procedure ListView1Click(Sender: TObject);
    procedure C1Click(Sender: TObject); // Handle ListView click event
  private
    { Private declarations }
    Server: TAsyncServer; // Server instance to manage connections
    procedure SendToSelectedClient(ClientID: Integer; const Msg: string);
    // Send message to selected client
    procedure SendToAllClients(const Msg: string);
    // Send message to all clients
    procedure LogMessage(const Msg: string); // Log messages to Memo
  public
    { Public declarations }
  end;

  TConnection = class(TAsyncConnection)
    // Connection class to handle individual client connections
  protected
    function OnRead: TPollAsyncSocketOnReadWrite; override;
    // Handles reading data from connection
    procedure AfterCreate; override; // Called after connection is created
    procedure OnClose; override; // Called when connection is closed
  end;

var
  Form1: TForm1; // Main form instance

implementation

{$R *.dfm}
{ TConnection }


//FROM MORMOT V2 DOCUMENTATION...
(*
  TPollAsyncSocketOnReadWrite = ( soContinue, soWaitWrite, soDone, soClose );
  Define the TPollAsyncSockets.OnRead/AfterWrite method result
  - soContinue should continue reading/writing content from/to the socket
  - soDone should unsubscribe for the current read/write phase, but should not shutdown the socket yet
  - soWaitWrite (for AfterWrite) should wait a little then retry writing
  - soClose would shutdown the socket
*)

//Following function is used as the Sockets On Read Data Event!
function TConnection.OnRead: TPollAsyncSocketOnReadWrite;
var
  Packet: pbyte; // Pointer to hold the incoming packet data
  BufferLen: Integer; // Length of the incoming data
  sl: TStringList; // StringList for parsing the incoming data
  RemoteIPAddress: string; // Remote IP address (IF NEEDED in this project im not really using it however I did include this as example for people who may require it)
  li: TListItem; // List item for displaying in the ListView
  data: UTF8String; // Decoded data from the packet
begin
//checking to ensure the Socket Connection is established... if its not There is no reason to be trying to read data from it.
  if IsClosed then
    Exit(soClose); // Exit if the connection is closed

  //Keep in mind that when we type self here we are not reffering to the Form1 itself but rather the current TConnection(Socket connection we are messing with).
  RemoteIPAddress := self.RemoteIP; // Retrieve the remote IP address of the (CLIENT) socket connection we are currently speaking with.
  Result := soContinue; // Continue processing

  //Looking at the mormot documentation as well as the "mormot.net.async.pas" file you can see that this (fRd) is the current Read data buffer for this connection.
  //We are mearly ensuring that there is in fact SOME DATA which we can work with...
  if (fRd.Len >= SizeOf(Integer)) then
  begin
  //In mormot V2 sockets recieve a fSendBufferSize: integer; which is a "SendBufferSize" or DEFAULT sendbuffersize and this should be retrieved at first connection Start
  //This allows us to tell the server what the default sendbuffersize will be thus allowing us to prep our data on the client endpoint and send over the "Expected size" to be recieved by the server.
  //In other words lets say you are going to send a file or image... You would on the client take the image or file or text or whatever and then
  //Get its TOTAL SIZE in bytes and send that to the server BEFORE sending the actual data, this tells the server how much data is to be expected so that we can
  //properly ensure that all data is indeed recieved by the server, and then we can process it. (Same thing had to be done using the old winsock wrappers shipped with Delphi over the years).
    BufferLen := PInteger(fRd.Buffer)^; // Get the length of the incoming data

    //This is following up on what was commented just above...
    //It ensures that the current data being recieved has been fully 100% recieved before we continue processing it for whatever we are doing.
    if (fRd.Len >= BufferLen + SizeOf(Integer)) then //if we got ALL the data expected to be recieved from our client socket... then we can proceed.
    begin
      Packet := AllocMem(BufferLen); //Setting aside 0byte free memory for our buffers length
      if Packet <> nil then //ensuring that AllocMem did its job and set aside the memory for our packet of data we will be messing with.
      begin
        // Remove the length of the data from the buffer as its not really part of our RAW recieved data!
        fRd.Remove(SizeOf(Integer));
        // Copy the packet data from the mormot recieving buffer and shove it into our newly allocated memory for our Packet...
        MoveFast(fRd.Buffer^, Packet^, BufferLen); //MoveFast is a mormot function which actually utilizes RAW ASM hense WHY ITS FAST at what it does,
        //Moving buffer data from one memory location to another.

        // Decode the packet data and place it into our data:string variable so now we can visually see its text and parce it and do stuff with it.
        FastSetString(data, Packet, BufferLen);//FastSetString is a mormot function which takes a pointer and the length of that pointer and places its string value into a RawUtf8 string.

        // Process the packet data in the main thread
        TThread.Queue(nil,
          procedure
          var
            RawBytes: TBytes; // Byte array for handling raw data
            ClientID: PInteger; // Pointer to hold client ID
            MemoryStream: TMemoryStream; // Memory stream for image data
            Bitmap: TBitmap; // Bitmap for displaying images
            TextMessage: string; //Obviously this is our actual TextMessage as a raw string
            TextMessageBytes: TBytes; //This is our TextMessage:string as "Tbytes"
          begin

          //Here we will be creating a Tstringlist which we can use to parce our decoded string data and process commands or whatever we want based on the data we recieved from the client socket.
            sl := TStringList.Create;
            try
              // Parse the data using '|' as the delimiter
              sl.Delimiter := '|';
              sl.StrictDelimiter := True;//Ensure that only one PIPE | will be truly used as a text delimiter
              sl.DelimitedText := data; //The text we will be parcing will be our Data variable "data: UTF8String"

              // Use a default IP if none is provided... in Mormot sockets i found that on my local machine the remote ip would show as '' BLANK
              //so to get arround this all I simply did was say if its BLANK that must mean your running the client app from the same localhost machine 127.0.0.1
              if RemoteIPAddress = '' then
                RemoteIPAddress := '127.0.0.1';

              //Ensuring the Count of the delimited text is greater than 0 (Which means we have some text data to parce in the first place)
              if sl.Count > 0 then
              begin
                // Handle new connection data
                if sl[0] = 'NewCon' then
                begin
                  // Add new connection details to the ListView (as you need them!)
                  // This is not being used in this project however im including it for people who may want to have a command / event for
                  // doing something when a client connects they could send NewCon and you could have something happen here... like adding them to a list or something useful.
                end;

                //MSG command from Client (if MSG recieved by client then you can do something with that text message here)
                if sl[0] = 'MSG' then
                begin
                  // Initialize the memory stream to store the incoming data
                  MemoryStream := TMemoryStream.Create;
                  try
                    // Write the data from the packet to the memory stream, skipping the first 4 bytes (length) SKIP first 4 bytes (IMG|) << They are not part of the Message data itself so we skip them.
                    MemoryStream.Write(pointer(Packet + 4)^, BufferLen - 4); //writing the Message to our memorystream.
                    MemoryStream.Position := 0; // Reset the stream position to 0 so "From the beginning of the message data"

                    // Convert the memory stream to a TBytes array first
                    SetLength(TextMessageBytes, MemoryStream.Size); //basically allocating the size / memory for our message into our TextMessageBytes
                    MemoryStream.ReadBuffer(TextMessageBytes[0], MemoryStream.Size); //Now filling those TextMessageBytes with our Text message BYTES that we basically just allocated memory for.

                    // Now Decoding the Tbytes into a UTF8 string so we can read it just like your reading all my comments now LOL!
                    TextMessage := TEncoding.UTF8.GetString(TextMessageBytes);

                    // Display the decoded message in Memo1 so we can visually see what it says!
                    Form1.Memo1.Lines.Add('Client: ' + IntToStr(self.Handle) + ' Says: ' + TextMessage);

                  finally
                    MemoryStream.Free; // Free the memory stream no need for it to be taking up memory space anymore!
                  end; // End of the finally block

                end; // End of sl[0] = 'MSG'


                // Incomming Desktop Screenshot from Client socket application...
                if sl[0] = 'image' then //The command to signal that we are about to recieve a screenshot from the client...
                begin
                  // Load and display image from the packet data
                  MemoryStream := TMemoryStream.Create; //Creating a memorystream to hold the image data from the client...
                  Bitmap := TBitmap.Create; //Creating a Bitmap to store the image on before applying that bitmap to our image1 VCL component residing on Form1.
                  try
                    try
                      // Write the image data to the memory stream
                      MemoryStream.Write(pointer(Packet + 6)^, BufferLen);// Why the + 6 you ask ... Because the command is image| we SKIP the command and the PIPE | as they are not the data for the image.
                      MemoryStream.Position := 0; // Reset the stream position to the beginning 0 so Beginning of the RAW image data recieved from the client...

                      // Basically taking the image data we recieved from the client and placing it into our newly created Bitmap image container.
                      // So at this point we have the image of the remote desktop and we can do wahtever we need to do with it...
                      Bitmap.LoadFromStream(MemoryStream);
                    except
                      on E: Exception do
                        // Handle any exceptions during image processing (here im doing NOTHING No Errors will show)
                    end;

                    // Time to show the image we recieved from the client (We assign our bitmap image onto our Image1 Component on our form)
                    Form1.Image1.Picture.Bitmap.Assign(Bitmap);
                  finally
                    MemoryStream.Free; // Free the memory stream no need in taking up memory space when its no longer needed.
                    Bitmap.Free; // Free the bitmap because its assigned on our Image1 component and we can visually see it now so no need for this bitmap to take up memory space when its no longer needed.
                  end;
                end; // End of sl[0] = 'image'

              end; // End of if sl.Count > 0

            finally
              sl.Free; // Free the TStringList we used it already and processed everything within it so no longer need it to take up memory space.
              FreeMem(Packet); // we allocated a block of memory erlier in our code for the Packet data we started out with, we have already used it and processed all data so now we must free its memory!
            end;

          end); // End of TThread.Queue

        // Remove the processed data from the buffer
        fRd.Remove(BufferLen); //Ensuring the Mormot socket inbound buffer reader returns to an Empty state (Freeing memory) so we can recieve future data from this connection. (Out with the OLD in with the NEW)
      end
      else
        Exit(soClose); // Exit if memory allocation failed for any reason... soClose is documented in the mormot documentation
        // soClose is documented as follows soClose would shutdown the socket... so essentially we are stating that if anything went wrong
        // durring our attempt to read and allocate the data recived by the client endpoint we would simply close the connection due to the error / issue.
    end;
  end;

end; // End of function OnRead


procedure TForm1.SendToSelectedClient(ClientID: Integer; const Msg: string);
var
  Conn: TConnection;
  Buffer: TBytes;
  BufferLength: Integer;
begin
  if Assigned(Server) then
  begin
    // Find the connection with the given ClientID
    Conn := TConnection(Server.ConnectionFind(ClientID)); //ConnectionFind is part of mormots TasyncConnection it has this function which can find a client by its ID very nice to have :)
    if Assigned(Conn) then //ensure that the found connection is a valid one before proceeding...
    begin

      // Prepare the data
      Buffer := TEncoding.UTF8.GetBytes(Msg); //Getting the UTF8 encoded bytes from the string MSG
      BufferLength := Length(Buffer); //Set the total length of our buffer which we will be sending over to the client...

      // Send the Message Data over to the client...
      Conn.Send(Buffer, BufferLength);
    end
    else
    begin
    //Any issues errors ect... ect... Log the message and display it onto our Forms memo1 component...
      LogMessage('Client ID ' + IntToStr(ClientID) + ' not found.');
    end;
  end;
end;

//The following procedure is used to mass broadcast data out to ALL the clients which are currently connected to our server...
procedure TForm1.SendToAllClients(const Msg: string);
var
  Conn: TConnection;            // Represents the connection to each client
  Client: TAsyncConnection;      // Represents each client found by the server
  Buffer: TBytes;                // Holds the byte-encoded message to send
  BufferLength: Integer;         // Length of the byte-encoded message
  I: Integer;                    // Loop variable for iterating through clients
  ClientID: Integer;             // ID of each client in the loop
begin
  // Check if Server is assigned
  if Assigned(Server) then
  begin
    // Prepare the data by converting the message to a UTF-8 byte array
    Buffer := TEncoding.UTF8.GetBytes(Msg);
    BufferLength := Length(Buffer);

    // Loop through all clients and send the message
    for I := 1 to Server.ConnectionCount do
    begin
      ClientID := I; // Set the current client ID
      Client := Server.ConnectionFind(ClientID); // Find the client connection
      if Assigned(Client) then
      begin
        Conn := TConnection(Client); // Cast to TConnection type
        Conn.Send(Buffer, BufferLength); // Send the message buffer to the client
      end;
    end;

    // Log a message indicating the message was sent to all clients
    LogMessage('Sent "' + Msg + '" to all clients.');
  end;
end;


//This procedure can technically be considered the "ON CONNECT" Event for our server socket
//Because AfterCreate means after a new connection from a client socket has been successfully created...
procedure TConnection.AfterCreate;
var
  li: TListItem; //List item for adding the clients Handle ID (which in mormot starts counting from 1 UP)
  //Mormot sockets do not hold Client ID's as custom data but rather as simple integer handles and this is for very good reason allow me to explain...
  //You see other socket libraries take up memory and resources... Mormots way of doing things is meant to keep memory and CPU usage as LOW as humanly
  //possible this greatly effects their performance as well as how many active connections you can achive with them.
begin
  inherited AfterCreate; // We are inheriting the mormots default aftercreate (simply making our own procedure / event from mormots base code)

  //Im using a thread to accomplish the following visual changes on the GUI to ensure it happens outside the boundaries of the mormot socket aftercreate procedure.
  TThread.Synchronize(nil,
    procedure
    begin
      li := Form1.ListView1.Items.Add;
      li.Caption := IntToStr(self.Handle); //Self.handle is = to the Client sockets HANDLE (so example first client to connect is client #1) and it goes UP from there.
      // Example for client ID, change as needed
      Form1.LogMessage('Client Connected: ' + IntToStr(self.Handle)); //simply displaying a message that a client has connected to our server!
    end);
end;


//This procedure fires when a client socket disconnection has been detected by the mormot server socket...
//so when a client disconnects you can do something here...
procedure TConnection.OnClose;
var
  li: TListItem; //List item for locking onto the current handle ID of the currently disconnecting Client...
begin
  inherited;   //inherited OnClose from the mormot base library...
  //I am utilizing a thread to ensure thread saftey outside of the boundaries of the mormot socket itself (finding and removing the Client from our Graphical User Interface) VCL
  TThread.Synchronize(nil,
    procedure
    begin
      // Find and remove the list item for this connection (in other words find the Disconnecting Clients ID in our listview containing all the connected clients, and remove it)
      li := Form1.ListView1.FindCaption(0, IntToStr(self.Handle), True,True, True);
      if Assigned(li) then
      begin
        li.Delete;//Removing / Deleting the disconnecting clients ID from our GUI as they are no longer connected to our server!
      end;
      Form1.LogMessage('Client Disconnected: ' + IntToStr(self.Handle));
    end);
end;

{ TForm1 }

//The following Code starts up a listening server socket on a port which should be typed into the spinedit1 component...
//It also enables and disables GUI elements as needed.
procedure TForm1.Button1Click(Sender: TObject);
begin
  if not Assigned(Server) then
  begin
    // Create and start the server
    Server := TAsyncServer.Create(IntToStr(SpinEdit1.Value), nil, nil,
      TConnection, 'MyAsyncServer', TSynLog, [acoVerboseLog], 5);

    Button1.Caption := 'Stop Listening';
    SpinEdit1.Enabled := False;
    Button2.Enabled:=true;
    Button3.Enabled:=true;
    Edit1.Enabled:=true;
    LogMessage('Server started on port ' + SpinEdit1.Text);
  end
  else
  begin
    // Stop the server
    Server.Free;
    Server := nil;
    Button1.Caption := 'Start Listening';
    SpinEdit1.Enabled := True;
    Button2.Enabled:=false;
    Button3.Enabled:=false;
    Edit1.Enabled:=false;
    LogMessage('Server stopped.');
  end;
end;

//Button for broadcasting a message out to all connected Clients!
procedure TForm1.Button2Click(Sender: TObject);
begin
if trim(form1.Edit1.Text) = '' then
begin
showmessage('You Must Enter A Message To Send!');
exit;
end;

SendToAllClients('MSG|' + Form1.Edit1.Text);
end;

//Button for sending a message out to a SINGLE "SELECTED" client... (so sending to a client you have selected in the client list)
procedure TForm1.Button3Click(Sender: TObject);
var
  SelectedItem: TListItem;
  ClientID: Integer;
begin
if form1.ListView1.selected = nil then
begin
showmessage('You Must Select A Client To Send Messages To!');
Exit;
end;

if trim(form1.Edit1.Text) = '' then
begin
showmessage('You Must Enter A Message To Send!');
exit;
end;

  if Assigned(Server) and (ListView1.Selected <> nil) then
  begin
    SelectedItem := ListView1.Selected;
    ClientID := StrToIntDef(SelectedItem.Caption, 0);
    SendToSelectedClient(ClientID, 'MSG|' + form1.Edit1.Text);
  end;
end;

procedure TForm1.C1Click(Sender: TObject);
begin
form1.Memo1.Clear; //clear out previous output messages!
if button1.Caption = 'Stop Listening' then
begin
form1.Memo1.lines.Add('Server started on port ' + inttostr(form1.SpinEdit1.Value));
end;
end;

//When you click on a client in the clients list we will send a command "image|" to them this means that...
//when the client recieves the image| command they will automatically take an image of their desktop and then send that image over the socket connection back to us.
procedure TForm1.ListView1Click(Sender: TObject);
var
  ClientID: Integer;
begin
  if self.ListView1.Selected = nil then
    Exit;
  ClientID := strtoint(self.ListView1.Selected.Caption);
  SendToSelectedClient(ClientID, 'image|');
end;

//Simple procedure for logging messages to our Memo1 component...
procedure TForm1.LogMessage(const Msg: string);
begin
  Memo1.Lines.Add(Msg); // Log message to Memo
end;

end.
