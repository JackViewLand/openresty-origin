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

## HTTPS 憑證（Let's Encrypt）

透過 certbot webroot 驗證申請憑證，驗證檔由 `openresty1` 的 80 port 提供
（`location ^~ /.well-known/acme-challenge/`）。

事前準備：域名的 DNS A record 指向本機，且對外 80 port 未被防火牆擋住。

申請憑證
```
./create_cert.sh example.com www.example.com
```
先用 staging 測試流程（不受瀏覽器信任，但不計入 Let's Encrypt rate limit）
```
STAGING=1 ./create_cert.sh example.com
```
略過互動輸入 email
```
CERTBOT_EMAIL=me@example.com ./create_cert.sh example.com
```

申請成功後，把憑證填入 `openresty1/conf.d/default.conf` 的 443 server：
```
ssl_certificate     /etc/letsencrypt/live/example.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
```

續期（certbot 只會續期 30 天內到期的憑證，可安全重複執行）
```
./renew_cert.sh
DRY_RUN=1 ./renew_cert.sh    # 只測試流程
```
建議加入 crontab 每天跑一次
```
0 3 * * * /path/to/openresty-origin/renew_cert.sh >> /var/log/certbot-renew.log 2>&1
```

憑證檔存放於主機 `./certbot/conf/`（已排除於版控之外）。
