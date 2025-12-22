#!/bin/bash

set -e

echo "======================================"
echo "Iniciando RunPod F5-TTS Handler"
echo "======================================"

# Configurar Git para não pedir credenciais interativamente
git config --global credential.helper store
git config --global core.askPass ""
export GIT_TERMINAL_PROMPT=0

# Baixar modelos customizados se configurados
if [ -n "$F5_DOWNLOAD_MODELS" ]; then
    echo "Baixando modelos customizados: $F5_DOWNLOAD_MODELS"
    IFS=',' read -ra MODELS <<< "$F5_DOWNLOAD_MODELS"
    for model_lang in "${MODELS[@]}"; do
        if [ -d "/root/.cache/f5-tts/$model_lang" ]; then
            echo "Modelo $model_lang já existe, pulando download..."
        else
            echo "Baixando modelo: $model_lang"
            /app/download_models.sh "$model_lang"
        fi
    done
fi

# Diretório para clonar o repositório
REPO_DIR="/app/repo"

# Verificar se a URL do repositório está configurada
if [ -z "$GITHUB_REPO_URL" ]; then
    echo "ERRO: GITHUB_REPO_URL não está configurada!"
    echo "Por favor, defina a variável de ambiente GITHUB_REPO_URL"
    exit 1
fi

echo "Repositório GitHub: $GITHUB_REPO_URL"

# Preparar URL com autenticação se GITHUB_TOKEN estiver definido
CLONE_URL="$GITHUB_REPO_URL"
if [ -n "$GITHUB_TOKEN" ]; then
    echo "Token GitHub detectado, usando autenticação..."
    # Converter URL para formato com token
    CLONE_URL=$(echo "$GITHUB_REPO_URL" | sed "s|https://|https://${GITHUB_TOKEN}@|")
fi

# Clonar ou atualizar o repositório
if [ -d "$REPO_DIR" ]; then
    echo "Repositório já existe. Atualizando..."
    cd "$REPO_DIR"
    
    # Atualizar remote URL se tiver token
    if [ -n "$GITHUB_TOKEN" ]; then
        git remote set-url origin "$CLONE_URL"
    fi
    
    git fetch origin
    git reset --hard origin/main || git reset --hard origin/master
    git pull
else
    echo "Clonando repositório..."
    git clone "$CLONE_URL" "$REPO_DIR"
    cd "$REPO_DIR"
fi

echo "Repositório atualizado com sucesso!"

# Instalar dependências extras se existir requirements.txt
if [ -f "requirements.txt" ]; then
    echo "Instalando dependências extras do requirements.txt..."
    pip install -r requirements.txt
else
    echo "Nenhum requirements.txt encontrado no repositório."
fi

# Verificar se handler.py existe
if [ ! -f "handler.py" ]; then
    echo "ERRO: handler.py não encontrado no repositório!"
    exit 1
fi

echo "======================================"
echo "Iniciando handler.py..."
echo "======================================"

# Executar o handler
exec python -u handler.py
