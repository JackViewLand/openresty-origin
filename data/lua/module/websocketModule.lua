local server = require "resty.websocket.server"
local tool = require 'module/toolModule'

local _M = {}

function init_websocket()
    local wb, err = server:new{
        timeout = 5000,
        max_payload_len = 65535
    }

    if not wb then
        ngx.log(ngx.ERR, "failed to create WebSocket: ", err)
        return nil,err
    end

    wb:send_text("WebSocket Connection successful!")
    tool.swrite("WebSocket Connection successful!")

    return wb
end

function handle_messages(wb)
    while true do
        local data, typ, err = wb:recv_frame()
        if not data then
            ngx.log(ngx.ERR, "failed to receive: ", err)
            return ngx.exit(444)
        end

        if typ == "close" then
            wb:send_close()
            return
        elseif typ == "ping" then
            wb:send_pong()
        elseif typ == "text" then
            wb:send_text("Echo: " .. data)
        end
    end
end

function main()
    local wb, err = init_websocket()
    if not wb then
        return ngx.exit(444)
    end
    handle_messages(wb)
end

_M.main = main

return _M