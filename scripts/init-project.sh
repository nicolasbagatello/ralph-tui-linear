#!/usr/bin/env bash
#
# Initialize Linear project link for a git repository
# Links a local repository to a Linear project for ralph-tui tracking
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
LINEAR_API_URL="https://api.linear.app/graphql"
DEFAULT_LABEL_NAME="ralph-tui"
DEFAULT_LABEL_COLOR="#6366f1"

# Variables to be populated
REPO_ROOT=""
REPO_URL=""
REPO_NAME=""
TEAM_ID=""
TEAM_NAME=""
TEAM_KEY=""
PROJECT_ID=""
PROJECT_NAME=""
LABEL_ID=""
LABEL_NAME="$DEFAULT_LABEL_NAME"

print_header() {
    echo ""
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}       Initialize Linear Project Link${NC}"
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
# Check Prerequisites
# =============================================================================

check_prerequisites() {
    print_step "Step 1: Checking prerequisites"

    # Check for curl
    if ! command -v curl &> /dev/null; then
        print_error "curl is required but not installed"
        exit 1
    fi
    print_success "curl is available"

    # Check for jq
    if ! command -v jq &> /dev/null; then
        print_error "jq is required but not installed"
        print_info "Install with: ${CYAN}brew install jq${NC} (macOS) or ${CYAN}apt install jq${NC} (Linux)"
        exit 1
    fi
    print_success "jq is available"

    # Check for LINEAR_API_KEY
    if [[ -z "$LINEAR_API_KEY" ]]; then
        print_warning "LINEAR_API_KEY not found in environment"
        echo ""
        print_info "You need to run the setup script first to configure your API key."
        echo ""
        read -p "  Run ralph-tui-linear-setup now? (y/n): " run_setup

        if [[ "$run_setup" == "y" || "$run_setup" == "Y" ]]; then
            if command -v ralph-tui-linear-setup &> /dev/null; then
                ralph-tui-linear-setup
                # Source shell profile to get the API key
                if [[ -f "$HOME/.zshrc" ]]; then
                    source "$HOME/.zshrc"
                elif [[ -f "$HOME/.bashrc" ]]; then
                    source "$HOME/.bashrc"
                fi
            else
                print_error "ralph-tui-linear-setup not found"
                print_info "Install ralph-tui-linear globally first"
                exit 1
            fi
        else
            print_error "LINEAR_API_KEY is required"
            print_info "Run: ${CYAN}ralph-tui-linear-setup${NC}"
            exit 1
        fi
    fi

    # Verify API key format
    if [[ ! "$LINEAR_API_KEY" =~ ^lin_api_ ]]; then
        print_warning "LINEAR_API_KEY doesn't start with 'lin_api_' - it may be invalid"
    fi

    print_success "LINEAR_API_KEY found"
}

# =============================================================================
# Detect Git Repository
# =============================================================================

detect_git_repo() {
    print_step "Step 2: Detecting git repository"

    # Check if we're in a git repository
    if ! git rev-parse --is-inside-work-tree &> /dev/null 2>&1; then
        print_error "Not inside a git repository"
        print_info "Please run this command from within a git repository"
        exit 1
    fi

    # Get repository root
    REPO_ROOT=$(git rev-parse --show-toplevel)
    print_success "Git repository detected"
    print_info "Root: ${CYAN}$REPO_ROOT${NC}"

    # Get remote URL
    REPO_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")

    # Extract repository name
    if [[ -n "$REPO_URL" ]]; then
        # Remove .git suffix and extract name
        REPO_NAME=$(basename -s .git "$REPO_URL")
        print_info "Remote: ${CYAN}$REPO_URL${NC}"
    else
        # Fallback to directory name
        REPO_NAME=$(basename "$REPO_ROOT")
        print_warning "No remote URL found, using directory name"
    fi

    print_info "Repository name: ${CYAN}$REPO_NAME${NC}"

    # Check for existing config
    local config_file="$REPO_ROOT/.ralph-tui/config.toml"
    if [[ -f "$config_file" ]]; then
        print_warning "Existing configuration found at $config_file"
        read -p "  Overwrite existing configuration? (y/n): " overwrite
        if [[ "$overwrite" != "y" && "$overwrite" != "Y" ]]; then
            print_info "Keeping existing configuration"
            exit 0
        fi
    fi
}

