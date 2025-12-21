# RunPod F5 TTS Serverless

Estrutura de serviço Serverless para o RunPod que executa o modelo F5 TTS com Docker genérico e código buscado diretamente do GitHub.

## 📋 Estrutura do Projeto

```
f5-tts/
├── Dockerfile           # Imagem Docker base com PyTorch e F5 TTS
├── entrypoint.sh        # Script que clona/atualiza o repositório
├── handler.py           # Handler RunPod com lógica de inferência
├── requirements.txt     # Dependências Python extras
└── README.md           # Este arquivo
```

## 🚀 Como Usar

### 1. Build da Imagem Docker

```bash
docker build -t seu-usuario/f5-tts-runpod:latest .
```

### 2. Push para Docker Hub

```bash
docker push seu-usuario/f5-tts-runpod:latest
```

### 3. Configurar no RunPod

No RunPod, configure as seguintes variáveis de ambiente:

**Obrigatórias:**
- `GITHUB_REPO_URL`: URL do seu repositório (ex: `https://github.com/seu-usuario/f5-tts.git`)
- `GCS_CREDENTIALS_JSON`: JSON com credenciais da Service Account do Google Cloud
- `GCS_BUCKET_NAME`: Nome do bucket do GCS para armazenar áudios

**Opcional:**
- `PYTHONUNBUFFERED=1`: Para logs em tempo real

### 4. Formato de Entrada

Envie jobs para o RunPod com o seguinte formato:

```json
{
  "input": {
    "gen_text": "Olá, este é um teste de geração de voz com F5 TTS.",
    "ref_audio_url": "gs://seu-bucket/referencias/voz_01.wav",
    "voice_id": "voz_01",
    "output_path": "outputs/voz_01/audio_123.wav"
  }
}
```

**Parâmetros:**
- `gen_text`: Texto para gerar o áudio (obrigatório)
- `ref_audio_url`: URL do áudio de referência no GCS (obrigatório)
- `voice_id`: Identificador único da voz para cache (obrigatório)
- `output_path`: Caminho no bucket GCS para salvar o áudio (opcional)

### 5. Formato de Saída

O handler retorna:

```json
{
  "audio_url": "https://storage.googleapis.com/...",
  "duration": 5.23,
  "voice_id": "voz_01",
  "sample_rate": 24000
}
```

## 🔧 Funcionalidades

### Cache de Áudio de Referência
- Áudios de referência são armazenados em `/tmp/audio_cache/{voice_id}.wav`
- Na primeira execução, o áudio é baixado do GCS
- Execuções subsequentes com o mesmo `voice_id` usam o cache local
- Reduz latência e custos de transferência

### Atualização Automática do Código
- A cada inicialização do container, o `entrypoint.sh` faz git pull do repositório
- Permite ajustes rápidos no `handler.py` sem rebuild da imagem Docker
- Dependências extras são instaladas automaticamente se houver `requirements.txt`

### Pesos do Modelo Pré-baixados
- Os pesos do F5 TTS são baixados durante o build da imagem
- Container inicia mais rápido no RunPod
- Reduz tempo de cold start

## 🔐 Configuração do Google Cloud Storage

### 1. Criar Service Account

```bash
gcloud iam service-accounts create f5-tts-runpod \
    --display-name="F5 TTS RunPod Service Account"
```

### 2. Dar Permissões ao Bucket

```bash
gcloud projects add-iam-policy-binding SEU_PROJECT_ID \
    --member="serviceAccount:f5-tts-runpod@SEU_PROJECT_ID.iam.gserviceaccount.com" \
    --role="roles/storage.objectAdmin"
```

### 3. Gerar Chave JSON

```bash
gcloud iam service-accounts keys create credentials.json \
    --iam-account=f5-tts-runpod@SEU_PROJECT_ID.iam.gserviceaccount.com
```

### 4. Converter para String (para variável de ambiente)

```bash
cat credentials.json | jq -c . | tr -d '\n'
```

Cole o resultado como valor da variável `GCS_CREDENTIALS_JSON` no RunPod.

## 📝 Ajustes Rápidos

Para fazer ajustes no código sem rebuild:

1. Edite o `handler.py` no seu repositório GitHub
2. Faça commit e push
3. Reinicie o pod no RunPod
4. O `entrypoint.sh` fará pull automático das mudanças

## 🐛 Debug

### Ver logs do container:
```bash
docker logs container_id
```

### Testar localmente:
```bash
docker run -it \
  -e GITHUB_REPO_URL=https://github.com/seu-usuario/f5-tts.git \
  -e GCS_CREDENTIALS_JSON='{"type":"service_account",...}' \
  -e GCS_BUCKET_NAME=seu-bucket \
  seu-usuario/f5-tts-runpod:latest
```

## 📦 Dependências Principais

- PyTorch 2.3.0 com CUDA 12.1
- F5 TTS
- RunPod SDK
- Google Cloud Storage
- FFmpeg, Git

## 📄 Licença

Este projeto segue as mesmas licenças do F5 TTS original.
