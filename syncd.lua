local component = require("component")
local internet = component.isAvailable("internet") and component.internet
local event = require("event")
local utils = require("utils")
local messageHandler = require("messagehandler")
local MessageType = require("messagetype")
local Message = require("message")
local Socket = require("socket")
local config = require("syncdconfig")
local socket

local enableLogging = true

if enableLogging then
    function log(str, ...)
        local logfile = io.open("/home/socklog.txt", "a")
        logfile:write(string.format(str.."\n", ...))
        logfile:close()
    end
else
    function log() end
end

local conversationState

local function conversationReset()
    conversationState = {
        requestedSubs = {}
    }
end
conversationReset()

local function internetReadyHandler(ev, inetAddress, socketId)
    if socket:id() == socketId then
        local ok, messages = socket:readLenPrep()
        if ok then
            for _, data in ipairs(messages) do
                log("Calling message handler with data: %s", data)
                local response = messageHandler(data, conversationState)
                if response then
                    for i = 1, #response do
                        socket:writeLenPrep(response[i])
                    end
                end
            end
        else
            if not socket:connect(config.addr, config.port) then
                event.ignore("internet_ready", internetReadyHandler)
            else
                -- reset conversation state
                conversationReset()
                socket:writeLenPrep(Message(MessageType.HELLO, config.protocolVersion, config.clientName):toBytes())
            end
        end
    end
end

function disconnect()
    event.ignore("internet_ready", internetReadyHandler)
    socket:close()
end

socket = Socket(config.headerFormat, config.maxRetries)
if not socket:connect(config.addr, config.port) then
    error("Couldn't connect to the server, check logs for more info")
end
event.listen("internet_ready", internetReadyHandler)
socket:writeLenPrep(Message(MessageType.HELLO, config.protocolVersion, config.clientName):toBytes())