# Templates Reference

Project templates and scaffolding for different project types.

## Template Location

**Repository:** `claude-project-framework/templates/`

**Available templates:**
```
templates/
├── signalk/           # SignalK plugin template
├── sensesp/           # SensESP sensor template
├── homelab-service/   # Docker service template
├── webapp/            # Web application template
├── cli/               # CLI tool template
└── generic/           # Generic project template
```

## Creating New Projects

### Using /new-project Skill

```bash
# User runs (in Claude Code):
/new-project my-project signalk
```

This:
1. Creates GitHub repo (PRIVATE by default)
2. Clones locally
3. Copies template files
4. Customizes CLAUDE.md
5. Creates initial commit
6. Pushes to remote

### Project Type Selection

| Type | When to Use |
|------|-------------|
| `signalk` | SignalK plugin development |
| `sensesp` | ESP32 sensor firmware |
| `homelab-service` | Docker-based services |
| `webapp` | React/Vue/other web apps |
| `cli` | Command-line tools |
| `generic` | Everything else |

## Template Structure

Each template contains:

```
template-name/
├── CLAUDE.md.template         # Customizable entry point
├── README.md.template         # Human-readable docs
├── .gitignore                 # Standard exclusions
├── .claude/
│   ├── commands/
│   │   ├── implement.md
│   │   ├── debug.md
│   │   ├── review.md
│   │   └── test.md
│   ├── context/
│   │   ├── architecture.md
│   │   ├── domain.md
│   │   └── patterns.md
│   └── handoff/
│       ├── todo/.gitkeep
│       ├── complete/.gitkeep
│       └── archive/.gitkeep
└── src/                       # Template source code
```

## Template Variables

### CLAUDE.md.template

Variables replaced during project creation:

| Variable | Replaced With | Example |
|----------|---------------|---------|
| `{{PROJECT_NAME}}` | Project name | `my-signalk-plugin` |
| `{{PROJECT_TYPE}}` | Project type | `signalk` |
| `{{ENTITY_ID}}` | Entity identifier | `CC-myPlugin` |
| `{{REPO_OWNER}}` | GitHub username | `dougkimmerly` |
| `{{REPO_NAME}}` | Repository name | `my-signalk-plugin` |
| `{{PROJECT_DIR}}` | Local directory | `/Users/doug/.../my-signalk-plugin` |
| `{{BROKER_URL}}` | Broker URL | `http://localhost:9500` |

**Example template:**
```markdown
# {{PROJECT_NAME}}

{{PROJECT_TYPE}} project using claude-project-framework.

## Entity Info

| Field | Value |
|-------|-------|
| **Entity ID** | `{{ENTITY_ID}}` |
| **Repo** | `{{REPO_OWNER}}/{{REPO_NAME}}` |
| **Directory** | `{{PROJECT_DIR}}` |
| **Broker** | `{{BROKER_URL}}` |
```

**After replacement:**
```markdown
# my-signalk-plugin

signalk project using claude-project-framework.

## Entity Info

| Field | Value |
|-------|-------|
| **Entity ID** | `CC-myPlugin` |
| **Repo** | `dougkimmerly/my-signalk-plugin` |
| **Directory** | `/Users/doug/Programming/dkSRC/my-signalk-plugin` |
| **Broker** | `http://localhost:9500` |
```

## SignalK Template

### Structure

```
templates/signalk/
├── CLAUDE.md.template
├── README.md.template
├── .gitignore
├── package.json.template
├── index.js
└── .claude/...
```

### Key Features

- **package.json** with SignalK dependencies
- **index.js** with plugin lifecycle boilerplate
- **Delta publishing** examples
- **Subscription management** patterns
- **PUT handler** boilerplate

### Quick Reference Section

Includes:
- Common SignalK paths
- SI unit conversions
- Plugin lifecycle hooks
- Data publishing examples

## SensESP Template

### Structure

```
templates/sensesp/
├── CLAUDE.md.template
├── README.md.template
├── .gitignore
├── platformio.ini.template
├── src/
│   └── main.cpp
└── .claude/...
```

### Key Features

- **platformio.ini** with ESP32 configuration
- **main.cpp** with SensESP setup
- **Sensor producers** examples
- **Transform pipeline** patterns
- **SignalK output** configuration

### Board Configurations

Template includes common boards:
- ESP32 DevKit
- ESP32-S3
- ESP32-C3

## Homelab Service Template

### Structure

```
templates/homelab-service/
├── CLAUDE.md.template
├── README.md.template
├── .gitignore
├── Dockerfile
├── .env.example
├── src/
│   └── index.js
└── .claude/...
```

### Key Features

- **Dockerfile** with Node.js base
- **.env.example** for configuration
- **Health check** endpoint
- **Deployment instructions** pointing to machine repo
- **NO compose.yaml** (goes in machine repo)

### CLAUDE.md Deployment Section

```markdown
## Deployment

