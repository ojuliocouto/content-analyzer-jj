#!/usr/bin/env bash
# (OPCIONAL) Salva uma analise de reel numa database do Notion.
# Uso: notion-save.sh <payload.json>
# O payload deve ser um JSON pronto pra POST /v1/pages (com parent.data_source_id ja preenchido).
#
# Pre-requisitos:
#   - NOTION_API_TOKEN no env (export NOTION_API_TOKEN="secret_...").
#   - Uma database no Notion compartilhada com a sua integracao.
#   - O data_source_id da SUA database preenchido no payload (parent.data_source_id).
#
# Schema sugerido da database (adapte ao seu gosto):
#   Titulo (title), URL (url), Conta (rich_text), "Duracao (s)" (number),
#   Formato (select: talking-head|screen-record|b-roll|mix),
#   Tema (multi_select: livre),
#   Aplicacao (select: inspirar-reel|inspirar-threads|pitch-comercial|so-arquivo),
#   Status (select: analisado|aplicar|aplicado|descartado),
#   "Data analise" (date)
#
# Esta etapa e OPCIONAL. Se voce nao usa Notion, ignore o Passo 5 da skill.

set -euo pipefail

PAYLOAD="${1:-}"
if [[ -z "$PAYLOAD" || ! -f "$PAYLOAD" ]]; then
  echo "uso: $0 <payload.json>" >&2
  exit 1
fi
if [[ -z "${NOTION_API_TOKEN:-}" ]]; then
  echo "ERRO: NOTION_API_TOKEN nao esta no env. Defina com: export NOTION_API_TOKEN=\"secret_...\"" >&2
  exit 1
fi

RESP=$(curl -sS -X POST "https://api.notion.com/v1/pages" \
  -H "Authorization: Bearer $NOTION_API_TOKEN" \
  -H "Notion-Version: 2025-09-03" \
  -H "Content-Type: application/json" \
  --data @"$PAYLOAD")

URL=$(echo "$RESP" | jq -r '.url // empty')
ID=$(echo "$RESP" | jq -r '.id // empty')

if [[ -n "$URL" ]]; then
  echo "OK: $URL"
  echo "id: $ID"
else
  echo "FALHOU. Resposta:" >&2
  echo "$RESP" | jq . >&2
  exit 1
fi
