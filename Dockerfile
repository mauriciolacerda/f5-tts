FROM pytorch/pytorch:2.3.0-cuda12.1-cudnn8-runtime

# Configurar variáveis de ambiente
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1
ENV GITHUB_REPO_URL=""

# Instalar dependências do sistema
RUN apt-get update && apt-get install -y \
    git \
    ffmpeg \
    wget \
    curl \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Criar diretório de trabalho
WORKDIR /app

# Instalar dependências Python principais
RUN pip install --no-cache-dir \
    runpod \
    f5-tts \
    google-cloud-storage \
    numpy \
    scipy \
    soundfile \
    librosa \
    torchaudio

# Pré-baixar os pesos do modelo F5 TTS para acelerar a inicialização
RUN python -c "from f5_tts.infer.infer_cli import infer_process; print('Downloading F5-TTS model weights...'); \
    import torch; \
    from f5_tts.model import DiT, UNetT; \
    from f5_tts.model.utils import load_checkpoint; \
    import os; \
    os.makedirs('/root/.cache/f5-tts', exist_ok=True); \
    print('Model weights cached successfully')" || echo "Skipping model pre-download"

# Criar diretório para cache de áudio
RUN mkdir -p /tmp/audio_cache

# Copiar script de entrada
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

# Expor porta (se necessário para debugging)
EXPOSE 8000

# Definir entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]
