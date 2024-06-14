local tool = require 'module/toolModule'
local _M ={}
local server_name = ngx.var.server_name
local container = 'openresty2'

local function getGeneral()
    local general = {}
    general['http_status'] = ngx.ctx.status
    general['http_protocol'] = ngx.req.http_version()
    general['tls_version'] = ngx.var.ssl_protocol
    general['request_url'] = ngx.ctx.request_uri
    general['method'] = ngx.ctx.method
    general['request_port'] = ngx.ctx.port
    general['client_ip'] = ngx.ctx.remote_addr

    --[[
    tool.swrite("---------General----------")
    for k,v in pairs(general) do
        tool.swrite(k..": "..v)
    end
    --]]

    return general
end	

local function getRequestHeaders()
    local requestHeaders = ngx.req.get_headers() or {}

    --[[
    tool.swrite("-----Request Headers------")
    for k,v in pairs(requestHeaders) do 
        tool.swrite(k..": "..v)
    end
    --]]
    
    return requestHeaders
end

local function getRequestArgs()
    local requestArgs = ngx.var.args or {}

    --[[
    tool.swrite("-------Request args-------")
    for k,v in pairs(requestArgs) do 
        tool.swrite(k..": "..v)
    end
    --]]

    return requestArgs
end

local function getResponseHeaders()
    local responseHeaders = ngx.resp.get_headers() or {}

    --[[
    tool.swrite("-----Response Headers-----")
    for k,v in pairs(responseHeaders) do 
        tool.swrite(k..": "..v)
    end
    --]]

    return responseHeaders
end

local function show()
    ngx.header.content_type = 'text/plain'
    ngx.say("Information ViewController")
    ngx.say("==== "..server_name.." =====")
    ngx.say(container)
    ngx.say(" ")

    local general = getGeneral()
    local requestHeaders = getRequestHeaders()
    local requestArgs = getRequestArgs()
    local responseHeaders = getResponseHeaders()

    ngx.say("---------General----------")
    for k,v in pairs(general) do
        ngx.say(k..": "..v)
    end
    ngx.say(" ")
    ngx.say("-----Request Headers------")
    for k,v in pairs(requestHeaders) do
        ngx.say(k..": "..v)
    end
    ngx.say(" ")
    ngx.say("-------Request args-------")
    for k,v in pairs(requestArgs) do
        ngx.say(k..": "..v)
    end
    ngx.say(" ")
    ngx.say("-----Response Headers-----")
    for k,v in pairs(responseHeaders) do
        ngx.say(k..": "..v)
    end
    ngx.say(" ")
end

_M.show = show

return _M

