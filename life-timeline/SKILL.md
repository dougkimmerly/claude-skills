---
name: life-timeline
description: Build and query Doug's unified life timeline — the "where were we when (and how much did it cost)" data pipeline in dk400-postgres. Use for ANY task on the timeline data: running/extending the email location crawler, adding an attachment-PDF parser (eTicket / hotel folio → flights/hotels + cost), the presence ledger ("where was Doug/Maggie on date X"), place normalization / the gazetteer, or joining calendar⋈photo⋈boat⋈mail. The "how" for the [[life-timeline-project]] memory; downstream of the [[lotus-notes]] (Notes mail) and [[lightroom]] (photos) skills.
metadata:
  type: skill
---

# Life Timeline — the "where were we when + how much" data pipeline

Goal: every dated **event** links to the photos/docs/emails/calendar/boat data that document it, so we can answer *"when did we go to X, where did we stay, how much did it cost?"* **Date is the join key.** Repo: `~/Programming/dkSRC/apps/life-timeline` (GitHub `dougkimmerly/life-timeline`, private). Rationale/decisions: ADRs in `docs/decisions/` + the `life-timeline-project` memory (read it for current state — counts are live, query them).

## Where everything lives
- **DB:** dk400-postgres, home `192.168.20.19`, db `dk400`, role `homelab_admin` (no `postgres` superuser). Connect:
  `ssh doug@192.168.20.19 "docker exec -i dk400-postgres psql -U homelab_admin -d dk400 ..."`
