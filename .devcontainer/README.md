# Vespa System Test Dev Container

Ready-to-use **Dev Container** for **Vespa development + system tests** on AlmaLinux 8.

## Quick Start

### Using VS Code

1. Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
2. Open this repository in VS Code
3. Click "Reopen in Container" when prompted (or use Command Palette: `Dev Containers: Reopen in Container`)
4. Wait for the initial setup to complete (Java/C++ builds run automatically on first start)
5. Open a terminal and start developing:

```bash
vespa-dev status                # Check environment and build status
vespa-dev system-test tests/search/basicsearch/basic_search.rb  # Run a system test
```

### Using GitHub Codespaces

1. Click "Code" → "Codespaces" → "Create codespace on <branch>"
2. Wait for the environment to initialize
3. Use the same `vespa-dev` commands as above

## What This Does

The devcontainer automatically sets up a complete Vespa development environment:

- **Base Image**: Uses `docker.io/vespaengine/vespa-dev-almalinux-8:latest` (prebuilt with all dependencies)
- **Persistent Volumes**: Maven cache, ccache, Vespa source, and installation persist across container rebuilds
- **Automatic Setup** (on first creation):
  - Clones [vespa](https://github.com/vespa-engine/vespa) repository into a persistent volume
  - Links the system-test repository from your workspace
  - Configures feature flags for system tests
  - Builds Java modules (tracked with marker files)
  - Builds C++ modules (tracked with marker files)
  - Installs Vespa to `$VESPA_HOME`
- **Port Forwarding**:
  - Port 5005: JVM debugger
  - Port 3334: SSH (for advanced use cases)
- **Privileged Mode**: Enabled by default for running Vespa services and debugging

## Environment Details

- **VESPA_HOME**: `/root/vespa` - Vespa installation directory (persistent volume)
- **Source Code**: `/root/git/vespa` - Vespa source (persistent volume)
- **System Tests**: `/workspaces/system-test` - This repository (mounted from workspace)
- **User**: `root` (required for some Vespa operations)
- **Maven Cache**: `/root/.m2` - Persistent across rebuilds
- **ccache**: `/root/.ccache` - Speeds up C++ rebuilds

### Working with Both Repositories

By default, only the `system-test` repository is visible in VS Code's Explorer. To work with both `system-test` and `vespa` repositories side-by-side:

1. Go to **File** → **Open Workspace from File**
2. Select `.devcontainer/vespa-dev.code-workspace`
3. VS Code will reload and show both repositories as separate folders in the Explorer

The workspace file is pre-configured to:
- Show both repositories with descriptive names
- Keep all your settings and extensions
- Allow you to easily navigate between system tests and Vespa source code

**Tip**: You can also open the workspace using the command line:
```bash
code .devcontainer/vespa-dev.code-workspace
```

## Build Caching

The devcontainer uses persistent Docker volumes to cache builds, significantly reducing rebuild times:

- **First build**: ~60-90 minutes (downloads dependencies, compiles everything)
- **Subsequent rebuilds**: ~5-15 minutes (or instant if markers exist)
- **Container restarts**: Instant (everything is cached)

See [CACHING.md](../CACHING.md) for detailed information about how caching works and how to manage it.

## Using the `vespa-dev` Helper

The `vespa-dev` command is automatically available in your PATH inside the devcontainer. It provides a unified interface for all development tasks.

### Common Commands

```bash
# Check environment status
vespa-dev status

# Build commands (normally run automatically on first start)
vespa-dev java              # Build Java modules
vespa-dev cpp               # Build C++ modules
vespa-dev install           # Install to $VESPA_HOME

# Force rebuild (ignores completion markers)
vespa-dev java --force
vespa-dev cpp --force
vespa-dev install --force

# Reset build markers (builds will run again on next container start)
vespa-dev reset-builds

# Testing
vespa-dev unit-java [module]     # Run Maven tests (optionally for specific module)
vespa-dev unit-cpp [regex]       # Run ctest (optionally filtered by regex)
vespa-dev system-test <path>     # Run a Ruby system test
vespa-dev nodeserver             # Start nodeserver if not running

# Get help
vespa-dev help
```

### Example Workflow

```bash
# Check that everything is set up
vespa-dev status

# Make changes to Vespa code in /home/vscode/git/vespa
cd /home/vscode/git/vespa
# ... edit files ...

# Rebuild and test
vespa-dev java
vespa-dev install

# Run a system test
vespa-dev system-test tests/search/basicsearch/basic_search.rb
```

## Build Markers

To avoid long rebuild times on every container restart, the devcontainer tracks completed builds using marker files in `$VESPA_HOME/.build-markers/`:

- `java-built` - Java modules have been built
- `cpp-built` - C++ modules have been built
- `install-completed` - Vespa has been installed

**Important**: Builds will only run once automatically. To rebuild:
- Use `vespa-dev java --force` / `vespa-dev cpp --force` / `vespa-dev install --force` for individual rebuilds
- Use `vespa-dev reset-builds` to clear all markers (builds will run again on next container start)

## VS Code Integration

### Debugging

The devcontainer includes extensions for:
- **C++ debugging**: ms-vscode.cpptools
- **Java debugging**: Red Hat Java extension pack
- **Ruby**: Shopify Ruby LSP

Java debugger port 5005 is forwarded, so you can attach a remote debugger from your host machine or within VS Code.

### Tasks

Pre-configured VS Code tasks are available via **Terminal → Run Task...**:
- Build Java modules
- Build C++ modules
- Install Vespa
- Run system tests

## Persistent Volumes

The following Docker volumes persist data across container rebuilds:

- `vespa-m2`: Maven local repository (~/.m2)
- `vespa-ccache`: C++ compilation cache (~/.ccache)
- `vespa-home`: Vespa installation (/home/vscode/vespa)
- `vespa-src`: Vespa source code (/home/vscode/git/vespa)

Your workspace (system-test repository) is bind-mounted, not in a volume, so changes are immediately visible on your host.

## Scripts

The `.devcontainer/scripts/` directory contains:

- **`bootstrap.sh`**: Runs during container creation (`postCreateCommand`). Sets up the environment, clones repositories, configures PATH, and runs initial builds.
- **`vespa-dev`**: A symlink to `../../bin/vespa-dev` that provides the helper commands listed above.

### PATH Setup

The bootstrap script automatically adds `.devcontainer/scripts/` to your PATH by modifying `~/.bashrc`. This means:

- You can run `vespa-dev` directly without any path prefix
- The PATH persists across terminal sessions
- If you rebuild the container, the PATH is set up again automatically

## Modifying the `vespa-dev` Script

**Important**: `.devcontainer/scripts/vespa-dev` is a **symlink** to `../../bin/vespa-dev`.

The `bin/vespa-dev` script is the **single source of truth** for multiple workflows:
- **Devcontainer workflow** (this setup): Run `vespa-dev` inside the container
- **Standalone workflow**: Run `bin/vespa-dev` from your host to manage Podman/Docker containers via SSH

**To modify the script**: Edit `bin/vespa-dev` at the repository root. Changes apply to both workflows.

### Symlink Considerations

- **Git on Windows**: Symlinks require Developer Mode enabled or clone with:
  ```bash
  git clone -c core.symlinks=true https://github.com/vespa-engine/system-test.git
  ```
- **Copying `.devcontainer/` alone**: The symlink will break. Either:
  - Copy the entire repository, or
  - Recreate the symlink:
    ```bash
    ln -s ../../bin/vespa-dev .devcontainer/scripts/vespa-dev
    ```
- **After script changes**: The container reads from your workspace, so changes take effect immediately (no rebuild needed)

## Configuration

### devcontainer.json

Key configuration options:

```jsonc
{
  "image": "docker.io/vespaengine/vespa-dev-almalinux-8:latest",
  "remoteUser": "root",
  "privileged": true,  // Required for Vespa services
  "forwardPorts": [5005, 3334],
  "mounts": [
    // Persistent volumes for caches and source
    "source=vespa-m2,target=/home/vscode/.m2,type=volume",
    "source=vespa-ccache,target=/home/vscode/.ccache,type=volume",
    "source=vespa-home,target=/home/vscode/vespa,type=volume",
    "source=vespa-src,target=/home/vscode/git/vespa,type=volume",
    // Docker socket for nested container operations
    "source=/var/run/docker.sock,target=/var/run/docker.sock,type=bind"
  ],
  "postCreateCommand": ".devcontainer/scripts/bootstrap.sh"
}
```

### Customization

- **Disable privileged mode**: Set `"privileged": false` in `devcontainer.json`. You may need to keep `"capAdd": ["SYS_PTRACE"]` and `"securityOpt": ["seccomp=unconfined"]` for C++ debugging.
- **Change ports**: Modify `"forwardPorts"` array
- **Add extensions**: Add to `"customizations.vscode.extensions"` array
- **Adjust resources**: See `"hostRequirements"` section (requires Docker Desktop or similar)

## Troubleshooting

### Builds fail on container creation

Check the creation log in VS Code's Dev Container output panel. You can manually run builds:

```bash
vespa-dev java
vespa-dev cpp
vespa-dev install
```

### `vespa-dev` command not found

The PATH is set in `~/.bashrc`. Try:

```bash
source ~/.bashrc
# or
export PATH="/workspaces/system-test/.devcontainer/scripts:$PATH"
```

If this persists, check that the symlink exists:

```bash
ls -la /workspaces/system-test/.devcontainer/scripts/vespa-dev
```

### Slow builds

First builds take significant time. Subsequent builds use:
- **ccache** for C++ (stored in persistent volume)
- **Maven cache** for Java (stored in persistent volume)

Ensure volumes are properly mounted with `docker volume ls` or `podman volume ls`.

### Permission issues

The container runs as `root` by default. If you need to change this:
1. Update `"remoteUser"` in `devcontainer.json`
2. Rebuild the container
3. Ensure the user has access to mounted volumes

### Out of disk space

Persistent volumes can grow large. Clean up with:

```bash
# Inside container
mvn clean -pl '!vespajlib' -Dmaven.test.skip=true  # Clean Java builds
rm -rf ~/.ccache/*                                   # Clear ccache

# On host
docker volume ls                                     # List volumes
docker volume prune                                  # Remove unused volumes (careful!)
```

## Alternative Workflows

If you prefer not to use devcontainers, see the main [README.md](../README.md) for:
- **Standalone Podman/Docker**: Use `bin/vespa-dev` from your host to manage containers
- **Manual setup**: Follow the [Vespa development guide](https://github.com/vespa-engine/docker-image-dev#vespa-development-on-almalinux-8)

## More Information

- [VS Code Dev Containers documentation](https://code.visualstudio.com/docs/devcontainers/containers)
- [GitHub Codespaces documentation](https://docs.github.com/en/codespaces)
- [Vespa development guide](https://github.com/vespa-engine/docker-image-dev)
- [System test framework documentation](../README.md)
