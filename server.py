import socketserver
import threading
import signal
import sys

class ThreadedTCPRequestHandler(socketserver.StreamRequestHandler):
    def setup(self):
        super(ThreadedTCPRequestHandler, self).setup()
        self.header_len = 4
        
    def handle_header(self, data):
        return int.from_bytes(data, byteorder='big', signed=False)

    def handle(self):
        print("{} connected".format(self.client_address))
        size = self.rfile.read(self.header_len)
        print("Received size message: {}".format(size))
        while size != b'':
            data = self.rfile.read(self.handle_header(size))
            if data != b'':
                print("{} wrote (len {}): {}".format(self.client_address, len(data), data))
                towrite = int.to_bytes(len(data), 4, byteorder='big', signed=False) + data.upper()
                self.wfile.write(towrite)
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
