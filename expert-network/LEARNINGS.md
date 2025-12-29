# Expert Network Learnings

## 2025-12-29 - Self-Registration System

**Context:** User suggested CCs should register their own expertise to keep the registry current.

**Solution:** Created self-registration system:
- `registry.md` - Searchable table with domain keywords, capabilities, handoff paths
- `templates/register.md` - Command template CCs copy to their repo
- CCs update their own entry in registry.md via `/register` command

**Key design decisions:**
- **Decentralized** - No central controller, each expert maintains their entry
- **Keyword searchable** - PM can search by domain keywords to find experts
- **Self-maintaining** - CCs re-register when capabilities change
- **Template-based** - Easy to add registration to any repo with handoff

**Structure:**
```
expert-network/
├── SKILL.md           # How to use the network
├── LEARNINGS.md       # This file
├── registry.md        # The searchable expert table (CC-maintained)
└── templates/
    └── register.md    # Copy to .claude/commands/ to enable /register
```

**Benefits:**
- ✅ Registry stays current automatically
- ✅ CCs know their own capabilities best
- ✅ No PM bottleneck for adding experts
- ✅ Keywords enable PM to find right expert quickly

---

## 2025-12-29 - Pattern Discovery

**Context:** Building c4-expert skill, needed TCP protocol details from signalk-snowmelt plugin.

**Discovery:** PM queued a task in snowmelt's handoff/todo, CC analyzed the codebase and returned comprehensive protocol documentation. This worked seamlessly - the expert had full code access and could provide line numbers, implementation details, gotchas.

**Key insight:** Local CC experts have context that PM can never have (full codebase). Rather than trying to load everything into PM, query the expert and extract knowledge into skills.

**Pattern established:**
1. PM identifies knowledge gap
2. PM searches registry for domain keywords
3. PM queues task to relevant expert's handoff
4. User runs CC against expert repo
5. CC responds with deep domain knowledge
6. PM extracts response into reusable skill reference

**Benefits observed:**
- Snowmelt expert provided 16KB of detailed protocol docs
- Included code locations, message formats, gotchas
- Now captured in c4-expert skill for all future sessions

---

## Improvements Completed

- [x] ~~Experts could have "capabilities" listed~~ → Added to registry.md with domain keywords + capabilities columns
- [x] ~~Consider orchestrator-level expert routing~~ → Registry provides centralized discovery, experts stay distributed

## Future Improvements

- [ ] JSON registry for programmatic queries (registry.json alongside registry.md)
- [ ] Auto-registration on first `/msg` if not in registry
- [ ] Capability versioning (track when expertise was last validated)
- [ ] Expert health check (is handoff queue responsive?)
