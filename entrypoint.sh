#!/bin/bash
set -e

# ── RunPod SSH対応: 注入されたPUBLIC_KEYでsshdを有効化（デバッグ用）──
# カスタムCMDだとRunPod標準のsshd起動が動かないため、ここで自前で立てる
if [ -n "$PUBLIC_KEY" ]; then
    mkdir -p ~/.ssh
    echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
    chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
fi
if command -v sshd >/dev/null 2>&1; then
    mkdir -p /run/sshd
    /usr/sbin/sshd 2>/dev/null && echo "[entrypoint] sshd started" || echo "[entrypoint] sshd skip"
fi

# ── coturn起動（WebRTC TURNリレー）──
/usr/bin/turnserver -c /etc/turnserver.conf -o &
echo "[entrypoint] coturn started on port 3478"

# ── LiveTalking起動（/opt配下、ボリュームに隠されない）──
# 初回: アバター前処理あり（数分）、2回目以降: 即起動
cd /opt/livetalking
echo "[entrypoint] Starting LiveTalking + MuseTalk..."
exec python3 app.py \
    --transport webrtc \
    --model musetalk \
    --avatar_id ani_neutral
