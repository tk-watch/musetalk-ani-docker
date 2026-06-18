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

# ── モデル: 永続ボリューム /workspace/models に初回DL（2回目以降はキャッシュ利用）──
# LiveTalkingのutils.pyは vae_type="sd-vae" を期待するため sd-vae-ft-mse をリネームする
MODELS_DIR=/workspace/models
if [ ! -f "$MODELS_DIR/musetalkV15/unet.pth" ]; then
    echo "[entrypoint] Downloading MuseTalk models to $MODELS_DIR (first run, ~6GB)..."
    python3 -c "
from huggingface_hub import snapshot_download
snapshot_download(repo_id='kevinwang676/MuseTalk1.5', local_dir='/workspace',
                  allow_patterns=['models/**'], ignore_patterns=['*.git*'])
print('Models downloaded')
"
    [ -d "$MODELS_DIR/sd-vae-ft-mse" ] && mv "$MODELS_DIR/sd-vae-ft-mse" "$MODELS_DIR/sd-vae"
    echo "[entrypoint] Models ready: $(ls $MODELS_DIR)"
else
    echo "[entrypoint] Models already cached in $MODELS_DIR"
fi
# /opt/livetalking/models → /workspace/models へsymlink（コードからの相対パスを解決）
rm -rf /opt/livetalking/models
ln -s "$MODELS_DIR" /opt/livetalking/models

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
