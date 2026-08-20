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

# ---------- 6. 重新載入 nginx ----------
echo
echo "重新載入 $WEBROOT_SERVICE ..."
$COMPOSE exec -T "$WEBROOT_SERVICE" openresty -s reload || \
    echo "⚠️  reload 失敗，請確認 nginx 設定後手動執行：$COMPOSE exec $WEBROOT_SERVICE openresty -s reload"

echo
echo "✅ 憑證申請完成：${DOMAINS[*]}"
echo
echo "容器內路徑（填入 nginx 設定用）："
echo "  ssl_certificate     /etc/letsencrypt/live/$CERT_NAME/fullchain.pem;"
echo "  ssl_certificate_key /etc/letsencrypt/live/$CERT_NAME/privkey.pem;"
echo
echo "主機端路徑：./certbot/conf/live/$CERT_NAME/"
echo "續期請執行：./renew_cert.sh"
