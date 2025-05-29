# openresty-origin

websocket 連線測試
```
websocat ws://{server_name}/socket.io/
```

## API
### dict相關
查看全部 shared.dict
```
curl http://127.0.0.1:5066/api/dict/status
```
查看指定 shared.dict
```
curl http://127.0.0.1:5066/api/dict/keys?dict={dictName}
```
清出全部 shared.dict
```
curl http://127.0.0.1:5066/api/dict/clearAll
```
清除指定 shared.dict
```
curl http://127.0.0.1:5066/api/dict/clear?dict={dictName}
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
