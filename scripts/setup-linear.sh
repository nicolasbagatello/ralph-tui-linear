#!/usr/bin/env bash
#
# Linear Setup Script for ralph-tui
# Guides users through Linear API configuration and stores credentials
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
ENV_FILE=".env"
LINEAR_API_URL="https://api.linear.app/graphql"

print_header() {
    echo ""
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}           Linear Setup for ralph-tui${NC}"
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_step() {
    echo ""
    echo -e "${CYAN}${BOLD}▶ $1${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "  $1"
}

# =============================================================================
# PIC-22: API Setup Guidance
# =============================================================================

show_api_instructions() {
    print_step "Step 1: Get your Linear API Key"

    echo -e "  To create a Linear API key, follow these steps:"
    echo ""
    echo -e "  ${BOLD}1.${NC} Open Linear in your browser:"
    echo -e "     ${CYAN}https://linear.app/settings/api${NC}"
    echo ""
    echo -e "  ${BOLD}2.${NC} Click ${BOLD}\"Create new API key\"${NC}"
    echo ""
    echo -e "  ${BOLD}3.${NC} Give it a label (e.g., \"ralph-tui\")"
    echo ""
    echo -e "  ${BOLD}4.${NC} Copy the generated key (starts with ${BOLD}lin_api_${NC})"
    echo ""
    echo -e "  ${YELLOW}Note: The key is only shown once, so copy it carefully!${NC}"
    echo ""
}

prompt_api_key() {
    local api_key=""

    while true; do
        echo -e "  Paste your Linear API key below (input is hidden):"
        echo -n "  > "
        read -s api_key
        echo ""

        # Validate key format
        if [[ -z "$api_key" ]]; then
            print_error "API key cannot be empty. Please try again."
            continue
        fi

        if [[ ! "$api_key" =~ ^lin_api_ ]]; then
            print_error "Invalid key format. Linear API keys should start with 'lin_api_'"
            echo ""
            read -p "  Try again? (y/n): " retry
            if [[ "$retry" != "y" && "$retry" != "Y" ]]; then
                echo ""
                print_error "Setup cancelled."
                exit 1
            fi
            continue
        fi

        # Key format is valid
        LINEAR_API_KEY="$api_key"
        print_success "API key format validated"
        break
    done
}

# =============================================================================
# PIC-23: Credential Storage
# =============================================================================

detect_shell_profile() {
    local shell_name=$(basename "$SHELL")

    case "$shell_name" in
        zsh)
            SHELL_PROFILE="$HOME/.zshrc"
            ;;
        bash)
            if [[ -f "$HOME/.bash_profile" ]]; then
                SHELL_PROFILE="$HOME/.bash_profile"
            else
                SHELL_PROFILE="$HOME/.bashrc"
            fi
            ;;
        *)
            # Default to .profile for other shells
            SHELL_PROFILE="$HOME/.profile"
            ;;
    esac

    print_info "Detected shell: $shell_name"
    print_info "Profile file: $SHELL_PROFILE"
}

store_api_key_in_profile() {
    print_step "Step 2: Store API Key in Shell Profile"

    detect_shell_profile
    echo ""

    # Check if LINEAR_API_KEY already exists in profile
    if grep -q "^export LINEAR_API_KEY=" "$SHELL_PROFILE" 2>/dev/null; then
        print_warning "LINEAR_API_KEY already exists in $SHELL_PROFILE"
        echo ""
        read -p "  Do you want to update it? (y/n): " update_key

        if [[ "$update_key" == "y" || "$update_key" == "Y" ]]; then
            # Remove existing export line
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' '/^export LINEAR_API_KEY=/d' "$SHELL_PROFILE"
            else
                sed -i '/^export LINEAR_API_KEY=/d' "$SHELL_PROFILE"
            fi
        else
            print_info "Keeping existing API key"
            # Source the existing key for this session
            export LINEAR_API_KEY=$(grep "^export LINEAR_API_KEY=" "$SHELL_PROFILE" | cut -d'=' -f2- | tr -d '"' | tr -d "'")
            return
        fi
    fi

    # Append export statement to profile
    echo "" >> "$SHELL_PROFILE"
    echo "# Linear API Key for ralph-tui" >> "$SHELL_PROFILE"
    echo "export LINEAR_API_KEY=\"$LINEAR_API_KEY\"" >> "$SHELL_PROFILE"

    print_success "API key saved to $SHELL_PROFILE"

    # Export for current session
    export LINEAR_API_KEY="$LINEAR_API_KEY"

    echo ""
    print_warning "To use the API key in other terminals, run:"
    echo -e "  ${CYAN}source $SHELL_PROFILE${NC}"
    echo ""
}

