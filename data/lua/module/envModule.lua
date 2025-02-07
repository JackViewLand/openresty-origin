local tool = require 'module/toolModule'
local _M = {}

function get()
    local prepareInfo = ngx.shared.prepareInfo
    local envTable = {}

    -- get from env
    envTable.SERVER = os.getenv("SERVER")


    -- set prepareInfo
    for key, value in pairs(envTable) do
        prepareInfo:set(key,value)
    end

end

_M.get = get
return _M