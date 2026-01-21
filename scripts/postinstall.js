#!/usr/bin/env node
/**
 * ABOUTME: Post-install script for ralph-tui-linear plugin.
 * Checks for ralph-tui installation, then copies the plugin to
 * ~/.config/ralph-tui/plugins/trackers/ for plugin discovery.
 */

import { mkdir, copyFile, access, stat } from 'node:fs/promises';
import { join, dirname } from 'node:path';
import { homedir } from 'node:os';
import { fileURLToPath } from 'node:url';
import { execSync } from 'node:child_process';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const PLUGIN_DIR = join(homedir(), '.config', 'ralph-tui', 'plugins', 'trackers');
const RALPH_TUI_CONFIG = join(homedir(), '.config', 'ralph-tui');
const PLUGIN_FILE = 'linear.js';

// ANSI colors
const RED = '\x1b[31m';
const GREEN = '\x1b[32m';
const YELLOW = '\x1b[33m';
const BLUE = '\x1b[34m';
const CYAN = '\x1b[36m';
const BOLD = '\x1b[1m';
const NC = '\x1b[0m'; // No color

/**
 * Check if ralph-tui is installed
 */
async function checkRalphTuiInstalled() {
  // Method 1: Check if ralph-tui command exists
  try {
    execSync('which ralph-tui', { stdio: 'ignore' });
    return { installed: true, method: 'command' };
  } catch {
    // Command not found, try other methods
  }

  // Method 2: Check if ralph-tui config directory exists
  try {
    await access(RALPH_TUI_CONFIG);
    return { installed: true, method: 'config' };
  } catch {
    // Config dir doesn't exist
  }

  // Method 3: Check if installed as npm package
  try {
    execSync('npm list -g ralph-tui', { stdio: 'ignore' });
    return { installed: true, method: 'npm' };
  } catch {
    // Not installed via npm
  }

  // Method 4: Check if installed via bun
  try {
    execSync('bun pm ls -g | grep ralph-tui', { stdio: 'ignore' });
    return { installed: true, method: 'bun' };
  } catch {
    // Not installed via bun
  }

  return { installed: false, method: null };
}

/**
 * Verify the plugin was installed correctly
 */
async function verifyInstallation(destPath) {
  try {
    const stats = await stat(destPath);
    return stats.size > 0;
  } catch {
    return false;
  }
}

async function main() {
  console.log(`
${BLUE}${BOLD}════════════════════════════════════════════════════════════${NC}
${BLUE}${BOLD}       Installing ralph-tui-linear plugin...${NC}
${BLUE}${BOLD}════════════════════════════════════════════════════════════${NC}
`);

  // Step 1: Check if ralph-tui is installed
  console.log(`${CYAN}▶ Checking for ralph-tui installation...${NC}`);

  const ralphCheck = await checkRalphTuiInstalled();

  if (!ralphCheck.installed) {
    console.log(`
${YELLOW}⚠ Warning: ralph-tui does not appear to be installed.${NC}

This plugin requires ralph-tui to function. Please install it first:

  ${CYAN}npm install -g ralph-tui${NC}

  Or with bun:
  ${CYAN}bun add -g ralph-tui${NC}

For installation instructions, visit:
  ${CYAN}https://ralph-tui.com/docs/getting-started/quick-start${NC}
  ${CYAN}https://github.com/subsy/ralph-tui${NC}

${YELLOW}Continuing with plugin installation anyway...${NC}
`);
  } else {
    console.log(`${GREEN}✓ ralph-tui detected (via ${ralphCheck.method})${NC}\n`);
  }

  try {
    // Step 2: Create plugins directory
    console.log(`${CYAN}▶ Creating plugin directory...${NC}`);
    await mkdir(PLUGIN_DIR, { recursive: true });
    console.log(`${GREEN}✓ Directory ready: ${PLUGIN_DIR}${NC}\n`);

    // Step 3: Copy the plugin files
    console.log(`${CYAN}▶ Copying plugin files...${NC}`);

    const sourcePath = join(__dirname, '..', 'dist', 'index.js');
    const destPath = join(PLUGIN_DIR, PLUGIN_FILE);

    // Copy main plugin
    await copyFile(sourcePath, destPath);
    console.log(`${GREEN}✓ Plugin: ${PLUGIN_FILE}${NC}`);

    // Copy template (optional)
    const templateSource = join(__dirname, '..', 'dist', 'template.hbs');
    const templateDest = join(PLUGIN_DIR, 'linear-template.hbs');
    try {
      await copyFile(templateSource, templateDest);
      console.log(`${GREEN}✓ Template: linear-template.hbs${NC}`);
    } catch {
      // Template copy is optional
    }

    // Copy client module (optional - if not bundled)
    const clientSource = join(__dirname, '..', 'dist', 'client.js');
    const clientDest = join(PLUGIN_DIR, 'linear-client.js');
    try {
      await copyFile(clientSource, clientDest);
      console.log(`${GREEN}✓ Client: linear-client.js${NC}`);
    } catch {
      // Client copy is optional if bundled
    }

    // Step 4: Verify installation
    console.log(`\n${CYAN}▶ Verifying installation...${NC}`);
    const verified = await verifyInstallation(destPath);

    if (verified) {
      console.log(`${GREEN}✓ Plugin verified successfully${NC}`);
    } else {
      console.log(`${YELLOW}⚠ Could not verify plugin installation${NC}`);
    }

    // Success message
    console.log(`
${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}
${GREEN}${BOLD}         ralph-tui-linear plugin installed!${NC}
${GREEN}${BOLD}════════════════════════════════════════════════════════════${NC}

Plugin installed to: ${destPath}

${BOLD}Next steps:${NC}

1. Run the setup script to configure Linear:

   ${CYAN}ralph-tui-linear-setup${NC}

2. Or set these environment variables:
   - LINEAR_API_KEY (required)
   - LINEAR_TEAM_ID
   - LINEAR_PROJECT_ID
   - LINEAR_LABEL_NAME (default: ralph-tui)

3. Configure ralph-tui to use the Linear tracker:

   Edit .ralph-tui/config.toml:

   ${CYAN}tracker = "linear"

   [trackerOptions]
   projectId = "your-project-id"
   teamId = "your-team-id"
   labelName = "ralph-tui"${NC}

4. Label your Linear issues with "ralph-tui" to track them.

${BOLD}Resources:${NC}
  - ralph-tui docs: ${CYAN}https://ralph-tui.com/docs/getting-started/quick-start${NC}
  - ralph-tui repo: ${CYAN}https://github.com/subsy/ralph-tui${NC}
  - This plugin:    ${CYAN}https://github.com/subsy/ralph-tui-linear${NC}
`);

  } catch (err) {
    if (err.code === 'ENOENT') {
      console.warn(`
${YELLOW}Warning: Could not install ralph-tui-linear plugin.${NC}
The built files may not exist yet. Try running:

  ${CYAN}npm run build${NC}
  ${CYAN}node scripts/postinstall.js${NC}
`);
    } else {
      console.error(`${RED}Error installing plugin:${NC}`, err.message);
    }
    // Don't fail the install
    process.exit(0);
  }
}

main();