# =============================================================================
# PIC-24: Connection Verification
# =============================================================================

verify_connection() {
    print_step "Step 3: Verify Linear Connection"

    print_info "Testing API connection..."
    echo ""

    # GraphQL query to get current user
    local query='{"query": "{ viewer { id name email } organization { id name } }"}'

    local response=$(curl -s -X POST "$LINEAR_API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: $LINEAR_API_KEY" \
        -d "$query")

    # Check for errors
    if echo "$response" | grep -q '"errors"'; then
        print_error "Failed to connect to Linear API"
        echo ""
        echo "  Response: $response"
        echo ""
        print_info "Please check your API key and try again."
        exit 1
    fi

    # Extract user and org info
    local user_name=$(echo "$response" | jq -r '.data.viewer.name // "Unknown"')
    local user_email=$(echo "$response" | jq -r '.data.viewer.email // "Unknown"')
    local org_name=$(echo "$response" | jq -r '.data.organization.name // "Unknown"')

    print_success "Connected to Linear!"
    echo ""
    print_info "User: $user_name ($user_email)"
    print_info "Organization: $org_name"
}

# =============================================================================
# PIC-25: Team Selection
# =============================================================================

select_team() {
    print_step "Step 4: Select Team"

    # Fetch teams
    local query='{"query": "{ teams { nodes { id name key } } }"}'

    local response=$(curl -s -X POST "$LINEAR_API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: $LINEAR_API_KEY" \
        -d "$query")

    # Parse teams
    local teams=$(echo "$response" | jq -r '.data.teams.nodes')
    local team_count=$(echo "$teams" | jq 'length')

    if [[ "$team_count" -eq 0 ]]; then
        print_error "No teams found. Please create a team in Linear first."
        exit 1
    fi

    if [[ "$team_count" -eq 1 ]]; then
        # Auto-select if only one team
        TEAM_ID=$(echo "$teams" | jq -r '.[0].id')
        TEAM_NAME=$(echo "$teams" | jq -r '.[0].name')
        TEAM_KEY=$(echo "$teams" | jq -r '.[0].key')
        print_info "Auto-selected team: $TEAM_NAME ($TEAM_KEY)"
    else
        # Display team options
        print_info "Available teams:"
        echo ""

        local i=1
        echo "$teams" | jq -r '.[] | "\(.name) (\(.key))"' | while read team; do
            echo "  [$i] $team"
            ((i++))
        done

        echo ""
        read -p "  Select team number: " team_choice

        # Validate choice
        if [[ ! "$team_choice" =~ ^[0-9]+$ ]] || [[ "$team_choice" -lt 1 ]] || [[ "$team_choice" -gt "$team_count" ]]; then
            print_error "Invalid selection"
            exit 1
        fi

        local index=$((team_choice - 1))
        TEAM_ID=$(echo "$teams" | jq -r ".[$index].id")
        TEAM_NAME=$(echo "$teams" | jq -r ".[$index].name")
        TEAM_KEY=$(echo "$teams" | jq -r ".[$index].key")
    fi

    print_success "Selected team: $TEAM_NAME ($TEAM_KEY)"
}

# =============================================================================
# PIC-26: Project Setup
# =============================================================================