- **Schemas (one DB, AS/400-library style):** `timeline` (the timeline), `mail` (the email archive), `cruising` (boat — read-only).
- **Key tables:** `mail.message` (337k+ msgs, all sources, `owner` = whose mailbox); `timeline.location_event` (flights/hotels/etc. with `cost`/`currency`); `timeline.calendar_event`; `timeline.photo` (exact GPS); `timeline.whereabouts` (VIEW unioning all sources); `timeline.presence` (resolved ledger); `timeline.presence_override` (manual fixes); `timeline.place` + `timeline.place_alias` (gazetteer); `cruising.moorages`/`stays`/`voyages` (boat geo, NOT `cruising.locations` = onboard stowage).
- **Attachments on disk:** `/home/doug/backups/unified/mail-attachments/<source_system>/<msgkey>/<NN>_<file>` on .19 (restic+USB). `pdftotext`/`pdfinfo` ARE installed on .19.
- **Scripts (in repo `scripts/`):** `extract_email_locations.py` (crawler), `parse_etickets.py` + `parse_folios.py` (attachment-PDF cost), `ingest_mbox_to_mail.py` / `ingest_emlx_to_mail.py` / `ingest_ics_calendars.py`. Gazetteer export → `gazetteer.csv` (the photo-CC's controlled vocab — re-export after place changes).

## The pipeline
sources → `mail.message` / `calendar_event` / `location_event` / `photo` / boat → **`whereabouts` VIEW** → **`presence_resolver.sql`** → `presence` ledger.
Resolver is **regenerable** (TRUNCATE + rebuild from whereabouts). Precedence per day: **manual > boat > photo > calendar > email > trip**. Re-run it after ANY new source lands:
`ssh doug@192.168.20.19 "docker exec -i dk400-postgres psql -U homelab_admin -d dk400 -v ON_ERROR_STOP=1 < /tmp/presence_resolver.sql"` (the resolver + place SQL live at `/tmp/*.sql` ON .19 — sync the repo copy there first: `/bin/cat db/presence_resolver.sql | ssh doug@192.168.20.19 "cat > /tmp/presence_resolver.sql"`).

## Run / extend the email location crawler
`scripts/extract_email_locations.py <Person>` (arg1 = whose mailbox; default Doug). It reads `/tmp/email_candidates.csv`, writes `/tmp/email_loc.sql`. Per-sender deterministic parsers (NO LLM): Air Canada/WestJet flights, Choice/Marriott/Fairmont hotels, Airbnb lodging, OpenTable etc. dining. Carries `cost`/`currency` (Marriott "Total for stay (for all rooms)", Airbnb "Total payment $X").
1. Export candidates (transactional senders) for a person:
   `COPY (SELECT source_system, source_msg_id, lower(from_addr), sent_ts::date, subject, COALESCE(left(body_text,4000),'') FROM mail.message WHERE owner='Doug' AND from_addr ILIKE ANY(ARRAY['%aircanada%','%marriott%','%airbnb%',...])) TO STDOUT WITH (FORMAT csv)` → `/tmp/email_candidates.csv`
2. `python3 scripts/extract_email_locations.py Doug`
3. Apply: `ssh doug@.19 "docker exec -i dk400-postgres psql ... -v ON_ERROR_STOP=1" < /tmp/email_loc.sql` (local stdin!), then re-run resolver.
Email is HIGH-precision/LOW-recall (ADR 0006): it ENRICHES whereabouts windows that photo/boat/calendar already detect — not a blind corpus sweep.

## Add an attachment-PDF parser (eTicket / folio → cost) — the reusable pattern
`parse_etickets.py` (AC/Aeroplan flight itineraries) and `parse_folios.py` (Choice/Hilton/Marriott/Fairmont hotel folios) are the templates. To add a new doc type:
1. **Find the PDFs:** `SELECT owner, source_system, source_msg_id, sent_ts::date, p FROM mail.message m, unnest(m.attachment_paths) p WHERE p ~* '\.pdf$' AND p ~* '<pattern>'` → `/tmp/<x>_list.tsv`.
2. **Batch-extract text on .19:** `/bin/cat /tmp/<x>_paths.txt | ssh -T doug@192.168.20.19 'while IFS="|" read -r sid path; do echo "@@@MARK@@@ $sid"; pdftotext -layout "$path" - 2>/dev/null; done' > /tmp/<x>_text.txt` (marker-delimited per sid; split with `re.split(r'@@@MARK@@@\s+(\S+)', raw)` — markers can land mid-line so DON'T line-anchor).
3. **Parse** per chain/format; **review mode first** (print an attribution table), `--load` writes SQL.
4. **ATTRIBUTE BY PASSENGER/GUEST NAME, never the mailbox owner** — Doug & Maggie booked travel for colleagues (Joan Kienzle, Patrick Grimard, Gail Frith) and friends; attributing to the owner would place them in cities they never visited. Match "Kimmerly, Doug/Douglas"→Doug, "Margaret/Maggie Kimmerly"→Maggie, else skip.
5. **Dedup** the same booking across mailboxes (kbl+gmail copies) by (person, place, date[, total]); watch for **2-page PDFs double-counting a folio total** (total ≈ 2× another in the same date/city group → drop the doubled one).
6. Geocode any new cities into the gazetteer, then re-run the resolver. `location_event` has `cost numeric`/`currency` for the "how much" leg.
Restrict segment/total parsing to the relevant SECTION (e.g. eTicket "Flight Itinerary" only) or tax codes (GST/QST/TSA) and stray dates leak in.

## Place normalization / gazetteer
`timeline.place` (name, keyword, kind, lat, lon, radius_km, country [, rollup]) + `timeline.place_alias` + `timeline.norm_coord(qlat,qlon)` (nearest place within radius — params are **qlat/qlon NOT lat/lon**, else they bind to table columns → distance 0) + `timeline.norm(txt,qlat,qlon)` (coords > alias > text). Add a place → nearby coords auto-resolve; add an alias for string variants. **`place_alias` FK = `place_id` (a place.id), NOT a name** — insert via `SELECT 'alias', id FROM place WHERE name='Canonical'`. Convention: canonical names `City, ST`; alias the bare/variant forms. `timeline.unresolved_places` = review queue. `timeline.learn_place(pattern)` discovers a named place's coords from geotagged photos taken during its calendar events (circularity-safe — real GPS only).

## Presence ledger + manual overrides
`timeline.presence` answers "where was <person> on <date>". For a known-bad observation (e.g. photo GPS drifted, or an event in no digital source): INSERT `timeline.presence_override (person, start_date, end_date, place, note)` — manual outranks everything and survives every regeneration. This is the canonical fix for "I remember we were at X" that no source captures (e.g. the Feb 2013 DSN party at The Old Mill — photo GPS had drifted ~1.3km to a friend's house).

## Hard gotchas (these will bite — they already did)
- **NEVER mass-`UPDATE mail.message` in place.** Its FTS is an *expression* GIN index (`to_tsvector(subject||body_text)`) — any row update re-evaluates to_tsvector per row → a full-table update runs 30+ min and may never finish. For a column-only mass update: `DROP INDEX mail.message_fts_idx` → UPDATE (~3 min) → recreate the index once (plain `CREATE INDEX`, ~13 min). Verify `indisvalid` after.
- **`CREATE INDEX CONCURRENTLY` can silently fail** under concurrent load (leaves `indisvalid=f`, planner ignores it → seq scans). Check `SELECT indisvalid FROM pg_index ...`; fall back to a plain `CREATE INDEX` when the table is quiet.
- **`ssh ".19" "psql < /tmp/file"` reads the file ON .19**, not your Mac (silent `INSERT 0 0` from a stale/absent remote file). To apply a LOCAL .sql: `ssh ".19" "docker exec -i ... psql ..." < /tmp/file` (redirect OUTSIDE the quotes). The resolver/place SQL deliberately live on .19, so `< /tmp/foo.sql` *inside* the quotes is correct for those.
- **Loads are ADDITIVE** — `INSERT ... ON CONFLICT DO NOTHING`. NEVER TRUNCATE/DROP the shared `mail.message` (a Notes load once clobbered 40k rows); reload one source only via `DELETE WHERE source_system=` or `extracted_by=`.
- **`cat`/`wc` intermittently "command not found"** inside compound ssh pipelines → use `/bin/cat`, `/usr/bin/grep`, `awk 'END{print NR}'`.
- Set `SET client_min_messages=warning;` to silence the harmless "word too long to be indexed" GIN notices when writing to `mail.message`.
- A photo's EXACT GPS is never lost to normalization — the rollup is only in the derived `presence`; raw coords stay in `timeline.photo` (drill via `captured_at`). Derived `gps:approx` photo coords are OUTPUT-only — never feed them back into whereabouts.
