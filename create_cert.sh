#!/bin/bash
#
# 申請 Let's Encrypt 憑證（webroot 驗證，由 openresty1 提供 /.well-known/acme-challenge/）
#
# 用法：
#   ./create_cert.sh example.com www.example.com
#   ./create_cert.sh                      # 互動輸入域名
#   CERTBOT_EMAIL=me@example.com ./create_cert.sh example.com
#   STAGING=1 ./create_cert.sh example.com    # 測試用，不計入 rate limit
#
set -euo pipefail

cd "$(dirname "$0")"

COMPOSE="docker compose"
WEBROOT_SERVICE="openresty1"
WEBROOT_PATH="/var/www/certbot"

# ---------- 1. 取得域名 ----------
DOMAINS=("$@")
if [ ${#DOMAINS[@]} -eq 0 ]; then
    read -rp "請輸入要申請憑證的域名（多組以空白分隔）: " -a DOMAINS
fi
if [ ${#DOMAINS[@]} -eq 0 ]; then
    echo "❌ 域名不能為空" >&2
    exit 1
fi

for d in "${DOMAINS[@]}"; do
    if ! [[ "$d" =~ ^\*?[a-zA-Z0-9._-]+\.[a-zA-Z]{2,}$ ]]; then
        echo "❌ 域名格式不正確：$d" >&2
        exit 1
    fi
done

# ---------- 2. 取得 email ----------
EMAIL="${CERTBOT_EMAIL:-}"
if [ -z "$EMAIL" ]; then
    read -rp "請輸入聯絡 email（憑證到期通知）: " EMAIL
fi
if ! [[ "$EMAIL" =~ ^[^@[:space:]]+@[^@[:space:]]+\.[a-zA-Z]{2,}$ ]]; then
    echo "❌ email 格式不正確：$EMAIL" >&2
    exit 1
fi

# ---------- 3. 確認 webroot 服務已啟動 ----------
if ! $COMPOSE ps --status running --services 2>/dev/null | grep -qx "$WEBROOT_SERVICE"; then
    echo "⚠️  $WEBROOT_SERVICE 未啟動，正在啟動..."
    $COMPOSE up -d "$WEBROOT_SERVICE"
    sleep 3
fi

# ---------- 4. 驗證 ACME challenge 路徑可被外部讀取 ----------
TOKEN="precheck-$(date +%s)"
$COMPOSE exec -T "$WEBROOT_SERVICE" sh -c \
    "mkdir -p $WEBROOT_PATH/.well-known/acme-challenge && printf '%s' '$TOKEN' > $WEBROOT_PATH/.well-known/acme-challenge/$TOKEN"

PRECHECK_FAILED=()
for d in "${DOMAINS[@]}"; do
    [[ "$d" == \** ]] && continue   # 萬用域名只能用 DNS 驗證，跳過
    if [ "$(curl -fsS --max-time 10 "http://$d/.well-known/acme-challenge/$TOKEN" 2>/dev/null)" != "$TOKEN" ]; then
        PRECHECK_FAILED+=("$d")
    fi
done

$COMPOSE exec -T "$WEBROOT_SERVICE" rm -f "$WEBROOT_PATH/.well-known/acme-challenge/$TOKEN" || true

if [ ${#PRECHECK_FAILED[@]} -gt 0 ]; then
    echo
    echo "❌ 以下域名無法從外部讀取 ACME challenge：${PRECHECK_FAILED[*]}" >&2
    echo "   請確認 DNS A record 指向本機、對外 80 port 未被防火牆擋住。" >&2
    echo "   （若確定環境無誤想直接申請，可用 SKIP_PRECHECK=1 略過此檢查）" >&2
    [ "${SKIP_PRECHECK:-0}" = "1" ] || exit 1
    echo "   已設定 SKIP_PRECHECK=1，繼續申請。" >&2
fi

# ---------- 5. 申請憑證 ----------
CERT_NAME="${DOMAINS[0]}"
DOMAIN_ARGS=()
for d in "${DOMAINS[@]}"; do DOMAIN_ARGS+=(-d "$d"); done

STAGING_ARG=()
if [ "${STAGING:-0}" = "1" ]; then
    STAGING_ARG=(--staging)
    echo "🧪 staging 模式：取得的憑證不受瀏覽器信任，僅供流程測試"
fi

echo
echo "準備申請憑證：${DOMAINS[*]}"
echo

$COMPOSE run --rm certbot certonly \
    --webroot \
    --webroot-path="$WEBROOT_PATH" \
    --cert-name "$CERT_NAME" \
    "${DOMAIN_ARGS[@]}" \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    --keep-until-expiring \
    --non-interactive \
    "${STAGING_ARG[@]}"

# ---------- 6. 產生 443 設定檔 ----------
# 80 port 的設定維持原樣不動，443 以獨立檔案並存。
SSL_CONF="openresty1/conf.d/ssl-$CERT_NAME.conf"

if [ -f "$SSL_CONF" ] && [ "${FORCE_SSL_CONF:-0}" != "1" ]; then
    echo "ℹ️  $SSL_CONF 已存在，保留不覆蓋（要重新產生請用 FORCE_SSL_CONF=1）"
else
    cat > "$SSL_CONF" <<CONF
# 由 create_cert.sh 自動產生（憑證：${CERT_NAME}）
# 憑證續期後路徑不變，此檔不需要跟著更新。
server {
    listen       443 ssl;
    # 不啟用 http2：全域 rewrite_by_lua 會呼叫 ngx.req.read_body()，
    # 而 OpenResty 1.25 的 read_body() 不支援沒有 content-length 的
    # HTTP/2 請求（例如一般 GET），開了會讓所有請求變成 500。
    server_name  ${DOMAINS[*]};

    ssl_certificate     /etc/letsencrypt/live/$CERT_NAME/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$CERT_NAME/privkey.pem;
    ssl_protocols       TLSv1.2 TLSv1.3;
    ssl_session_cache   shared:SSL:10m;
    ssl_session_timeout 1d;

    location / {
        content_by_lua_file /data/lua/phase/content/controllerModule.lua;
    }

    location /proxy {
        proxy_pass http://backend;
        proxy_http_version 1.1;
        proxy_set_header stream-true-ip \$remote_addr;
        proxy_set_header Host \$host;
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        add_header Pragma "no-cache";
        add_header Expires "0";
    }

    location /image {
        root   /data/static;
        index  Leonardo.gif;
    }

    location /video {
        root   /data/static;
        index  view.mp4;
        add_header Content-Type video/mp4;
    }

    location /mp3 {
        root /data/static;
        index playlist.mp3;
        add_header Content-Type 'audio/mpeg';
    }

    location /doc {
        root /data/static;
        index test.doc;
        add_header Content-Disposition 'attachment; filename="test.doc"';
    }

    location /socket.io {
        content_by_lua_block{
           local websocket = require "module/websocketModule"
           websocket.main()
        }
    }

    location /api/ {
        proxy_pass http://goapi:5000/;
    }

    location ~ ^/httpcode/(\\d+)\$ {
        content_by_lua_block{
            ngx.header.content_type = 'text/plain'
            local uri = ngx.var.uri
            local code = tonumber(uri:match("/httpcode/(%d+)\$"))
            if code then
                ngx.status = code
                ngx.say("http code: ",code)
                ngx.exit(code)
            else
                ngx.status = 200
                ngx.say("ok")
                ngx.exit(200)
            end
        }
    }

    error_page  404              /404.html;

    error_page   500 502 503 504  /50x.html;
    location = /50x.html {
        root   /usr/local/openresty/nginx/html;
    }
}
CONF
    echo "📝 已產生 $SSL_CONF"
fi

# ---------- 7. 驗證設定並重新載入 ----------
echo
echo "驗證 nginx 設定..."
if ! $COMPOSE exec -T "$WEBROOT_SERVICE" openresty -t; then
    echo "❌ nginx 設定驗證失敗，未重新載入（現有服務不受影響）" >&2
    echo "   請檢查 $SSL_CONF 後手動執行：$COMPOSE exec $WEBROOT_SERVICE openresty -s reload" >&2
    exit 1
fi

echo "重新載入 $WEBROOT_SERVICE ..."
$COMPOSE exec -T "$WEBROOT_SERVICE" openresty -s reload

echo
echo "✅ 憑證申請完成：${DOMAINS[*]}"
echo "   HTTPS 已啟用，80 port 的原有行為維持不變。"
echo
echo "   憑證存放：./certbot/conf/live/$CERT_NAME/"
echo "   443 設定：$SSL_CONF"
echo "   續期請執行：./renew_cert.sh（憑證路徑不變，設定檔不必跟著改）"