| Field | Value |
|-------|-------|
| **Target Machine** | Synology (.16) or CasaOS (.19) |
| **Machine Repo** | `homelab-synology` or `homelab-casaos` |
| **Compose Path** | `/volume1/docker/homelab-synology/{{SERVICE_NAME}}/` |
| **Container Name** | `{{SERVICE_NAME}}` |
| **Port** | `3000:3000` |
```

## WebApp Template

### Structure

```
templates/webapp/
├── CLAUDE.md.template
├── README.md.template
├── .gitignore
├── package.json.template
├── src/
│   ├── App.jsx
│   └── index.js
└── .claude/...
```

### Key Features

- **Modern build setup** (Vite or similar)
- **Component structure** examples
- **State management** patterns
- **API integration** patterns

### Framework Options

Template can be customized for:
- React
- Vue
- Svelte
- Vanilla JS

## CLI Template

### Structure

```
templates/cli/
├── CLAUDE.md.template
├── README.md.template
├── .gitignore
├── package.json.template
├── bin/
│   └── cli.js
└── .claude/...
```

### Key Features

- **Commander.js** setup
- **Argument parsing**
- **Subcommands** structure
- **Help text** generation

## Generic Template

### Structure

```
templates/generic/
├── CLAUDE.md.template
├── README.md.template
├── .gitignore
└── .claude/...
```

### Key Features

- **Minimal structure** for any project type
- **Framework files only**
- **No assumptions** about tech stack

## Template Customization

### Adding Project-Specific Content

After creating from template:

1. **Update CLAUDE.md:**
   - Add Quick Reference commands
   - Document key files
   - Add critical rules

2. **Update context files:**
   - `.claude/context/architecture.md` - System design
   - `.claude/context/domain.md` - Business logic
   - `.claude/context/patterns.md` - Code patterns

3. **Update commands:**
   - `.claude/commands/implement.md` - Implementation workflow
   - `.claude/commands/debug.md` - Debugging steps
   - `.claude/commands/test.md` - Testing procedures

### Adding New Templates

To create a new template type:

1. **Create directory:**
   ```bash
   mkdir templates/new-type
   ```

2. **Add template files:**
   - CLAUDE.md.template
   - README.md.template
   - .gitignore
   - Project-specific files

3. **Add to /new-project skill:**
   - Update type list
   - Add template logic

4. **Document in README:**
   - Add to project types table
   - Describe use case

## Hooks in Templates

### Startup Hook

All templates include `.claude/hooks/prompt-submit.sh`:

```bash
#!/bin/bash
# Matches: user types "msg"

if [[ "$USER_MESSAGE" == "msg" ]]; then
  # Register with broker
  curl -X POST http://localhost:9500/register ...

  # Pull latest
  git pull origin main

  # Check for tasks
  ls .claude/handoff/todo/
fi
```

### Other Common Hooks

**Pre-commit hook** (optional):
```bash
#!/bin/bash
# Run tests before commit
npm test
```

**Post-checkout hook** (optional):
```bash
#!/bin/bash
# Install dependencies after checkout
npm install
```

## .gitignore Standard

All templates include:

```gitignore
# Secrets - NEVER commit
.env
*.env
!.env.example

# Dependencies
node_modules/

# Build outputs
dist/
build/

# IDE
.vscode/
.idea/

# OS
.DS_Store

# Project-specific (varies by template)
```

## Best Practices

### When Creating Templates

1. **Keep CLAUDE.md minimal** - Under 150 lines
2. **Use progressive disclosure** - Context files for details
3. **Include working examples** - Not just boilerplate
4. **Document tech stack** - Dependencies, versions
5. **Private by default** - Don't change this

### When Using Templates

1. **Review generated files** - Understand what was created
2. **Customize immediately** - Add project-specific info
3. **Commit initial state** - Before making changes
4. **Update README** - Make it human-readable
5. **Configure CI/CD** - If applicable

## Template Maintenance

### Updating Templates

When standards change:

1. **Update template files** in `claude-project-framework/templates/`
2. **Test with /new-project** to verify
3. **Update documentation** in this file
4. **Consider migration guide** for existing projects

### Versioning

Templates follow framework version:
- Framework v1.0 → Template v1.0
- Breaking changes → Major version bump
- New features → Minor version bump

### Migration Guides

When templates change significantly:

1. **Create migration guide** in `docs/migrations/`
2. **Document breaking changes**
3. **Provide upgrade steps**
4. **Automate where possible**

## Template Validation

### Required Files

Every template MUST have:
- [ ] CLAUDE.md.template
- [ ] README.md.template
- [ ] .gitignore
- [ ] .claude/commands/ (all 4 files)
- [ ] .claude/context/ (at least 3 files)
- [ ] .claude/handoff/ (all 3 directories)

### Required Sections in CLAUDE.md.template

- [ ] Title + Description
- [ ] Quick Reference
- [ ] Key Files
- [ ] Critical Rules
- [ ] Architecture
- [ ] Commands
- [ ] Context Files
- [ ] PM GitHub Access
- [ ] Entity Info

### Validation Script

```bash
# Run from claude-project-framework root
./scripts/validate-template.sh templates/signalk
```

Checks:
- All required files exist
- CLAUDE.md < 150 lines
- No hardcoded values (uses variables)
- .gitignore includes secrets
- Handoff directories exist
