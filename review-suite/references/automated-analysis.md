# Automated analysis (SAST) & codebase context (semantic index)

Two machine layers that make every review sharper. Run them **before the agents** so reviewers spend
their reasoning on what tools *can't* find — not on what a linter would have caught for free.

---

## A. Static analysis / SAST — the automated first pass (L0)

Deterministic, fast, cheap, zero LLM tokens. Catches known-vulnerability patterns, common bug
patterns, and convention violations. Run as part of **L0** on every review; feed its findings into
the review as **pre-surfaced candidates** (still adversarially verified — SAST has false positives).

**Semgrep — the default** (fast, multi-language, *no build or database needed*):
- `semgrep --config auto <path>` — community rules auto-selected by language.
- `semgrep --config p/security-audit --config p/secrets --config p/owasp-top-ten <path>` — security.
- Install: `pipx install semgrep` (or `brew install semgrep`). Machine-readable: add `--json`.
- **Custom rules = the feedback loop, mechanized.** Write a repo-specific pattern once (e.g. "never
  `write_text` on `catalog.json` — use `atomic_write_text`") as a `.semgrep.yml` rule, and that
  escaped-bug lesson becomes a **permanent, automated check** on every future run. This is the single
  highest-leverage way to turn a review finding into a gate.

**Deeper / alternates:**
- **CodeQL** — semantic dataflow/taint analysis; needs a build + database, so best in CI on a
  schedule for security-critical code (`github/codeql`).
- **Snyk Code / SonarQube** — commercial SAST + dashboards + dependency scanning.
- **Language-native (cheap L0 wins):** `bandit` (Python sec), `gosec` (Go), `brakeman` (Rails),
  `eslint` + `eslint-plugin-security` (JS/TS), `cargo clippy` (Rust), `ruff` + `mypy` (Python).

**Dependency / supply-chain (part of L0):** `pip-audit`, `npm audit`, `cargo audit`, `osv-scanner`,
Dependabot — flags known-CVE and abandoned deps.

**How it wires in:** L0 runs SAST + linters + type-check + dep-audit *first*; findings become
candidate items (deduped, adversarially verified like any other). A clean SAST + dep-audit run is a
**ship-gate checkbox**. When a bug escapes, add a **custom Semgrep rule** so its whole class is
caught deterministically forever.

---

## B. Semantic index / repo map — cross-file context for seam bugs

Diff-only review misses the highest-value bugs: the ones in the **seams** — a change that's locally
fine but breaks a *caller*, a *contract/schema*, or an assumption *elsewhere*. Whole-codebase-indexing
reviewers catch **~50% more bugs** for exactly this reason. Give your reviewers the same context.

**Tier 1 — repo map (works today, no infrastructure):** build a symbol → definition → callers map +
an import/dependency graph, so for any change a reviewer can answer "who calls this, what contract
does it uphold, what else touches this data."
- `ctags -R` (universal-ctags) → symbol → definition index.
- `ast-grep` / `tree-sitter` → structural queries ("every call site of X", "every writer of file Y").
- `ripgrep` for fast caller/text search; a small script for the import/dependency graph.
- In a multi-agent review, hand each area agent the map and instruct it to **trace every change to
  its callers and the contracts it must uphold** — never judge a diff in isolation.

**Tier 2 — real semantic (embeddings) index (large / multi-service repos):** embed every
function/file into a vector store; retrieve the top-k semantically-related snippets for each change
(callers, similar logic, related contracts) and hand them to the reviewer. This is what the
commercial tools do under the hood.
- Practical build: chunk by function (tree-sitter) → embed with a code-embedding model → store in a
  local vector DB (`sqlite-vec` / FAISS / `lancedb`) → retrieve per change.
- **Re-index incrementally on change** — a stale index = missed context (index staleness is the #1
  failure mode of these systems).
- Worth it when "grep for callers" misses *indirect* relationships: dynamic dispatch, string-keyed
  lookups, reflection, cross-service contracts.

**Rule of thumb:** small/medium repo → **Tier 1** repo map (cheap, immediate, enough). Large or
multi-service → stand up **Tier 2**. Either way the point is identical: **reviewers must see beyond
the diff.**

---

## Wiring both into a review
- **L0:** SAST + linters + type-check + dep-audit run first; clean run is a ship-gate item; failures
  become verified candidates.
- **L3/L4 setup:** build the repo map (or refresh the index) before fan-out; pass it to every area
  agent so seam bugs are in scope.
- **Feedback loop:** every escaped bug → a **regression test** (code memory) **+ a custom Semgrep
  rule** (automated memory) **+ a sharpened review lens** (reviewer memory).
