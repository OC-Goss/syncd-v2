import socketserver
import threading
import signal
import sys
import os
from queue import Queue, Empty
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from message import Message, MessageType
from pathlib import Path, PurePath

host = ""
port = 2137

class SocketNotifierEventHandler(FileSystemEventHandler):
    def on_any_event(self, event):
        print("Event: {}".format(str(event)))
        notifications.put(event)

class MessageHandler(object):
    def __init__(self):
        self.protocol_version = "0.1.1"
        self.server_name = "Syncd server alpha v0.1"
        self.handlers = {
            MessageType.HELLO: self.hello,
            MessageType.GET_SUBSCRIPTIONS: self.get_subscriptions,
            MessageType.SUBSCRIBE: self.subscribe,
            MessageType.COMPARE_FILES: self.compare_files,
            MessageType.GET_FILE: self.get_file
        }
        self.subscriptions = []
        self.basepath = Path(monitored_path)

    def handle(self, data):
        msg = Message(data)
        response = self.handlers[msg.type](msg)
        if response is not None:
            return response.toBytes()

    def hello(self, msg):
        if msg.protocol_version == self.protocol_version:
            response_msg = Message(MessageType.HELLO_OK, self.protocol_version, self.server_name)
            return response_msg
        else:
            response_msg = Message(MessageType.HELLO_ERROR, b'Protocol version mismatch')
            return response_msg

    def get_subscriptions(self, msg):
        to_send = [[path.as_posix(), (self.basepath / path).is_dir()] for path in self.walk_tree(self.basepath)]
        to_send.append(['.', True])
        response_msg = Message(MessageType.SEND_SUBSCRIPTIONS, len(to_send), to_send)
        return response_msg

    def subscribe(self, msg):
        fail = []
        subscribed = []
        for path in msg.paths:
            path = Path(path)
            fullpath = self.basepath / path
            if fullpath.exists():
                subscribed.append([path.as_posix(), fullpath.is_dir()])
                self.subscriptions.append(path)
            else:
                fail.append([path.as_posix(), 0, False])
        response_msg = Message(MessageType.SUBSCRIBE_RESPONSE, len(subscribed), subscribed, len(fail), fail)
        return response_msg

    def compare_files(self, msg):
        pass

    def get_file(self, msg):
        fullpath = self.basepath / msg.path
        if fullpath.is_file():
            return Message(MessageType.SEND_FILE, msg.path, fullpath.read_bytes())
        elif fullpath.is_dir():
            return Message(MessageType.SEND_FILE_ERROR, "Path is a directory")
        elif not fullpath.exists():
            return Message(MessageType.SEND_FILE_ERROR, "File doesn't exist")
        else:
            return Message(MessageType.SEND_FILE_ERROR, "Internal server error")

    def send_notify(self, event):
        relpath = Path(event.src_path).relative_to(self.basepath)
        if relpath in self.subscriptions or relpath.parent in self.subscriptions:
            if event.event_type in ['modified', 'created', 'deleted']:
                return Message({
                    'modified': MessageType.NOTIFY_CHANGE,
                    'created': MessageType.NOTIFY_CREATE,
                    'deleted': MessageType.NOTIFY_DELETE,
                }[event.event_type], relpath.as_posix(), Path(event.src_path).is_dir()).toBytes()
            elif event.event_type == 'moved':
                destpath = Path(event.dest_path)
                return Message(MessageType.NOTIFY_MOVE, relpath.as_posix(), destpath.relative_to(self.basepath).as_posix(), destpath.is_dir()).toBytes()

    def walk_tree(self, basedir):
        for root, dirs, files in os.walk(basedir, followlinks=True):
            root = Path(root)
            for directory in dirs:
                yield (root / directory).relative_to(basedir)
            for file in files:
                yield (root / file).relative_to(basedir)

class SocketClosedException(ConnectionError):
    pass

class ThreadedTCPRequestHandler(socketserver.StreamRequestHandler):
    header_len = 4

    def setup(self, *args, **kwargs):
        super(ThreadedTCPRequestHandler, self).setup(*args, **kwargs)
        self.request.setblocking(False)
        self.message_handler = MessageHandler()

    def read_len(self, data):
        return int.from_bytes(data[:self.header_len], byteorder='big', signed=False)

    def prepend_len(self, data):
        return int.to_bytes(len(data), self.header_len, byteorder='big', signed=False) + data

    def read_parallel(self, length, parallel_func, *args, **kwargs):
        read_total = 0
        data = b''
        while read_total < length:
            try:
                # rfile.read and request.recv in non-blocking mode both return data in bytes
                # object when it's available, and an empty bytes object when the socket is closed
                # read returns None when no data is available (despite what the docs say)
                # recv raises BlockingIOError when no data is available
                # we use rfile.read for performance reasons (catching exceptions is expensive)
                received = self.rfile.read(length)
            except BlockingIOError:
                # in case we change the implementation to use request.recv
                pass
            else:
                # if data was received and it's not an empty bytes object
                if received and len(received) > 0:
                    read_total += len(received)
                    data += received
                elif received == b'':
                    raise SocketClosedException
            parallel_func(*args, **kwargs)
        return data

    def send_message(self, message):
        if message is not None:
            self.wfile.write(self.prepend_len(message))

    def process_events(self, *args, **kwargs):
        try:
            while not notifications.empty():
                self.send_message(self.message_handler.send_notify(notifications.get(False)))
        except Empty:
            pass

    def handle(self):
        print("{} connected".format(self.client_address))
        try:
            while True:
                size = self.read_parallel(self.header_len, self.process_events, self)
                data = self.read_parallel(self.read_len(size), self.process_events, self)
                print("{} wrote: {}".format(self.client_address, data))
                response = self.message_handler.handle(data)
                print("{} responding with: {}".format(self.client_address, response))
                self.send_message(response)
        except SocketClosedException:
            pass
        print("{} end of transmission".format(self.client_address))

class ThreadedTCPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    pass

if __name__ == "__main__":
    monitored_path = sys.argv[1] if len(sys.argv) > 1 else '.'
    notifications = Queue()
    observer = Observer()
    observer.schedule(SocketNotifierEventHandler(), monitored_path, recursive=True)

    server = ThreadedTCPServer((host, port), ThreadedTCPRequestHandler)
    with server:
        server_thread = threading.Thread(target=server.serve_forever)
        server_thread.daemon = True
        server_thread.start()
        observer.start()

        signal.signal(signal.SIGINT, signal.default_int_handler)
        try:
            while observer.isAlive():
                observer.join(0.5)
        except KeyboardInterrupt:
            observer.stop()
        observer.join()
