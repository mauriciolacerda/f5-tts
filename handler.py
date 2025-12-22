"""
RunPod Handler para F5 TTS
Implementa cache de áudio de referência e integração com Google Cloud Storage
"""

import os
import json
import runpod
import torch
import torchaudio
import tempfile
from pathlib import Path
from google.cloud import storage
from google.oauth2 import service_account
from datetime import timedelta
import logging

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Importações do F5 TTS
from f5_tts.api import F5TTS

# Diretório de cache para áudios de referência
CACHE_DIR = Path("/tmp/audio_cache")
CACHE_DIR.mkdir(exist_ok=True)

# Configurar credenciais do Google Cloud Storage
GCS_CREDENTIALS_JSON = os.environ.get("GCS_CREDENTIALS_JSON", "")
GCS_BUCKET_NAME = os.environ.get("GCS_BUCKET_NAME", "")

# Inicializar cliente GCS
gcs_client = None
bucket = None

if GCS_CREDENTIALS_JSON and GCS_BUCKET_NAME:
    try:
        credentials_info = json.loads(GCS_CREDENTIALS_JSON)
        credentials = service_account.Credentials.from_service_account_info(credentials_info)
        gcs_client = storage.Client(credentials=credentials, project=credentials_info.get("project_id"))
        bucket = gcs_client.bucket(GCS_BUCKET_NAME)
        logger.info("Cliente GCS inicializado com sucesso")
    except Exception as e:
        logger.warning(f"Não foi possível inicializar cliente GCS: {e}")
else:
    logger.warning("Credenciais GCS não configuradas. Define GCS_CREDENTIALS_JSON e GCS_BUCKET_NAME")

# Inicializar modelo F5 TTS
logger.info("Carregando modelo F5 TTS...")

# Cache de modelos por idioma
f5tts_models = {}

# Modelo padrão (EN/ZH)
logger.info("Carregando modelo padrão (EN/ZH)...")
f5tts_models["default"] = F5TTS()
f5tts_models["en"] = f5tts_models["default"]  # Alias
f5tts_models["zh"] = f5tts_models["default"]  # Alias

# Configuração de modelos customizados via variável de ambiente
# Formato: LANG_CODE:MODEL_PATH:VOCAB_PATH,LANG_CODE:MODEL_PATH:VOCAB_PATH,...
custom_models_config = os.environ.get("F5_CUSTOM_MODELS", "")

if custom_models_config:
    logger.info("Carregando modelos customizados...")
    for model_config in custom_models_config.split(","):
        try:
            parts = model_config.strip().split(":")
            if len(parts) != 3:
                logger.warning(f"Configuração inválida ignorada: {model_config}")
                continue
            
            lang_code, model_path, vocab_path = parts
            
            if not os.path.exists(model_path) or not os.path.exists(vocab_path):
                logger.warning(f"Arquivos não encontrados para {lang_code}: {model_path}, {vocab_path}")
                continue
            
            logger.info(f"Carregando modelo {lang_code}: {model_path}")
            f5tts_models[lang_code] = F5TTS(model_type="F5-TTS", ckpt_file=model_path, vocab_file=vocab_path)
            logger.info(f"Modelo {lang_code} carregado com sucesso!")
        except Exception as e:
            logger.error(f"Erro ao carregar modelo {model_config}: {e}")

logger.info(f"Modelos disponíveis: {list(f5tts_models.keys())}")

# Variável para controlar se a transcrição automática deve ser desabilitada
DISABLE_AUTO_TRANSCRIPTION = os.environ.get("DISABLE_AUTO_TRANSCRIPTION", "true").lower() == "true"


def download_from_gcs(gcs_url: str, local_path: str) -> bool:
    """
    Baixa um arquivo do Google Cloud Storage
    
    Args:
        gcs_url: URL do arquivo no GCS (formato: gs://bucket/path ou https://storage.googleapis.com/bucket/path)
        local_path: Caminho local para salvar o arquivo
        
    Returns:
        True se o download foi bem-sucedido, False caso contrário
    """
    try:
        # Extrair bucket e blob path da URL
        if gcs_url.startswith("gs://"):
            # Formato: gs://bucket/path/to/file
            parts = gcs_url[5:].split("/", 1)
            bucket_name = parts[0]
            blob_path = parts[1] if len(parts) > 1 else ""
        elif "storage.googleapis.com" in gcs_url:
            # Formato: https://storage.googleapis.com/bucket/path/to/file
            parts = gcs_url.split("storage.googleapis.com/")[1].split("/", 1)
            bucket_name = parts[0]
            blob_path = parts[1] if len(parts) > 1 else ""
        else:
            logger.error(f"Formato de URL GCS inválido: {gcs_url}")
            return False
        
        # Baixar arquivo
        client = storage.Client() if not gcs_client else gcs_client
        bucket = client.bucket(bucket_name)
        blob = bucket.blob(blob_path)
        blob.download_to_filename(local_path)
        
        logger.info(f"Arquivo baixado com sucesso: {gcs_url} -> {local_path}")
        return True
    except Exception as e:
        logger.error(f"Erro ao baixar arquivo do GCS: {e}")
        return False


