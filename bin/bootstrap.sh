#!/usr/bin/env bash
set -euo pipefail

# Set default values for environment variables
VESPA_HOME="${VESPA_HOME:-$HOME/vespa}"
SYSTEM_TEST_ROOT="${SYSTEM_TEST_ROOT:-}"

echo "[devcontainer] Bootstrapping Vespa dev environment..."

# Detect if running in a devcontainer
# REMOTE_CONTAINERS is set by VS Code devcontainers
# CODESPACES is set by GitHub Codespaces
if [ -n "${REMOTE_CONTAINERS:-}" ] || [ -n "${CODESPACES:-}" ]; then
  # Disable GPG signing for git commits (AlmaLinux 8 has OpenSSH 8.0p1, but 8.2p1+ is needed)
  echo "[devcontainer] Running in devcontainer - configuring git to disable SSH signing..."
  git config --global gpg.format ""
  git config --global commit.gpgsign false
else
  echo "[devcontainer] Not running in devcontainer - skipping git signing configuration"
fi

# Ensure directories
mkdir -p "$HOME/git"

# Clone Vespa repo into persistent volume if missing
if [ ! -d "$HOME/git/vespa/.git" ]; then
  echo "[devcontainer] Cloning vespa repo (first time only)..."
  git clone --depth 1 https://github.com/vespa-engine/vespa.git "$HOME/git/vespa"
else
  echo "[devcontainer] vespa repo already present, skipping clone."
fi

# If the workspace is the system-test repo, keep a convenience link under $HOME/git
if [ -d "${SYSTEM_TEST_ROOT:-}" ] && [ -d "${SYSTEM_TEST_ROOT}/.git" ]; then
  if [ ! -e "$HOME/git/system-test" ]; then
    echo "[devcontainer] Linking system-test from workspace..."
    ln -s "${SYSTEM_TEST_ROOT}" "$HOME/git/system-test"
  fi
else
  # Otherwise, clone system-test if not present
  if [ ! -d "$HOME/git/system-test/.git" ]; then
    echo "[devcontainer] Cloning system-test repo (first time only)..."
    git clone --depth 1 https://github.com/vespa-engine/system-test.git "$HOME/git/system-test"
  else
    echo "[devcontainer] system-test repo already present, skipping clone."
  fi
fi

# Feature flags required by some system tests
mkdir -p "$VESPA_HOME/var/vespa"
mkdir -p "$VESPA_HOME/logs/systemtests"

# Copy feature flags - flag.db should be a FILE, not a directory
if [ -f "$HOME/git/system-test/docker/include/feature-flags.json" ]; then
  echo "[devcontainer] Setting up feature flags..."
  cp -f "$HOME/git/system-test/docker/include/feature-flags.json" "$VESPA_HOME/var/vespa/flag.db"
else
  echo "[devcontainer] Warning: feature-flags.json not found, skipping."
fi

# Add bin directory to PATH for vespa-dev helper
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Since this script is in bin/bootstrap.sh, SCRIPT_DIR is already the bin directory
if [[ ":$PATH:" != *":$SCRIPT_DIR:"* ]]; then
  export PATH="$SCRIPT_DIR:$PATH"
  echo "[devcontainer] Added $SCRIPT_DIR to PATH"
fi

# Ensure vespa-dev is executable
chmod +x "$SCRIPT_DIR/vespa-dev" 2>/dev/null || true

# Build marker files to track completed builds
BUILD_MARKER_DIR="$VESPA_HOME/.build-markers"
JAVA_BUILD_MARKER="$BUILD_MARKER_DIR/java-built"
CPP_BUILD_MARKER="$BUILD_MARKER_DIR/cpp-built"
INSTALL_MARKER="$BUILD_MARKER_DIR/install-completed"

mkdir -p "$BUILD_MARKER_DIR"

# Run builds automatically on first container creation
if [ ! -f "$JAVA_BUILD_MARKER" ]; then
  echo "[devcontainer] Running initial Java build (this may take several minutes)..."
  if vespa-dev java; then
    touch "$JAVA_BUILD_MARKER"
    echo "[devcontainer] Java build completed successfully."
  else
    echo "[devcontainer] Warning: Java build failed. You can retry with 'vespa-dev java'."
  fi
else
  echo "[devcontainer] Java build already completed (marker found). Use 'vespa-dev java --force' to rebuild."
fi

if [ ! -f "$CPP_BUILD_MARKER" ]; then
  echo "[devcontainer] Running initial C++ build (this may take several minutes)..."
  if vespa-dev cpp; then
    touch "$CPP_BUILD_MARKER"
    echo "[devcontainer] C++ build completed successfully."
  else
    echo "[devcontainer] Warning: C++ build failed. You can retry with 'vespa-dev cpp'."
  fi
else
  echo "[devcontainer] C++ build already completed (marker found). Use 'vespa-dev cpp --force' to rebuild."
fi

if [ ! -f "$INSTALL_MARKER" ]; then
  echo "[devcontainer] Running initial install..."
  if vespa-dev install; then
    touch "$INSTALL_MARKER"
    echo "[devcontainer] Install completed successfully."
  else
    echo "[devcontainer] Warning: Install failed. You can retry with 'vespa-dev install'."
  fi
else
  echo "[devcontainer] Install already completed (marker found). Use 'vespa-dev install --force' to rerun."
fi

echo "[devcontainer] Done. Try: 'vespa-dev system-test tests/search/basicsearch/basic_search.rb'."
