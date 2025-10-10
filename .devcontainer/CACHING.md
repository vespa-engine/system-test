# Build Caching in Dev Container

## Overview

The dev container uses persistent Docker volumes to cache build artifacts, speeding up rebuilds significantly.

## Quick Start: Making Code Changes

**TL;DR**: The build commands **always run** when you call them, doing incremental builds by default.

```bash
# 1. Edit Vespa code
cd /root/git/vespa
# ... make your changes ...

# 2. Rebuild (incremental - only changed files)
vespa-dev java          # If you changed Java code (10s - 2min)
vespa-dev cpp           # If you changed C++ code (30s - 5min)
vespa-dev install       # Install to $VESPA_HOME

# 3. Test your changes
vespa-dev system-test tests/search/basicsearch/basic_search.rb

# 4. If something's broken, force clean rebuild
vespa-dev java --force  # or cpp --force
```

**Key Point**: You don't need to worry about cache invalidation or forcing rebuilds during normal development. The build tools (Maven, Make) handle incremental compilation automatically, and caches make it fast!

### Example Timeline

```
Day 1 - First container creation:
  ├─ bootstrap.sh runs automatically
  ├─ vespa-dev java      (60 min - full build, populates Maven cache)
  ├─ vespa-dev cpp       (30 min - full build, populates ccache)
  └─ vespa-dev install   (2 min)
  Total: ~90 minutes

Day 2 - Edit 3 Java files:
  ├─ vespa-dev java      (30 seconds - incremental!)
  └─ vespa-dev install   (10 seconds)
  Total: ~40 seconds ⚡

Day 3 - Edit 10 C++ files:
  ├─ vespa-dev cpp       (2 minutes - incremental + ccache!)
  └─ vespa-dev install   (30 seconds)
  Total: ~2.5 minutes ⚡

Day 4 - Container restart:
  └─ bootstrap.sh runs (sees markers, skips builds)
  Total: ~5 seconds ⚡

Day 5 - Container rebuild (e.g., updated base image):
  └─ bootstrap.sh runs (sees markers, skips builds)
  Total: ~5 seconds ⚡
  └─ Then continue editing as normal (incremental builds still fast!)
```

## Cached Components

### 1. Maven Dependencies (`vespa-m2` volume)
- **Location**: `/root/.m2/repository`
- **What it caches**: All Java dependencies downloaded during Maven builds
- **Benefit**: Avoids re-downloading dependencies on rebuild (saves ~5-10 minutes)
- **First build**: Downloads all dependencies
- **Subsequent builds**: Uses cached dependencies (offline mode when possible)

### 2. C++ Compilation Cache (`vespa-ccache` volume)
- **Location**: `/root/.ccache`
- **What it caches**: Compiled C++ object files
- **Benefit**: Avoids recompiling unchanged C++ files (can save 30-60+ minutes)
- **Configuration**: Automatically enabled via `CMAKE_CXX_COMPILER_LAUNCHER=ccache`
- **Check status**: Run `ccache -s` to see cache hit rate

### 3. Vespa Installation (`vespa-home` volume)
- **Location**: `/root/vespa`
- **What it caches**: Installed Vespa binaries and configuration
- **Benefit**: Preserves installation state across container rebuilds

### 4. Vespa Source Code (`vespa-src` volume)
- **Location**: `/root/git/vespa`
- **What it caches**: Cloned Vespa repository and build outputs
- **Benefit**: Avoids re-cloning and preserves build state

## Build Markers vs Manual Builds

### Build Markers (for automatic builds)
Build completion is tracked using marker files in `$VESPA_HOME/.build-markers/`:
- `java-built` - Initial Java build completed
- `cpp-built` - Initial C++ build completed
- `install-completed` - Initial Vespa install completed

**Purpose**: These markers prevent **automatic** rebuilds during `bootstrap.sh` (container start).

**Important**: These markers do NOT prevent manual builds. When you run `vespa-dev java` or `vespa-dev cpp`, the build **always runs** (incrementally).

### How Builds Work

