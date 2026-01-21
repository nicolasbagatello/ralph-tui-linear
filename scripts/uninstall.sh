#!/usr/bin/env bash
#
# Uninstaller for ralph-tui-linear plugin
# Removes plugin files, optionally cleans up environment variables and webhooks
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

# Paths
PLUGIN_DIR="$HOME/.config/ralph-tui/plugins/trackers"
PLUGIN_FILES=(
    "linear.js"
    "linear-template.hbs"
    "linear-client.js"
)

print_header() {
    echo ""
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}       ralph-tui-linear Uninstaller${NC}"
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
# Remove plugin files
# =============================================================================

remove_plugin_files() {
    print_step "Step 1: Removing plugin files"

    local removed=0

    for file in "${PLUGIN_FILES[@]}"; do
        local filepath="$PLUGIN_DIR/$file"
        if [ -f "$filepath" ]; then
            rm -f "$filepath"
            print_success "Removed: $filepath"
            ((removed++))
        fi
    done

    if [ $removed -eq 0 ]; then
        print_warning "No plugin files found"
    else
        print_success "Removed $removed plugin file(s)"
    fi
}

# =============================================================================
# Remove environment variables from shell profile
# =============================================================================

remove_env_vars() {
    print_step "Step 2: Remove environment variables"

    echo ""
    print_info "The setup script may have added LINEAR_* variables to your shell profile."
    print_info "Would you like to remove them?"
    echo ""
    read -p "  Remove LINEAR_* env vars from shell profile? (y/n): " remove_choice

    if [[ "$remove_choice" != "y" && "$remove_choice" != "Y" ]]; then
        print_info "Skipping environment variable cleanup"
        return 0
    fi

    # Detect shell profile
    local shell_profile=""
    if [ -f "$HOME/.zshrc" ]; then
        shell_profile="$HOME/.zshrc"
    elif [ -f "$HOME/.bashrc" ]; then
        shell_profile="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
        shell_profile="$HOME/.bash_profile"
    fi

    if [ -z "$shell_profile" ]; then
        print_warning "Could not find shell profile"
        return 0
    fi

    print_info "Checking $shell_profile..."

    # Create backup
    cp "$shell_profile" "${shell_profile}.backup.$(date +%Y%m%d%H%M%S)"
    print_success "Created backup of shell profile"

    # Remove LINEAR_* export lines
    local temp_file=$(mktemp)
    grep -v "^export LINEAR_" "$shell_profile" > "$temp_file" 2>/dev/null || true

    # Check if anything was removed
    local original_lines=$(wc -l < "$shell_profile")
    local new_lines=$(wc -l < "$temp_file")
    local removed_lines=$((original_lines - new_lines))

    if [ $removed_lines -gt 0 ]; then
        mv "$temp_file" "$shell_profile"
        print_success "Removed $removed_lines LINEAR_* export line(s)"
        print_info "Run: ${CYAN}source $shell_profile${NC} to apply changes"
    else
        rm -f "$temp_file"
        print_info "No LINEAR_* exports found in $shell_profile"
    fi
}

# =============================================================================
# Delete Linear webhook
# =============================================================================

