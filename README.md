# ralph-tui-linear

Linear tracker plugin for [ralph-tui](https://github.com/subsy/ralph-tui) - enables two-way synchronization between ralph-tui and Linear for real-time task tracking.

> **New to ralph-tui?** Check out the [Quick Start Guide](https://ralph-tui.com/docs/getting-started/quick-start) to get started.

## Features

- **Task Discovery**: Fetch and display Linear issues labeled with `ralph-tui`
- **Hierarchical Display**: Navigate Project → Epic → Task structure
- **Task Claiming**: Automatically assign tasks and update status when starting work
- **Two-Way Sync**: Pull changes from Linear and push local updates
- **Conflict Resolution**: Detect and resolve sync conflicts
- **Real-time Updates**: Sync on task start/complete events
- **Webhook Support**: Optional webhook configuration for real-time Linear updates
- **GitHub Integration**: Auto-link PRs and branches to Linear issues

## Prerequisites

- **[ralph-tui](https://github.com/subsy/ralph-tui)** installed - See the [Quick Start Guide](https://ralph-tui.com/docs/getting-started/quick-start) for installation instructions
- Node.js 18+ or [Bun](https://bun.sh)
- A [Linear](https://linear.app) account with API access
- `curl` and `jq` (for the setup script)

## Installation

### One-Line Install (Recommended)

Download and run the automated installer:

```bash
# Using curl
curl -fsSL https://raw.githubusercontent.com/subsy/ralph-tui-linear/main/scripts/install.sh | bash

# Or using wget
wget -qO- https://raw.githubusercontent.com/subsy/ralph-tui-linear/main/scripts/install.sh | bash
```

The installer will:
1. Check for ralph-tui (and offer to install if missing)
2. Verify dependencies (curl, jq)
3. Install the ralph-tui-linear plugin
4. Run the Linear configuration wizard

### Manual Installation

```bash
# Install globally with npm
npm install -g ralph-tui-linear

# Or with bun
bun add -g ralph-tui-linear

# Or with yarn
yarn global add ralph-tui-linear
```

The plugin automatically installs to `~/.config/ralph-tui/plugins/trackers/linear.js` during postinstall.

### Verifying Installation

After installation, verify the plugin is installed:

```bash
# Check if plugin exists
ls ~/.config/ralph-tui/plugins/trackers/linear.js

# Check if setup script is available
which ralph-tui-linear-setup
```

## Quick Start

```bash
# 1. Run the interactive setup
ralph-tui-linear-setup

# 2. Source your shell profile (to load the API key)
source ~/.zshrc  # or ~/.bashrc

# 3. Label your Linear issues with "ralph-tui"

# 4. Start ralph-tui in your project
ralph-tui
```

## Setup Guide

### Option 1: Interactive Setup (Recommended)

Run the setup script:

```bash
ralph-tui-linear-setup
```

The script guides you through 9 steps:

| Step | Description |
|------|-------------|
| 1 | **API Key Setup** - Instructions to create a Linear API key |
| 2 | **Credential Storage** - Saves API key to shell profile (~/.zshrc or ~/.bashrc) |
| 3 | **Connection Verification** - Tests the API connection |
| 4 | **Team Selection** - Choose your Linear team |
| 5 | **Project Setup** - Create or select a project |
| 6 | **Label Setup** - Creates the `ralph-tui` label |
| 7 | **View Configuration** - Instructions for custom Linear views |
| 8 | **Webhook Setup** (Optional) - Configure webhooks for real-time sync |
| 9 | **GitHub Integration** - Instructions for PR/branch linking |

#### Getting Your Linear API Key

1. Go to [Linear API Settings](https://linear.app/settings/api)
2. Click **"Create new API key"**
3. Label it (e.g., "ralph-tui")
4. Copy the key (starts with `lin_api_`)

> **Note**: The key is only shown once!

### Option 2: Environment Variables

Set these environment variables manually:

```bash
# Required
export LINEAR_API_KEY="lin_api_..."

# Optional (can also be set via .env file)
export LINEAR_TEAM_ID="your-team-id"
export LINEAR_PROJECT_ID="your-project-id"
export LINEAR_LABEL_NAME="ralph-tui"
```

### Option 3: Config File

Create `.ralph-tui/config.toml` in your project:

```toml
tracker = "linear"

[trackerOptions]
projectId = "your-project-id"
teamId = "your-team-id"
labelName = "ralph-tui"
```

### Option 4: .env File

The setup script creates a `.env` file with your configuration:

```bash
# Linear Configuration for ralph-tui
LINEAR_TEAM_ID=abc123
LINEAR_TEAM_NAME=MyTeam
LINEAR_TEAM_KEY=MT
LINEAR_PROJECT_ID=def456
LINEAR_PROJECT_NAME=My Project
LINEAR_LABEL_ID=ghi789
LINEAR_WEBHOOK_ID=jkl012  # If webhook configured
```

## Usage

### 1. Label Your Issues

Add the `ralph-tui` label to any Linear issues you want to track:

- In Linear, open an issue
- Add the label `ralph-tui`
- The issue will now appear in ralph-tui

### 2. Start ralph-tui

```bash
cd your-project
ralph-tui
```

### 3. Work on Tasks

When you select a task, ralph-tui will:
- Assign the task to you
- Set status to "In Progress"
- Sync changes back to Linear on completion

## GitHub Integration

### Connecting GitHub to Linear

1. Go to [Linear GitHub Integration](https://linear.app/settings/integrations/github)
2. Click **"Connect GitHub"**
3. Authorize Linear to access your repositories
4. Select repositories to connect

### Branch Naming

Linear auto-links branches containing the issue ID:

```bash
# These formats are recognized:
feature/PIC-123-add-login
fix/PIC-456-button-style
nicolasbagatello/pic-123-description
```

### PR Linking Keywords

Include these in your PR title or description:

| Keyword | Effect |
|---------|--------|
| `Fixes PIC-123` | Links and closes on merge |
| `Closes PIC-123` | Links and closes on merge |
| `Resolves PIC-123` | Links and closes on merge |
| `Part of PIC-123` | Links without auto-close |

## Webhook Configuration

Webhooks enable real-time updates when issues change in Linear.

### Requirements

- A publicly accessible URL (e.g., using [ngrok](https://ngrok.com))
- The setup script will create the webhook for you

### Manual Webhook Setup

If you need to configure webhooks manually:

1. Go to [Linear Webhook Settings](https://linear.app/settings/api#webhooks)
2. Create a webhook with:
   - **URL**: Your public endpoint
   - **Resource types**: Issue
   - **Events**: create, update, delete

### Without Webhooks

If you skip webhook setup, ralph-tui uses event-driven sync instead (syncs on task start/complete).

## State Mapping

| Linear State | ralph-tui State | Trigger |
|-------------|-----------------|---------|
| Backlog | `open` | Default |
| Todo | `open` | Prioritized |
| In Progress | `in_progress` | Claimed |
| Done | `completed` | Finished |
| Cancelled | `cancelled` | Abandoned |

## Configuration Reference

| Option | Environment Variable | Description | Default |
|--------|---------------------|-------------|---------|
| `apiKey` | `LINEAR_API_KEY` | Linear API key | Required |
| `teamId` | `LINEAR_TEAM_ID` | Team ID for workflow states | Auto-detected |
| `projectId` | `LINEAR_PROJECT_ID` | Project to fetch issues from | Optional |
| `labelName` | `LINEAR_LABEL_NAME` | Label to filter issues | `ralph-tui` |

## Architecture

```
~/.config/ralph-tui/
└── plugins/
    └── trackers/
        └── linear.js          # Main plugin (auto-installed)

Your Project/
├── .ralph-tui/
│   └── config.toml            # Project config (optional)
└── .env                       # Linear credentials (from setup)
```

### How It Works

1. **Plugin Discovery**: ralph-tui discovers the plugin from `~/.config/ralph-tui/plugins/trackers/linear.js`

2. **Initialization**: Plugin connects to Linear API and caches workflow states

3. **Task Fetching**: Queries Linear for issues in the configured project with the specified label

4. **Claiming**: When you select a task:
   - Assigns you as the owner
   - Updates state to "In Progress"
   - Adds `ralph-tui` label if not present

5. **Sync**: On task start/complete:
   - Fetches latest from Linear
   - Detects conflicts
   - Prompts for resolution if needed

## Development

```bash
# Clone the repository
git clone https://github.com/subsy/ralph-tui-linear.git
cd ralph-tui-linear

# Install dependencies
bun install

# Build the plugin
bun run build

# Type check
bun run typecheck

# Run tests
bun test

# Manually install the plugin (after build)
node scripts/postinstall.js
```

### Project Structure

```
ralph-tui-linear/
├── src/
│   ├── index.ts       # Main plugin entry point
│   ├── client.ts      # Linear API client
│   ├── types.ts       # TypeScript types
│   └── template.hbs   # Prompt template
├── scripts/
│   ├── install.sh         # Automated installer (checks ralph-tui, installs plugin, runs setup)
│   ├── setup-linear.sh    # Interactive Linear configuration wizard
│   └── postinstall.js     # Auto-install to ralph-tui plugins (runs on npm install)
├── dist/              # Built output
├── package.json
└── tsconfig.json
```

### Available Scripts

| Command | Description |
|---------|-------------|
| `ralph-tui-linear-install` | Full automated installation |
| `ralph-tui-linear-setup` | Configure Linear API, team, project |
| `bun run build` | Build the plugin |
| `bun run typecheck` | Run TypeScript type checking |
| `bun test` | Run tests |

## Troubleshooting

### "LINEAR_API_KEY not set"

Run the setup script or set the environment variable:

```bash
ralph-tui-linear-setup
# or
export LINEAR_API_KEY="lin_api_..."
```

### "Plugin not found"

Ensure the plugin is installed in the correct location:

```bash
ls ~/.config/ralph-tui/plugins/trackers/linear.js
```

If missing, reinstall:

```bash
npm install -g ralph-tui-linear
```

### "Failed to connect to Linear API"

1. Verify your API key is correct
2. Check your internet connection
3. Ensure the key has appropriate permissions

### Issues not appearing

1. Make sure issues have the `ralph-tui` label
2. Verify the project ID matches your Linear project
3. Check that issues are not archived

## License

MIT
