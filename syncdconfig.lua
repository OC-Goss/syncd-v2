-- local Config = require("config")

local defaults = {
    addr = "127.0.0.1",
    port = 2137,
    headerFormat = ">I4",
    maxRetries = 3,
    clientName = "Syncd client alpha v0.1",
    protocolVersion = "0.1.1",
    localDir = "/home/tests"
}

-- local configPath = "/etc/syncd.cfg"
-- local config = Config(configPath)
-- config:read(defaults)
-- config:write()

-- return config
return defaults