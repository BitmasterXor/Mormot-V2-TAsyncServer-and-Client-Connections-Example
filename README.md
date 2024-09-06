Delphi Asynchronous Server
A Delphi VCL application that demonstrates an asynchronous server using the mORMot library to manage multiple client connections and send messages.

📋 Features
Asynchronous Server: Uses mORMot.net.async and mORMot.net.sock to implement an efficient non-blocking server.
Send Messages to Clients: Ability to send messages to a specific client or broadcast to all connected clients.
Client Management: Displays connected clients in a TListView and logs server activity in a TMemo.
Dynamic Client Updates: Automatically updates the client list when clients connect or disconnect.
🔍 Overview
Button1Click: Starts or stops the asynchronous server on the specified port.
Button2Click: Sends a predefined message to all connected clients.
Button3Click: Sends a predefined message to a selected client.
SendToSelectedClient: Sends a message to a specified client ID.
SendToAllClients: Broadcasts a message to all connected clients.
LogMessage: Displays server events and messages in the TMemo control.
TConnection: Manages client connections, reads data, and handles connection events.
🛠️ Requirements
Delphi RAD Studio: With VCL support.
mORMot V2 Library: Available at mORMot2 GitHub.
📜 License
This project is freeware provided as is. Use at your own risk for research purposes!

📧 Contact
Discord: BitmasterXor

Made with ❤️ by BitmasterXor, using Delphi RAD Studio.
