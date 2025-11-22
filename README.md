# Kubernetes Android ROM Build System

A containerized Android ROM build system that runs builds in Kubernetes using Helm charts or standalone Docker. Build LineageOS, crDroid, AOSP, and other custom ROMs with optional [KernelSU-Next](https://github.com/KernelSU-Next/KernelSU-Next) integration.

## Quick Start

### Prerequisites - Kubernetes

- Kubernetes cluster with 500GB+ storage available
- `kubectl` configured to access your cluster
- `helm` installed (v3+)
- `make` installed

### Prerequisites - Docker

- Docker installed
- 500GB+ storage available for build volume
- 16GB+ RAM

### Initial Setup

1. **Clone this repository**
   ```bash
   git clone <your-repo-url>
   cd android-build
   ```

2. **Choose your device branch**

   **Option A: Use existing device branch** (if your device is supported)
   ```bash
   git checkout dm1q-crDroid16  # Samsung Galaxy S23 + crDroid 16
   # See available branches: git branch -r
   ```

   **Option B: Create custom configuration** (for new devices)
   ```bash
   # Stay on master and add your device files
   # - Create manifests/your-device.xml
   # - Add hooks/postSync/*.sh if needed
   ```

3. **Configure your build**
   ```bash
   make config                    # Creates build.env from template
   vim build.env                  # Set DEVICE_CODENAME, MANIFEST_URL, etc.
   ```

### Building on Kubernetes

4. **Adjust cluster resources (optional)**
   ```bash
   # Edit values.yaml to adjust resources and storage for your cluster
   # Build configuration is automatically loaded from build.env
   vim values.yaml
   ```

5. **Deploy and build**
   ```bash
   # This will deploy to Kubernetes and follow the build logs
   make install
   ```

6. **Download your ROM**
   ```bash
   # After build completes, download the ROM zip via SSH
   # The SSH server remains active in the pod for artifact download
   make download
   ```

### Building with Docker

4. **Run the build**
   ```bash
   # Set build storage path
   BUILD_STORAGE=/path/to/build-storage

   # Create storage directory
   mkdir -p $BUILD_STORAGE

   # Run build with configuration from build.env
   docker run -it --rm \
     -v $BUILD_STORAGE:/build \
     -v $(pwd)/manifests:/build/manifests:ro \
     -v $(pwd)/hooks:/build/hooks:ro \
     --env-file build.env \
     ghcr.io/queeq/android-builder:latest
   ```

5. **Access your ROM**
   ```bash
   ls $BUILD_STORAGE/zips/<device>/
   ```

## Branch Structure

This repository uses a branching strategy to support multiple devices:

- **`master`**: Generic template with examples - start here for any device
- **`dm1q-crDroid16`**: Samsung Galaxy S23 example (device-ROM-version naming)
- **Your device**: Create your own branch following the pattern `<device>-<ROM><version>`

Branch naming convention: `<device>-<ROM><version>` (e.g., `cheetah-lineage21`, `davinci-crDroid15`)

Since all manifest files in `manifests/` are used together, each device configuration should have its own branch to avoid conflicts.

## Architecture

- **Helm Chart**: Kubernetes deployment using Job resources for build execution
- **Docker Container**: Ubuntu 22.04-based build environment with Android build tools
- **Persistent Storage**: 500GB+ volume for source code and build artifacts
- **SSH Access**: Built-in SSH server for downloading build results (k8s only)
- **Custom Manifests**: Device-specific Android repo manifests
- **Build Hooks**: Shell scripts that run at specific points in the build process
- **KernelSU-Next**: Optional root solution integration (skipped if KERNEL_DIR not set)

## Configuration

### Build Configuration Files

1. **`build.env`** (gitignored)
   - Single source of truth for build configuration
   - Created from `build.env.example` via `make config`
   - Contains device codename, ROM source URL, branch, etc.
   - Used directly by Docker (`--env-file build.env`)
   - Automatically loaded by Helm for Kubernetes deployments

2. **`values.yaml`** (Kubernetes only)
   - Helm chart configuration (resource limits, storage)
   - Build variables loaded from `build.env` automatically
   - Adjust `resources.limits` and `persistence.size` for your cluster
   - Optional: can override build.env values if needed

3. **`manifests/*.xml`**
   - Android repo manifests defining device repositories
   - All `.xml` files in this directory are used
   - See `manifests/README.md` for details

4. **`hooks/preSync/` and `hooks/postSync/`**
   - Shell scripts that run before/after repo sync
   - Use for patches, shims, partition adjustments
   - See `hooks/README.md` for details

### Environment Variables

Build behavior is controlled via environment variables in `build.env`:

| Variable | Required | Description | Example |
|----------|----------|-------------|---------|
| `MANIFEST_URL` | Yes | ROM source repository URL | `https://github.com/LineageOS/android` |
| `BRANCH_NAME` | Yes | Android version branch | `lineage-21.0` |
| `DEVICE_CODENAME` | Yes | Target device codename | `cheetah`, `dm1q` |
| `KERNEL_DIR` | No | Kernel directory for KernelSU (optional) | `kernel/google/gs201` |
| `SIGN_BUILDS` | No | Enable release signing (default: true) | `true` / `false` |
| `CLEAN` | No | Clean output directory and logs before build | `true` / `false` |
| `GIT_AUTHOR_NAME` | No | Git user name for commits/patches | `Your Name` |
| `GIT_AUTHOR_EMAIL` | No | Git user email for commits/patches | `your@email.com` |
| `PUBLIC_SSH_KEY` | No | SSH key for container access (k8s only) | Your SSH public key |

**Note on optional variables:**
- **KERNEL_DIR**: If empty, KernelSU-Next integration is skipped
- **GIT_AUTHOR_\***: Used to configure git for applying patches or making commits during hooks
- **PUBLIC_SSH_KEY**: Enables SSH access to the build pod for downloading artifacts (Kubernetes only; Docker uses volume mounts directly)

## Common Commands

### Build Management
```bash
make install          # Deploy and start build (runs helm install + watch-build)
make watch-build      # Monitor build progress and logs
make uninstall        # Remove deployment
make download         # Download build artifacts via SSH
make config           # Create build.env from template
```

### Container Management
```bash
make image            # Build, tag and push Docker image
make debug            # Create debug pod with shell access
```

### Development
```bash
make template         # Generate Kubernetes YAML template
```

## Build Process

1. Container initializes with persistent storage mounted
2. SSH server started if `PUBLIC_SSH_KEY` provided (Kubernetes only)
3. Git uses `GIT_AUTHOR_*` environment variables if set
4. Android repo initialized with ROM source from `MANIFEST_URL`
5. Custom device manifests added from `manifests/` directory
6. **preSync hooks** execute (if any)
7. Repo sync downloads source code
8. **postSync hooks** execute (patches, shims, configuration)
9. KernelSU-Next integrated if `KERNEL_DIR` specified
10. Signing keys generated if `SIGN_BUILDS=true`
11. ROM compiled using `brunch <device> userdebug`
12. Build artifacts saved to `/build/zips` or logs to `/build/logs`
13. SSH server remains active for download (Kubernetes) or volume access (Docker)

## Resource Requirements

### Minimum Requirements

- **CPU**: 4+ cores (8+ recommended)
- **Memory**: 16GB RAM (32GB+ recommended for faster builds)
- **Storage**: 500GB persistent volume
- **Build time**: 6-24 hours depending on hardware and ROM

### Kubernetes Resource Adjustment

Edit `values.yaml` to match your cluster capabilities:

```yaml
resources:
  limits:
    cpu: 8          # Adjust based on available CPU
    memory: 32Gi    # Increase for better performance
  requests:
    cpu: 4
    memory: 16Gi

persistence:
  size: 500Gi       # Adjust based on available storage
  storageClass: your-storage-class  # e.g., openebs, local-path
```

## Persistent Storage Structure

The persistent volume at `/build` contains:

```
/build/
├── src/           # Android source code (200GB+)
│   └── .repo/     # CRITICAL: Repo metadata - see warnings below
├── out/           # Build output directory (cleaned if CLEAN=true)
├── ccache/        # Compiler cache
├── zips/          # Final ROM zip files
├── logs/          # Build logs
└── keys/          # Signing keys
```

### CRITICAL: .repo Directory

**NEVER DELETE `/build/src/.repo/` alone**

The `.repo` directory contains git metadata for all projects. Deleting it while leaving source directories orphans hundreds of git repositories and corrupts the repo state.

### Safe Storage Operations

**✅ Delete specific project:**
```bash
rm -rf /build/src/device/samsung/dm1q
# Repo sync will recreate it
```

**✅ Complete wipe:**
```bash
cd /build/src && find . -mindepth 1 -delete
# This removes everything including .repo
```

**❌ Never do this:**
```bash
rm -rf /build/src/.repo  # Orphans source directories
rm -rf /build/src/*       # Leaves .repo (hidden file)
```

## Troubleshooting

### Storage Issues

1. **Check disk usage**: `df -h /build`
2. **Check .repo integrity**: `ls -la /build/src/.repo/`
3. **For complete reset**: Delete the entire PVC and recreate
4. **For project-specific issues**: Delete only that project's source directory

### Build Failures

1. **Check build logs**: `kubectl logs -f -l app=android-build -c build -n android-build`
2. **Check saved logs**: Build logs are saved to `/build/logs/build-<timestamp>.log`
3. **Debug interactively**: Use `make debug` to create a shell session in the build environment (k8s)
4. **Inspect hook output**: Look for errors during preSync/postSync phases
5. **Verify manifests**: Ensure device repositories are accessible
6. **Check resources**: Verify pod has enough CPU/memory allocated

### SSH Access Issues (Kubernetes)

1. **Verify SSH key**: Ensure `PUBLIC_SSH_KEY` is set in values.yaml
2. **Check pod status**: `kubectl get pods -n android-build`
3. **Port forwarding**: The download script handles this automatically via `make download`

## Key Files

- `values.yaml`: Kubernetes build configuration and resource limits
- `Makefile`: Build automation and deployment commands
- `build.env.example`: Template for build configuration
- `manifests/`: Android repo manifest files (device-specific)
- `hooks/`: Build hook scripts (preSync, postSync)
- `docker/entrypoint.sh`: Main build orchestration script
- `docker/Dockerfile`: Container image definition
- `templates/`: Helm chart templates (Job, ConfigMap, PVC)
- `download.sh`: SSH-based artifact download script

## Contributing

See `CONTRIBUTING.md` for information on how to:
- Create device-specific branches
- Customize manifests and hooks
- Build your own Docker image
- Contribute improvements

## Resources

- [Android Source Documentation](https://source.android.com/)
- [Repo Manifest Format](https://gerrit.googlesource.com/git-repo/+/HEAD/docs/manifest-format.md)
- [LineageOS Device Tree Guide](https://wiki.lineageos.org/devices/)
- [KernelSU-Next Documentation](https://github.com/KernelSU-Next/KernelSU-Next)
