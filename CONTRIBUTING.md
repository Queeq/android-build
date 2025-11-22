# Contributing to Android Build System

Thank you for your interest in contributing! This document explains how to use and customize this build system for your device.

## Branch Strategy

This repository uses a branching strategy to support multiple devices:

```
master (generic template)
├── dm1q-crDroid16 (Samsung Galaxy S23 example)
│   └── queeq (personal config - local only)
├── cheetah-lineage21 (your device configuration)
│   └── your-personal (your personal config - local only)
```

### Branch Types

1. **`master` branch**: Generic template
   - Example manifest and hooks
   - Generic values.yaml with placeholders
   - Start here for any device
   - Public and open source

2. **Device branches** (e.g., `dm1q-crDroid16`, `cheetah-lineage21`): Device-specific configuration
   - Branch naming: `<device>-<ROM><version>` (e.g., `davinci-crDroid15`)
   - Device-specific manifests (e.g., `dm1q.xml`)
   - Device-specific hooks (e.g., partition adjustments, shims)
   - Device codename, ROM, and kernel path configured
   - No personal details (SSH keys, git info)
   - Public and open source (can be shared)

3. **Personal branches** (e.g., `queeq`): Your private configuration
   - Inherits device configuration
   - Adds personal SSH key, git author info
   - Local only - NOT pushed to GitHub
   - Private to you

## Creating a Device Branch

### Option 1: Start from Scratch

1. **Create a new branch from master**
   ```bash
   git checkout master
   git checkout -b cheetah-lineage21  # Format: <device>-<ROM><version>
   ```

2. **Create your device manifest**
   ```bash
   # Remove the example manifest
   rm manifests/example-manifest.xml

   # Create your device manifest
   vim manifests/cheetah.xml
   ```

   Example structure:
   ```xml
   <?xml version="1.0" encoding="UTF-8"?>
   <manifest>
     <remote name="device-maintainer"
             fetch="https://github.com/username"
             revision="lineage-21.0" />

     <project path="device/manufacturer/codename"
              name="android_device_manufacturer_codename"
              remote="device-maintainer" />

     <project path="kernel/manufacturer/platform"
              name="android_kernel_manufacturer_platform"
              remote="device-maintainer" />

     <project path="vendor/manufacturer/codename"
              name="proprietary_vendor_manufacturer_codename"
              remote="device-maintainer" />
   </manifest>
   ```

3. **Update build.env.example**
   ```bash
   # Update with your device-specific values
   vim build.env.example
   # Set DEVICE_CODENAME="cheetah"
   # Set MANIFEST_URL="https://github.com/LineageOS/android"
   # Set BRANCH_NAME="lineage-21.0"
   # Set KERNEL_DIR="kernel/google/gs201"
   ```

4. **Create hooks if needed**
   ```bash
   # Remove example hook
   rm hooks/postSync/example-hook.sh

   # Create your hooks if needed
   vim hooks/postSync/10-cheetah-setup.sh
   chmod +x hooks/postSync/10-cheetah-setup.sh
   ```

5. **Commit and push**
   ```bash
   git add .
   git commit -m "Add cheetah-lineage21 configuration"
   git push origin cheetah-lineage21
   ```

### Option 2: Fork an Existing Device Branch

If you have a similar device, fork an existing branch:

```bash
# Start from dm1q-crDroid16 example (similar Samsung device)
git checkout dm1q-crDroid16
git checkout -b dm2q-crDroid16  # Your similar device

# Modify for your device
vim manifests/dm2q.xml          # Update device repos
vim build.env.example           # Update DEVICE_CODENAME, KERNEL_DIR
vim hooks/postSync/*.sh         # Adjust if needed

git add .
git commit -m "Add dm2q-crDroid16 configuration"
git push origin dm2q-crDroid16
```

## Manifest System

### How Manifests Work

- **All `.xml` files** in `manifests/` are automatically included
- They are layered on top of your base ROM's default manifest
- This is why each device needs its own branch

### Adding Device Repositories

Your manifest should include:

1. **Device tree**: `device/manufacturer/codename`
2. **Kernel**: `kernel/manufacturer/platform`
3. **Vendor blobs**: `vendor/manufacturer/codename`
4. **Hardware support** (if needed): `hardware/manufacturer`

### Removing Base Projects

If you need to replace a ROM's default project:

```xml
<!-- Remove the default kernel -->
<remove-project name="LineageOS/android_kernel_default" />

<!-- Add your custom kernel -->
<project path="kernel/custom/platform"
         name="android_kernel_custom_platform"
         remote="your-remote" />
```

## Hook System

### Hook Phases

- **`preSync/`**: Run before repo sync (rarely needed)
- **`postSync/`**: Run after repo sync, before build (most common)

### Hook Execution