def upload_to_gcs(local_path: str, gcs_path: str) -> str:
    """
    Faz upload de um arquivo para o Google Cloud Storage
    
    Args:
        local_path: Caminho local do arquivo
        gcs_path: Caminho no GCS (sem gs:// prefix)
        
    Returns:
        URL assinada do arquivo ou URL pública
    """
    try:
        if not bucket:
            logger.error("Bucket GCS não configurado")
            return ""
        
        blob = bucket.blob(gcs_path)
        blob.upload_from_filename(local_path)
        
        # Gerar URL assinada válida por 7 dias
        url = blob.generate_signed_url(
            version="v4",
            expiration=timedelta(days=7),
            method="GET"
        )
        
        logger.info(f"Arquivo enviado com sucesso: {local_path} -> gs://{GCS_BUCKET_NAME}/{gcs_path}")
        return url
    except Exception as e:
        logger.error(f"Erro ao fazer upload para GCS: {e}")
        # Tentar retornar URL pública como fallback
        return f"gs://{GCS_BUCKET_NAME}/{gcs_path}"


def get_cached_audio(voice_id: str, ref_audio_url: str) -> str:
    """
    Obtém o áudio de referência do cache ou baixa do GCS
    
    Args:
        voice_id: Identificador único da voz
        ref_audio_url: URL do áudio de referência no GCS
        
    Returns:
        Caminho local do áudio de referência
    """
    cache_path = CACHE_DIR / f"{voice_id}.wav"
    
    # Verificar se já existe no cache
    if cache_path.exists():
        logger.info(f"Áudio de referência encontrado no cache: {cache_path}")
        return str(cache_path)
    
    # Baixar do GCS
    logger.info(f"Baixando áudio de referência do GCS: {ref_audio_url}")
    if download_from_gcs(ref_audio_url, str(cache_path)):
        return str(cache_path)
    else:
        raise Exception(f"Falha ao baixar áudio de referência: {ref_audio_url}")


def handler(job):
    """
    Handler principal do RunPod
    
    Entrada esperada:
    {
        "input": {
            "gen_text": "Texto para gerar o áudio",
            "ref_audio_url": "gs://bucket/path/to/reference.wav",
            "ref_text": "Texto falado no áudio de referência (opcional)",
            "voice_id": "identificador_unico_da_voz",
            "language": "default|en|zh|es|fr|de|it|ja|ru|hi|fi - Código do idioma",
            "output_path": "path/to/output.wav" (opcional),
            "speed": 1.0 (opcional)
        }
    }
    
    Saída:
    {
        "audio_url": "URL assinada do áudio gerado",
        "duration": "Duração do áudio em segundos",
        "voice_id": "Identificador da voz utilizada"
    }
    """
    try:
        job_input = job["input"]
        
        # Validar entrada
        gen_text = job_input.get("gen_text")
        ref_audio_url = job_input.get("ref_audio_url")
        ref_text = job_input.get("ref_text", "")  # Texto de referência opcional
        language = job_input.get("language", "default")  # Idioma do modelo
        voice_id = job_input.get("voice_id")
        output_path = job_input.get("output_path", f"outputs/{voice_id}/output_{job['id']}.wav")
        speed = job_input.get("speed", 1.0)  # Velocidade de síntese (padrão: 1.0)
        
        if not gen_text:
            return {"error": "gen_text é obrigatório"}
        if not ref_audio_url:
            return {"error": "ref_audio_url é obrigatório"}
        if not voice_id:
            return {"error": "voice_id é obrigatório"}
        
        # IMPORTANTE: ref_text é obrigatório se transcrição automática estiver desabilitada
        if DISABLE_AUTO_TRANSCRIPTION and not ref_text:
            return {"error": "ref_text é obrigatório (transcrição automática desabilitada para evitar erros de compatibilidade)"}
        
        # Se ref_text não fornecido, usar texto genérico para evitar transcrição
        if not ref_text:
        # Selecionar modelo baseado no idioma
        if language not in f5tts_models:
            return {"error": f"Idioma '{language}' não disponível. Modelos disponíveis: {list(f5tts_models.keys())}"}
        
        f5tts = f5tts_models[language]
        
            ref_text = "Audio de referência para clonagem de voz."
        
        logger.info(f"Processando job {job['id']}")
        logger.info(f"Texto: {gen_text[:100]}...")
        logger.info(f"Voice ID: {voice_id}")
        
        # Obter áudio de referência (com cache)
        ref_audio_path = get_cached_audio(voice_id, ref_audio_url)
        
        # Criar arquivo temporário para saída
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as tmp_output:
            output_file = tmp_output.name
        
        try:
            # Realizar inferência com F5 TTS
            logger.info("Iniciando inferência F5 TTS...")
            logger.info(f"Ref text: {ref_text if ref_text else 'Auto-transcrição'}")
            
            # Gerar áudio usando a API do F5 TTS
            f5tts.infer(
                ref_file=ref_audio_path,
                ref_text=ref_text,
                gen_text=gen_text,
                file_wave=output_file,
                speed=speed,
                remove_silence=True
            )
            
            logger.info("Inferência concluída com sucesso")
            
            # Calcular duração do áudio
            waveform, sample_rate = torchaudio.load(output_file)
            duration = waveform.shape[1] / sample_rate
            
            # Upload para GCS
            logger.info("Fazendo upload do áudio gerado para GCS...")
            audio_url = upload_to_gcs(output_file, output_path)
            
            # Retornar resultado
            result = {
                "audio_url": audio_url,
                "duration": float(duration),
                "voice_id": voice_id,
                "sample_rate": int(sample_rate)
            }
            
            logger.info(f"Job {job['id']} concluído com sucesso")
            return result
            
        finally:
            # Limpar arquivo temporário
            if os.path.exists(output_file):
                os.remove(output_file)
    
    except Exception as e:
        logger.error(f"Erro ao processar job: {e}", exc_info=True)
        return {"error": str(e)}


if __name__ == "__main__":
    logger.info("Iniciando RunPod serverless handler...")
    runpod.serverless.start({"handler": handler})