# =============================================================================
# Verify API Connection
# =============================================================================

verify_connection() {
    print_step "Step 3: Verifying Linear API connection"

    local query='{"query": "{ viewer { id name email } organization { id name } }"}'

    local response=$(curl -s -X POST "$LINEAR_API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: $LINEAR_API_KEY" \
        -d "$query")

    local viewer_name=$(echo "$response" | jq -r '.data.viewer.name // empty')
    local org_name=$(echo "$response" | jq -r '.data.organization.name // empty')

    if [[ -z "$viewer_name" ]]; then
        print_error "Failed to connect to Linear API"
        print_info "Please check your API key"
        exit 1
    fi

    print_success "Connected as: $viewer_name"
    print_info "Organization: $org_name"
}

# =============================================================================
# Select Team
# =============================================================================

select_team() {
    print_step "Step 4: Select Linear team"

    # Fetch teams
    local query='{"query": "{ teams { nodes { id name key } } }"}'

    local response=$(curl -s -X POST "$LINEAR_API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: $LINEAR_API_KEY" \
        -d "$query")

    local teams=$(echo "$response" | jq -r '.data.teams.nodes')
    local team_count=$(echo "$teams" | jq 'length')

    if [[ "$team_count" -eq 0 ]]; then
        print_error "No teams found in your Linear workspace"
        exit 1
    fi

    if [[ "$team_count" -eq 1 ]]; then
        # Auto-select single team
        TEAM_ID=$(echo "$teams" | jq -r '.[0].id')
        TEAM_NAME=$(echo "$teams" | jq -r '.[0].name')
        TEAM_KEY=$(echo "$teams" | jq -r '.[0].key')
        print_success "Auto-selected team: $TEAM_NAME ($TEAM_KEY)"
    else
        # Show team selection menu
        print_info "Available teams:"
        echo ""

        local i=1
        while read -r team; do
            local name=$(echo "$team" | jq -r '.name')
            local key=$(echo "$team" | jq -r '.key')
            echo "  [$i] $name ($key)"
            ((i++))
        done < <(echo "$teams" | jq -c '.[]')

        echo ""
        read -p "  Select team number: " team_num

        # Validate selection
        if [[ ! "$team_num" =~ ^[0-9]+$ ]] || [[ "$team_num" -lt 1 ]] || [[ "$team_num" -gt "$team_count" ]]; then
            print_error "Invalid selection"
            exit 1
        fi

        local idx=$((team_num - 1))
        TEAM_ID=$(echo "$teams" | jq -r ".[$idx].id")
        TEAM_NAME=$(echo "$teams" | jq -r ".[$idx].name")
        TEAM_KEY=$(echo "$teams" | jq -r ".[$idx].key")

        print_success "Selected team: $TEAM_NAME ($TEAM_KEY)"
    fi
}

# =============================================================================
# Select or Create Project
# =============================================================================

select_project_name() {
    print_step "Step 5: Configure Linear project"

    # Generate suggested name from repo name
    # Convert kebab-case/snake_case to Title Case
    local suggested_name=$(echo "$REPO_NAME" | sed 's/[-_]/ /g' | awk '{for(i=1;i<=NF;i++)$i=toupper(substr($i,1,1))tolower(substr($i,2))}1')

    print_info "Suggested project name based on repository: ${CYAN}$suggested_name${NC}"
    echo ""
    read -p "  Project name [$suggested_name]: " user_name

    PROJECT_NAME="${user_name:-$suggested_name}"
}

