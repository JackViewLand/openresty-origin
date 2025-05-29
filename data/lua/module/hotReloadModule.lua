local tool = require './module/toolModule'
local allow_load = false
local clear_files = {
}

local function clear_module(clear_files)
    if type(clear_files) ~= "table" then return end
    for index=1 ,#clear_files do
        local filePath = clear_files[index]
        if package.loaded[filePath] then
            package.loaded[filePath] = nil
            tool.swrite("worker"..ngx.worker.id()..", clear package.loaded: "..filePath)
        end
    end
end

local function do_action()
    if not allow_load then return end
    clear_module(clear_files)
end

do_action()