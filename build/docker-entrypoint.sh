#!/bin/bash
set -e

# 背景跑 logrotate
(
  while true; do
    logrotate -f /etc/logrotate.conf
    sleep 3600  # 每小時跑一次
  done
) &

# 啟動 openresty 前台
exec openresty -g 'daemon off;'
