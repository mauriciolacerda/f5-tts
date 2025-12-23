FROM nvidia/cuda:12.1.0-cudnn8-runtime-ubuntu22.04

# Configurar variáveis de ambiente
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV GITHUB_REPO_URL=""

# Instalar dependências do sistema incluindo Python
RUN apt-get update && apt-get install -y \
    python3.10 \
    python3-pip \
    python3-dev \
    git \
    ffmpeg \
    wget \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Criar symlinks para python
RUN ln -sf /usr/bin/python3.10 /usr/bin/python && \
    ln -sf /usr/bin/python3.10 /usr/bin/python3

# Criar diretório de trabalho
WORKDIR /app

# Atualizar pip
RUN python3 -m pip install --upgrade pip

# Instalar PyTorch 2.4.1 com CUDA 12.1
RUN pip3 install --no-cache-dir \
    torch==2.4.1 \
    torchaudio==2.4.1 \
    torchvision==0.19.1 \
    --index-url https://download.pytorch.org/whl/cu121

# Instalar transformers e dependências de áudio
RUN pip3 install --no-cache-dir \
    transformers>=4.46.0 \
    accelerate \
    soundfile \
    librosa

# Instalar F5-TTS e outras dependências
RUN pip3 install --no-cache-dir \
    runpod \
    f5-tts \
    google-cloud-storage \
    numpy \
    scipy

# Pré-baixar os pesos do modelo F5 TTS para acelerar a inicialização
# Modelo padrão (EN/ZH)
RUN python -c "from f5_tts.infer.infer_cli import infer_process; print('Downloading F5-TTS model weights...'); \
    import torch; \
    from f5_tts.model import DiT, UNetT; \
    from f5_tts.model.utils import load_checkpoint; \
    import os; \
    os.makedirs('/root/.cache/f5-tts', exist_ok=True); \
    print('Model weights cached successfully')" || echo "Skipping model pre-download"

# Copiar script de download de modelos
COPY download_models.sh /app/download_models.sh
RUN chmod +x /app/download_models.sh

# Baixar modelo espanhol (será usado para substituir o modelo padrão)
RUN /app/download_models.sh es

# Criar diretório para cache de áudio
RUN mkdir -p /tmp/audio_cache

# Copiar script de entrada
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Expor porta (se necessário para debugging)
EXPOSE 8000

# Definir entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
