local tool = require './module/toolModule'
local block_ip_file = "/data/base/block/block_ip.txt"
local blockIpDict = ngx.shared.blockIpList

local function load_block_ip()
    local file, err = io.open(block_ip_file, "r")
    if not file then
        ngx.log(ngx.ERR, "failed to open block_ip file: ", err)
        return
    end
    for line in file:lines() do
        local ip = line:match("^%s*(.-)%s*$")
        if ip ~= "" then
            blockIpDict:set(ip, true)
        end
    end
    file:close()
end

local function block_ip_exists(ip)
    if not ip or type(ip) ~= "string" then
        return false
    end
    return blockIpDict:get(ip) ~= nil
end

local _M = {}
_M.load_block_ip = load_block_ip
_M.block_ip_exists = block_ip_exists
return _M