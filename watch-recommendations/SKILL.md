---
name: watch-recommendations
description: Pick something to watch AND the "Shows" app (aka watch-rater) that drives it — the rating/search/WatchList/recommendations PWA, its watchlist DB + schema, the watch_sync Plex sync, and deploy. Use when Doug/Maggie want a recommendation or to log a watch, OR when working on / deploying / debugging the watch-rater (Shows) app.
metadata:
  type: skill
---

# Watch Recommendations

## Quick start

1. Query `watchlist.titles` + `watchlist.ratings` for the taste profile
2. Ask what platform they have access to tonight (Plex, Netflix, etc.)
3. Find candidates: Overseerr discover OR JustWatch browsing
4. Fetch TMDB metadata via Overseerr for each candidate
5. Score candidates against taste profile, cross-check against seen titles
6. Recommend 2–3 with explanation, then log any new views

---

## Viewers

Watching with **Maggie**, who has Irish roots. Authenticity of setting, dialect, and culture matters — Derry Girls resonated deeply because it captured real Irish life.

**Per-viewer notes:**
- Belfast (2021) — Maggie won't watch, too emotional. Skip for joint viewing.
- Use `viewer = 'both'` for joint recommendations; can query per viewer for solo viewing.

---

## Viewers

- **Doug** — taste extends into historical drama, military, political, dark thriller, sci-fi action (Matrix, Star Trek). Swiss Family Robinson (1960) was his first film and shaped his character (self-sufficiency, inventiveness, family, just-do-it attitude) — but this is biographical context, NOT a genre cue. Do not recommend similar family adventure films on that basis.
- **Maggie** — Irish roots, authenticity matters deeply. Loves warmth, cosiness, family. Adores Paddington ("anything with teddy bears, except Ted"). **Darkness isn't a dealbreaker when there's a strong pull** (2026-06-01 survey): she's watched Peaky Blinders *twice* — the British/historical/period connection overrides the darkness — and loved Slow Horses (dark spy, but strong characters + wit). So don't rule out dark/intense crime for her, but the *hook* matters: British/historical, strong characters, or humour. Her hard no's: emotionally-close-to-home Irish trauma (Belfast 2021), and — biggest of all — **animals/dogs dying or suffering (see HARD TRIGGER below)**. She also rates cosy mystery / warm rom-com *higher* than the joint baseline (the bigger fan).
- **HARD TRIGGER — dogs/animals dying or suffering. The single firmest filter for Maggie.** She was in tears throughout **A Dog's Purpose (2017)** — and the reincarnation "he always comes back" framing did NOT help; the repeated deaths were too much. **Never recommend anything where a dog or pet dies or suffers, no matter how feel-good the overall tone or how it's resolved.** This overrides everything else — a movie can be perfect on every other axis and still be an instant no on this. When unsure whether a film has animal death, flag it rather than recommend blind.
- **Comfort rewatches are a whole viewing mode of their own.** Maggie rewatches feel-good sitcoms endlessly — **Friends and The Big Bang Theory** above all, plus **Corner Gas**. (**M*A*S*H is Doug's comfort rewatch, not hers** — he rewatches it repeatedly; she liked it but doesn't return to it the same way.) She ticked "wouldn't rewatch" for Corner Gas on the survey yet still turns it on for a light easy watch — so the survey's rewatch box is unreliable for *her* comfort shows. These are go-to background staples, not done-with-it. ("Wouldn't rewatch" genuinely means low-priority for The Diplomat / Lupin, which just didn't stick.) When she wants comfort rather than something new, the answer is a warm familiar sitcom, not a recommendation.
- **THE FALLS-ASLEEP TEST — the strongest engagement signal we have.** Joint viewing is **after dinner, when Maggie is often tired**, so *pace and engagement* matter as much as taste: if something doesn't hold her, she falls asleep — even when she's genuinely interested in the subject. This is more predictive than her stated ratings. **Now captured structurally** as `ratings.engagement` (`held`/`faded`/`asleep`) by the watch-rater app — query it, don't just infer it.
  - *Interested but doesn't hold attention → asleep:* **Hamnet (2025)** — she likes it, but it's slow/heavy/literary; she fell asleep two nights running, still only 2/3 through. So slow-burn, contemplative, heavy, or literary films fail the after-dinner slot **even when the subject appeals to her**.
  - *Engaging + feel-good → wide awake despite exhaustion:* **The Muppet Christmas Carol** — she was really tired and stayed awake the whole way through.
  - **Implication:** for after-dinner joint picks, weight ENGAGEMENT + uplift + momentum heavily. "Good" or "her kind of thing" isn't enough — it has to *hold* her. Note this also refines the period-drama preference: propulsive, soapy, character-driven period (Downton, Bridgerton, Peaky) holds her; slow literary period (Hamnet) does not — it's about **pace, not genre**. Save slow-burn/heavy for when she's fresh, or for Doug-solo.

