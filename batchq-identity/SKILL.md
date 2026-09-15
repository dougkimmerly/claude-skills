---
name: batchq-identity
description: Change which Claude account the batchq WORKER PLANE runs as — the unattended identity on the batch VM that every queue's jobs burn. Use when Doug says "switch the batchq account", "move the queue onto the other account", "the worker is on the wrong account", "batchq hit the spend limit", or when a queue is held with AUTH LAPSE / SPEND LIMIT. This is ONE account for ALL queues — the worker has no per-repo identity — and it is a different decision from an interactive repo switch (that is the `account-switch` skill). Covers the drain-first order, the static-token trap that silently keeps the old account, and proving which account a job ACTUALLY used.
---

# batchq-identity — which account the unattended plane runs as

**This is not `account-switch`.** That skill moves **one repo's interactive**
sessions on the Mac, one at a time, and Doug decides each on its own evidence.
This one moves **the whole worker plane at once**, on another host, and every
repo's queue goes with it. Different host, different blast radius, different
prerequisites — which is why they are separate skills. Each points at the other;
neither should do the other's job.

## The constraint that shapes everything

**The worker runs as ONE identity, for every queue.** Verify rather than trust
this — but as built, `CLAUDE_CONFIG_DIR` appears nowhere in `~/.batchq/engine/`,
so the worker uses the VM's default `~/.claude`:

```bash
ssh 192.168.20.13 'grep -rn CLAUDE_CONFIG_DIR ~/.batchq/engine/ || echo "none — single identity for the whole plane"'
```

So "switch the batchq to a given identity" means **choosing which single account
the whole plane uses**. Per-repo unattended identity does not exist and cannot be
had by configuration alone — it would need the engine to set `CLAUDE_CONFIG_DIR`
per queue, which is a change to batchq's own domain (a verify-first job to the
`batchq` queue, not an edit from here).

Read the current one:

```bash
ssh 192.168.20.13 'python3 -c "
import json,os
a=json.load(open(os.path.expanduser(\"~/.claude.json\"))).get(\"oauthAccount\",{})
print(a.get(\"emailAddress\"), \"|\", a.get(\"organizationName\"))
"'
```

## The trap: two credential sources, and the static one can win

The worker can get its credential from **either**, and they disagree silently:

| Source | Behaviour |
|---|---|
| `~/.claude-oat` → `CLAUDE_CODE_OAUTH_TOKEN` | **static**, injected by the `token.conf` systemd drop-in |
| `~/.claude/.credentials.json` | self-refreshing OAuth, written by `claude setup-token` |

```bash
ssh 192.168.20.13 'ls ~/.config/systemd/user/batchq@.service.d/; \
  cut -d= -f1 ~/.claude-oat 2>/dev/null; \
  ls -la ~/.claude/.credentials.json'
```

**If a static token is present and still valid, logging in as a different
account changes nothing** — the worker keeps using the env token, on the old
account, and every check that reads `~/.claude.json` will tell you the switch
worked. Handle the static token *before* re-logging in, not after.

This is the same shape as the **2026-08-23 plane-wide outage**: a static
`CLAUDE_CODE_OAUTH_TOKEN` expired overnight and every queue's first job died
`401 OAuth access token has expired`, unnoticed until a job happened to fail.
The fix then was a `zz-auth-hotfix.conf` drop-in clearing the `EnvironmentFile`
so the worker falls back to the self-refreshing credential. **Check whether that
drop-in is still present** — if only `token.conf` is there, the static path is
armed again, and that is a finding for the batchq domain, not something to
silently patch from here.

## Order of operations

**1. Drain first.** A credential swap under a running job kills it mid-flight.

```bash
sbmjob -wrk        # nothing running, nothing queued
```

`worker.sh` has a bounded `ANTHROPIC_API_KEY` drain-only retry for a job already
in flight, and holds new work afterwards — that is a safety net for an unplanned
lapse, not a licence to swap under load.

**2. Hold new work** so nothing starts mid-switch, and say what you held.

**3. Settle the static token** — remove or replace `~/.claude-oat`, or confirm
the `EnvironmentFile` is cleared by a drop-in. Whichever, know which source will
win before step 4.

**4. Re-login as the target account** on the VM. Interactive — Doug runs it:

```bash
ssh 192.168.20.13
claude setup-token
```

**5. Prove which account a job ACTUALLY used.** `~/.claude.json` records what was
configured, not what ran — and with a live static token those differ. The probe
must go through the worker's own resolution (`BATCHQ_CLAUDE`, same binary,
same env) or it proves nothing:

```bash
ssh 192.168.20.13 'systemctl --user show-environment | grep -i claude; \
  ~/.local/bin/claude -p "reply with only: ok"'
```

Then submit **one throwaway job** to a low-stakes queue and confirm it completes.
`auth-health-check.sh` runs the same probe on a timer and is the durable version
of this check.

**6. Release the queues** and watch the first real job land.

## Reading a held queue

`auth-health-check.sh` MSGWs every real queue and labels the class — never
conflate them:

- **`SPEND LIMIT`** (429 / `rate_limit_error` / usage-limit) — the account's own
  cap. Nothing is broken; waiting or moving accounts both fix it. Pushed at
  routine priority.
- **`AUTH LAPSE`** (401 / OAuth expired / unattributable failure) — the
  credential itself is broken. Pushed **urgent** because only a re-login fixes
  it. This is the class this skill exists for.

A held queue releases with `sbmjob -release` once the cause is actually gone.

## Before switching at all

Moving the plane moves **every repo's** unattended spend at once, including
repos whose interactive sessions are on a different identity — the two are
independent and that is fine, but say it out loud so nobody assumes a repo's
interactive account governs its jobs. If the trigger was a spend limit, check
whether the cap resets sooner than the switch costs to do and undo.
