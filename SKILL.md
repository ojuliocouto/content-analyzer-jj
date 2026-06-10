---
name: content-analyzer-jj
description: "Baixa e analisa a fundo um conteudo de Instagram, TikTok ou YouTube a partir de uma URL (reel, video, short, carrossel): faz o download (mesmo com login wall, via cookies do navegador), extrai grids de frames pra ver o visual, transcreve o audio (parakeet-mlx por padrao, whisper como fallback) e entrega analise completa de hook, conteudo, formato, retencao, CTA e leitura estrategica. Use quando o usuario mandar um link de Instagram, TikTok ou YouTube e pedir pra analisar, estudar, ver o video, transcrever, ou auditar. Triggers: analisa esse reel, analisa esse tiktok, analisa esse youtube, ve esse video, estuda esse conteudo, transcreve esse video, link do instagram/tiktok/youtube, instagram.com/reel, tiktok.com, youtube.com, youtu.be."
allowed-tools: Bash, Read, Glob
---

# Content Analyzer JJ

Pipeline pra ingerir e analisar um conteudo de Instagram, TikTok ou YouTube a partir da URL (reel, video, short, carrossel). O motor e o yt-dlp, que baixa de praticamente qualquer plataforma. Resolve o problema de redes bloquearem acesso direto (login wall, video em blob) e de a legenda raramente conter o conteudo real (que esta no audio do video).

## Pre-requisitos
Veja o `README.md` pra instalacao completa. Em resumo: `yt-dlp`, `ffmpeg`, `gallery-dl` (carrosseis), e um transcritor de audio (`parakeet-mlx` em Apple Silicon, ou `whisper` em qualquer maquina). Precisa de um navegador (Edge/Chrome) logado no Instagram, pois os cookies dele furam o login wall.

## Passo 1 — Ingestao (download + frames + transcricao)

Rode o script. Ele baixa, monta os grids de frames e transcreve, tudo de uma vez:

```bash
~/.claude/skills/content-analyzer-jj/scripts/ingest.sh "<URL_DO_REEL>" /tmp/ig_reel
```

Saida: `/tmp/ig_reel/reel.mp4`, `/tmp/ig_reel/grid_*.png` (cada grid aprox. 60s do video, 1 frame a cada 3s) e `/tmp/ig_reel/reel.txt` (transcricao). A transcricao e impressa no final.

Notas:
- **Parakeet-mlx e o padrao** (rapido, local, Apple Silicon). Se parakeet retornar vazio (ex: reel so com musica, sem fala) o script automaticamente faz fallback pro whisper.
- Override manual: `TRANSCRIBER=whisper ingest.sh ...` forca whisper desde o inicio (use isto se nao estiver em Apple Silicon).
- Se o download falhar por cookies, tente outro navegador: `IG_COOKIES_BROWSER=chrome ingest.sh ...`.
- Se for carrossel de imagens (sem video), o script baixa os slides via gallery-dl; nesse caso analise as imagens direto.

## Passo 2 — Metadados publicos (opcional)

O `reel.info.json` (gerado pelo download) traz conta, likes, comments e a legenda (campo `.description`). Use pra enriquecer a analise.

## Passo 3 — Ler o visual

Use o `Read` tool em cada `grid_*.png`. Cada grid e um mosaico 5x4 (20 frames). Observe: formato (talking-head / screen-record / B-roll), legendas embutidas, inserts de tela, cortes, e o frame 1 (hook visual).

## Passo 4 — Analise (entregar isto)

Cruze transcricao + frames + engajamento e entregue:

1. **Ficha**: conta, duracao, formato, engajamento, data.
2. **Hook (0-3s)**: o que prende o scroll (frase + frame 1). Padrao usado.
3. **Conteudo**: resumo fiel do que e ensinado/dito (da transcricao, nao inventar).
4. **Estrutura e retencao**: como encadeia, onde usa insert/B-roll pra segurar atencao, ritmo.
5. **CTA / objetivo**: o que pede no fim, qual o objetivo (autoridade, lead, venda).
6. **Leitura estrategica**: relevancia pro negocio/nicho do usuario, o que da pra aprender ou fazer melhor, e se vale produzir algo no tema.

Seja honesto sobre o que veio do audio (verbatim) vs inferencia visual. Nunca reproduza a transcricao inteira como se fosse fala original longa; resuma.

## Passo 5 — Salvar no Notion (OPCIONAL)

Se voce quiser catalogar as analises numa database do Notion:

1. Defina `NOTION_API_TOKEN` no ambiente e crie uma database compartilhada com sua integracao.
2. Monte o JSON de payload com `parent.data_source_id` apontando pra SUA database (veja schema sugerido em `scripts/notion-save.sh`).
3. Rode: `~/.claude/skills/content-analyzer-jj/scripts/notion-save.sh /tmp/notion_reel_payload.json`
4. O script imprime a URL da pagina criada.

Se voce nao usa Notion, ignore este passo.

## Limpeza
Os arquivos ficam em `/tmp/`. Remova quando nao precisar mais.