**Always ask "joint or solo?" before recommending.** The DB has per-viewer ratings — use them.

## Taste Profile (as of 2026-06-01 — updated from Maggie's survey)

**Joint — both enjoy:**
- Cozy whodunit mystery (Only Murders, Knives Out trilogy, Thursday Murder Club, Death in Paradise, Madame Blanc)
- British/Irish period drama (Downton Abbey, The Crown, Peaky Blinders, Bridgerton)
- Warm romantic comedy (Four Weddings, Notting Hill, Something's Gotta Give, Love Actually, Bridget Jones)
- Authentic Irish content (Derry Girls ★★★, Waking Ned Devine ★★★, Bodkin, Father Ted, Republic of Doyle)
- Classic British comedy (M*A*S*H ★★★, West Wing ★★, Fawlty Towers, Yes Minister, Corner Gas, Hustle)
- Beverly Hills Cop style action-comedy (both really liked)
- Paddington — Maggie adores, Doug likes; all three films

**Doug solo (not for Maggie):**
- Military/action drama (The Unit, The Deer Hunter)
- Solo thrillers (The Blacklist)
- Political/historical heavy (The Apprentice, Oppenheimer more so)

**Maggie's core driver: FEEL-GOOD — she watches to be uplifted.** Warmth, heart, and a happy/satisfying tone are what she's after. This is the through-line behind every preference below: the cosy mystery, the warm rom-com, the heartwarming comedy. It's also why genuinely bleak/sad is out (Belfast), even though dark-with-a-strong-hook is fine (Peaky's British/historical pull, Slow Horses' wit). When in doubt for Maggie, optimise for uplift.

**Maggie-preferred (she rates higher than the joint baseline):**
- Love Actually, Paddington, Never Have I Ever, The Pradeeps of Pittsburgh
- From her 2026-06-01 survey she *loved* (vs joint 'liked'): Death in Paradise, Knives Out, Only Murders in the Building, Notting Hill, Four Weddings, Downton Abbey, Hacks, Slow Horses

**Era rule:** Doug likes older films (black and white, classic Hollywood — Charade, Roman Holiday, etc.). Maggie prefers newer films, tolerates old ones but doesn't enjoy them the same way. For joint viewing default to post-1980 unless truly exceptional. Older films are fine for Doug-solo picks.

**Avoid for joint viewing:**
- Heavy action / pure action without comedy
- Horror
- Campy/self-aware/heightened tone (Enola Holmes — felt forced)
- Shallow glossy light comedy (Emily in Paris — didn't connect)
- Genuinely bleak with no warmth, wit, or hook (Captain Hook: The Cursed Tides — disliked). NOTE: dark/intense alone is NOT a disqualifier for Maggie — she loved Peaky Blinders (watched twice) and Slow Horses. The bar is bleakness with no character/humour/historical pull.
- Belfast (2021) — Maggie won't watch (emotionally too close to home, not because it's dark)

**Taste profile query** (now with the structured signals — score, engagement, reaction tags):
```sql
SELECT t.title, t.year, t.genres, t.keywords, t.origin_country,
       r.viewer, r.rating, r.score, r.engagement, r.notes,
       (SELECT array_agg(rt2.label) FROM watchlist.rating_tags rtg
        JOIN watchlist.reaction_tags rt2 ON rt2.id = rtg.tag_id
        WHERE rtg.rating_id = r.id) AS tags
FROM watchlist.titles t
JOIN watchlist.ratings r ON r.title_id = t.id
WHERE r.status = 'watched' AND r.rating IN ('loved', 'liked')
ORDER BY r.score DESC NULLS LAST, t.title;
```
Weight `engagement='asleep'` as a strong *negative* for after-dinner joint picks
even when `rating` is positive (the falls-asleep test, now structured), and read
per-viewer rows (`r.viewer`) for solo profiles. Negative-polarity tags
(too dark/violent/sad, dragged) flag *why* something missed.

---

## The Shows app (watch-rater) — the front end for all of this

**"Shows"** (display name) is the PWA Doug + Maggie use to rate, search, build a
WatchList, and act on recommendations. Internally everything is named
**watch-rater** (repo, container, GHCR image, compose dir, SOPS file) — grep and
deploy by that name. Full architecture + endpoints live in the repo README;
rationale in fixer **ADR 0018**. This section is the operational summary + the
gotchas.

- **URL:** `http://192.168.20.19:3125` (docker-server, host network). Add-to-home-screen on phones/iPad; Tailscale away from home. Identity is a per-device localStorage choice (Doug/Maggie) — no login.
- **Tabs:** **Rate** (per-viewer queue of watched-but-unrated + "needs review"); **Search** (Overseerr titles + people, "On Plex" computed from our own `plex_library`, Request, "＋ Later"); **WatchList** (shared **vote** model — Doug/Maggie/Both sub-tabs, each `want_to_watch` row = one person's vote, both votes ⇒ Both); **Recs** (`status='recommended'` — accept ⇒ `want_to_watch` + Overseerr download if not on Plex; "Seen it" ⇒ `watched`/rating-NULL + Plex scrobble).
- **Cross-repo layout:** app + canonical schema → `dkSRC/apps/watch-rater` (`db/schema.sql`, idempotent); Plex→DB sync → `dk400-homelab/programs/watch_sync.py` (daily Robot job `WATCH_SYNC`, 08:00); compose + `deploy.sh` → `homelab-docker-server/watch-rater`; secret → `homelab-secrets/secrets/home/watch-rater.sops.yaml` (`DK400_DB_URL`, `GHCR_TOKEN`, `OVERSEERR_API_KEY`, `PLEX_TOKEN`).
- **DB role:** app + watch_sync connect as **dk400** (granted on the `watchlist` schema); **fixer** owns it — apply schema as fixer.

### Deploy (and the gotchas)
1. Push the app repo → GitHub Actions builds `ghcr.io/dougkimmerly/watch-rater:latest`.
2. On docker-server: **`cd /opt/docker-server && git pull` FIRST** — `deploy.sh` only pulls the homelab-secrets repo, **not** the compose repo, so compose/env changes won't land otherwise. Then `cd /opt/docker-server/watch-rater && ./deploy.sh` (sops exec-env → docker login → compose pull → up).
3. **Schema changes before deploy:** `cat db/schema.sql | ssh doug@192.168.20.19 "docker exec -i dk400-postgres psql -U fixer -d dk400 -v ON_ERROR_STOP=1"` (idempotent — safe to re-run).
4. **watch_sync changes** bake into the running container only on the next dk400 rebuild; to test immediately, `docker cp` the file into the running `dk400` container and invoke `from programs import watch_sync; asyncio.run(watch_sync.run())`.

### Integration gotchas
- **Marking "watched" in Plex uses the LOCAL server API** (`GET {PLEX_URL}/:/scrobble?identifier=com.plexapp.plugins.library&key=<plex_key>&X-Plex-Token=…`) — reliable. The Plex **watchlist cloud API** (`discover.provider.plex.tv`) is flaky/undocumented — **don't** build on it.
- **"Is it on Plex?" is computed from our own `plex_library`** (kept current by watch_sync), not Overseerr's `mediaInfo` (which is often empty here).
- **Overseerr runs on docker-server** (`localhost:5055`); the **API key alone authorizes** search/request — no Plex session cookie needed (the cookie dance in the Overseerr section below is outdated).

## Watchlist Database

**Connection:**
```bash
ssh doug@192.168.20.19 "docker exec dk400-postgres psql -U fixer -d dk400 -c \"...\""
```

**Schema:** `watchlist` (five tables). Canonical DDL is codified in the
`watch-rater` repo (`db/schema.sql`); the `fixer` role owns it, the `dk400` role
has read/write (used by the app + the `watch_sync` program).

**How ratings get captured now (2026-06-02):** the **watch-rater PWA**
(`http://192.168.20.19:3125`, add-to-home-screen on the phones/iPad) shows what
was watched in Plex but not yet rated and captures per-viewer reactions. The
Plex→DB sync is automated by the **`watch_sync` dk400 program** (daily 08:00,
Robot job `WATCH_SYNC`) — it links `plex_library` rows to `titles` via the
`tmdb://` GUID and TMDB-enriches. So `plex_library`/`titles` self-maintain and
ratings arrive continuously; don't hand-sync Plex or hand-insert watched ratings
unless backfilling something the app can't reach.

**The app has WatchList + Recommendations tabs (per-person):**
- **WatchList** = `status='want_to_watch'`, now written **per viewer** (`doug`/`maggie`), not `both`. Search "＋ Later" and accepted recs land here. A title drops off automatically once it's watched/started in Plex (view activity) or the viewer rates/dismisses it. Legacy `both` want_to_watch rows still show for both people.
- **Recommendations** = `status='recommended'`. **This is how you surface picks into the app.** When recommending, insert a row per viewer with the pitch in `notes`:
  ```sql
  INSERT INTO watchlist.ratings (title_id, viewer, status, notes)
  VALUES (<title_id>, 'maggie', 'recommended', 'Cozy Irish whodunit — Derry Girls energy')
  ON CONFLICT (title_id, viewer) DO UPDATE SET status='recommended', notes=EXCLUDED.notes;
  ```
  (Ensure the `titles` row exists first — enrich via Overseerr like any new entry.) In the app, tapping a rec moves it to that viewer's WatchList and fires an Overseerr download if it's not already on Plex. Recs for titles the viewer has already watched/dismissed/listed are auto-filtered.

### `watchlist.titles` — one row per title, TMDB-enriched
| Column | Type | Notes |
|--------|------|-------|
| id | serial PK | |
| title | text | |
| year | integer | |
| media_type | text | `movie` or `show` |
| tmdb_id | integer UNIQUE | TMDB ID for metadata |
| imdb_id | text | |
| genres | text[] | from TMDB |
| keywords | text[] | from TMDB (tone/theme signals) |
| director | text | first director |
| cast_top | text[] | top 5 cast |
| origin_country | text | ISO 2-letter |
| original_language | text | ISO 2-letter |
| runtime_minutes | integer | |
| decade | integer | GENERATED: floor(year/10)*10 |
| tmdb_fetched_at | timestamptz | NULL = not yet enriched |

### `watchlist.ratings` — per-viewer status and rating (UNIQUE on (title_id, viewer))
| Column | Type | Notes |
|--------|------|-------|
| title_id | FK → titles.id | |
| viewer | text | `doug`, `maggie`, `both` (app writes per-person; `both` is historical) |
| status | text | `watched`, `want_to_watch` (per-person WatchList), `wont_watch`, `requested`, `abandoned`, `not_watched`, `recommended` (app Recs feed) |
| rating | text | `loved`, `liked`, `neutral`, `disliked` — NULL if not yet seen |
| score | smallint | 1–10 (finer than `rating`; app derives `rating` from it) |
| engagement | text | `held` / `faded` / `asleep` — **the structured falls-asleep signal** |
| finished | boolean | did they finish it |
| watched_together | boolean | first rater's audience call: did the partner also watch |
| notes | text | free-text reaction |
| watched_at | date | |

`status='not_watched'` = the app's per-viewer "I didn't watch this" dismiss (not a real rating — exclude from taste).

### `watchlist.reaction_tags` / `watchlist.rating_tags` — checkbox reactions
`reaction_tags` defines the editable checkboxes (id, key, label, `polarity`
positive/negative, `category` tone/craft, `active`, `display_order`); add/retire
by inserting rows or flipping `active`. `rating_tags(rating_id, tag_id)` records
which boxes were ticked for a rating. Tone tags (Too dark/Too violent/Too
sad/Scary) and craft tags (Good story/Great characters/Funny/Heartwarming/
Predictable/Dragged) are strong content-based signals — join them for scoring.

### `watchlist.plex_library` — Plex library sync
| Column | Type | Notes |
|--------|------|-------|
| plex_key | text PK | Plex ratingKey |
| title | text | |
| media_type | text | |
| section | text | movies or tvshows |
| tmdb_id | int → titles.id | |
| view_count | int | |
| last_viewed_at | timestamptz | |
| last_synced | timestamptz | |

### Common queries
```sql
-- Everything watched + rating
SELECT t.title, t.year, r.status, r.rating, r.notes
FROM watchlist.titles t JOIN watchlist.ratings r ON r.title_id = t.id
ORDER BY r.rating NULLS LAST, t.title;

-- Check if title has been seen
SELECT t.title, r.status, r.rating FROM watchlist.titles t
JOIN watchlist.ratings r ON r.title_id = t.id
WHERE t.title ILIKE '%search term%';

-- Not yet seen (available to recommend)
SELECT t.title, t.year, t.media_type, t.genres FROM watchlist.titles t
JOIN watchlist.ratings r ON r.title_id = t.id
WHERE r.status IN ('want_to_watch', 'requested') AND r.rating IS NULL;
```

### Add a new entry (two-step: title then rating)
```sql
-- Step 1: insert title (use Overseerr to get tmdb_id first)
INSERT INTO watchlist.titles (title, year, media_type, tmdb_id, genres, keywords, director, cast_top, origin_country, original_language, runtime_minutes, tmdb_fetched_at)
VALUES ('Title', 2024, 'movie', 12345, ARRAY['Comedy','Drama'], ARRAY['whodunit'], 'Director Name', ARRAY['Actor 1'], 'GB', 'en', 95, NOW())
ON CONFLICT (tmdb_id) DO UPDATE SET title=EXCLUDED.title
RETURNING id;

-- Step 2: insert rating
INSERT INTO watchlist.ratings (title_id, viewer, status, rating, notes)
VALUES (<id from above>, 'both', 'watched', 'liked', 'optional note');
```

---

## Overseerr — TMDB Metadata + Requesting

**URL:** `http://192.168.20.16:5055` (also accessible at port 5055 from docker-server)
**API key:** SOPS `secrets/home/watch-rater.sops.yaml` → `OVERSEERR_API_KEY`
  - `export OVERSEERR_API_KEY=$(SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys.txt sops -d --extract '["OVERSEERR_API_KEY"]' ~/Programming/dkSRC/infrastructure/homelab-secrets/secrets/home/watch-rater.sops.yaml)`
  - Fallback: `docker exec overseerr cat /app/config/settings.json | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['main']['apiKey'])" | base64 -d`

**Auth: API key alone only works for `/api/v1/status`. Everything else needs Plex session cookie:**

```bash
export SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys.txt
PLEX_TOKEN=$(sops -d --extract '["PLEX_TOKEN"]' ~/Programming/dkSRC/infrastructure/homelab-secrets/secrets/home/dk400.sops.yaml)

# Login — saves session cookie on docker-server
ssh doug@192.168.20.19 "curl -s -X POST \
  -H 'Content-Type: application/json' \
  -H 'X-Api-Key: ${OVERSEERR_API_KEY}' \
  -c /tmp/ovcookie.txt \
  -d '{\"authToken\": \"$PLEX_TOKEN\"}' \
  'http://localhost:5055/api/v1/auth/plex'"

# Now use cookie for all subsequent requests
ssh doug@192.168.20.19 "curl -s -b /tmp/ovcookie.txt 'http://localhost:5055/api/v1/...'"
```

### Search
```bash
# URL-encode the query manually (spaces → %20, not +)
ssh doug@192.168.20.19 "curl -s -b /tmp/ovcookie.txt 'http://localhost:5055/api/v1/search?query=Knives%20Out'"
# Returns: [{id, title, mediaType:'movie'|'tv', releaseDate, ...}, ...]
```

### Get TMDB metadata for a title
```bash
# movie: /api/v1/movie/{tmdb_id}   tv: /api/v1/tv/{tmdb_id}
ssh doug@192.168.20.19 "curl -s -b /tmp/ovcookie.txt 'http://localhost:5055/api/v1/movie/546554' | python3 -c \"
import sys, json
d = json.load(sys.stdin)
print('Title:', d.get('title'))
print('Genres:', [g.get('name') for g in d.get('genres',[])])
print('Keywords:', [k.get('name') for k in d.get('keywords',[])[:10]])
print('Director:', [c.get('name') for c in d.get('credits',{}).get('crew',[]) if c.get('job')=='Director'])
print('Cast:', [c.get('name') for c in d.get('credits',{}).get('cast',[])[:5]])
print('Country:', d.get('originCountry'))
\""
```

### Discover popular movies/shows
```bash
ssh doug@192.168.20.19 "curl -s -b /tmp/ovcookie.txt 'http://localhost:5055/api/v1/discover/movies?page=1' | python3 -c \"
import sys, json
d = json.load(sys.stdin)
for r in d.get('results', [])[:10]:
    print(r.get('id'), r.get('title'), r.get('releaseDate','')[:4])
\""
```

### Request a title (via Overseerr)
```bash
# Get tmdb_id from search first, then:
ssh doug@192.168.20.19 "curl -s -X POST -b /tmp/ovcookie.txt \
  -H 'Content-Type: application/json' \
  -d '{\"mediaType\": \"movie\", \"mediaId\": 546554}' \
  'http://localhost:5055/api/v1/request'"
```

---

## Plex API

**Server:** `http://192.168.20.12:32400` (55VIDEOSERVER, Windows)
**Token:** SOPS `secrets/home/dk400.sops.yaml` → `PLEX_TOKEN`

Access via homelab SSH since Plex IP not directly reachable from Mac:

```bash
export SOPS_AGE_KEY_FILE=$HOME/.config/sops/age/keys.txt
PLEX_TOKEN=$(sops -d --extract '["PLEX_TOKEN"]' ~/Programming/dkSRC/infrastructure/homelab-secrets/secrets/home/dk400.sops.yaml)
PLEX="http://192.168.20.12:32400"

# Recent watch history
ssh doug@192.168.20.19 "curl -s -H 'X-Plex-Token: $PLEX_TOKEN' \
  '$PLEX/status/sessions/history/all?sort=viewedAt:desc&limit=50'" | python3 -c "
import sys, xml.etree.ElementTree as ET
from datetime import datetime
tree = ET.parse(sys.stdin)
for v in tree.getroot().findall('Video'):
    ts = int(v.get('viewedAt', 0))
    date = datetime.fromtimestamp(ts).strftime('%Y-%m-%d')
    t = v.get('type')
    title = v.get('title') if t == 'movie' else f\"{v.get('grandparentTitle')} — {v.get('title')}\"
    print(f'{date}  [{t}]  {title}')
"

# Movie library (section 3)
ssh doug@192.168.20.19 "curl -s -H 'X-Plex-Token: $PLEX_TOKEN' '$PLEX/library/sections/3/all'" | python3 -c "
import sys, xml.etree.ElementTree as ET
tree = ET.parse(sys.stdin)
for v in tree.getroot().findall('Video'):
    print(v.get('title'), v.get('year'))
"

# TV shows library (section 5)
ssh doug@192.168.20.19 "curl -s -H 'X-Plex-Token: $PLEX_TOKEN' '$PLEX/library/sections/5/all'" | python3 -c "
import sys, xml.etree.ElementTree as ET
tree = ET.parse(sys.stdin)
for v in tree.getroot().findall('Directory'):
    print(v.get('title'), v.get('year'))
"
```

---

## Kometa — Plex Library Management

**Kometa** runs on the Synology and manages Plex collections, overlays, and metadata automatically.

**Config location (live):** `/volume1/Home Files/Media/arrStack/kometa/config/` on `192.168.20.16`

**Key files:**
| File | Purpose |
|------|---------|
| `config.yml` | Main config — libraries, collection sources, overlay sources |
| `franchises.yml` | Custom metadata: franchise sort titles (see below) |

### Franchise Sort Titles

All multi-film franchise series have sort titles set in `franchises.yml` so that:
1. Films that don't start with the franchise name (e.g. "Raiders of the Lost Ark", "Jason Bourne") group with the rest of the franchise in the main alphabetical library view
2. Films within a franchise appear in **release date order** rather than alphabetical subtitle order

**Franchises covered** (as of 2026-05-31):
James Bond (25 films), Indiana Jones, Bourne, Star Wars (incl. Rogue One + Solo), Harry Potter, Pirates of the Caribbean, Lord of the Rings, The Hobbit, Star Trek (13 films), The Matrix, Mission: Impossible, Batman (Burton era), Alien, Pink Panther, The Exorcist, Stargate, Ocean's, Beverly Hills Cop, Back to the Future

**Sort title format:** `Franchise Name YYYY - Subtitle`
Example: `Indiana Jones 1981 - Raiders of the Lost Ark`

**Adding a new franchise (or new film in an existing franchise):**
```bash
# Edit franchises.yml on Synology directly, or edit locally and push:
ssh doug@192.168.20.16 "cat >> '/volume1/Home Files/Media/arrStack/kometa/config/franchises.yml'" << 'EOF'

  "New Film Title":
    sort_title: "Franchise Name YYYY - New Film Title"
EOF
```

Or edit via the local backup path and let Syncthing sync it:
`/home/doug/backups/unified/arrstack/kometa/config/franchises.yml` (on docker-server)

**Triggering a Kometa run:**
Find the Kometa container on the Synology and restart it, or wait for the scheduled run. Check Kometa logs at `/volume1/Home Files/Media/arrStack/kometa/config/logs/meta.log`.

**Year disambiguation** (for films with same title, e.g. two "Casino Royale"):
```yaml
  "Casino Royale (2006)":
    sort_title: "James Bond 2006 - Casino Royale"
  "Star Trek (2009)":
    sort_title: "Star Trek 2009 - Star Trek"
```

---

## JustWatch — Platform Availability Check

Use Playwright MCP to verify a title is on a specific platform.

**Check a specific title:**
1. Navigate to `https://www.justwatch.com/us/movie/<slug>` or `/tv-show/<slug>`
2. Evaluate: `() => { const text = document.body.innerText; const idx = text.indexOf('STREAMING:'); return text.substring(idx, idx + 300); }`

**Browse platform catalog:**
```
https://www.justwatch.com/us/provider/netflix/movies?sort_by=popular
https://www.justwatch.com/us/provider/amazon-prime-video/movies?sort_by=popular
```
Then extract titles:
```js
() => {
  const links = document.querySelectorAll('a[href*="/us/movie/"], a[href*="/us/tv-show/"]');
  const results = [];
  links.forEach(el => {
    const t = el.getAttribute('aria-label') || el.textContent?.trim();
    if (t && t.length > 1 && t !== 'Watch Now') results.push(t);
  });
  return [...new Set(results)].slice(0, 50);
}
```

**Note:** Genre filter URLs often return empty results — browse unfiltered, cross-reference with taste profile.

---

## Recommendation Workflow

1. **Query unseen titles already in watchlist** — these are highest-priority (already wanted/requested):
   ```sql
   SELECT t.title, t.year, t.media_type, t.genres, t.origin_country, r.notes
   FROM watchlist.titles t JOIN watchlist.ratings r ON r.title_id = t.id
   WHERE r.status IN ('want_to_watch', 'requested') AND r.rating IS NULL
   ORDER BY t.year DESC;
   ```

2. **Ask what platform** is available tonight (Plex, Netflix, etc.)

3. **For Plex recommendations:** Query Plex library for unwatched titles, cross-reference against watchlist

4. **For streaming:** Browse JustWatch for that platform → get candidate list → search each via Overseerr for TMDB metadata → score against taste profile

5. **Score candidates** using taste profile (genres + keywords + country):
   - Positive signals: Comedy, Mystery, Crime, Drama, Romance, GB/IE/FR origin
   - Strong positive keywords: whodunit, period drama, ireland, murder mystery, sitcom
   - Negative signals: Action (pure), Horror, Adventure (campy/superhero type), Sci-Fi

6. **Pick 2–3** with highest scores and good fit for both viewers; explain why each fits

**When user says they've seen/liked something mid-conversation:**
Add it to the database immediately (title + rating). Use Overseerr search to get tmdb_id first.

---

## Scoring Algorithm (content-based filtering)

```python
def score(candidate_meta, taste_profile):
    pos_genres, neg_genres, pos_keywords, neg_keywords, pos_countries = taste_profile
    score = 0
    for g in candidate_meta['genres']:
        score += pos_genres.get(g, 0)         # e.g. Comedy=18, Drama=16, Mystery=6
        score -= neg_genres.get(g, 0) * 1.5   # penalty for disliked genre combos
    for k in candidate_meta['keywords']:
        score += pos_keywords.get(k, 0) * 0.5
        score -= neg_keywords.get(k, 0)
    country = candidate_meta.get('country')
    if country:
        score += pos_countries.get(country, 0) * 0.3  # GB/IE bonus
    return score
```

Build `taste_profile` from `watchlist.ratings` WHERE rating IN ('loved','liked') and `disliked`.

---

## Adding a New Viewed Title (full flow)

```python
# 1. Search Overseerr for tmdb_id
# 2. Fetch metadata from /api/v1/movie/{id} or /api/v1/tv/{id}
# 3. Insert into watchlist.titles with all TMDB fields
# 4. Insert into watchlist.ratings with status/rating/notes

# Quick bash version for a known title:
ssh doug@192.168.20.19 "docker exec dk400-postgres psql -U fixer -d dk400 -c \"
WITH t AS (
  INSERT INTO watchlist.titles (title, year, media_type, tmdb_id, genres, keywords, origin_country, original_language, runtime_minutes, tmdb_fetched_at)
  VALUES ('Title', 2024, 'movie', 12345, ARRAY['Comedy'], ARRAY['whodunit'], 'GB', 'en', 90, NOW())
  ON CONFLICT (tmdb_id) DO UPDATE SET title=EXCLUDED.title
  RETURNING id
)
INSERT INTO watchlist.ratings (title_id, viewer, status, rating, notes)
SELECT id, 'both', 'watched', 'liked', 'optional note' FROM t
ON CONFLICT (title_id, viewer) DO UPDATE SET status=EXCLUDED.status, rating=EXCLUDED.rating;
\""
```
