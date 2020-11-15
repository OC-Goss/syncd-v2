from message import Message, MessageType

def test(*args):
    msg = Message(*args)
    print(vars(msg))
    bytemsg = msg.toBytes()
    print(bytemsg)
    msg2 = Message(bytemsg)
    if msg != msg2:
        print(vars(msg2))
        print("Test failed")
        exit()

paths = [["foo.lua"], ["bar.txt"], ["baz.py"]]
paths2 = [["foo.lua", 5363], ["bar.txt", 324], ["baz.py", 64312]]
paths3 = [["baz.exe", 43], ["foo.psd", 234], ["bar.bin", 73]]
paths4 = [["bar.lua", "49a09acd"], ["baz.html", "6439eafe0"], ["foo.xml", "4068adce"]]
test(MessageType.HELLO, "v0.1", "v0.2")
test(MessageType.GET_SUBSCRIPTIONS)
test(MessageType.SUBSCRIBE, len(paths), paths)
test(MessageType.COMPARE_FILES, len(paths2), paths2)
test(MessageType.GET_FILE, "foo.lua")
test(MessageType.HELLO_OK, "v0.3", "syncd server v0.4")
test(MessageType.HELLO_ERROR, "Invalid protocol")
test(MessageType.SEND_SUBSCRIPTIONS, len(paths), paths)
test(MessageType.SUBSCRIBE_RESPONSE, len(paths), paths, len(paths3), paths3)
test(MessageType.SEND_HASHES, len(paths4), paths4)
test(MessageType.SEND_FILE, "foo.lua", "Lorem ipsum dolor\nsit amet")
test(MessageType.SEND_FILE_ERROR, "foo.lua", "Invalid file")
test(MessageType.NOTIFY_CHANGE, "foo.exe")
test(MessageType.NOTIFY_DELETE, "bar.exe")
test(MessageType.NOTIFY_CREATE, "baz.exe")
print("All tests successful")