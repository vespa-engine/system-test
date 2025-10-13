# Vespa Development Environment Quickstart

This guide provides a simplified, automated way to set up a complete Vespa development environment using the `vespa-dev` script.

## What Does It Do?

The `vespa-dev` script automates all the manual steps required to:
- Set up a container (Docker or Podman) with persistent storage
- Clone the Vespa and system-test repositories
- Build Java and C++ modules
- Configure the development environment
- Provide easy commands for rebuilding and managing the environment

## Prerequisites

### macOS
- **Docker Desktop** or **Podman Desktop** installed
  - Docker: [Download Docker Desktop](https://www.docker.com/products/docker-desktop)
  - Podman: `brew install podman-desktop`
- Resources (Docker/Podman Desktop - Preferences - Resources):
  - CPUs: Minimum 2 (8+ recommended)
  - Memory: Minimum 8 GB (16 GB+ recommended)
  - Disk: 128 GB

### Linux
- **Docker** or **Podman** installed
  - Docker: Follow [official Docker installation](https://docs.docker.com/engine/install/)
  - Podman: Use your distribution's package manager
- For Docker: User added to `docker` group (no sudo required)

### Common Requirements
- SSH key generated (if not already):
  ```bash
  ssh-keygen -t ed25519 -C "your_email@example.com"
  ```

## Quick Start

### 1. One-Time Setup

From the `system-test` repository root:

```bash
./vespa-dev setup
```

This will:
- Automatically detect Docker or Podman
- Pull the `vespa-dev-almalinux-8` image
- Create a persistent volume for build artifacts
- Create and configure the container
- Clone Vespa and system-test repositories
- Build all Java and C++ modules (takes 30-60 minutes)

**Note**: The first build takes a while. Grab a coffee! ☕

### 2. Access the Container

Once setup is complete, SSH into the container:

```bash
ssh -A 127.0.0.1 -p 3334
```

Or use the helper command:

```bash
./vespa-dev ssh
```

### 3. Development Workflow

Inside the container, make your code changes, then rebuild:

```bash
# Rebuild everything (Java + C++)
vespa-dev build

# Or rebuild only what you need
vespa-dev build-java
vespa-dev build-cpp
```

The `vespa-dev` script is available in your PATH inside the container!

## Commands Reference

### Host Commands (run from system-test directory)

```bash
# Setup & Management
./vespa-dev setup       # First-time setup (creates container, builds everything)
./vespa-dev start       # Start the container
./vespa-dev stop        # Stop the container
./vespa-dev status      # Check container and build status
./vespa-dev destroy     # Remove container (keeps data volume)

# Quick access
./vespa-dev ssh         # SSH into the container

# Building from host (if container is running)
./vespa-dev build       # Rebuild Java + C++
./vespa-dev build-java  # Rebuild only Java
./vespa-dev build-cpp   # Rebuild only C++
./vespa-dev clean       # Clean build artifacts
```

### Inside Container Commands

Once SSH'd into the container, you can use `vespa-dev` directly:

```bash
vespa-dev build         # Rebuild Vespa (Java + C++)
vespa-dev build-java    # Rebuild only Java modules
vespa-dev build-cpp     # Rebuild only C++ modules
vespa-dev clean         # Clean build caches
vespa-dev status        # Show repo and build status
```

## Directory Structure

### On Host

```
system-test/
├── vespa-dev                    # Main automation script
└── VESPA-DEV-QUICKSTART.md      # This file
```

### In Container (after setup)

```
$HOME/
├── git/
│   ├── vespa/              # Vespa source code
│   └── system-test/        # System test framework
├── vespa/                  # Vespa installation ($VESPA_HOME)
├── .m2/                    # Maven cache (persisted)
└── .ccache/                # C++ compilation cache (persisted)
```

## Persistent Storage

Build artifacts and caches are stored in a persistent volume that survives container restarts:

- **macOS**: Named Docker/Podman volume (`volume-vespa-dev-almalinux-8`)
- **Linux**: Directory volume (`$HOME/volumes/vespa-dev-almalinux-8`)

This means:
- ✅ Subsequent builds are much faster (using Maven and ccache)
- ✅ Your changes persist between container restarts
- ✅ You can destroy and recreate the container without losing data

## Running System Tests

After setup is complete and you've SSH'd into the container:

### 1. Start the node server (in one terminal)

```bash
nodeserver.sh
```

### 2. Run a test (in another terminal)

```bash
# SSH into container again in a new terminal
ssh -A 127.0.0.1 -p 3334

# Run a specific test
runtest.sh $HOME/git/system-test/tests/search/basicsearch/basic_search.rb
```

## Common Workflows

### Daily Development

```bash
# 1. Start container (if not running)
./vespa-dev start

# 2. SSH in
./vespa-dev ssh

# 3. Inside container: make changes, then rebuild
cd ~/git/vespa
# ... edit files ...
vespa-dev build-java    # if you changed Java code
vespa-dev build-cpp     # if you changed C++ code
```

### After Pulling Latest Changes

```bash
ssh -A 127.0.0.1 -p 3334
cd ~/git/vespa
git pull
vespa-dev build
```

### Clean Rebuild

```bash
ssh -A 127.0.0.1 -p 3334
vespa-dev clean
vespa-dev build
```

### Checking Status

```bash
# From host
./vespa-dev status

# Inside container
vespa-dev status
```

## Runtime Detection

The script automatically detects:
- **Container runtime**: Docker or Podman (tries Podman first, falls back to Docker)
- **Platform**: macOS or Linux
- **CPU cores**: For optimal parallel builds
- **Volume strategy**: Named volumes (macOS) or bind mounts (Linux)

## Troubleshooting

### SSH Connection Refused

Wait a few seconds after starting the container for SSH to be ready:
```bash
./vespa-dev start
sleep 5
./vespa-dev ssh
```

### Build Fails with Out of Memory

Increase Docker/Podman Desktop memory allocation to 16 GB or more.

### Container Won't Start

Check Docker/Podman is running:
```bash
docker info   # or: podman info
```

On macOS with Podman, ensure the Podman machine is running:
```bash
podman machine list
podman machine start   # if needed
```

### Can't Find vespa-dev Command Inside Container

The script should be installed automatically during setup. If missing:
```bash
# Exit container and re-run configuration
./vespa-dev stop
./vespa-dev start
# Configuration runs automatically on setup, but you can also access container as root:
docker exec -it vespa-dev-almalinux-8 bash
# Then re-copy the script
```

### Starting Fresh

To completely reset:
```bash
./vespa-dev destroy    # Remove container
docker volume rm volume-vespa-dev-almalinux-8  # Remove volume (macOS)
# or
rm -rf ~/volumes/vespa-dev-almalinux-8  # Remove volume (Linux)

./vespa-dev setup      # Start over
```

## Comparison with Manual Setup

### Manual Setup (from VESPA-DEV-ON-ALMALINUX-8.md)
- Multiple commands to run
- Easy to miss steps
- Need to remember volume types per platform
- Manual repository cloning
- Manual build commands

### Automated Setup (this guide)
- Single `./vespa-dev setup` command
- All steps automated
- Platform detection automatic
- Repositories cloned automatically
- Simple rebuild commands

Both approaches work and are fully compatible. The `vespa-dev` script doesn't modify any existing files or workflows.

## Advanced Usage

### Custom CPU/Memory Settings

For Podman on macOS, you can create a custom machine:
```bash
podman machine init vespa-machine --cpus=16 --memory=32768 --disk-size=256 --rootful
podman machine start vespa-machine
```

### Remote Debugging

The container forwards port 5005 for remote debugging. In IntelliJ or your IDE:
- Host: `127.0.0.1`
- Port: `5005`

Attach the debugger to your running Vespa process.

### Building with Sanitizers

Inside the container:
```bash
cd ~/git/vespa
cmake -DVESPA_USE_SANITIZER=address .
vespa-dev build-cpp
```

See [VESPA-DEV-ON-ALMALINUX-8.md](VESPA-DEV-ON-ALMALINUX-8.md) for more sanitizer options.

## Getting Help

```bash
./vespa-dev help
```

Or see the full development guide: [VESPA-DEV-ON-ALMALINUX-8.md](VESPA-DEV-ON-ALMALINUX-8.md)

## What's Next?

After setup:
1. Explore the [Vespa documentation](https://docs.vespa.ai)
2. Look at existing system tests in `tests/`
3. Try modifying Vespa code and rebuilding
4. Run system tests to verify your changes

Happy coding! 🚀
