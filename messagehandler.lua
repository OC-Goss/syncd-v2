local MessageType = require("messagetype")
local Message = require("message")
local utils = require("utils")
local config = require("syncdconfig")
local filesystem = require("filesystem")

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
        state.requestedSubs = {}
        for _, entry in ipairs(msg.paths) do
            log("%s, isDir: %s", entry.path, tostring(entry.isDir))
            state.requestedSubs[#state.requestedSubs+1] = entry.path
        end
        log("Subscribing to all paths")
        return Message(MessageType.SUBSCRIBE, #state.requestedSubs, state.requestedSubs)
    end,
    
    [MessageType.SUBSCRIBE_RESPONSE] = function(msg, state)
        if not state.subs then
            state.subs = {}
        end
        for _, entry in ipairs(msg.paths) do
            state.subs[#state.subs+1] = entry
        end
        log("Failed to subscribe to paths:")
        for _, failed in ipairs(msg.pathsFail) do
            log("%s", failed.path)
        end

        local getAll = {}
        for i, entry in ipairs(state.subs) do
            if entry.isDir == 0 then
                getAll[#getAll+1] = Message(MessageType.GET_FILE, entry.path)
            else
                filesystem.makeDirectory(filesystem.concat(config.localDir, entry.path))
            end
        end
        return getAll

        -- local toCompare = {}
        -- if #state.subs > 0 then
        --     for _, path in ipairs(state.subs) do
        --         local serverPath = filesystem.canonical(path)
        --         local localPath = filesystem.canonical(config.localDir)

        --         -- translate server path to local path
        --         local serverSegments = filesystem.segments(serverPath)
        --         local localSegments = filesystem.segments(localPath)

        --         local fullLocalPath = filesystem.concat(localPath, serverPath)
        --         if not filesystem.isDirectory(fullLocalPath) then
        --             -- if path doesn't exist size is 0
        --             toCompare[#toCompare+1] = {path = serverPath, size = filesystem.size(fullLocalPath)}
        --         else
        --             -- if dir then create
        --         end
        --     end
        -- end
        -- return Message(MessageType.COMPARE_FILES, #toCompare, toCompare)
    end,
    [MessageType.SEND_HASHES] = function(msg, state) end,
    [MessageType.SEND_FILE] = function(msg, state)
        local targetPath = filesystem.concat(config.localDir, msg.path)
        log("Got requested file %s, saving as %s", msg.path, targetPath)
        filesystem.makeDirectory(filesystem.path(targetPath))
        local file = io.open(targetPath, "w")
        file:write(msg.contents)
        file:close()
    end,
    [MessageType.SEND_FILE_ERROR] = function(msg, state)
        log("Error requesting file %s, server responded with: %s", msg.path, msg.reason)
    end,

    [MessageType.NOTIFY_CHANGE] = function(msg, state)
        log("%s modified", msg.path)
        if msg.isDir == 0 then
            return Message(MessageType.GET_FILE, msg.path)
        end
    end,

    [MessageType.NOTIFY_DELETE] = function(msg, state)
        log("%s deleted", msg.path)
        filesystem.remove(filesystem.concat(config.localDir, msg.path))
    end,
    
    [MessageType.NOTIFY_CREATE] = function(msg, state)
        log("%s created", msg.path)
        local targetPath = filesystem.concat(config.localDir, msg.path)
        if msg.isDir == 0 then
            io.open(targetPath, "w"):close()
        elseif msg.isDir == 1 then
            filesystem.makeDirectory(targetPath)
            log("Subscribing to new folder: %s", msg.path)
            return Message(MessageType.SUBSCRIBE, 1, {msg.path})
        end
    end,

    [MessageType.NOTIFY_MOVE] = function(msg, state)
        log("%s moved to %s", msg.srcPath, msg.dstPath)
        filesystem.rename(filesystem.concat(config.localDir, msg.srcPath), filesystem.concat(config.localDir, msg.dstPath))
        filesystem.remove(filesystem.concat(config.localDir, msg.srcPath))
    end,
}

local function messageHandler(data, state)
    local message = Message(data)
    local response = handlers[message.type](message, state)
    if response then
        if utils.isInstance(response, Message) then
            return {response:toBytes()}
        elseif type(response) == "table" then
            for i = 1, #response do
                response[i] = response[i]:toBytes()
            end
            return response
        end
    end
end

return messageHandler