setup_project() {
    print_step "Step 5: Setup Project"

    # Fetch existing projects for the team
    local query="{\"query\": \"{ team(id: \\\"$TEAM_ID\\\") { projects { nodes { id name } } } }\"}"

    local response=$(curl -s -X POST "$LINEAR_API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: $LINEAR_API_KEY" \
        -d "$query")

    local projects=$(echo "$response" | jq -r '.data.team.projects.nodes')
    local project_count=$(echo "$projects" | jq 'length')

    print_info "Options:"
    echo ""
    echo "  [1] Create new project: \"ralph-tui Development\""

    if [[ "$project_count" -gt 0 ]]; then
        echo ""
        print_info "Or select existing project:"
        local i=2
        echo "$projects" | jq -r '.[].name' | while read project; do
            echo "  [$i] $project"
            ((i++))
        done
    fi

    echo ""
    read -p "  Select option: " project_choice

    if [[ "$project_choice" == "1" ]]; then
        # Create new project
        local create_query="{\"query\": \"mutation { projectCreate(input: { name: \\\"ralph-tui Development\\\", teamIds: [\\\"$TEAM_ID\\\"] }) { success project { id name } } }\"}"

        local create_response=$(curl -s -X POST "$LINEAR_API_URL" \
            -H "Content-Type: application/json" \
            -H "Authorization: $LINEAR_API_KEY" \
            -d "$create_query")

        if echo "$create_response" | jq -e '.data.projectCreate.success' > /dev/null 2>&1; then
            PROJECT_ID=$(echo "$create_response" | jq -r '.data.projectCreate.project.id')
            PROJECT_NAME=$(echo "$create_response" | jq -r '.data.projectCreate.project.name')
            print_success "Created project: $PROJECT_NAME"
        else
            print_error "Failed to create project"
            echo "  Response: $create_response"
            exit 1
        fi
    else
        # Select existing project
        local index=$((project_choice - 2))
        if [[ "$index" -lt 0 ]] || [[ "$index" -ge "$project_count" ]]; then
            print_error "Invalid selection"
            exit 1
        fi

        PROJECT_ID=$(echo "$projects" | jq -r ".[$index].id")
        PROJECT_NAME=$(echo "$projects" | jq -r ".[$index].name")
        print_success "Selected project: $PROJECT_NAME"
    fi
}

# =============================================================================
# PIC-28: Label Setup
# =============================================================================

setup_label() {
    print_step "Step 6: Setup Label"

    local label_name="ralph-tui"
    local label_color="#6366f1"  # Indigo color

    # Check if label already exists
    local query="{\"query\": \"{ issueLabels(filter: { name: { eq: \\\"$label_name\\\" } }) { nodes { id name } } }\"}"

    local response=$(curl -s -X POST "$LINEAR_API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: $LINEAR_API_KEY" \
        -d "$query")

    local existing_label=$(echo "$response" | jq -r '.data.issueLabels.nodes[0].id // empty')

    if [[ -n "$existing_label" ]]; then
        LABEL_ID="$existing_label"
        print_info "Label \"$label_name\" already exists"
        print_success "Using existing label"
    else
        # Create new label
        local create_query="{\"query\": \"mutation { issueLabelCreate(input: { name: \\\"$label_name\\\", color: \\\"$label_color\\\", teamId: \\\"$TEAM_ID\\\" }) { success issueLabel { id name } } }\"}"

        local create_response=$(curl -s -X POST "$LINEAR_API_URL" \
            -H "Content-Type: application/json" \
            -H "Authorization: $LINEAR_API_KEY" \
            -d "$create_query")

        if echo "$create_response" | jq -e '.data.issueLabelCreate.success' > /dev/null 2>&1; then
            LABEL_ID=$(echo "$create_response" | jq -r '.data.issueLabelCreate.issueLabel.id')
            print_success "Created label: $label_name"
        else
            print_warning "Could not create label (may already exist at workspace level)"
            # Try to find workspace-level label
            LABEL_ID=$(echo "$response" | jq -r '.data.issueLabels.nodes[0].id // "unknown"')
        fi
    fi
}

