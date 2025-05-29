local tool = require 'module/toolModule'
local blockM = require './module/waf/blockModule'

if blockM.block_ip_exists(ngx.ctx.remote_addr) then
    tool.swrite("hit block ip")
    ngx.exit(444)
end