#!/bin/bash
#
# 續期 Let's Encrypt 憑證，並把更新後的憑證部署到站台設定所讀的位置。
#
# certbot 只會續期「30 天內到期」的憑證，本腳本也只在憑證實際變動時才
# 複製與 reload，因此可以每天安全地重複執行。
#
# 憑證對應方式：
#   /etc/letsencrypt/live/<域名>/fullchain.pem -> conf.d/certs/<域名>.pem (644)
#   /etc/letsencrypt/live/<域名>/privkey.pem   -> conf.d/certs/<域名>.key (600)
#
# 複製動作在 openresty1 容器內執行 —— 容器內是 root，可以讀取 host 上
# 屬於 root 0700 的 live/ 與 archive/ 目錄。
#
# 用法：
#   ./renew_cert.sh              # 續期並部署
#   DRY_RUN=1 ./renew_cert.sh    # 只測試 certbot 流程，不續期、不部署
#   FORCE_DEPLOY=1 ./renew_cert.sh  # 憑證沒變動也強制重新複製並 reload
#
# 建議加入 crontab 每天執行一次：
#   0 3 * * * /path/to/openresty-origin/renew_cert.sh >> /var/log/certbot-renew.log 2>&1
#
set -euo pipefail

cd "$(dirname "$0")"

COMPOSE="docker compose"
WEBROOT_SERVICE="openresty1"
CERT_DIR="/etc/nginx/conf.d/certs"     # 容器內路徑
LE_DIR="/etc/letsencrypt/live"         # 容器內路徑

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

DRY_RUN_ARG=()
if [ "${DRY_RUN:-0}" = "1" ]; then
    DRY_RUN_ARG=(--dry-run)
    log "🧪 dry-run 模式：不會實際續期，也不會部署憑證"
fi

if ! $COMPOSE ps --status running --services 2>/dev/null | grep -qx "$WEBROOT_SERVICE"; then
    log "❌ $WEBROOT_SERVICE 未啟動，webroot 驗證與憑證部署都無法進行"
    exit 1
fi

# ---------- 1. 續期 ----------
log "檢查憑證續期..."
$COMPOSE run --rm certbot renew \
    --webroot \
    --webroot-path=/var/www/certbot \
    --non-interactive \
    "${DRY_RUN_ARG[@]}"

if [ "${DRY_RUN:-0}" = "1" ]; then
    log "✅ dry-run 完成（未部署）"
    exit 0
fi

# ---------- 2. 部署憑證到站台讀取的位置 ----------
# 在容器內比對來源與目的，只有內容不同才複製，避免無謂的 reload。
log "檢查憑證是否需要部署..."

DEPLOY_OUTPUT=$($COMPOSE exec -T "$WEBROOT_SERVICE" sh -s <<SH || true
set -e
force="${FORCE_DEPLOY:-0}"
mkdir -p "$CERT_DIR"
changed=0
[ -d "$LE_DIR" ] || { echo "NO_LE_DIR"; exit 0; }
for d in "$LE_DIR"/*/; do
    [ -d "\$d" ] || continue
    name=\$(basename "\$d")
    [ "\$name" = "README" ] && continue
    src_crt="\$d/fullchain.pem"
    src_key="\$d/privkey.pem"
    [ -f "\$src_crt" ] && [ -f "\$src_key" ] || { echo "SKIP \$name (來源檔不存在)"; continue; }
    dst_crt="$CERT_DIR/\$name.pem"
    dst_key="$CERT_DIR/\$name.key"
    if [ "\$force" = "1" ] || ! cmp -s "\$src_crt" "\$dst_crt" || ! cmp -s "\$src_key" "\$dst_key"; then
        cp "\$src_crt" "\$dst_crt"
        cp "\$src_key" "\$dst_key"
        chmod 644 "\$dst_crt"
        chmod 600 "\$dst_key"
        echo "DEPLOYED \$name"
        changed=1
    else
        echo "UNCHANGED \$name"
    fi
done
[ "\$changed" = "1" ] && echo "CHANGED" || echo "NOCHANGE"
SH
)

echo "$DEPLOY_OUTPUT" | grep -E '^(DEPLOYED|UNCHANGED|SKIP|NO_LE_DIR)' | while read -r line; do
    case "$line" in
        DEPLOYED*)  log "  📦 已更新憑證：${line#DEPLOYED }" ;;
        UNCHANGED*) log "  ⏭️  無變動：${line#UNCHANGED }" ;;
        SKIP*)      log "  ⚠️  略過：${line#SKIP }" ;;
        NO_LE_DIR)  log "  ⚠️  找不到 ${LE_DIR}，尚未申請過任何憑證？" ;;
    esac
done

# ---------- 3. 僅在憑證有變動時驗證並 reload ----------
if ! echo "$DEPLOY_OUTPUT" | grep -q '^CHANGED$'; then
    log "✅ 憑證皆無變動，不需要 reload"
    exit 0
fi

log "驗證 nginx 設定..."
if ! $COMPOSE exec -T "$WEBROOT_SERVICE" openresty -t; then
    log "❌ nginx 設定驗證失敗，未 reload（現有服務不受影響）"
    log "   憑證已複製到 conf.d/certs/，請檢查設定後手動執行："
    log "   $COMPOSE exec $WEBROOT_SERVICE openresty -s reload"
    exit 1
fi

log "重新載入 $WEBROOT_SERVICE ..."
$COMPOSE exec -T "$WEBROOT_SERVICE" openresty -s reload
log "✅ 憑證已部署並套用"
