#!/bin/bash
set -e

/usr/bin/turnserver -c /etc/turnserver.conf -o
echo "[entrypoint] coturn started"

mkdir -p /workspace/livetalking/models/dwpose
mkdir -p /workspace/livetalking/models/whisper/tiny
mkdir -p /workspace/livetalking/data/video

# モデルを初回のみDL（/workspaceに永続保存）
if [ ! -d "/workspace/livetalking/models/musetalk" ]; then
    echo "[entrypoint] Downloading MuseTalk models (first run, ~10 min)..."
    python3 -c "
from huggingface_hub import snapshot_download, hf_hub_download
snapshot_download(repo_id='TMElyralab/MuseTalk', local_dir='/workspace/livetalking/models/musetalk', ignore_patterns=['*.git*'])
hf_hub_download(repo_id='yzd-v/DWPose', filename='dw-ll_ucoco_384.onnx', local_dir='/workspace/livetalking/models/dwpose')
hf_hub_download(repo_id='yzd-v/DWPose', filename='det_onnx_model.onnx', local_dir='/workspace/livetalking/models/dwpose')
hf_hub_download(repo_id='openai/whisper-tiny', filename='pytorch_model.bin', local_dir='/workspace/livetalking/models/whisper/tiny')
print('Models ready')
"
fi

AVATAR_SRC="/workspace/livetalking/data/video/ani_neutral.mp4"
if [ ! -f "$AVATAR_SRC" ]; then
    echo "ERROR: Avatar not found at $AVATAR_SRC"
    echo "Upload: scp -P <PORT> neutral_boomerang.mp4 root@<IP>:/workspace/livetalking/data/video/ani_neutral.mp4"
    exit 1
fi

cd /workspace/livetalking
echo "[entrypoint] Starting LiveTalking + MuseTalk..."
exec python3 app.py --transport webrtc --model musetalk --avatar_id ani_neutral
