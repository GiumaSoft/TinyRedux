#!/bin/zsh

set -e  # Exit immediately on error
set -u  # Error on unset variables

# --- Configuration ---
TUIST_VERSION="4.90.0"
MISI_HOME="/Users/giuseppe/.local/share/mise"
MISI_BIN="/Users/giuseppe/.local/bin"
TUIST_BIN="$MISI_HOME/installs/tuist/$TUIST_VERSION/bin"

# --- Helper functions ---
info()    { echo "\033[1;34mℹ️  $1\033[0m"; }
success() { echo "\033[1;32m✅ $1\033[0m"; }
warn()    { echo "\033[1;33m⚠️  $1\033[0m"; }
error()   { echo "\033[1;31m❌ $1\033[0m"; }

# --- Ensure PATH includes Mise and Tuist bins ---
export PATH="$TUIST_BIN:$MISI_BIN:$PATH"

# --- Step 1: Check for Tuist ---
if command -v tuist >/dev/null 2>&1; then
  success "tuist already installed ($(tuist --version))"
else
  info "tuist not found, proceeding with installation..."

  # --- Step 2: Check for Mise ---
  if ! command -v mise >/dev/null 2>&1; then
    info "mise not found, installing mise..."
    curl https://mise.run | sh
    success "mise installed successfully"

    # Reload PATH to include mise tools
    export PATH="$MISI_HOME/shims:$MISI_BIN:$PATH"
    source "$MISI_HOME/mise.sh" 2>/dev/null || true
  else
    success "mise already installed ($(mise --version))"
  fi

  # --- Step 3: Ensure Tuist plugin exists ---
  if ! mise plugins | grep -q "tuist"; then
    info "Adding mise-tuist plugin..."
    mise plugin add tuist https://github.com/mise-plugins/mise-tuist.git
    success "mise-tuist plugin added"
  else
    success "mise-tuist plugin already added"
  fi

  eval "$($HOME/.local/bin/mise activate zsh)" >> "$HOME/.zshrc"
  #mise doctor

  # --- Step 4: Install Tuist via Mise ---
  info "Installing tuist@$TUIST_VERSION via mise..."
  mise install "tuist@$TUIST_VERSION"
  mise use -g "tuist@$TUIST_VERSION"

  # Reload PATH after Tuist installation
  export PATH="$TUIST_BIN:$MISI_BIN:$PATH"
  success "tuist@$TUIST_VERSION installed successfully"
fi

# --- Step 5: Clean only if files exist ---
info "Checking for existing Xcode workspaces and projects..."

workspace_count=$(find . -maxdepth 1 -name "*.xcworkspace" | wc -l | tr -d ' ')
project_count=$(find ./Projects/ -name "*.xcodeproj" | wc -l | tr -d ' ')

if [[ "$workspace_count" -gt 0 ]]; then
  info "Found $workspace_count workspace(s) — removing..."
  rm -rf *.xcworkspace
  success "Workspaces removed"
else
  warn "No .xcworkspace found, skipping"
fi

if [[ "$project_count" -gt 0 ]]; then
  info "Found $project_count project(s) — removing..."
  find ./Projects/ -name "*.xcodeproj" -print -delete
  success "Projects removed"
else
  warn "No .xcodeproj found, skipping"
fi

# --- Step 6: Generate project ---
info "Generating project with Tuist..."
tuist generate
success "Tuist project generated successfully 🎉"

