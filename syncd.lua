local component = require("component")
local internet = component.isAvailable("internet") and component.internet
local event = require("event")
local utils = require("utils")

local addr = "127.0.0.1"
local port = 2137
local headerfmt = ">I4"
local headerlen = string.packsize(headerfmt)
local maxRetries = {
    reconnect = 3
}
local socket

local function log(str, ...)
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


local function processmsg(msg)
    log("Message received: %s\n", msg)
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
        if msglen then
            while #buf - headerlen >= msglen do
                processmsg(string.sub(buf, headerlen+1, headerlen+msglen))
                buf = string.sub(buf, headerlen+msglen+1)
                -- read next message length if available
                if #buf >= headerlen then
                    msglen = string.unpack(headerfmt, string.sub(buf, 1, headerlen))
                else
                    msglen = nil
                end
            end
        end
    end

   return sockmsg
end

local ipsum = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. In id ipsum nibh. Fusce tempor nisl ac enim finibus commodo. Nam lorem est, tincidunt id sagittis id, euismod ac est. Pellentesque sapien velit, pellentesque sollicitudin turpis at, mattis malesuada dolor. Nunc lacinia sollicitudin molestie. Quisque at justo neque. Praesent felis quam, imperdiet vel ipsum in, consectetur elementum ipsum. Phasellus sollicitudin est non auctor ultrices. Sed auctor nulla at sem rutrum consequat. Phasellus semper ante non fringilla malesuada. Suspendisse non volutpat massa. Nunc non tincidunt arcu. Nunc sed turpis eu leo mollis congue dapibus nec erat. Curabitur blandit tortor in sapien blandit tincidunt. Praesent feugiat leo sed tortor rutrum, vitae fermentum tortor cursus. Proin lobortis volutpat elit, nec suscipit ligula hendrerit ac. Nulla et interdum orci. Nulla interdum leo feugiat, rhoncus quam sed, porttitor lectus. Nulla ornare porta erat in ullamcorper. Nam facilisis odio tellus, vehicula rutrum purus pellentesque sed. Sed nec magna convallis, dignissim lacus fermentum, ultrices lorem. Sed eget metus et elit euismod sagittis. Vestibulum leo lacus, mattis id pharetra sit amet, lobortis in libero. Phasellus mattis justo quis elementum vulputate. Vestibulum ante ipsum primis in faucibus orci luctus et ultrices posuere cubilia curae; Maecenas consectetur mauris sed leo sollicitudin vehicula. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Ut tempus magna justo, quis maximus elit mattis in. Nulla rutrum rhoncus neque ac consectetur. Nam venenatis nulla sit amet est suscipit rutrum. Aenean bibendum elit leo, sed lacinia massa mollis et. Sed nec nisi fringilla, condimentum elit a, mollis libero. Aliquam erat volutpat. In posuere orci orci, vel euismod arcu efficitur et. Donec pretium vestibulum nunc in ultricies. Interdum et malesuada fames ac ante ipsum primis in faucibus. Nunc odio lectus, fermentum sit amet facilisis eget, egestas eu urna. Morbi pellentesque nisl sapien, vitae fringilla felis auctor dignissim. Cras vestibulum magna erat, ac dignissim nisi ornare vel. Fusce purus odio, sodales sed vulputate et, elementum congue nulla. Integer sed porttitor metus. Maecenas non tincidunt dolor, sit amet rutrum enim. Nullam quis quam rutrum, molestie nibh ut, elementum dolor. Sed quam magna, eleifend in sagittis ut, molestie nec dui. Ut pharetra nulla nec iaculis pulvinar. Etiam vel eros ullamcorper, scelerisque lorem eget, bibendum purus. Proin massa lorem, rhoncus ac malesuada ac, faucibus sed ipsum. Etiam mollis ligula vel turpis dignissim, ac consectetur arcu luctus. Ut neque justo, iaculis nec mollis vel, sollicitudin nec eros. Praesent posuere nulla sed arcu pretium molestie. Sed et nisl non odio ornare varius. Suspendisse potenti. Quisque dapibus sollicitudin erat, vestibulum condimentum nibh. Integer accumsan metus eros, vitae scelerisque leo mollis ac. Quisque lobortis tincidunt est sed pulvinar. Vestibulum mollis accumsan turpis, feugiat finibus nulla sagittis eu. Aenean eu sodales ex, eget sagittis mauris. Nam eget lectus id dolor eleifend consequat hendrerit ac orci. Integer iaculis efficitur magna, sit amet elementum arcu facilisis a. Suspendisse blandit, turpis eget ornare feugiat, ante leo blandit diam, posuere ultricies ipsum nunc eu sapien. Cras luctus justo quam, eget malesuada quam venenatis id. Maecenas volutpat enim ac porttitor tempor. Sed ac."

local ok
ok, socket = connect(addr, port)
if not ok then
    error("Couldn't connect to the server, check logs for more info")
end

event.listen("internet_ready", getMsgHandler())

if send(socket, msgfmt(ipsum)) then
    print("Message sent")
else
    print("Error occured")
end