- Hooks execute in alphabetical order
- Use numeric prefixes: `10-first.sh`, `20-second.sh`, `30-third.sh`
- All hooks must be executable (`chmod +x`)
- Hooks run with `set -e`, so errors stop the build

### Common Hook Patterns

1. **Product configuration shims**
   ```bash
   #!/usr/bin/env bash
   set -e

   DEVICE_TREE="device/manufacturer/${DEVICE_CODENAME}"
   LINEAGE_MK="${DEVICE_TREE}/lineage_${DEVICE_CODENAME}.mk"

   if [ ! -f "${LINEAGE_MK}" ]; then
       cat > "${LINEAGE_MK}" <<EOF
   $(call inherit-product, ${DEVICE_TREE}/aosp_${DEVICE_CODENAME}.mk)
   PRODUCT_NAME := lineage_${DEVICE_CODENAME}
   EOF
   fi
   ```

2. **Partition size adjustments**
   ```bash
   #!/usr/bin/env bash
   set -e

   BOARD_CONFIG="device/manufacturer/${DEVICE_CODENAME}/BoardConfig.mk"

   sed -i 's/BOARD_PRODUCTIMAGE_PARTITION_SIZE.*/BOARD_PRODUCTIMAGE_PARTITION_SIZE := 3221225472/' "${BOARD_CONFIG}"
   ```

3. **Applying patches**
   ```bash
   #!/usr/bin/env bash
   set -e

   if [ -d "frameworks/base" ]; then
       cd frameworks/base
       git am < /build/patches/0001-feature.patch
       cd "${SRC_DIR}"
   fi
   ```

## Building Your Own Docker Image

If you need a customized build environment:

1. **Modify the Dockerfile**
   ```bash
   vim docker/Dockerfile
   # Add your custom tools, dependencies, etc.
   ```

2. **Update Makefile registry**
   ```bash
   # In Makefile, change:
   REGISTRY_ADDRESS := ghcr.io
   IMAGE_NAME := your-username/android-builder
   ```

3. **Build and push**
   ```bash
   make image
   ```

4. **Use your image**
   ```bash
   # Makefile will automatically use your registry
   make install
   ```

## Creating a Personal Branch

For your private configuration with SSH keys and git settings:

1. **Create from your device branch**
   ```bash
   git checkout cheetah-lineage21
   git checkout -b my-personal
   ```

2. **Add personal details to build.env.example**
   ```bash
   vim build.env.example
   # Set GIT_AUTHOR_NAME="Your Name"
   # Set GIT_AUTHOR_EMAIL="your@email.com"
   # Set PUBLIC_SSH_KEY="ssh-ed25519 AAAA..."
   ```

3. **Commit your changes**
   ```bash
   git add build.env.example
   git commit -m "Add personal configuration"
   ```

4. **Prevent accidental push** (strongly recommended)
   ```bash
   # Create pre-push hook to block this branch
   cat > .git/hooks/pre-push << 'EOF'
#!/bin/bash
# Pre-push hook to prevent pushing personal branches

while read local_ref local_sha remote_ref remote_sha
do
    if [[ "$local_ref" =~ refs/heads/my-personal ]]; then
        echo "ERROR: Refusing to push 'my-personal' branch (contains personal configuration)"
        echo "This branch should remain local only."
        exit 1
    fi
done

exit 0
EOF

   chmod +x .git/hooks/pre-push
   ```

   Replace `my-personal` with your actual branch name if different.

## Submitting Improvements

### For Generic Improvements (master branch)

1. Fork the repository
2. Create a feature branch from `master`
3. Make your changes
4. Test thoroughly
5. Submit a pull request to `master`

### For Device Examples

1. Fork the repository
2. Create your device branch
3. Ensure no personal details are included
4. Submit a pull request for your device branch
5. Include README updates explaining your device

## Guidelines

### What to Include in Device Branches

✅ **Include:**
- Device manifests
- Device-specific hooks
- Device codename and kernel path
- Build configuration flags
- Example build.env with device values

❌ **Don't Include:**
- Personal SSH keys
- Personal git author information
- Passwords or secrets
- Build artifacts or logs

### Code Quality

- Comment your hooks well
- Explain why specific changes are needed
- Test builds before submitting
- Keep changes focused and minimal

### Documentation

- Update README if you add features
- Document device-specific quirks in commit messages
- Add comments to complex hooks

## Getting Help

- **Issues**: Open a GitHub issue for bugs or questions
- **Discussions**: Use GitHub Discussions for general questions
- **Examples**: Check the `dm1q-crDroid16` branch for a complete working example

## Resources

- [Android Source Documentation](https://source.android.com/)
- [Repo Manifest Format](https://gerrit.googlesource.com/git-repo/+/HEAD/docs/manifest-format.md)
- [LineageOS Build Guide](https://wiki.lineageos.org/build_guides)
- [Helm Chart Best Practices](https://helm.sh/docs/chart_best_practices/)
