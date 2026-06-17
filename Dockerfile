FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404

# システムパッケージ
RUN apt-get update && apt-get install -y \
    coturn \
    git \
    ffmpeg \
    cmake \
    libopenblas-dev \
    liblapack-dev \
    && rm -rf /var/lib/apt/lists/*

# LiveTalkingクローン
RUN git clone --depth=1 https://github.com/lipku/livetalking /workspace/livetalking

# Python依存パッケージ（torch/torchvisionはベースイメージ済み）
RUN pip install --no-cache-dir \
    onnxruntime-gpu \
    diffusers \
    accelerate \
    transformers \
    opencv-python \
    imageio \
    imageio-ffmpeg \
    scipy \
    einops \
    timm \
    face-alignment \
    insightface \
    onnx \
    av \
    aiortc \
    aiohttp \
    aiohttp-cors \
    tqdm \
    huggingface_hub

# モデルダウンロード（ビルド時に実行）
RUN python3 -c "\
from huggingface_hub import snapshot_download, hf_hub_download; \
import os; \
os.makedirs('/workspace/livetalking/models/dwpose', exist_ok=True); \
snapshot_download(repo_id='TMElyralab/MuseTalk', local_dir='/workspace/livetalking/models/musetalk', ignore_patterns=['*.git*']); \
hf_hub_download(repo_id='yzd-v/DWPose', filename='dw-ll_ucoco_384.onnx', local_dir='/workspace/livetalking/models/dwpose'); \
hf_hub_download(repo_id='yzd-v/DWPose', filename='det_onnx_model.onnx', local_dir='/workspace/livetalking/models/dwpose'); \
hf_hub_download(repo_id='openai/whisper-tiny', filename='pytorch_model.bin', local_dir='/workspace/livetalking/models/whisper/tiny'); \
print('Models ready')"

# coturn設定
COPY turnserver.conf /etc/turnserver.conf

# Aniアバター動画
RUN mkdir -p /workspace/livetalking/data/video
COPY neutral_boomerang.mp4 /workspace/livetalking/data/video/ani_neutral.mp4

# エントリーポイント
COPY entrypoint.sh /workspace/entrypoint.sh
RUN chmod +x /workspace/entrypoint.sh

EXPOSE 8010 3478

CMD ["/workspace/entrypoint.sh"]
