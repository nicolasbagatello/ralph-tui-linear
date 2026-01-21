# ralph-tui-linear

Linear tracker plugin for [ralph-tui](https://github.com/subsy/ralph-tui) - two-way sync with Linear issues.

## Installation

```bash
curl -fsSL https://raw.githubusercontent.com/nicolasbagatello/ralph-tui-linear/main/scripts/install.sh | bash
```

Or manually: `npm install -g ralph-tui-linear`

## Quick Start

```bash
# 1. Global setup (one-time) - configures API key
ralph-tui-linear-setup
source ~/.zshrc

# 2. Per-repo setup - links repo to Linear project
cd your-project
ralph-tui-linear-init

# 3. Add "ralph-tui" label to Linear issues you want to track

# 4. Start working
ralph-tui
```

## Getting Your API Key

1. Go to [Linear API Settings](https://linear.app/settings/api)
2. Click "Create new API key"
3. Copy the key (starts with `lin_api_`)

## Commands

| Command | Description |
|---------|-------------|
| `ralph-tui-linear-setup` | Configure API key (global, one-time) |
| `ralph-tui-linear-init` | Link repo to Linear project |
| `ralph-tui-linear-uninstall` | Remove plugin and cleanup |

## Configuration

The `init` command creates `.ralph-tui/config.toml` in your project:

```toml
tracker = "linear"

[trackerOptions]
projectId = "abc123"
teamId = "team-xyz"
labelName = "ralph-tui"
```

Or use environment variables:

```bash
export LINEAR_API_KEY="lin_api_..."
export LINEAR_PROJECT_ID="your-project-id"
export LINEAR_TEAM_ID="your-team-id"
```

## GitHub Integration

Connect GitHub to Linear at [Linear Settings](https://linear.app/settings/integrations/github).

Branch names with issue IDs auto-link: `feature/ENG-123-add-feature`

PR keywords: `Fixes ENG-123`, `Closes ENG-123`, `Part of ENG-123`

## Troubleshooting

**LINEAR_API_KEY not set**: Run `ralph-tui-linear-setup`

**Plugin not found**: Run `npm install -g ralph-tui-linear`

**Issues not appearing**: Ensure issues have the `ralph-tui` label

## Development

```bash
git clone https://github.com/nicolasbagatello/ralph-tui-linear.git
cd ralph-tui-linear
bun install
bun run build
```

## License

MIT
