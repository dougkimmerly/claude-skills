# Expert Network Learnings

## 2025-12-29 - Pattern Discovery

**Context:** Building c4-expert skill, needed TCP protocol details from signalk-snowmelt plugin.

**Discovery:** PM queued a task in snowmelt's handoff/todo, CC analyzed the codebase and returned comprehensive protocol documentation. This worked seamlessly - the expert had full code access and could provide line numbers, implementation details, gotchas.

**Key insight:** Local CC experts have context that PM can never have (full codebase). Rather than trying to load everything into PM, query the expert and extract knowledge into skills.

**Pattern established:**
1. PM identifies knowledge gap
2. PM queues task to relevant expert's handoff
3. User runs CC against expert repo
4. CC responds with deep domain knowledge
5. PM extracts response into reusable skill reference

**Benefits observed:**
- Snowmelt expert provided 16KB of detailed protocol docs
- Included code locations, message formats, gotchas
- Now captured in c4-expert skill for all future sessions

## Future Improvements

- [ ] CC could auto-discover expert-network skill and check for available experts
- [ ] Experts could have "capabilities" listed (what questions they can answer)
- [ ] Consider orchestrator-level expert routing (signalk55 hub pattern)
