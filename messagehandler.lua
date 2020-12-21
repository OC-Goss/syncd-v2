local MessageType = require("messagetype")
local Message = require("message")
local utils = require("utils")

local handlers = {
    [MessageType.HELLO_OK] = function(msg, state)
        log("Connected to %s (protocol version %s)", msg.serverName, msg.protocolVersion)
        log("Asking for available subscriptions")
        return Message(MessageType.GET_SUBSCRIPTIONS)
    end,

    [MessageType.HELLO_ERROR] = function(msg, state)
        log("Error connecting to the server: %s", msg.reason)
    end,

    [MessageType.SEND_SUBSCRIPTIONS] = function(msg, state)
        log("Got subscription list from the server:")
        for _, path in ipairs(msg.paths) do
            log("%s", path)
        end
        state.subscribedPaths = utils.deepCopy(msg.paths)
        log("Subscribing to all paths")
        return Message(MessageType.SUBSCRIBE, #state.subscribedPaths, state.subscribedPaths)
    end,
    
    [MessageType.SUBSCRIBE_RESPONSE] = function(msg, state) end,
    [MessageType.SEND_HASHES] = function(msg, state) end,
    [MessageType.SEND_FILE] = function(msg, state) end,
    [MessageType.SEND_FILE_ERROR] = function(msg, state) end,

    [MessageType.NOTIFY_CHANGE] = function(msg, state)
        log("File %s modified", msg.path)
    end,

    [MessageType.NOTIFY_DELETE] = function(msg, state)
        log("File %s deleted", msg.path)
    end,
    
    [MessageType.NOTIFY_CREATE] = function(msg, state)
        log("File %s created", msg.path)
    end,
}

local function messageHandler(data, state)
    local message = Message(data)
    local response = handlers[message.type](message, state)
    if response then
        return response:toBytes()
    end
end

return messageHandler