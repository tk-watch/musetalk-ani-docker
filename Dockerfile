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

# ── すべて /opt 配下に置く（RunPodが /workspace をボリュームマウントで上書きするため）──
# LiveTalkingクローン
RUN git clone --depth=1 https://github.com/lipku/livetalking /opt/livetalking

# rtc_manager.py: TURNサーバー設定パッチ（RunPod UDPブロック対策）
# coturn(pod内)をSSHトンネル経由でTCPリレーする
RUN python3 - << 'PYEOF'
import re, pathlib
p = pathlib.Path('/opt/livetalking/server/rtc_manager.py')
txt = p.read_text()
txt2 = re.sub(
    r"( +)(ice_server = RTCIceServer\(urls='stun:stun\.freeswitch\.org:3478'\))",
    lambda m: m.group(0) + '\n' + m.group(1) +
        "turn_server = RTCIceServer(urls='turn:127.0.0.1:3478?transport=tcp', username='ani', credential='ani123')",
    txt
)
txt3 = txt2.replace('iceServers=[ice_server]', 'iceServers=[ice_server, turn_server]')
if txt3 != txt:
    p.write_text(txt3)
    print('rtc_manager.py: TURN patch OK')
else:
    print('WARN: rtc_manager.py patch skipped (pattern not found)')
    import sys; sys.exit(1)
PYEOF

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

# モデルダウンロード（ビルド時に実行、/opt 配下へ）
RUN python3 -c "\
from huggingface_hub import snapshot_download, hf_hub_download; \
import os; \
os.makedirs('/opt/livetalking/models/dwpose', exist_ok=True); \
snapshot_download(repo_id='TMElyralab/MuseTalk', local_dir='/opt/livetalking/models/musetalk', ignore_patterns=['*.git*']); \
hf_hub_download(repo_id='yzd-v/DWPose', filename='dw-ll_ucoco_384.onnx', local_dir='/opt/livetalking/models/dwpose'); \
hf_hub_download(repo_id='yzd-v/DWPose', filename='det_onnx_model.onnx', local_dir='/opt/livetalking/models/dwpose'); \
hf_hub_download(repo_id='openai/whisper-tiny', filename='pytorch_model.bin', local_dir='/opt/livetalking/models/whisper/tiny'); \
print('Models ready')"

# coturn設定
COPY turnserver.conf /etc/turnserver.conf

# Aniアバター動画（/opt 配下へ）
RUN mkdir -p /opt/livetalking/data/video
COPY neutral_boomerang.mp4 /opt/livetalking/data/video/ani_neutral.mp4

# エントリーポイント
COPY entrypoint.sh /opt/entrypoint.sh
RUN chmod +x /opt/entrypoint.sh

EXPOSE 8010 3478

CMD ["/opt/entrypoint.sh"]
