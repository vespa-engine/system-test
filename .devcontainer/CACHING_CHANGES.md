# Build Caching Improvements - Summary

## Problem
When rebuilding the devcontainer, Java and C++ modules were rebuilding unnecessarily, increasing rebuild time significantly.

## Root Cause
1. **User mismatch**: Container runs as `root`, but volumes were mounted to `/home/vscode/` paths
2. **ccache not configured**: C++ builds weren't using ccache despite having a volume for it
3. **Maven offline mode not used**: Even with cached dependencies, Maven was checking remote repositories

## Solution

### 1. Fixed Volume Mount Paths (devcontainer.json)
Changed all volume mount targets from `/home/vscode/` to `/root/`:
- `/home/vscode/.m2` → `/root/.m2`
- `/home/vscode/.ccache` → `/root/.ccache`
- `/home/vscode/vespa` → `/root/vespa`
- `/home/vscode/git/vespa` → `/root/git/vespa`

Updated environment variables:
- `VESPA_HOME=/root/vespa`
- `CCACHE_DIR=/root/.ccache`

### 2. Enabled ccache for C++ Builds (bin/vespa-dev)
Modified `build_cpp()` function to:
- Detect if ccache is available
- Configure CMake with `CMAKE_CXX_COMPILER_LAUNCHER=ccache`
- This enables automatic caching of compiled C++ objects
- **Incremental by default**: `make` only recompiles changed files
- Use `--force` for clean rebuild (`make clean && make`)

### 3. Improved Maven Caching (bin/vespa-dev)
Modified `build_java()` function to:
- Check if Maven cache is populated
- Use `--offline` mode when cache exists
- Provides faster builds by avoiding remote repository checks
- **Incremental by default**: `mvn install` (no clean) only recompiles changed files
- Use `--force` for clean rebuild (`mvn clean install`)

### 4. Clarified Build Behavior
**Important**: Build commands (`vespa-dev java`, `vespa-dev cpp`) **always run** when called:
- This is intentional and correct for development workflow
- Builds are **incremental** by default (fast!)
- Build markers only prevent **automatic** builds on container start
- Developers can edit code and rebuild as often as needed

### 5. Updated Bootstrap Script (bin/bootstrap.sh)
- Use `$GIT_DIR` variable consistently
- Display cache status at completion
- Show ccache statistics if available
- Show Maven cache size

### 6. Documentation
Created two new documentation files:
- **CACHING.md**: Comprehensive guide to build caching
- Updated **.devcontainer/README.md**: Added caching section

## Expected Results

### Before Changes
- **Container rebuild**: 60-90 minutes (full recompile)
- **Volume caches**: Present but not used effectively
- **Incremental builds**: Not properly configured

### After Changes
- **First build**: 60-90 minutes (same - needs to populate caches)
- **Container rebuild**: Instant (markers prevent automatic builds)
- **Container restarts**: Instant (markers prevent automatic builds)
- **Incremental build after code changes**: 10 seconds - 5 minutes ⚡
- **Clean rebuild with --force**: 5-15 minutes (uses dependency caches)

## Development Workflow

### Making Changes (Fast! ⚡)
```bash
# Edit code
vim /root/git/vespa/some/module/File.java

# Incremental rebuild (10s - 2min for Java)
vespa-dev java
vespa-dev install

# Test
vespa-dev system-test tests/search/basicsearch/basic_search.rb
```

### Why This is Fast
1. **Maven incremental compilation**: Only recompiles changed .java files
2. **Make incremental compilation**: Only recompiles changed .cpp files
3. **ccache**: Caches compiled C++ objects across clean builds
4. **Maven offline mode**: Uses cached dependencies, no remote checks
5. **Build markers**: Prevent automatic rebuilds on container start

### When to Use --force
- Build errors that seem incorrect
- Major refactoring where dependencies might be stale
- After git operations (branch switching, rebasing)
- When in doubt!

### Cache Hit Scenarios
- **Java dependencies**: Cached in `/root/.m2/repository`
- **C++ objects**: Cached in `/root/.ccache` (30-60 minutes saved on rebuilds)
- **Build markers**: Prevent unnecessary rebuilds on container restart
- **Source code**: Persists in volume (no re-cloning needed)

## Testing the Changes

After applying these changes, rebuild your devcontainer:

```bash
# From VS Code Command Palette:
# Dev Containers: Rebuild Container

# Inside the rebuilt container:
vespa-dev status        # Check cache status
ccache -s              # Check ccache statistics
du -sh ~/.m2/repository # Check Maven cache size
```

## Notes

- Volumes persist across container rebuilds as long as they're not explicitly deleted
- Build markers in `$VESPA_HOME/.build-markers/` prevent re-running completed builds
- Use `vespa-dev reset-builds` to force rebuilds if needed
- Use `--force` flags for individual rebuild commands
