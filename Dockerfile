FROM runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404

RUN apt-get update && apt-get install -y \
    coturn git ffmpeg cmake libopenblas-dev liblapack-dev \
    && rm -rf /var/lib/apt/lists/*

RUN git clone --depth=1 https://github.com/lipku/livetalking /workspace/livetalking

RUN pip install --no-cache-dir \
    onnxruntime-gpu diffusers accelerate transformers \
    opencv-python imageio imageio-ffmpeg scipy einops timm \
    face-alignment insightface onnx av aiortc \
    aiohttp aiohttp-cors tqdm huggingface_hub

COPY turnserver.conf /etc/turnserver.conf
COPY entrypoint.sh /workspace/entrypoint.sh
RUN chmod +x /workspace/entrypoint.sh

EXPOSE 8010 3478
CMD ["/workspace/entrypoint.sh"]
