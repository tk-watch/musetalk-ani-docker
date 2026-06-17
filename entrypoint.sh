#!/bin/bash
set -e

# coturn起動
/usr/bin/turnserver -c /etc/turnserver.conf -o
echo "[entrypoint] coturn started on port 3478"

# LiveTalking起動
# 初回: アバター前処理あり（数分）、2回目以降: 即起動
cd /workspace/livetalking
echo "[entrypoint] Starting LiveTalking + MuseTalk..."
exec python3 app.py \
    --transport webrtc \
    --model musetalk \
    --avatar_id ani_neutral
