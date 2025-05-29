local ntable = require "table.new"
local tool = require "module/toolModule"

local function getRequestBody()
    ngx.req.read_body()
    local data = ngx.req.get_body_data()
    if not data then
        local dataFile = ngx.req.get_body_file()
	if dataFile then 
	    data = tool.read_file(dataFile)
	else
           return nil, "err: need data value"
	end
    end
    return data
end


local function setCtx(ctx)
    ctx["remote_addr"] = ngx.var.remote_addr
    ctx['status'] =  ngx.var.status
    --ctx["infoEnv"] = ngx.var.infoEnv
    ctx["method"] = ngx.var.request_method
    ctx["port"] = ngx.var.server_port
    ctx["request_uri"] = ngx.var.request_uri
    ctx["uri"] = ngx.var.uri
    ctx["args"] = ngx.req.get_uri_args()
    ctx["host"] = ngx.var.host
    ctx["localtime"] = ngx.var.time_local
    ctx["request_body"] = getRequestBody() or "-"
    ctx["messageLog"] = {}

    local reqHeader, err = ngx.req.get_headers(200)
    if err == "truncated" then ngx.exit(403) end
    ctx["request_header_tbl"] = reqHeader
end

local function waf_bucket()
    if bucket.search() then
        tool.log_record("hit bucket ip")
        ngx.exit(444)
    end
end

local _M = ntable(0,1)
_M.setCtx = setCtx
_M.waf_bucket = waf_bucket
return _M