delete_webhook() {
    print_step "Step 3: Delete Linear webhook"

    # Check if we have the necessary info
    local api_key="${LINEAR_API_KEY:-}"
    local webhook_id="${LINEAR_WEBHOOK_ID:-}"

    # Try to get from .env if not in environment
    if [ -z "$webhook_id" ] && [ -f ".env" ]; then
        webhook_id=$(grep "^LINEAR_WEBHOOK_ID=" .env 2>/dev/null | cut -d'=' -f2 || true)
    fi

    if [ -z "$api_key" ]; then
        print_warning "LINEAR_API_KEY not found - skipping webhook deletion"
        print_info "You can manually delete webhooks at: ${CYAN}https://linear.app/settings/api${NC}"
        return 0
    fi

    if [ -z "$webhook_id" ]; then
        print_info "No webhook ID found - skipping webhook deletion"
        return 0
    fi

    echo ""
    print_info "Found webhook ID: $webhook_id"
    read -p "  Delete this webhook from Linear? (y/n): " delete_choice

    if [[ "$delete_choice" != "y" && "$delete_choice" != "Y" ]]; then
        print_info "Skipping webhook deletion"
        return 0
    fi

    # Check for required tools
    if ! command -v curl &> /dev/null || ! command -v jq &> /dev/null; then
        print_warning "curl and jq required for webhook deletion"
        print_info "Delete manually at: ${CYAN}https://linear.app/settings/api${NC}"
        return 0
    fi

    print_info "Deleting webhook..."

    local response=$(curl -s -X POST \
        -H "Content-Type: application/json" \
        -H "Authorization: $api_key" \
        --data "{\"query\":\"mutation { webhookDelete(id: \\\"$webhook_id\\\") { success } }\"}" \
        https://api.linear.app/graphql)

    local success=$(echo "$response" | jq -r '.data.webhookDelete.success // false')

    if [ "$success" = "true" ]; then
        print_success "Webhook deleted successfully"
    else
        print_warning "Could not delete webhook (may already be deleted)"
        print_info "Delete manually at: ${CYAN}https://linear.app/settings/api${NC}"
    fi
}

# =============================================================================
# Uninstall npm package
# =============================================================================

uninstall_package() {
    print_step "Step 4: Uninstall npm package"

    echo ""
    print_info "Would you like to uninstall the ralph-tui-linear npm package?"
    echo ""
    read -p "  Uninstall npm package? (y/n): " uninstall_choice

    if [[ "$uninstall_choice" != "y" && "$uninstall_choice" != "Y" ]]; then
        print_info "Skipping npm package uninstall"
        return 0
    fi

    # Detect package manager
    if command -v bun &> /dev/null; then
        print_info "Uninstalling with bun..."
        bun remove -g ralph-tui-linear 2>/dev/null || true
    elif command -v npm &> /dev/null; then
        print_info "Uninstalling with npm..."
        npm uninstall -g ralph-tui-linear 2>/dev/null || true
    elif command -v yarn &> /dev/null; then
        print_info "Uninstalling with yarn..."
        yarn global remove ralph-tui-linear 2>/dev/null || true
    else
        print_warning "No package manager found"
        return 0
    fi

    print_success "npm package uninstalled"
}

# =============================================================================
# Print completion message
# =============================================================================

print_complete() {
    echo ""
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}           Uninstall Complete!${NC}"
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo ""
    print_info "ralph-tui-linear has been removed."
    echo ""
    print_info "Note: Project-specific .env files were not removed."
    print_info "You can delete them manually if needed."
    echo ""
    print_info "To reinstall:"
    echo -e "  ${CYAN}curl -fsSL https://raw.githubusercontent.com/nicolasbagatello/ralph-tui-linear/main/scripts/install.sh | bash${NC}"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    print_header

    echo -e "${YELLOW}This will remove the ralph-tui-linear plugin.${NC}"
    echo ""
    read -p "Continue? (y/n): " confirm

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Aborted."
        exit 0
    fi

    # Remove plugin files
    remove_plugin_files

    # Remove environment variables
    remove_env_vars

    # Delete webhook
    delete_webhook

    # Uninstall npm package
    uninstall_package

    # Done
    print_complete
}

# Run with optional flags
case "${1:-}" in
    --help|-h)
        echo "Usage: uninstall.sh [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --force, -f    Skip confirmation prompts"
        echo ""
        echo "This script will:"
        echo "  1. Remove plugin files from ~/.config/ralph-tui/plugins/trackers/"
        echo "  2. Optionally remove LINEAR_* env vars from shell profile"
        echo "  3. Optionally delete the Linear webhook"
        echo "  4. Optionally uninstall the npm package"
        exit 0
        ;;
    --force|-f)
        FORCE=1
        main
        ;;
    *)
        main
        ;;
esac
