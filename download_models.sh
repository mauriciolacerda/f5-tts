#!/bin/bash

# Script para baixar modelos F5-TTS de diferentes idiomas
# Uso: ./download_models.sh [es|fr|de|it|ja|ru|hi|fi|all]

CACHE_DIR="/root/.cache/f5-tts"
mkdir -p "$CACHE_DIR"

download_model() {
    local lang=$1
    local repo=$2
    local model_file=$3
    local vocab_file=$4
    
    echo "Baixando modelo $lang de $repo..."
    mkdir -p "$CACHE_DIR/$lang"
    
    wget -q --show-progress \
        "https://huggingface.co/$repo/resolve/main/$model_file" \
        -O "$CACHE_DIR/$lang/model.safetensors"
    
    wget -q --show-progress \
        "https://huggingface.co/$repo/resolve/main/$vocab_file" \
        -O "$CACHE_DIR/$lang/vocab.txt"
    
    echo "✓ Modelo $lang baixado com sucesso!"
}

# Definir modelos disponíveis
case "$1" in
    es|spanish)
        download_model "es" "jpgallegoar/F5-Spanish" "model_1200000.safetensors" "vocab.txt"
        ;;
    fr|french)
        download_model "fr" "RASPIAUDIO/F5-French" "model_1200000.safetensors" "vocab.txt"
        ;;
    de|german)
        download_model "de" "hvoss-techfak/F5-German" "model_1200000.safetensors" "vocab.txt"
        ;;
    it|italian)
        download_model "it" "alien79/F5-Italian" "model_1200000.safetensors" "vocab.txt"
        ;;
    ja|japanese)
        download_model "ja" "Jmica/F5-Japanese" "model_1200000.safetensors" "vocab.txt"
        ;;
    ru|russian)
        download_model "ru" "HotDro4illa/F5-Russian" "model_1200000.safetensors" "vocab.txt"
        ;;
    hi|hindi)
        download_model "hi" "SPRINGLab/F5-Hindi-Small" "model_1200000.safetensors" "vocab.txt"
        ;;
    fi|finnish)
        download_model "fi" "AsmoKoskinen/F5-Finnish" "model_1200000.safetensors" "vocab.txt"
        ;;
    all)
        echo "Baixando todos os modelos disponíveis..."
        download_model "es" "jpgallegoar/F5-Spanish" "model_1200000.safetensors" "vocab.txt"
        download_model "fr" "RASPIAUDIO/F5-French" "model_1200000.safetensors" "vocab.txt"
        download_model "de" "hvoss-techfak/F5-German" "model_1200000.safetensors" "vocab.txt"
        download_model "it" "alien79/F5-Italian" "model_1200000.safetensors" "vocab.txt"
        download_model "ja" "Jmica/F5-Japanese" "model_1200000.safetensors" "vocab.txt"
        download_model "ru" "HotDro4illa/F5-Russian" "model_1200000.safetensors" "vocab.txt"
        download_model "hi" "SPRINGLab/F5-Hindi-Small" "model_1200000.safetensors" "vocab.txt"
        download_model "fi" "AsmoKoskinen/F5-Finnish" "model_1200000.safetensors" "vocab.txt"
        ;;
    *)
        echo "Uso: $0 [es|fr|de|it|ja|ru|hi|fi|all]"
        echo ""
        echo "Idiomas disponíveis:"
        echo "  es - Espanhol (jpgallegoar/F5-Spanish)"
        echo "  fr - Francês (RASPIAUDIO/F5-French)"
        echo "  de - Alemão (hvoss-techfak/F5-German)"
        echo "  it - Italiano (alien79/F5-Italian)"
        echo "  ja - Japonês (Jmica/F5-Japanese)"
        echo "  ru - Russo (HotDro4illa/F5-Russian)"
        echo "  hi - Hindi (SPRINGLab/F5-Hindi-Small)"
        echo "  fi - Finlandês (AsmoKoskinen/F5-Finnish)"
        echo "  all - Todos os idiomas"
        exit 1
        ;;
esac

echo ""
echo "Modelos salvos em: $CACHE_DIR"
