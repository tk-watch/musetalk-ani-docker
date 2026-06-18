#!/bin/bash
# 全出力を永続ログ /workspace/boot.log にも記録（クラッシュ後もSSHで確認可能）
mkdir -p /workspace
exec > >(tee -a /workspace/boot.log) 2>&1
echo "===== entrypoint start $(date) ====="

# ── RunPod SSH対応: 注入されたPUBLIC_KEYでsshdを有効化（デバッグ用）──
# カスタムCMDだとRunPod標準のsshd起動が動かないため、ここで自前で立てる
if [ -n "$PUBLIC_KEY" ]; then
    mkdir -p ~/.ssh
    echo "$PUBLIC_KEY" >> ~/.ssh/authorized_keys
    chmod 700 ~/.ssh && chmod 600 ~/.ssh/authorized_keys
fi
if command -v sshd >/dev/null 2>&1; then
    mkdir -p /run/sshd
    /usr/sbin/sshd && echo "[entrypoint] sshd started" || echo "[entrypoint] sshd skip"
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
" || { echo '[entrypoint] ERROR: model download failed'; }
    [ -d "$MODELS_DIR/sd-vae-ft-mse" ] && mv "$MODELS_DIR/sd-vae-ft-mse" "$MODELS_DIR/sd-vae"
    echo "[entrypoint] Models dir: $(ls $MODELS_DIR 2>/dev/null)"
else
    echo "[entrypoint] Models already cached in $MODELS_DIR"
fi
# /opt/livetalking/models → /workspace/models へsymlink（コードからの相対パスを解決）
rm -rf /opt/livetalking/models
ln -s "$MODELS_DIR" /opt/livetalking/models

cd /opt/livetalking

# ── アバター前処理: 動画 → data/avatars/ani_neutral（latents.pt等）──
# app.pyは事前生成されたアバターをロードするため、初回はgenavatarで生成必須。
# 生成結果も永続ボリューム /workspace/avatars にキャッシュ（2回目以降スキップ）
AVATARS_DIR=/workspace/avatars
mkdir -p "$AVATARS_DIR"
rm -rf /opt/livetalking/data/avatars
ln -s "$AVATARS_DIR" /opt/livetalking/data/avatars
if [ ! -f "$AVATARS_DIR/ani_neutral/latents.pt" ]; then
    echo "[entrypoint] Generating avatar 'ani_neutral' from video (first run, ~数分)..."
    python3 -m avatars.musetalk.genavatar \
        --file data/video/ani_neutral.mp4 \
        --avatar_id ani_neutral \
        --version v15 || { echo '[entrypoint] ERROR: genavatar failed'; }
    echo "[entrypoint] Avatar dir: $(ls $AVATARS_DIR/ani_neutral 2>/dev/null)"
else
    echo "[entrypoint] Avatar 'ani_neutral' already cached"
fi

# ── coturn起動（WebRTC TURNリレー）──
/usr/bin/turnserver -c /etc/turnserver.conf -o &
echo "[entrypoint] coturn started on port 3478"

# ── LiveTalking起動（/opt配下、ボリュームに隠されない）──
echo "[entrypoint] Starting LiveTalking + MuseTalk..."
python3 app.py --transport webrtc --model musetalk --avatar_id ani_neutral
echo "[entrypoint] app.py exited code $? — コンテナはデバッグ用に生存させます"
sleep infinity
