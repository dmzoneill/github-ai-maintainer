#!/bin/bash
# Send a notification to the maintainer Telegram chat
# Usage: scripts/telegram-notify.sh "message"
[ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$TELEGRAM_MAINTAINER_CHAT_ID" ] && exit 0
curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{\"chat_id\":\"${TELEGRAM_MAINTAINER_CHAT_ID}\",\"text\":\"$1\"}" > /dev/null 2>&1