#### Automatic Builds (bootstrap.sh)
- Run **only on first container creation** (when markers don't exist)
- Markers prevent rebuilds on container restart
- To force re-run: `vespa-dev reset-builds` then restart container

#### Manual Builds (vespa-dev commands)
- **Always run when you call them** (this is what you want for development!)
- **Incremental by default**: Only rebuilds changed files
  - Java: `mvn install` (no clean) - uses Maven's incremental compilation
  - C++: `make` - only recompiles changed .cpp files (with ccache)
- **Clean rebuild**: Use `--force` flag
  - Java: `mvn clean install` - rebuilds everything
  - C++: `make clean && make` - recompiles all files

### Examples

```bash
# After editing Java code
vespa-dev java           # Incremental rebuild (fast, only changed files)
vespa-dev install        # Install updated artifacts

# After editing C++ code  
vespa-dev cpp            # Incremental rebuild (fast, uses ccache)
vespa-dev install        # Install updated binaries

# Something broken? Force clean rebuild
vespa-dev java --force   # Clean + full rebuild
vespa-dev cpp --force    # Clean + full rebuild
```

## Managing Caches

### Check cache status
```bash
vespa-dev status
```

### After making code changes (incremental build)
```bash
# Edit files in $GIT_DIR/vespa
vespa-dev java           # Incremental Java build (fast!)
vespa-dev cpp            # Incremental C++ build (fast with ccache!)
vespa-dev install        # Install updated artifacts
```

### Force clean rebuild
```bash
vespa-dev java --force   # Clean rebuild (mvn clean install)
vespa-dev cpp --force    # Clean rebuild (make clean && make)
```

### Reset all build markers
```bash
vespa-dev reset-builds
```

### Check ccache statistics
```bash
ccache -s
```

### Clear ccache (if needed)
```bash
ccache -C  # Clear cache
ccache -z  # Zero statistics
```

### Remove volumes completely (nuclear option)
```bash
# Exit the container first, then from host:
docker volume rm vespa-m2 vespa-ccache vespa-home vespa-src
```

## How Rebuilding Works

### Container Restart (Fast - ~seconds)
- Volumes persist
- Markers persist
- No automatic builds run
- Everything is ready immediately
- **You can make code changes and rebuild manually**

### Container Rebuild (Fast - ~seconds)
- Volumes **persist** (key improvement!)
- Markers persist in `vespa-home` volume
- Automatic builds **skip** if markers exist
- ccache and Maven cache make manual rebuilds fast
- **You can make code changes and rebuild manually**

### Incremental Build After Code Changes (Fast - seconds to minutes)
- **This is your main development workflow!**
- Java: 10 seconds - 2 minutes (depends on changes)
- C++: 30 seconds - 5 minutes (depends on changes, ccache helps)
- Only changed files are recompiled
- Caches make this very fast

### Clean Rebuild with --force (Medium - ~5-15 minutes with cache)
- Forces full recompilation
- Still uses dependency caches (Maven, ccache)
- Useful when build state is corrupted

### Fresh Start (Slow - ~60-90 minutes)
- Only happens if volumes are deleted
- Downloads all dependencies
- Compiles everything from scratch
- Populates all caches

## Best Practices

1. **Don't delete volumes** unless absolutely necessary
2. **Use `--force` flags** instead of deleting markers manually
3. **Monitor cache sizes** periodically:
   - Maven cache can grow to several GB
   - ccache typically 1-5 GB depending on size limit
4. **Increase ccache size** if needed:
   ```bash
   ccache -M 10G  # Set max size to 10GB
   ```

## Troubleshooting

### Builds still run on every rebuild
- Check if volumes exist: `docker volume ls | grep vespa`
- Verify markers exist: `ls -la $VESPA_HOME/.build-markers/`
- Check volume mounts: Look in devcontainer.json

### ccache not working
- Verify it's installed: `command -v ccache`
- Check configuration: `ccache -p`
- Verify CCACHE_DIR: `echo $CCACHE_DIR`

### Maven still downloads dependencies
- Check cache exists: `ls -la ~/.m2/repository/`
- Verify offline mode is attempted (check bootstrap logs)
- Some plugins may require online mode

## Volume Persistence

The volumes are named and persist across:
- ✅ Container stops/starts
- ✅ Container rebuilds
- ✅ Dev Container rebuilds
- ✅ VS Code restarts
- ❌ Explicit volume deletion
- ❌ Docker system prune (use `--volumes` flag carefully)

As long as the volume names remain the same in `devcontainer.json`, your caches will persist!
