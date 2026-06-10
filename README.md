# Content Analyzer JJ (Claude Code Skill)

Uma skill pro **Claude Code** que baixa e analisa a fundo um conteudo de **Instagram, TikTok ou YouTube** a partir do link (reel, video, short, carrossel). O motor e o yt-dlp, que baixa de praticamente qualquer plataforma. Ela resolve dois problemas: as redes bloqueiam o acesso direto (login wall, video em blob) e a legenda quase nunca tem o conteudo real, que esta no audio do video.

O que ela faz, ponta a ponta, quando voce cola um link:
1. **Baixa** o video (mesmo com login wall, usando os cookies do seu navegador logado).
2. **Extrai grids de frames** pra "ver" o visual do reel.
3. **Transcreve o audio** (Parakeet local por padrao, Whisper como fallback).
4. **Entrega a analise**: hook, conteudo, formato, retencao, CTA e leitura estrategica.
5. (Opcional) **Salva no Notion** numa database sua.

---

## O que a skill ativa (dependencias)

Pra ela funcionar, a maquina precisa ter estas ferramentas instaladas. Sem elas, o passo correspondente falha.

| Ferramenta | Pra que serve | Obrigatoria? |
|---|---|---|
| **Claude Code** | onde a skill roda | sim |
| **yt-dlp** | baixar o video do Instagram | sim |
| **ffmpeg / ffprobe** | extrair os grids de frames e ler a duracao | sim |
| **gallery-dl** | baixar carrosseis de imagens (posts sem video) | sim (pra carrossel) |
| **parakeet-mlx** | transcrever o audio (rapido, local, **so Apple Silicon**) | opcional* |
| **whisper** (openai-whisper) | transcrever o audio (qualquer maquina, fallback) | opcional* |
| **jq** | ler os metadados JSON | sim |
| **Navegador logado** (Edge ou Chrome) | os cookies furam o login wall do Instagram | sim |

\* Precisa de **pelo menos um** transcritor. Em Mac com Apple Silicon, use o `parakeet-mlx` (muito mais rapido). Em qualquer outra maquina, use o `whisper`.

---

## Instalacao

### 1. Instalar as dependencias

**macOS (Homebrew):**
```bash
brew install yt-dlp ffmpeg gallery-dl jq
```

**Transcritor de audio, escolha um:**
```bash
# Apple Silicon (recomendado, rapido):
pip install --user parakeet-mlx

# Qualquer maquina (fallback):
pip install --user openai-whisper
```

**Linux:** instale `yt-dlp`, `ffmpeg`, `gallery-dl`, `jq` pelo gerenciador da sua distro (apt/dnf) ou via pip, e use `whisper` como transcritor.

### 2. Logar no Instagram no navegador

A skill usa os cookies do **Edge** por padrao (mude com `IG_COOKIES_BROWSER=chrome`). Abra o Edge (ou Chrome) e faca login normal no Instagram uma vez. Pronto, os cookies ficam salvos.

### 3. Instalar a skill no Claude Code

Copie a pasta pra dentro das skills do Claude Code:
```bash
git clone https://github.com/ojuliocouto/content-analyzer-jj.git
mkdir -p ~/.claude/skills/content-analyzer-jj
cp content-analyzer-jj/SKILL.md ~/.claude/skills/content-analyzer-jj/
cp -r content-analyzer-jj/scripts ~/.claude/skills/content-analyzer-jj/
chmod +x ~/.claude/skills/content-analyzer-jj/scripts/*.sh
```

Pronto. Na proxima sessao do Claude Code, a skill ja e reconhecida.

---

## Como usar

No Claude Code, e so mandar:

> analisa esse reel: https://www.instagram.com/reel/XXXXXXXX/

O Claude aciona a skill sozinho, baixa, transcreve, le os frames e devolve a analise.

Pra rodar o download na mao (sem o Claude):
```bash
~/.claude/skills/content-analyzer-jj/scripts/ingest.sh "https://www.instagram.com/reel/XXXX/" /tmp/ig_reel
```

### Flags uteis
- `TRANSCRIBER=whisper ingest.sh ...` forca o whisper (use se nao estiver em Apple Silicon).
- `IG_COOKIES_BROWSER=chrome ingest.sh ...` usa os cookies do Chrome em vez do Edge.

---

## Notion (opcional)

Se quiser catalogar as analises numa database do Notion:
1. Crie uma integracao no Notion e pegue o token (`secret_...`).
2. `export NOTION_API_TOKEN="secret_..."`.
3. Crie uma database e compartilhe com a integracao.
4. O `scripts/notion-save.sh` faz o POST. Veja o schema sugerido no proprio script.

Se voce nao usa Notion, ignore. A analise funciona 100% sem isso.

---

## Notas
- Funciona com reels (video) e com carrosseis (imagens).
- Reels so com musica (sem fala) retornam transcricao vazia; a analise segue pelo visual + legenda.
- Nada de credenciais fica no codigo: o token do Notion vem do ambiente.
