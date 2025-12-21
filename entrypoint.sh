#!/bin/bash

set -e

echo "======================================"
echo "Iniciando RunPod F5-TTS Handler"
echo "======================================"

# Diretório para clonar o repositório
REPO_DIR="/app/repo"

# Verificar se a URL do repositório está configurada
if [ -z "$GITHUB_REPO_URL" ]; then
    echo "ERRO: GITHUB_REPO_URL não está configurada!"
    echo "Por favor, defina a variável de ambiente GITHUB_REPO_URL"
    exit 1
fi

echo "Repositório GitHub: $GITHUB_REPO_URL"

# Clonar ou atualizar o repositório
if [ -d "$REPO_DIR" ]; then
    echo "Repositório já existe. Atualizando..."
    cd "$REPO_DIR"
    git fetch origin
    git reset --hard origin/main || git reset --hard origin/master
    git pull
else
    echo "Clonando repositório..."
    git clone "$GITHUB_REPO_URL" "$REPO_DIR"
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
