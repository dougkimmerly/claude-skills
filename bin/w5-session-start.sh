#!/bin/bash
# w5-session-start.sh — H25 (dk-w5 M7, 2026-08-21): the GLOBAL session-start
# wire. Every CC session on every domain records one row in the w5 appliance's
# w5m.session_start_log via an MCP initialize handshake with X-W5-Asker set to
# the repo/dir the session opened in. Replaces M6-H15's per-repo wiring.
# Fail-silent + fast: the router being down must never slow a session start.
W5_URL="${W5_MCP_URL:-https://homecore.tail39e0b3.ts.net/mcp}"
ASKER="$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")"
curl -s -o /dev/null --max-time 3 -X POST "$W5_URL" \
  -H "Content-Type: application/json" \
  -H "X-W5-Asker: ${ASKER}" \
  -d '{"jsonrpc":"2.0","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"cc-session-start","version":"1"}},"id":1}' 2>/dev/null
exit 0
