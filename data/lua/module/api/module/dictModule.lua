local tool = require 'module/toolModule'
local cjson = require 'cjson'
local dictList = {}
table.insert(dictList,"bucketList")
table.insert(dictList,"blockIpList")

local function getStatus()
    local respTable = {}
    for index,name in ipairs(dictList) do
        local tmp = {}
        local dict = ngx.shared
        local bucket = dict[name]
        if not bucket then return nil,"dictName is none" end
        local freeSpace = bucket:free_space()
        local keysTable = bucket:get_keys(0)
        local keysCount = #keysTable

        tmp.dictName = name
        tmp.freeSpace = freeSpace
        tmp.keysCount = keysCount

        table.insert(respTable,tmp)
    end

    local respJson = cjson.encode(respTable)
    return respJson
end

local function getKeys(dictName)
    local dict = ngx.shared[dictName]
    if not dict then return nil, "dictName is none" end
    local keysTable = dict:get_keys(0)
    if not keysTable then
        return nil, "no keys found in dict: " .. dictName
    end
    local respJson = cjson.encode(keysTable)
    return respJson
end

local function clearAll()
    for _, name in ipairs(dictList) do
        local dict = ngx.shared[name]
        if dict then
            dict:flush_all()
            dict:flush_expired()
        end
    end
    return "clear all dicts success"
end

local function clearDict(dictName)
    local dict = ngx.shared[dictName]
    if not dict then return nil, "dictName is none" end
    dict:flush_all()
    dict:flush_expired()
    return "clear dict " .. dictName .. " success"
end

local _M = {}
_M.getStatus = getStatus
_M.getKeys = getKeys
_M.clearAll = clearAll
_M.clearDict = clearDict
return _M