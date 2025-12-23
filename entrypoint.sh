#!/bin/bash

set -e

echo "======================================"
echo "Iniciando RunPod F5-TTS Handler"
echo "======================================"

# Configurar Git para não pedir credenciais interativamente
git config --global credential.helper store
git config --global core.askPass ""
export GIT_TERMINAL_PROMPT=0

# Substituir modelo padrão pelo espanhol se configurado
if [ "$REPLACE_MODEL_WITH_SPANISH" = "true" ]; then
    echo "Substituindo modelo padrão pelo modelo espanhol..."
    
    # Aguardar F5-TTS criar o cache (se necessário)
    sleep 2
    
    # Encontrar o diretório do modelo padrão
    MODEL_DIR=$(find /root/.cache/huggingface/hub -type d -name "models--SWivid--F5-TTS" 2>/dev/null | head -n 1)
    
    if [ -n "$MODEL_DIR" ]; then
        # Encontrar o snapshot mais recente
        SNAPSHOT_DIR=$(find "$MODEL_DIR/snapshots" -type d -maxdepth 1 | tail -n 1)
        
        if [ -n "$SNAPSHOT_DIR" ]; then
            MODEL_FILE="$SNAPSHOT_DIR/F5TTS_Base/model_1200000.safetensors"
            
            if [ -f "$MODEL_FILE" ]; then
                echo "Backup do modelo original..."
                mv "$MODEL_FILE" "$MODEL_FILE.bak"
                
                echo "Copiando modelo espanhol..."
                if [ -f "/root/.cache/f5-tts/es/model.safetensors" ]; then
                    cp "/root/.cache/f5-tts/es/model.safetensors" "$MODEL_FILE"
                    echo "✓ Modelo espanhol instalado com sucesso!"
                else
                    echo "✗ Modelo espanhol não encontrado, restaurando original..."
                    mv "$MODEL_FILE.bak" "$MODEL_FILE"
                fi
            else
                echo "Arquivo do modelo não encontrado: $MODEL_FILE"
            fi
        fi
    else
        echo "Diretório do modelo F5-TTS não encontrado no cache"
    fi
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
