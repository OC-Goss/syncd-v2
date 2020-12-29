local MessageType = {
    HELLO = 0x00,
    GET_SUBSCRIPTIONS = 0x01,
    SUBSCRIBE = 0x02,
    COMPARE_FILES  = 0x03,
    GET_FILE = 0x04,

    HELLO_OK = 0x80,
    HELLO_ERROR = 0x81,
    SEND_SUBSCRIPTIONS = 0x82,
    SUBSCRIBE_RESPONSE = 0x83,
    SEND_HASHES = 0x84,
    SEND_FILE = 0x85,
    SEND_FILE_ERROR = 0x86,
    NOTIFY_CHANGE = 0x87,
    NOTIFY_DELETE = 0x88,
    NOTIFY_CREATE = 0x89,
    NOTIFY_MOVE = 0x8A,

    [0x00] = "HELLO",
    [0x01] = "GET_SUBSCRIPTIONS",
    [0x02] = "SUBSCRIBE",
    [0x03] = "COMPARE_FILES",
    [0x04] = "GET_FILE",

    [0x80] = "HELLO_OK",
    [0x81] = "HELLO_ERROR",
    [0x82] = "SEND_SUBSCRIPTIONS",
    [0x83] = "SUBSCRIBE_RESPONSE",
    [0x84] = "SEND_HASHES",
    [0x85] = "SEND_FILE",
    [0x86] = "SEND_FILE_ERROR",
    [0x87] = "NOTIFY_CHANGE",
    [0x88] = "NOTIFY_DELETE",
    [0x89] = "NOTIFY_CREATE",
    [0x8A] = "NOTIFY_MOVE",
}

return MessageType