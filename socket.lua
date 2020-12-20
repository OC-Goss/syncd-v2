local utils = require("utils")
local internet = require("component").internet

local Socket = utils.makeClass(function(self, lenPattern, maxRetries)
    self.lenPattern = lenPattern or ">I4"
    self.maxRetries = maxRetries or 3
    self.readBuffer = ""
    self.currentMsgLen = nil
end)

function Socket:connect(addr, port)
    self.readBuffer = ""
    self.currentMsgLen = nil
    if self.socket then
        self.socket.close()
    end

    local retries = 0
    while retries <= self.maxRetries do
        local socket, reason = internet.connect(addr, port)
        if not socket then
            log("Failed to create socket: %s", reason)
            self.socket = nil
            return false, reason
        end
        -- ensure connection
        local ok, reason = socket.finishConnect()
        -- can get either true when connection was successful, false, or nil + reason when it failed
        while not ok and not reason do
            ok, reason = socket.finishConnect()
        end
        if ok then
            -- socket connected
            log("Connected to %s:%s", addr, port)
            self.socket = socket
            return true
        else
            log("Failed to connect to %s:%s, reason: %s", addr, port, reason)
            retries = retries + 1
        end
    end
    log("Retries to connect to %s:%s failed", addr, port)
    -- return failure
    self.socket = nil
    return false, "Couldn't connect to the remote server"
end

function Socket:close(...)
    return self.socket.close(...)
end

function Socket:id(...)
    return self.socket.id(...)
end

function Socket:read(bytes)
    if bytes then
        local fullMsg = {}
        while bytes > 0 do
            local msg, reason = self.socket.read(bytes)
            if msg then
                bytes = bytes - #msg
                fullMsg[#fullMsg+1] = msg 
                log("Read %d bytes, %d bytes left to read", #msg, bytes)
            else
                -- socket error
                log("Socket read failed: %s", reason)
                return false, reason
            end
        end
        return true, table.concat(fullMsg)
    else
        return true, self.socket.read()
    end
end

-- reads new data from the socket and returns all messages prepended with a length contained in the read buffer after reading
function Socket:readLenPrep()
    log("internet_ready handler called")
    local partialMsg, reason = self.socket.read()
    if partialMsg then
        self.readBuffer = self.readBuffer .. partialMsg
    else
        log("Socket read failed: %s", reason)
        return false, reason
    end

    -- first stage - parse message length
    local lenSize = string.packsize(self.lenPattern)
    if #self.readBuffer >= lenSize and not self.currentMsgLen then
        self.currentMsgLen = string.unpack(self.lenPattern, string.sub(self.readBuffer, 1, lenSize))
        log("Received message length: %d", self.currentMsgLen)
    end

    -- second stage - while there are whole messages in buffer, dispatch message for processing and then remove it from buffer
    log("Current buffer length: %d", #self.readBuffer)
    local messages = {}
    while self.currentMsgLen and #self.readBuffer - lenSize >= self.currentMsgLen do
        messages[#messages+1] = string.sub(self.readBuffer, lenSize+1, lenSize+self.currentMsgLen)
        self.readBuffer = string.sub(self.readBuffer, lenSize+self.currentMsgLen+1)
        -- read next message length if available
        if #self.readBuffer >= lenSize then
            self.currentMsgLen = string.unpack(self.lenPattern, string.sub(self.readBuffer, 1, lenSize))
        else
            self.currentMsgLen = nil
        end
    end
    return true, messages
end

-- synchronous socket write, returns status and failure reason if status is false
function Socket:write(msg)
    local written = 0
    -- sock.write should always write 0 bytes or the whole message, but we do a standard write loop just in case
    while written < #msg do
        local bytes, reason = self.socket.write(string.sub(msg, written+1)) -- correct string start for lua indexing starting at 1
        if bytes then
            written = written + bytes
            log("Wrote %d bytes, fully written %d bytes", bytes, written)
        else
            -- socket error
            log("Socket write failed: %s", reason)
            return false, reason
        end
    end
    return true
end

function Socket:writeLenPrep(msg)
    return self:write(string.pack(self.lenPattern, #msg) .. msg)
end

return Socket