find_or_create_project() {
    print_step "Step 6: Setting up Linear project"

    # Search for existing project with this name
    local search_query=$(cat <<EOF
{"query": "{ team(id: \"$TEAM_ID\") { projects(filter: { name: { containsIgnoreCase: \"$PROJECT_NAME\" } }) { nodes { id name state } } } }"}
EOF
)

    local response=$(curl -s -X POST "$LINEAR_API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: $LINEAR_API_KEY" \
        -d "$search_query")

    local projects=$(echo "$response" | jq -r '.data.team.projects.nodes')
    local project_count=$(echo "$projects" | jq 'length')

    # Check for exact match
    local exact_match=$(echo "$projects" | jq -r --arg name "$PROJECT_NAME" '.[] | select(.name == $name) | .id' | head -1)

    if [[ -n "$exact_match" ]]; then
        print_info "Found existing project: ${CYAN}$PROJECT_NAME${NC}"
        read -p "  Use this existing project? (y/n): " use_existing

        if [[ "$use_existing" == "y" || "$use_existing" == "Y" ]]; then
            PROJECT_ID="$exact_match"
            print_success "Using existing project: $PROJECT_NAME"
            return
        fi

        # User wants to create new - append suffix
        print_info "Creating new project with different name..."
        read -p "  Enter new project name: " new_name
        PROJECT_NAME="$new_name"
    elif [[ "$project_count" -gt 0 ]]; then
        # Show similar projects
        print_info "Similar projects found:"
        echo ""
        echo "$projects" | jq -r '.[] | "  - \(.name)"'
        echo ""
        read -p "  Create new project \"$PROJECT_NAME\"? (y/n): " create_new

        if [[ "$create_new" != "y" && "$create_new" != "Y" ]]; then
            print_info "Select from existing projects:"
            local i=1
            while read -r proj; do
                local name=$(echo "$proj" | jq -r '.name')
                echo "  [$i] $name"
                ((i++))
            done < <(echo "$projects" | jq -c '.[]')

            read -p "  Select project number: " proj_num
            local idx=$((proj_num - 1))
            PROJECT_ID=$(echo "$projects" | jq -r ".[$idx].id")
            PROJECT_NAME=$(echo "$projects" | jq -r ".[$idx].name")
            print_success "Selected project: $PROJECT_NAME"
            return
        fi
    fi

    # Create new project
    print_info "Creating new project: ${CYAN}$PROJECT_NAME${NC}"

    local create_query=$(cat <<EOF
{"query": "mutation { projectCreate(input: { name: \"$PROJECT_NAME\", teamIds: [\"$TEAM_ID\"] }) { success project { id name } } }"}
EOF
)

    response=$(curl -s -X POST "$LINEAR_API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: $LINEAR_API_KEY" \
        -d "$create_query")

    local success=$(echo "$response" | jq -r '.data.projectCreate.success')

    if [[ "$success" == "true" ]]; then
        PROJECT_ID=$(echo "$response" | jq -r '.data.projectCreate.project.id')
        print_success "Created project: $PROJECT_NAME"
    else
        local error=$(echo "$response" | jq -r '.errors[0].message // "Unknown error"')
        print_error "Failed to create project: $error"
        exit 1
    fi
}

# =============================================================================
# Setup Label
# =============================================================================

setup_label() {
    print_step "Step 7: Setting up label"

    print_info "Label name: ${CYAN}$LABEL_NAME${NC}"

    # Check if label exists
    local check_query=$(cat <<EOF
{"query": "{ issueLabels(filter: { name: { eq: \"$LABEL_NAME\" } }) { nodes { id name } } }"}
EOF
)

    local response=$(curl -s -X POST "$LINEAR_API_URL" \
        -H "Content-Type: application/json" \
        -H "Authorization: $LINEAR_API_KEY" \
        -d "$check_query")

    local existing_label=$(echo "$response" | jq -r '.data.issueLabels.nodes[0].id // empty')

    if [[ -n "$existing_label" ]]; then
        LABEL_ID="$existing_label"
        print_success "Label already exists: $LABEL_NAME"
    else
        # Create label
        print_info "Creating label..."

        local create_query=$(cat <<EOF
{"query": "mutation { issueLabelCreate(input: { name: \"$LABEL_NAME\", color: \"$DEFAULT_LABEL_COLOR\", teamId: \"$TEAM_ID\" }) { success issueLabel { id name } } }"}
EOF
)

        response=$(curl -s -X POST "$LINEAR_API_URL" \
            -H "Content-Type: application/json" \
            -H "Authorization: $LINEAR_API_KEY" \
            -d "$create_query")

        local success=$(echo "$response" | jq -r '.data.issueLabelCreate.success')

        if [[ "$success" == "true" ]]; then
            LABEL_ID=$(echo "$response" | jq -r '.data.issueLabelCreate.issueLabel.id')
            print_success "Created label: $LABEL_NAME"
        else
            print_warning "Could not create label (may require permissions)"
            print_info "You can create it manually in Linear"
        fi
    fi
}

