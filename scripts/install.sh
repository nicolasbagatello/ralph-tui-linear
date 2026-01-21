#!/usr/bin/env bash
#
# Automated installer for ralph-tui-linear plugin
# Installs ralph-tui (if needed), the Linear plugin, and runs setup
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

print_header() {
    echo ""
    echo -e "${BLUE}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}${BOLD}       ralph-tui-linear Installer${NC}"
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
# Check for package manager
# =============================================================================

detect_package_manager() {
    if command -v bun &> /dev/null; then
        PKG_MANAGER="bun"
        PKG_INSTALL="bun add -g"
    elif command -v npm &> /dev/null; then
        PKG_MANAGER="npm"
        PKG_INSTALL="npm install -g"
    elif command -v yarn &> /dev/null; then
        PKG_MANAGER="yarn"
        PKG_INSTALL="yarn global add"
    else
        print_error "No package manager found (npm, bun, or yarn required)"
        echo ""
        print_info "Install Node.js: https://nodejs.org"
        print_info "Or install Bun: https://bun.sh"
        exit 1
    fi

    print_success "Using package manager: $PKG_MANAGER"
}

# =============================================================================
# Check for ralph-tui
# =============================================================================

check_ralph_tui() {
    print_step "Step 1: Checking for ralph-tui"

    if command -v ralph-tui &> /dev/null; then
        local version=$(ralph-tui --version 2>/dev/null || echo "unknown")
        print_success "ralph-tui is installed (version: $version)"
        return 0
    fi

    # Check if installed but not in PATH
    if [ -d "$HOME/.config/ralph-tui" ]; then
        print_warning "ralph-tui config exists but command not found"
        print_info "You may need to add it to your PATH"
        return 0
    fi

    return 1
}

install_ralph_tui() {
    print_warning "ralph-tui is not installed"
    echo ""
    print_info "ralph-tui is required for this plugin to work."
    print_info "Would you like to install it now?"
    echo ""
    read -p "  Install ralph-tui? (y/n): " install_choice

    if [[ "$install_choice" != "y" && "$install_choice" != "Y" ]]; then
        print_warning "Skipping ralph-tui installation"
        print_info "You can install it later with: ${CYAN}$PKG_INSTALL ralph-tui${NC}"
        print_info "Or visit: ${CYAN}https://ralph-tui.com/docs/getting-started/quick-start${NC}"
        return 1
    fi

    print_info "Installing ralph-tui..."
    if $PKG_INSTALL ralph-tui; then
        print_success "ralph-tui installed successfully"
        return 0
    else
        print_error "Failed to install ralph-tui"
        print_info "Try installing manually: ${CYAN}$PKG_INSTALL ralph-tui${NC}"
        return 1
    fi
}

# =============================================================================
# Check dependencies
# =============================================================================

check_dependencies() {
    print_step "Step 2: Checking dependencies"

    local missing=0

    # Check curl
    if command -v curl &> /dev/null; then
        print_success "curl is installed"
    else
        print_error "curl is not installed"
        missing=1
    fi

    # Check jq
    if command -v jq &> /dev/null; then
        print_success "jq is installed"
    else
        print_error "jq is not installed"
        print_info "Install with: ${CYAN}brew install jq${NC} (macOS) or ${CYAN}apt install jq${NC} (Linux)"
        missing=1
    fi

    if [ $missing -eq 1 ]; then
        print_warning "Some dependencies are missing. The setup script may not work correctly."
        read -p "  Continue anyway? (y/n): " continue_choice
        if [[ "$continue_choice" != "y" && "$continue_choice" != "Y" ]]; then
            exit 1
        fi
    fi
}

# =============================================================================
# Install plugin
# =============================================================================

install_plugin() {
    print_step "Step 3: Installing ralph-tui-linear plugin"

    # Check if already installed
    local plugin_path="$HOME/.config/ralph-tui/plugins/trackers/linear.js"
    if [ -f "$plugin_path" ]; then
        print_warning "Plugin already installed at: $plugin_path"
        read -p "  Reinstall? (y/n): " reinstall_choice
        if [[ "$reinstall_choice" != "y" && "$reinstall_choice" != "Y" ]]; then
            print_info "Keeping existing installation"
            return 0
        fi
    fi

    print_info "Installing ralph-tui-linear..."
    if $PKG_INSTALL ralph-tui-linear; then
        print_success "ralph-tui-linear installed successfully"
    else
        print_error "Failed to install ralph-tui-linear"
        exit 1
    fi
}

# =============================================================================
# Verify installation
# =============================================================================

verify_installation() {
    print_step "Step 4: Verifying installation"

    local plugin_path="$HOME/.config/ralph-tui/plugins/trackers/linear.js"

    if [ -f "$plugin_path" ]; then
        local size=$(wc -c < "$plugin_path" | tr -d ' ')
        print_success "Plugin installed: $plugin_path ($size bytes)"
    else
        print_error "Plugin not found at expected location"
        print_info "Expected: $plugin_path"
        exit 1
    fi

    # Check if setup script is available
    if command -v ralph-tui-linear-setup &> /dev/null; then
        print_success "Setup script available: ralph-tui-linear-setup"
    else
        print_warning "Setup script not in PATH"
        print_info "You may need to restart your terminal or source your profile"
    fi
}

# =============================================================================
# Run setup
# =============================================================================

run_setup() {
    print_step "Step 5: Configure Linear"

    echo ""
    print_info "Would you like to run the Linear setup wizard now?"
    print_info "This will configure your Linear API key, team, and project."
    echo ""
    read -p "  Run setup? (y/n): " setup_choice

    if [[ "$setup_choice" != "y" && "$setup_choice" != "Y" ]]; then
        print_info "Skipping setup"
        print_info "You can run it later with: ${CYAN}ralph-tui-linear-setup${NC}"
        return 0
    fi

    echo ""

    # Try to run the setup script
    if command -v ralph-tui-linear-setup &> /dev/null; then
        ralph-tui-linear-setup
    else
        # Fallback: try to find it in common locations
        local script_locations=(
            "./scripts/setup-linear.sh"
            "$HOME/.config/ralph-tui/plugins/trackers/setup-linear.sh"
            "$(npm root -g)/ralph-tui-linear/scripts/setup-linear.sh"
        )

        for loc in "${script_locations[@]}"; do
            if [ -f "$loc" ]; then
                bash "$loc"
                return 0
            fi
        done

        print_warning "Could not find setup script"
        print_info "Try running: ${CYAN}ralph-tui-linear-setup${NC}"
        print_info "Or restart your terminal and try again"
    fi
}

# =============================================================================
# Print completion message
# =============================================================================

print_complete() {
    echo ""
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}${BOLD}           Installation Complete!${NC}"
    echo -e "${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}"
    echo ""
    print_info "Next steps:"
    echo ""
    echo "  1. If you haven't already, run the setup wizard:"
    echo -e "     ${CYAN}ralph-tui-linear-setup${NC}"
    echo ""
    echo "  2. Label your Linear issues with 'ralph-tui'"
    echo ""
    echo "  3. Start ralph-tui in your project:"
    echo -e "     ${CYAN}ralph-tui${NC}"
    echo ""
    print_info "Resources:"
    echo -e "  - ralph-tui docs:  ${CYAN}https://ralph-tui.com/docs/getting-started/quick-start${NC}"
    echo -e "  - ralph-tui repo:  ${CYAN}https://github.com/subsy/ralph-tui${NC}"
    echo -e "  - Plugin repo:     ${CYAN}https://github.com/subsy/ralph-tui-linear${NC}"
    echo ""
}

# =============================================================================
# Main
# =============================================================================

main() {
    print_header

    # Detect package manager
    detect_package_manager

    # Check/install ralph-tui
    if ! check_ralph_tui; then
        install_ralph_tui
    fi

    # Check dependencies
    check_dependencies

    # Install plugin
    install_plugin

    # Verify installation
    verify_installation

    # Run setup
    run_setup

    # Done
    print_complete
}

# Run with optional flags
case "${1:-}" in
    --help|-h)
        echo "Usage: install.sh [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Show this help message"
        echo "  --skip-setup   Skip the Linear setup wizard"
        echo ""
        echo "This script will:"
        echo "  1. Check for ralph-tui (and offer to install if missing)"
        echo "  2. Verify dependencies (curl, jq)"
        echo "  3. Install the ralph-tui-linear plugin"
        echo "  4. Run the Linear configuration wizard"
        echo ""
        echo "Resources:"
        echo "  https://ralph-tui.com/docs/getting-started/quick-start"
        echo "  https://github.com/subsy/ralph-tui"
        echo "  https://github.com/subsy/ralph-tui-linear"
        exit 0
        ;;
    --skip-setup)
        SKIP_SETUP=1
        main
        ;;
    *)
        main
        ;;
esac
