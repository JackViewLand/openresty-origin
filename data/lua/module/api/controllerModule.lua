local tool = require 'module/toolModule'
local dictModule = require 'module/api/module/dictModule'
local cjson = require 'cjson'
local uri = ngx.ctx.uri
local agrs = ngx.ctx.args

--------------
--dict
--------------
if uri == "/api/dict/status" then
    local respJson, err = dictModule.getStatus()
    if not respJson then
        tool.swrite(err)
        ngx.exit(500)
    end
    return ngx.say(respJson)
elseif uri == "/api/dict/keys" then
    local dictName = agrs and agrs["dict"]
    if not dictName then
        tool.swrite("missing dict arg")
        ngx.exit(400)
    end
    local respJson, err = dictModule.getKeys(dictName)
    if not respJson then
        tool.swrite(err)
        ngx.exit(500)
    end
    return ngx.say(respJson)
elseif uri == "/api/dict/clearAll" then
    local resp, err = dictModule.clearAll()
    if not resp then
        tool.swrite(err)
        ngx.exit(500)
    end
    return ngx.say(resp)
elseif uri == "/api/dict/clear" then
    local dictName = agrs and agrs["dict"]
    if not dictName then
        tool.swrite("missing dict arg")
        ngx.exit(400)
    end
    local resp, err = dictModule.clearDict(dictName)
    if not resp then
        tool.swrite(err)
        ngx.exit(500)
    end
    return ngx.say(resp)
else
    tool.swrite("api not found: " .. uri)
    ngx.exit(403)
end