# =============================================================================
# Write Configuration
# =============================================================================

write_config() {
    print_step "Step 8: Saving configuration"

    local config_dir="$REPO_ROOT/.ralph-tui"
    local config_file="$config_dir/config.toml"

    # Create directory
    mkdir -p "$config_dir"

    # Get current timestamp
    local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    # Write config file
    cat > "$config_file" << EOF
# Ralph TUI Configuration
# Generated by init-project.sh on $(date)
# Repository: $REPO_NAME

configVersion = "2.0"
tracker = "linear"
agent = "claude"
maxIterations = 10
autoCommit = true

[trackerOptions]
projectId = "$PROJECT_ID"
projectName = "$PROJECT_NAME"
teamId = "$TEAM_ID"
teamKey = "$TEAM_KEY"
labelName = "$LABEL_NAME"

[trackerOptions.repository]
url = "$REPO_URL"
name = "$REPO_NAME"
linkedAt = "$timestamp"
EOF

    print_success "Configuration saved to: $config_file"

    # Optionally add to .gitignore
    local gitignore="$REPO_ROOT/.gitignore"
    if [[ -f "$gitignore" ]]; then
        if ! grep -q "^\.ralph-tui/$" "$gitignore" 2>/dev/null; then
            echo ""
            print_info "The .ralph-tui folder can be committed to share config with your team,"
            print_info "or added to .gitignore for local-only configuration."
            read -p "  Add .ralph-tui/ to .gitignore? (y/n): " add_gitignore

            if [[ "$add_gitignore" == "y" || "$add_gitignore" == "Y" ]]; then
                echo "" >> "$gitignore"
                echo "# Ralph TUI local config" >> "$gitignore"
                echo ".ralph-tui/" >> "$gitignore"
                print_success "Added .ralph-tui/ to .gitignore"
            fi
        fi
    fi
}

# =============================================================================
# Print Completion Message
# =============================================================================

print_complete() {
    echo ""
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}         Project Linked Successfully!${NC}"
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo ""
    print_info "Configuration Summary:"
    echo ""
    echo -e "  Repository:     ${CYAN}$REPO_NAME${NC}"
    echo -e "  Linear Project: ${CYAN}$PROJECT_NAME${NC}"
    echo -e "  Team:           ${CYAN}$TEAM_NAME ($TEAM_KEY)${NC}"
    echo -e "  Label:          ${CYAN}$LABEL_NAME${NC}"
    echo ""
    print_info "Next steps:"
    echo ""
    echo "  1. Create issues in Linear under \"$PROJECT_NAME\""
    echo "  2. Add the \"$LABEL_NAME\" label to issues you want to track"
    echo -e "  3. Run: ${CYAN}ralph-tui${NC}"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    print_header

    check_prerequisites
    detect_git_repo
    verify_connection
    select_team
    select_project_name
    find_or_create_project
    setup_label
    write_config
    print_complete
}

# Run with optional flags
case "${1:-}" in
    --help|-h)
        echo "Usage: init-project.sh [OPTIONS]"
        echo ""
        echo "Initialize a Linear project link for the current git repository."
        echo "This creates a .ralph-tui/config.toml file with the project configuration."
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo ""
        echo "Prerequisites:"
        echo "  - LINEAR_API_KEY must be set (run ralph-tui-linear-setup first)"
        echo "  - Must be run from within a git repository"
        echo ""
        echo "The script will:"
        echo "  1. Detect the current git repository"
        echo "  2. Let you select a Linear team"
        echo "  3. Create or select a Linear project"
        echo "  4. Set up the ralph-tui label"
        echo "  5. Save configuration to .ralph-tui/config.toml"
        exit 0
        ;;
    *)
        main
        ;;
esac
