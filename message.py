from collections import namedtuple
from enum import Enum
import rawutil

class MessageType(Enum):
    HELLO = 0x00
    GET_SUBSCRIPTIONS = 0x01
    SUBSCRIBE = 0x02
    COMPARE_FILES  = 0x03
    GET_FILE = 0x04

    HELLO_OK = 0x80
    HELLO_ERROR = 0x81
    SEND_SUBSCRIPTIONS = 0x82
    SUBSCRIBE_RESPONSE = 0x83
    SEND_HASHES = 0x84
    SEND_FILE = 0x85
    SEND_FILE_ERROR = 0x86
    NOTIFY_CHANGE = 0x87
    NOTIFY_DELETE = 0x88
    NOTIFY_CREATE = 0x89

Format = namedtuple('Format', ['struct_fmt', 'field_names'])

class Message(object):
    type_format = ">B"
    formats = {
        MessageType.HELLO: Format(">nn", ["protocol_version", "client_name"]),
        MessageType.GET_SUBSCRIPTIONS: Format("", []),
        MessageType.SUBSCRIBE: Format(">I /0(n)", ["num_paths", "paths"]),
        MessageType.COMPARE_FILES: Format(">I /0[n I]", ["num_paths", namedtuple("paths", ["path", "size"])]),
        MessageType.GET_FILE: Format(">n", ["path"]),
        MessageType.HELLO_OK: Format(">nn", ["protocol_version", "server_name"]),
        MessageType.HELLO_ERROR: Format(">n", ["reason"]),
        MessageType.SEND_SUBSCRIPTIONS: Format(">I /0[n B]", ["num_paths", namedtuple("paths", ["path", "isDir"])]),
        MessageType.SUBSCRIBE_RESPONSE: Format(">I /0[n B] I /2[n H B]", ["num_paths", namedtuple("paths", ["path", "isDir"]), "num_paths_fail", namedtuple("paths_fail", ["path", "error_code", "isDir"])]),
        MessageType.SEND_HASHES: Format(">I /0[n 8s]", ["num_paths", namedtuple("paths", ["path", "hash"])]),
        MessageType.SEND_FILE: Format(">nn", ["path", "contents"]),
        MessageType.SEND_FILE_ERROR: Format(">nn", ["path", "reason"]),
        MessageType.NOTIFY_CHANGE: Format(">n B", ["path", "isDir"]),
        MessageType.NOTIFY_DELETE: Format(">n B", ["path", "isDir"]),
        MessageType.NOTIFY_CREATE: Format(">n B", ["path", "isDir"]),
    }

    def __init__(self, msg_type_or_data, *args):
        if type(msg_type_or_data) == MessageType:
            self.fromFields(msg_type_or_data, *args)
        else:
            self.fromBytes(msg_type_or_data)

    def __eq__(self, other):
        for varname in vars(self).keys():
            if getattr(self, varname) != getattr(other, varname):
                return False
        return True

    def fromFields(self, msg_type, *args):
        self.type = msg_type
        for name, obj in zip(Message.formats[self.type].field_names, args):
            if type(name) != str:
                setattr(self, name.__name__, [name._make(el) for el in obj])
            else:
                setattr(self, name, obj)

    def fromBytes(self, data):
        try:
            raw_type = rawutil.unpack(Message.type_format, data)[0]
            self.type = MessageType(raw_type)
        except ValueError as e:
            print("Unsupported message type id {}".format(raw_type))

        msg_format = Message.formats[self.type]
        if msg_format.struct_fmt and len(msg_format.struct_fmt) > 0:
            bytes_to_string = lambda obj: list(map(lambda s: s.decode("utf-8") if type(s) == bytes else s, obj)) if hasattr(obj, '__iter__') and type(obj) == list else obj
            for name, obj in zip(msg_format.field_names, rawutil.unpack(msg_format.struct_fmt, data[rawutil.struct.calcsize(Message.type_format):])):
                if type(name) != str:
                    setattr(self, name.__name__, [name._make(bytes_to_string(el)) for el in obj])
                else:
                    obj = bytes_to_string(obj)
                    setattr(self, name, obj if type(obj) != bytes else obj.decode("utf-8"))


    def toBytes(self):
        byte_str = bytes()
        byte_str += rawutil.pack(Message.type_format, self.type.value)
        msg_format = Message.formats[self.type]
        if msg_format.struct_fmt and len(msg_format.struct_fmt) > 0:
            field_list = [([list(el) for el in getattr(self, name.__name__)] if type(name) != str else getattr(self, name)) for name in msg_format.field_names]
            print(*field_list)
            byte_str += rawutil.pack(msg_format.struct_fmt, *field_list)
        return byte_str