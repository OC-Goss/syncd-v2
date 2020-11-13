import socketserver
import threading
import signal
import sys
import rawutil

class ThreadedTCPRequestHandler(socketserver.StreamRequestHandler):
    def setup(self):
        super(ThreadedTCPRequestHandler, self).setup()
        self.header_len = 4
        self.protocol_version = "0.1"
        self.server_name = "Syncd server alpha v0.1"

    def read_len(self, data):
        return int.from_bytes(data[:self.header_len], byteorder='big', signed=False)

    def prepend_len(self, data):
        return int.to_bytes(len(data), self.header_len, byteorder='big', signed=False) + data

    def handle_message(self, msg):
        (msg_type,) = rawutil.unpack(">B", msg[:1])
        print("Received message type: {}".format(msg_type))
        if msg_type == 0x00: # hello message
            client_name, protocol_version = rawutil.unpack("nn", msg[1:])
            print(client_name, protocol_version)
            if protocol_version.decode("utf-8") == self.protocol_version:
                self.wfile.write(self.prepend_len(b'\01' + rawutil.pack("nn", self.protocol_version, self.server_name)))
            else:
                self.wfile.write(self.prepend_len(b'\02Protocol version mismatch'))

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
    
    def register(self, payload):
        pass

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
