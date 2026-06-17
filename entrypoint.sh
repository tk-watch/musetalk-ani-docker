#!/bin/bash
set -e

# coturn起動
/usr/bin/turnserver -c /etc/turnserver.conf -o
echo "[entrypoint] coturn started on port 3478"

# アバター動画チェック
AVATAR_SRC="/workspace/livetalking/data/video/ani_neutral.mp4"
if [ ! -f "$AVATAR_SRC" ]; then
    echo ""
    echo "ERROR: Avatar video not found at $AVATAR_SRC"
    echo ""
    echo "Upload your avatar video via SCP:"
    echo "  scp -P <PORT> neutral_boomerang.mp4 root@<POD_IP>:/workspace/livetalking/data/video/ani_neutral.mp4"
    echo ""
    echo "Then restart the pod. Avatar preprocessing runs on first boot (~3 min)."
    exit 1
fi

mkdir -p /workspace/livetalking/data/video

# LiveTalking起動
# 初回: アバター前処理あり（数分）、2回目以降: 即起動
cd /workspace/livetalking
echo "[entrypoint] Starting LiveTalking + MuseTalk..."
exec python3 app.py \
    --transport webrtc \
    --model musetalk \
    --avatar_id ani_neutral
