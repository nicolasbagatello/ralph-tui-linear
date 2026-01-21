# Product Requirements Document: Linear Integration for ralph-tui

## Overview

### Product Name
ralph-tui Linear Integration

### Description
A bash setup script and task tracking integration that connects ralph-tui to Linear for issue management. This enables teams to use Linear as the source of truth for tracking ralph-tui development work, replacing JSON-based PRD files with real-time Linear issues.

### Target Repository
https://github.com/subsy/ralph-tui

### Goals
1. Provide a guided setup experience for Linear MCP/API configuration
2. Store credentials securely for agent access
3. Enable two-way synchronization between ralph-tui and Linear
4. Allow ralph-tui to work on Linear issues and update them in real-time

---

## User Stories

### Epic 1: Linear Setup Script

#### US-1.1: API Setup Guidance
**As a** developer setting up ralph-tui  
**I want** step-by-step terminal instructions for Linear API setup  
**So that** I can quickly configure my Linear API token without confusion

**Acceptance Criteria:**
- Script prints clear instructions for navigating to Linear Settings → API
- Instructions explain how to create a personal API key
- Script prompts user to paste the API key
- Key format is validated before proceeding

#### US-1.2: Credential Storage
**As a** developer  
**I want** my Linear API key stored in my shell profile  
**So that** the credentials are globally accessible to ralph-tui and agents

**Acceptance Criteria:**
- Script detects user's shell (bash/zsh)
- Exports `LINEAR_API_KEY` to appropriate profile file (~/.bashrc or ~/.zshrc)
- Prompts user to source the profile or open new terminal
- Validates credential is accessible after setup

#### US-1.3: Connection Verification
**As a** developer  
**I want** the script to verify Linear is connected and working  
**So that** I know the setup was successful before proceeding

**Acceptance Criteria:**
- Script makes test API call to Linear
- Displays authenticated user name and workspace
- Shows clear success/failure message
- On failure, provides troubleshooting guidance

#### US-1.4: Team Selection
**As a** developer  
**I want** to select my Linear team from available options  
**So that** ralph-tui knows which team context to use

**Acceptance Criteria:**
- Script fetches all teams user belongs to
- Auto-selects if only one team exists
- Displays numbered list if multiple teams
- Stores selected team ID in configuration

#### US-1.5: Project Setup
**As a** developer  
**I want** to create or select a Linear project for ralph-tui tracking  
**So that** all ralph-tui work is organized in one place

**Acceptance Criteria:**
- Script lists existing projects in selected team
- Offers option to create new project
- Pre-fills suggested name: "ralph-tui Development"
- Stores selected/created project ID in configuration

#### US-1.6: View Configuration
**As a** developer  
**I want** custom Linear views created for ralph-tui workflow  
**So that** I can easily see task status at a glance

**Acceptance Criteria:**
- Creates "ralph-tui Board" view filtered by ralph-tui label
- Creates "ralph-tui Backlog" view for unstarted tasks
- Creates "In Progress" view for active work
- Views are configured with appropriate columns/grouping

#### US-1.7: Label Setup
**As a** developer  
**I want** a "ralph-tui" label created automatically  
**So that** tasks can be identified and filtered consistently

**Acceptance Criteria:**
- Creates "ralph-tui" label if it doesn't exist
- Uses distinctive color for easy identification
- Label is applied to the configured project

---

### Epic 2: Task Tracking Integration

#### US-2.1: Task Discovery
**As a** ralph-tui user  
**I want** to see all Linear tasks labeled "ralph-tui"  
**So that** I can choose which task to work on

**Acceptance Criteria:**
- ralph-tui fetches tasks with "ralph-tui" label from configured project
- Displays tasks in hierarchy: Project → Epic → Task
- Shows task status, assignee, and priority
- Filters to show only actionable tasks (not Done/Cancelled)

#### US-2.2: Task Selection and Claiming
**As a** ralph-tui user  
**I want** to claim a task when I start working on it  
**So that** others know it's being actively worked

**Acceptance Criteria:**
- Selecting a task assigns it to configured user
- Task state changes to "In Progress"
- "ralph-tui" label is added if not present
- Linear is updated immediately (sync on task start)

#### US-2.3: Real-time Progress Updates
**As a** ralph-tui user  
**I want** my progress reflected in Linear as I work  
**So that** the team has visibility into active work

