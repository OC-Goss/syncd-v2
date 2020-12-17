local component = require("component")
local internet = component.isAvailable("internet") and component.internet
local event = require("event")
local utils = require("utils")
local MessageType = require("messagetype")
local Message = require("message")

local addr = "127.0.0.1"
local port = 2137
local headerfmt = ">I4"
local clientName = "Syncd client alpha v0.1"
local protocolVersion = "0.1"
local headerlen = string.packsize(headerfmt)
local maxRetries = {
    reconnect = 3
}
local subscribedPaths = {}
--local socket
socket = nil

function log(str, ...)
    local logfile = io.open("socklog.txt", "a")
    logfile:write(string.format(str.."\n", ...))
    logfile:close()
end

local function msgfmt(msg)
    return string.pack(headerfmt, #msg) .. msg
end

-- tries to connect to a given address:port pair and returns status and socket object if status is ok
local function connect(addr, port)
    local retries = 0
    while retries <= maxRetries.reconnect do
        local sock, reason = internet.connect(addr, port)
        if not sock then
            log("Failed to create socket: %s", reason)
            return ok, sock
        end
        -- ensure connection
        local ok, reason = sock.finishConnect()
        -- can get either true when connection was successful, false, or nil + reason when it failed
        while not ok and not reason do
            ok, reason = sock.finishConnect()
        end
        if ok then
            -- socket connected
            log("Connected to %s:%s", addr, port)
            return ok, sock
        else
            log("Failed to connect to %s:%s, reason: %s", addr, port, reason)
            retries = retries + 1
        end
    end
    log("Retries to connect to %s:%s failed", addr, port)
    -- return failure
    return false
end

-- synchronous socket send, returns status, if false then reconnect is needed
local function send(sock, msg)
    local written = 0
    -- sock.write should always write 0 bytes or the whole message, but we do a standard write loop just in case
    while written < #msg do
        --log("Sending %s", string.sub(msg, written+1))

        local bytes, reason = sock.write(string.sub(msg, written+1)) -- correct string start for lua indexing starting at 1
        if bytes then
            written = written + bytes
            log("Wrote %d bytes, fully written %d bytes", bytes, written)
        else
            -- socket error
            log("Socket write failed: %s", reason)
            return false
        end
    end
    return true
end

-- synchronous socket recv
local function recv(sock, len)
    -- length not specified, header with length in big endian expected
    local msg = ""
    if not len then
        while #msg < headerlen do
            local partialmsg, reason = sock.read()
            if partialmsg then
                msg = msg .. partialmsg
            else
                log("Socket read failed: %s", reason)
                return false
            end
        end
        len = string.unpack(headerfmt, string.sub(msg, 1, headerlen))
        msg = string.sub(msg, headerlen+1)
    end
    
    while #msg < len do
        -- receive message and save extra data elsewhere
    end
end

local function messageHandler(data)
    local function helloOk(msg)
        log("Connected to %s (protocol version %s)", msg.serverName, msg.protocolVersion)
        log("Asking for available subscriptions")
        send(socket, msgfmt(Message(MessageType.GET_SUBSCRIPTIONS):toBytes()))
    end
    local function helloError(msg)
        log("Error connecting to the server: %s", msg.reason)
    end
    local function sendSubscriptions(msg)
        log("Got subscription list from the server:")
        for _, path in ipairs(msg.paths) do
            log("%s", path)
        end
        subscribedPaths = utils.deepCopy(msg.paths)
        log("Subscribing to all paths")
        send(socket, msgfmt(Message(MessageType.SUBSCRIBE, #subscribedPaths, subscribedPaths):toBytes()))
    end
    local function subscribeResponse(msg) end
    local function sendHashes(msg) end
    local function sendFile(msg) end
    local function sendFileError(msg) end
    local function notifyChange(msg)
        log("File %s modified", msg.path)
    end
    local function notifyDelete(msg)
        log("File %s deleted", msg.path)
    end
    local function notifyCreate(msg)
        log("File %s created", msg.path)
    end

    local handlers = {
        [MessageType.HELLO_OK] = helloOk,
        [MessageType.HELLO_ERROR] = helloError,
        [MessageType.SEND_SUBSCRIPTIONS] = sendSubscriptions,
        [MessageType.SUBSCRIBE_RESPONSE] = subscribeResponse,
        [MessageType.SEND_HASHES] = sendHashes,
        [MessageType.SEND_FILE] = sendFile,
        [MessageType.SEND_FILE_ERROR] = sendFileError,
        [MessageType.NOTIFY_CHANGE] = notifyChange,
        [MessageType.NOTIFY_DELETE] = notifyDelete,
        [MessageType.NOTIFY_CREATE] = notifyCreate
    }

    log("message handler called with data: %s", data)
    local message = Message(data)
    handlers[message.type](message)
end

local function getMsgHandler()
    local buf = ""
    local msglen

    local function sockmsg(ev, inetaddr, sockid)
        log("internet_ready handler called")
        local partialmsg, reason = socket.read()
        if partialmsg then
            buf = buf .. partialmsg
        else
            log("Socket read failed: %s", reason)
            socket.close()
            buf = ""
            msglen = nil
            local ok
            ok, socket = connect(addr, port)
            if not ok then
                event.ignore("internet_ready", sockmsg)
            end
            return
        end

        -- first stage - parse message length
        if #buf >= headerlen and not msglen then
            msglen = string.unpack(headerfmt, string.sub(buf, 1, headerlen))
            log("Received message length: %d", msglen)
        end

        -- second stage - while there are whole messages in buffer, dispatch message for processing and then remove it from buffer
        log("Current buffer length: %d", #buf)
        while msglen and #buf - headerlen >= msglen do
            messageHandler(string.sub(buf, headerlen+1, headerlen+msglen))
            buf = string.sub(buf, headerlen+msglen+1)
            -- read next message length if available
            if #buf >= headerlen then
                msglen = string.unpack(headerfmt, string.sub(buf, 1, headerlen))
            else
                msglen = nil
            end
        end
    end

    return sockmsg
end

local msgHandler = getMsgHandler()

function disconnect()
    event.ignore("internet_ready", msgHandler)
    socket.close()
end

local ok
ok, socket = connect(addr, port)
if not ok then
    error("Couldn't connect to the server, check logs for more info")
end

event.listen("internet_ready", msgHandler)

send(socket, msgfmt(Message(MessageType.HELLO, protocolVersion, clientName):toBytes()))