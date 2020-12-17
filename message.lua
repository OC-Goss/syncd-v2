local utils = require("utils")
local MessageType = require("messagetype")

local Message = utils.makeClass(function(self, msgTypeOrData, ...)
    if type(msgTypeOrData) == "number" then
        self:fromFields(msgTypeOrData, ...)
    elseif type(msgTypeOrData) == "string" then
        self:fromBytes(msgTypeOrData)
    end
end)

local Format = utils.makeClass(function(self, structFmt, fieldNames)
    self.structFmt = structFmt
    self.fieldNames = fieldNames
end)

Message.typeFormat = ">B"
Message.formats = {
    [MessageType.HELLO] = Format(">zz", {"protocolVersion", "clientName"}),
    [MessageType.GET_SUBSCRIPTIONS] = Format("", {}),
    [MessageType.SUBSCRIBE] = Format(">I4 /0[z]", {"numPaths", "paths"}),
    [MessageType.COMPARE_FILES] = Format(">I4 /0[zI4]", {"numPaths", "paths"}),
    [MessageType.GET_FILE] = Format(">z", {"path"}),

    [MessageType.HELLO_OK] = Format(">zz", {"protocolVersion", "serverName"}),
    [MessageType.HELLO_ERROR] = Format(">z", {"reason"}),
    [MessageType.SEND_SUBSCRIPTIONS] = Format(">I4 /0[z]", {"numPaths", "paths"}),
    [MessageType.SUBSCRIBE_RESPONSE] = Format(">I4 /0[z] I4 /2[zI2]", {"numPaths", "paths", "numPathsFail", "pathsFail"}),
    -- proposal for the future: {numPaths = "I4", paths = {__size = "numPaths", "z"}, numPathsFail = "I4", pathsFail = {__size = "numPaths", path = "z", errorCode = "I2"}}
    [MessageType.SEND_HASHES] = Format(">I4 /0[z z]", {"numPaths", "paths"}),
    [MessageType.SEND_FILE] = Format(">zz", {"path", "contents"}),
    [MessageType.SEND_FILE_ERROR] = Format(">zz", {"path", "reason"}),
    [MessageType.NOTIFY_CHANGE] = Format(">z", {"path"}),
    [MessageType.NOTIFY_DELETE] = Format(">z", {"path"}),
    [MessageType.NOTIFY_CREATE] = Format(">z", {"path"}),
}

local function unpackArray(lenPattern, pattern, data, offset, fieldNames)
    local len, offset = string.unpack(lenPattern, data, offset)

    local res = {}
    for i = 1, len do
        local unpacked = table.pack(string.unpack(pattern, data, offset))
        offset = unpacked[#unpacked]
        unpacked[#unpacked] = nil -- remove last unpacked byte from unpacked values
        if fieldNames then
            res[i] = {}
        end
        for j, v in ipairs(unpacked) do
            if fieldNames then
                if fieldNames[j] then
                    res[i][fieldNames[j]] = v
                end
            else
                res[i] = v
            end
        end
    end
    return res, len, offset
end

local function packArray(lenPattern, pattern, len, array, fieldNames)
    local res = {string.pack(lenPattern, len)}
    for i = 1, len do
        if fieldNames then
            local toPack = {}
            for i, v in ipairs(fieldNames) do
                toPack[i] = array[v]
            end
            res[i+1] = string.pack(pattern, table.unpack(toPack))
        else
            res[i+1] = string.pack(pattern, array[i])
        end
    end
    return table.concat(res), #res
end

function Message:fromFields(msgType, ...)
    local format = Message.formats[msgType]
    self.type = msgType
    if format then
        for i, v in ipairs(table.pack(...)) do
            if format.fieldNames[i] then
                self[format.fieldNames[i]] = v
            end
        end
    end
end

function Message:fromBytes(data)
    self.type = string.unpack(Message.typeFormat, data)
    local offset = 1 + string.packsize(Message.typeFormat)
    
    if self.type == MessageType.SUBSCRIBE or self.type == MessageType.SEND_SUBSCRIPTIONS then
        self.paths, self.numPaths = unpackArray(">I4", ">z", data, offset)
    elseif self.type == MessageType.COMPARE_FILES then
        self.paths, self.numPaths = unpackArray(">I4", ">zI4", data, offset, {"path", "size"})
    elseif self.type == MessageType.SUBSCRIBE_RESPONSE then
        self.paths, self.numPaths, offset = unpackArray(">I4", ">z", data, offset)
        self.pathsFail, self.numPathsFail = unpackArray(">I4", ">zI2", data, offset, {"path", "errorCode"})
    elseif self.type == MessageType.SEND_HASHES then
        self.paths, self.numPaths = unpackArray(">I4", "zz", data, offset, {"path", "hash"})
    elseif Message.formats[self.type] ~= nil then
        local format = Message.formats[self.type]
        for i, v in ipairs(table.pack(string.unpack(format.structFmt, data, offset))) do
            if format.fieldNames[i] then
                self[format.fieldNames[i]] = v
            end
        end
    end
end

function Message:toBytes()
    local msg = {string.pack(Message.typeFormat, self.type)}
    if self.type == MessageType.SUBSCRIBE or self.type == MessageType.SEND_SUBSCRIPTIONS then
        msg[2] = packArray(">I4", "z", self.numPaths, self.paths)
    elseif self.type == MessageType.COMPARE_FILES then
        msg[2] = packArray(">I4", "zI4", self.numPaths, self.paths, {"path", "size"})
    elseif self.type == MessageType.SUBSCRIBE_RESPONSE then
        msg[2] = packArray(">I4", "z", self.numPaths, self.paths)
        msg[3] = packArray(">I4", "zI2", self.numPathsFail, self.pathsFail, {"path", "errorCode"})
    elseif self.type == MessageType.SEND_HASHES then
        msg[2] = packArray(">I4", "zz", self.numPaths, self.paths, {"path", "hash"})
    elseif Message.formats[self.type] ~= nil then
        local format = Message.formats[self.type]
        msg[2] = packArray("", format.structFmt, 1, self, format.fieldNames)
    end
    return table.concat(msg)
end

return Message