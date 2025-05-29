local tool = require './module/toolModule'

local function readHotReload(premature,filePath)
    if premature then return end
    if type(filePath) ~= "string" then return end
    package.loaded[filePath] = nil
    require(filePath)
end

local function hotReloadTimer(circleTime,filePath)
    ngx.timer.every(circleTime, readHotReload, filePath)
end

local _M = {}
_M.hotReloadTimer = hotReloadTimer
return _M