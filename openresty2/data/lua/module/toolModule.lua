local ntable = require "table.new"
local concat = table.concat
local cjson = require "cjson"
local path = "/var/log/openresty/lua.log"

local function swrite(content)
    local file = io.open(path,'a+');
    file:write(content.."\n")
    file:close()
end

local function read_file(path)
    local file = io.open(path,"r")
    if file == nil then return false end
    local allfile = file:read("a")
    if allfile == "" then return false end
    file:close()
    return allfile
end

local function fileSize(path)
    local file = io.open(path,"r")
    if not file then 
        ngx.log(ngx.ERR,"not found file: "..tostring(path))
	return 0
    end
    local current = file:seek() -- get current position
    local size = file:seek("end") -- git file size
    file:seek("set", current)
    file:close()
    return size
end

local _M = ntable(0,3)
_M.swrite = swrite
_M.read_file = read_file
_M.fileSize = fileSize

return _M