# =============================================================================
# PIC-27: View Configuration (informational only - views created via Linear UI)
# =============================================================================

show_view_instructions() {
    print_step "Step 7: View Configuration (Optional)"

    print_info "For best experience, create these custom views in Linear:"
    echo ""
    echo "  ${BOLD}1. ralph-tui Board${NC}"
    echo "     Filter: Label = ralph-tui"
    echo "     Group by: Status"
    echo ""
    echo "  ${BOLD}2. ralph-tui Backlog${NC}"
    echo "     Filter: Label = ralph-tui, Status = Backlog"
    echo ""
    echo "  ${BOLD}3. In Progress${NC}"
    echo "     Filter: Label = ralph-tui, Status = In Progress"
    echo ""
    print_info "Views can be created at: ${CYAN}https://linear.app${NC}"
}

# =============================================================================
# PIC-35: Webhook Setup
# =============================================================================

setup_webhook() {
    print_step "Step 8: Webhook Setup (Optional)"

    print_info "Webhooks enable real-time sync when issues change in Linear."
    print_info "This requires a publicly accessible URL (e.g., using ngrok)."
    echo ""
    read -p "  Do you want to configure a webhook? (y/n): " setup_webhook_choice

    if [[ "$setup_webhook_choice" != "y" && "$setup_webhook_choice" != "Y" ]]; then
        print_info "Skipping webhook setup."
        print_info "ralph-tui will use event-driven sync instead."
        WEBHOOK_ID=""
        return
    fi

    echo ""
    print_info "Enter your webhook URL (must be publicly accessible):"
    print_info "For local development, use ngrok: ${CYAN}ngrok http 3000${NC}"
    echo ""
    read -p "  Webhook URL: " webhook_url

    if [[ -z "$webhook_url" ]]; then
        print_warning "No URL provided. Skipping webhook setup."
        WEBHOOK_ID=""
        return
    fi

    # Validate URL format
    if [[ ! "$webhook_url" =~ ^https?:// ]]; then
        print_error "Invalid URL format. Must start with http:// or https://"
        WEBHOOK_ID=""
        return
    fi

    print_info "Creating webhook..."

    # Create webhook via Linear API
    local create_query="{\"query\": \"mutation { webhookCreate(input: { url: \\\"$webhook_url\\\", teamId: \\\"$TEAM_ID\\\", resourceTypes: [\\\"Issue\\\"], allPublicTeams: false, enabled: true, label: \\\"ralph-tui\\\" }) { success webhook { id url enabled } } }\"}"

    local response=$(curl -s -X POST "$LINEAR_API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: $LINEAR_API_KEY" \
        -d "$create_query")

    if echo "$response" | jq -e '.data.webhookCreate.success' > /dev/null 2>&1; then
        WEBHOOK_ID=$(echo "$response" | jq -r '.data.webhookCreate.webhook.id')
        local webhook_enabled=$(echo "$response" | jq -r '.data.webhookCreate.webhook.enabled')
        print_success "Webhook created!"
        print_info "Webhook ID: $WEBHOOK_ID"
        print_info "Enabled: $webhook_enabled"
        echo ""
        print_info "Webhook will trigger on: Issue.create, Issue.update, Issue.delete"
    else
        local error_msg=$(echo "$response" | jq -r '.errors[0].message // "Unknown error"')
        print_error "Failed to create webhook: $error_msg"
        print_info "You can configure webhooks manually in Linear settings."
        WEBHOOK_ID=""
    fi
}

# =============================================================================
# PIC-36: GitHub Integration (PR Linking)
# =============================================================================

show_github_instructions() {
    print_step "Step 9: GitHub Integration (Optional)"

    print_info "Linear can automatically link GitHub PRs to issues."
    echo ""
    echo "  ${BOLD}To enable GitHub integration:${NC}"
    echo ""
    echo "  1. Go to Linear Settings → Integrations → GitHub"
    echo "     ${CYAN}https://linear.app/settings/integrations/github${NC}"
    echo ""
    echo "  2. Click \"Connect GitHub\" and authorize Linear"
    echo ""
    echo "  3. Select the repositories to connect"
    echo ""
    echo "  ${BOLD}Branch Naming Convention:${NC}"
    echo "  Linear will auto-link branches containing the issue ID:"
    echo ""
    echo "     ${CYAN}feature/PIC-123-add-login${NC}"
    echo "     ${CYAN}fix/PIC-456-button-style${NC}"
    echo "     ${CYAN}nicolasbagatello/pic-123-description${NC}"
    echo ""
    echo "  ${BOLD}PR Linking Keywords:${NC}"
    echo "  Include these in PR title or description to link/close issues:"
    echo ""
    echo "     ${CYAN}Fixes PIC-123${NC}      - Links and closes on merge"
    echo "     ${CYAN}Closes PIC-123${NC}     - Links and closes on merge"
    echo "     ${CYAN}Resolves PIC-123${NC}   - Links and closes on merge"
    echo "     ${CYAN}Part of PIC-123${NC}    - Links without auto-close"
    echo ""
    print_info "Once connected, PRs will appear in Linear issue activity."
}

# =============================================================================
# Save Configuration to .env
# =============================================================================

save_env_file() {
    print_step "Saving Configuration"

    cat > "$ENV_FILE" << EOF
# Linear Configuration for ralph-tui
# Generated by setup-linear.sh on $(date)

LINEAR_TEAM_ID=$TEAM_ID
LINEAR_TEAM_NAME=$TEAM_NAME
LINEAR_TEAM_KEY=$TEAM_KEY
LINEAR_PROJECT_ID=$PROJECT_ID
LINEAR_PROJECT_NAME=$PROJECT_NAME
LINEAR_LABEL_ID=$LABEL_ID
EOF

    # Add webhook ID if configured
    if [[ -n "$WEBHOOK_ID" ]]; then
        echo "LINEAR_WEBHOOK_ID=$WEBHOOK_ID" >> "$ENV_FILE"
    fi

    print_success "Configuration saved to $ENV_FILE"
}

# =============================================================================
# Main
# =============================================================================

main() {
    print_header

    # Check dependencies
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed"
        print_info "Install with: brew install jq (macOS) or apt install jq (Linux)"
        exit 1
    fi

    # Check if already configured
    if [[ -n "$LINEAR_API_KEY" ]]; then
        print_info "LINEAR_API_KEY already set in environment"
        read -p "  Do you want to reconfigure? (y/n): " reconfigure
        if [[ "$reconfigure" != "y" && "$reconfigure" != "Y" ]]; then
            print_info "Using existing configuration"
            verify_connection
            select_team
            setup_project
            setup_label
            show_view_instructions
            setup_webhook
            show_github_instructions
            save_env_file
            print_header_complete
            exit 0
        fi
    fi

    # Run setup steps
    show_api_instructions
    prompt_api_key
    store_api_key_in_profile
    verify_connection
    select_team
    setup_project
    setup_label
    show_view_instructions
    setup_webhook
    show_github_instructions
    save_env_file

    print_header_complete
}

print_header_complete() {
    echo ""
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}           Setup Complete!${NC}"
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo ""
    print_info "Configuration saved to:"
    print_info "  - API Key: $SHELL_PROFILE"
    print_info "  - Settings: $ENV_FILE"
    echo ""
    if [[ -n "$WEBHOOK_ID" ]]; then
        print_info "Webhook configured: $WEBHOOK_ID"
        echo ""
    fi
    print_info "Next steps:"
    echo "  1. Source your profile: ${CYAN}source $SHELL_PROFILE${NC}"
    echo "  2. Connect GitHub at: ${CYAN}https://linear.app/settings/integrations/github${NC}"
    echo "  3. Start ralph-tui and select Linear tasks"
    echo ""
}

main "$@"
