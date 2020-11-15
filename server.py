import socketserver
import threading
import signal
import sys
from message import Message, MessageType

class MessageHandler(object):
    def __init__(self):
        self.protocol_version = "0.1"
        self.server_name = "Syncd server alpha v0.1"
        self.handlers = {
            MessageType.HELLO: self.hello,
            MessageType.GET_SUBSCRIPTIONS: self.get_subscriptions,
            MessageType.SUBSCRIBE: self.subscribe,
            MessageType.COMPARE_FILES: self.compare_files,
            MessageType.GET_FILE: self.get_file
        }

    def handle(self, msg):
        return self.handlers[msg.type](msg)

    def hello(self, msg):
        if msg.protocol_version == self.protocol_version:
            response_msg = Message(MessageType.HELLO_OK, self.protocol_version, self.server_name)
            return response_msg
        else:
            response_msg = Message(MessageType.HELLO_ERROR, b'Protocol version mismatch')
            return response_msg

    def get_subscriptions(self, msg):
        pass

    def subscribe(self, msg):
        pass

    def compare_files(self, msg):
        pass

    def get_file(self, msg):
        pass

class ThreadedTCPRequestHandler(socketserver.StreamRequestHandler):
    header_len = 4

    def setup(self, *args, **kwargs):
        super(ThreadedTCPRequestHandler, self).setup(*args, **kwargs)
        self.message_handler = MessageHandler()

    def read_len(self, data):
        return int.from_bytes(data[:self.header_len], byteorder='big', signed=False)

    def prepend_len(self, data):
        return int.to_bytes(len(data), self.header_len, byteorder='big', signed=False) + data

    def handle_message(self, data):
        received_msg = Message(data)
        response_msg = self.message_handler.handle(received_msg)
        print("{} responding with: {}".format(self.client_address, response_msg.toBytes()))
        self.wfile.write(self.prepend_len(response_msg.toBytes()))

    def handle(self):
        print("{} connected".format(self.client_address))
        size = self.rfile.read(self.header_len)
        while size != b'':
            data = self.rfile.read(self.read_len(size))
            if data != b'':
                print("{} wrote: {}".format(self.client_address, data))
                self.handle_message(data)
                self.wfile.flush()
            else:
                break
            size = self.rfile.read(self.header_len)
        print("{} end of transmission".format(self.client_address))

class ThreadedTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    pass

if __name__ == "__main__":
    host = ""
    port = 2137
    server = ThreadedTCPServer((host, port), ThreadedTCPRequestHandler)
    with server:
        server_thread = threading.Thread(target=server.serve_forever)
        server_thread.daemon = True
        server_thread.start()

        while True:
            try:
                signal.signal(signal.SIGINT, signal.default_int_handler)
            except KeyboardInterrupt:
                sys.exit()
