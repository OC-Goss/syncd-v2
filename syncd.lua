local component = require("component")
local internet = component.isAvailable("internet") and component.internet
local event = require("event")
local utils = require("utils")
local messageHandler = require("messagehandler")
local MessageType = require("messagetype")
local Message = require("message")
local Socket = require("socket")

local addr = "127.0.0.1"
local port = 2137
local headerFormat = ">I4"
local maxRetries = 3
local clientName = "Syncd client alpha v0.1"
local protocolVersion = "0.1"
local socket

function log(str, ...)
    local logfile = io.open("socklog.txt", "a")
    logfile:write(string.format(str.."\n", ...))
    logfile:close()
end

local conversationState

local function conversationReset()
    conversationState = {
        subscribedPaths = {}
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
                    socket:writeLenPrep(response)
                end
            end
        else
            if not socket:connect(addr, port) then
                event.ignore("internet_ready", internetReadyHandler)
            else
                -- reset conversation state
                conversationReset()
                socket:writeLenPrep(Message(MessageType.HELLO, protocolVersion, clientName):toBytes())
            end
        end
    end
end

function disconnect()
    event.ignore("internet_ready", internetReadyHandler)
    socket:close()
end

socket = Socket(headerFormat, maxRetries)
if not socket:connect(addr, port) then
    error("Couldn't connect to the server, check logs for more info")
end
event.listen("internet_ready", internetReadyHandler)
socket:writeLenPrep(Message(MessageType.HELLO, protocolVersion, clientName):toBytes())