|  ID | Hex | Identifier | Message | Sender | Receiver | Description | Structure - all messages have a prefix of [message length:4][ID:1], strings are null-terminated |
| --- | --- | --- | --- | --- | --- | --- | --- |
|  0 | 0x00 | HELLO | Hello | Client | Server | Sent right after connecting to get server info, sends client info | [client protocol version string][client custom name] |
|  1 | 0x01 | GET_SUBSCRIPTIONS | Get available subscriptions | Client | Server | Request to send a list of available files/directories which can be subscribed to receive notifications about changes to them |  |
|  2 | 0x02 | SUBSCRIBE | Subscribe to specified | Client | Server | Request to subscribe to files and/or folders included in the list to receive notifications about changes to them | [n - number of list entries:4][list entry string 1]...[list entry string n] |
|  3 | 0x03 | COMPARE_FILES | Get identical-sized files | Client | Server | Sends a list of file paths along with filesizes sizes for the server to compare | [n - number of list entries][path 1 string][filesize 1:4]...[path n string][filesize n:4] |
|  4 | 0x04 | GET_FILE | Request file | Client | Server | Request to send a specific file | [path string] |
|   |  |  |  |  |  |  |  |
|  0 | 0x80 | HELLO_OK | Hello ok response | Server | Client | Sent as a response to Hello message, sends server info | [server protocol version string][server custom name] |
|  1 | 0x81 | HELLO_ERROR | Hello error response | Server | Client | Sent as a response to Hello message, signals error due to protocol version mismatch or other issue | [error reason string] |
|  2 | 0x82 | SEND_SUBSCRIPTIONS | Send available subscriptions | Server | Client | Sends a list of all files which can be subscribed to receive notifications about changes to them | [n - number of list entries:4][list entry string 1][is directory:1]...[list entry string n][is directory:1] |
|  3 | 0x83 | SUBSCRIBE_RESPONSE | Subscribe response | Server | Client | Response from the server containing which subscriptions were successful and which failed with a reason of failure included | [n - number of succesful subscriptions:4][success list entry string 1]...[success list entry string n][k - number of failed subscriptions:4][fail list entry string 1][failure 1 code:2]...[fail list entry string k][failure k code:2] |
|  4 | 0x84 | SEND_HASHES | Send hashes of identical-sized files | Server | Client | Sends a list of paths along with their hashes, of files which have identical sizes in response to Get identical-sized files message | [n - number of list entries][path 1 string][hash 1 string]...[path n string][hash n string] |
|  5 | 0x85 | SEND_FILE | Sending file | Server | Client | Sends a specified file along with its path in response to Request file message | [path string][file contents string] |
|  6 | 0x86 | SEND_FILE_ERROR | Sending file error | Server | Client | Sends an error describing why the requested file couldn't be sent in response to Request file message | [error reason string] |
|  7 | 0x87 | NOTIFY_CHANGE | Notify change | Server | Client | Notifies the client about change made to a subscribed file/folder | [path string] |
|  8 | 0x88 | NOTIFY_DELETE | Notify deletion | Server | Client | Notifies the client about deletion of subscribed file/folder | [path string] |
|  9 | 0x89 | NOTIFY_CREATE | Notify creation | Server | Client | Notifies the client about creation of subscribed file/folder | [path string] |