**Acceptance Criteria:**
- Task description/comments can be updated during work
- State changes sync to Linear immediately
- Completion moves task to "Done" state
- All syncs happen on task start/complete events

#### US-2.4: Epic to Task Navigation
**As a** ralph-tui user  
**I want** to navigate from Epics down to individual tasks  
**So that** I can work through features systematically

**Acceptance Criteria:**
- Displays Epic hierarchy (Project → Epic → Task)
- Can expand/collapse Epics to see child tasks
- Shows completion progress on Epics
- Can select any level to view details

#### US-2.5: Two-Way Sync
**As a** ralph-tui user  
**I want** changes made in Linear to be reflected in ralph-tui  
**So that** I always see the current state

**Acceptance Criteria:**
- Changes made in Linear appear in ralph-tui on next sync
- Syncs triggered on task start and task complete
- Sync includes: title, description, state, assignee, labels

#### US-2.6: Conflict Resolution
**As a** ralph-tui user  
**I want** to be prompted when conflicts occur  
**So that** I can decide how to resolve them

**Acceptance Criteria:**
- Detects when Linear issue changed while ralph-tui was working
- Displays both versions (Linear vs local)
- Prompts user to choose: keep Linear, keep local, or merge
- Applies user's choice and continues

---

### Epic 3: GitHub Integration

#### US-3.1: Webhook Setup
**As a** developer  
**I want** Linear webhooks configured for real-time updates  
**So that** external changes trigger immediate sync

**Acceptance Criteria:**
- Setup script offers to configure Linear webhook
- Webhook points to ralph-tui endpoint (if available)
- Webhook triggers on issue create/update/delete
- Falls back to event-driven sync if webhook unavailable

#### US-3.2: PR Linking
**As a** developer  
**I want** GitHub PRs automatically linked to Linear issues  
**So that** I can track code changes against tasks

**Acceptance Criteria:**
- Setup script configures Linear GitHub integration
- PRs mentioning Linear issue ID are auto-linked
- Branch names with issue ID are recognized
- Links appear in Linear issue activity

---

## Technical Requirements

### Setup Script (`setup-linear.sh`)

```
Location: scripts/setup-linear.sh
Type: Bash shell script
Dependencies: curl, jq
```

**Configuration Output:**
- Adds `export LINEAR_API_KEY=<key>` to shell profile
- Creates `.env` file with:
  ```
  LINEAR_API_KEY=<key>
  LINEAR_TEAM_ID=<team_id>
  LINEAR_PROJECT_ID=<project_id>
  LINEAR_LABEL_ID=<ralph_tui_label_id>
  ```

### Linear State Mapping

| Linear State | ralph-tui State | Trigger |
|--------------|-----------------|---------|
| Backlog | Available | Default for new tasks |
| Todo | Ready | Task prioritized |
| In Progress | Working | Task claimed by ralph-tui |
| Done | Completed | Task marked complete |
| Cancelled | Skipped | Task abandoned |

### API Endpoints Used

- `GET /teams` - List user's teams
- `GET /projects` - List team projects
- `POST /projects` - Create project
- `GET /issues` - Fetch tasks by label
- `PATCH /issues/:id` - Update task
- `POST /labels` - Create ralph-tui label
- `GET /users/me` - Verify authentication
- `POST /webhooks` - Configure webhook
- `POST /integrations/github` - GitHub integration

### Sync Triggers

1. **On Task Start**: Full sync of selected task
2. **On Task Complete**: Update state, sync final changes
3. **On Conflict**: Prompt user for resolution

---

## Non-Functional Requirements

### Security
- API keys stored in shell profile (user-readable only)
- No keys committed to repository
- Keys validated before storage

### Usability
- Setup completes in under 5 minutes
- Clear error messages with remediation steps
- Idempotent: can re-run setup safely

### Compatibility
- Supports bash and zsh shells
- Works on macOS and Linux
- Linear API v2 compatibility

---

## Out of Scope (v1)

- OAuth authentication flow (uses personal API key)
- Multiple workspace support
- Offline mode / local caching
- Custom field mapping
- Time tracking integration
- Automated PR creation

---

## Success Metrics

1. Setup script completes without errors on first run
2. Credentials accessible to ralph-tui after setup
3. Tasks sync within 2 seconds of trigger
4. Conflict resolution preserves user intent

---

## Dependencies

- Linear account with API access
- GitHub repository connected to Linear (for Epic 3)
- ralph-tui installed and configured