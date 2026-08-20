#!/bin/bash
#
# 續期所有已申請的 Let's Encrypt 憑證。
# certbot 只會續期「30 天內到期」的憑證，可安全地重複執行。
#
# 用法：
#   ./renew_cert.sh              # 實際續期
#   DRY_RUN=1 ./renew_cert.sh    # 只測試流程，不真的更新憑證
#
# 建議加入 crontab 每天執行一次：
#   0 3 * * * /path/to/openresty-origin/renew_cert.sh >> /var/log/certbot-renew.log 2>&1
#
set -euo pipefail

cd "$(dirname "$0")"

COMPOSE="docker compose"
WEBROOT_SERVICE="openresty1"

DRY_RUN_ARG=()
if [ "${DRY_RUN:-0}" = "1" ]; then
    DRY_RUN_ARG=(--dry-run)
    echo "🧪 dry-run 模式：不會實際更新憑證"
fi

if ! $COMPOSE ps --status running --services 2>/dev/null | grep -qx "$WEBROOT_SERVICE"; then
    echo "❌ $WEBROOT_SERVICE 未啟動，webroot 驗證無法進行" >&2
    exit 1
fi

echo "檢查憑證續期..."
$COMPOSE run --rm certbot renew \
    --webroot \
    --webroot-path=/var/www/certbot \
    --non-interactive \
    "${DRY_RUN_ARG[@]}"

if [ "${DRY_RUN:-0}" != "1" ]; then
    echo "重新載入 $WEBROOT_SERVICE ..."
    $COMPOSE exec -T "$WEBROOT_SERVICE" openresty -s reload || \
        echo "⚠️  reload 失敗，請手動執行：$COMPOSE exec $WEBROOT_SERVICE openresty -s reload"
fi

echo "✅ 續期檢查完成"
