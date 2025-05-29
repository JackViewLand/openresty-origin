# openresty-origin

websocket 連線測試
```
websocat ws://{server_name}/socket.io/
```

## 測試
debug log 模組
```
local tool = require 'module/toolModule'

tool.swrite("debug msg")
```
debug log 路徑
```
tail -f /var/log/nginx/lua.log
```
