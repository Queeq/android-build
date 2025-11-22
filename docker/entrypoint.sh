#!/usr/bin/env bash
set -euo pipefail

# Env variables expected:
# MANIFEST_URL, BRANCH_NAME, DEVICE_CODENAME
# KERNEL_DIR (kernel folder, relative to SRC_DIR; e.g. "kernel/samsung/sm8550")
# SIGN_BUILDS (true/false)
# KEYS_SUBJECT (if SIGN_BUILDS=true)
# PUBLIC_SSH_KEY (optional)
# CLEAN (true/false)
# ZIPS_DIR (output folder for built stuff)

run_hooks() {  # $1 = phase (preSync / postSync / etc.)
  local phase=$1 dir=/build/hooks

  for script in "$dir"/${phase}__*.sh; do
    [ -f "$script" ] || continue
    echo ">> Hook [$phase] $(basename "$script")"

    (
      # isolate options from the parent; exit on first error
      set -euo pipefail

      # if the file is already executable and has a she-bang, call it directly
      if [ -x "$script" ]; then
        "$script"
      else                # otherwise force bash with -e for fail-fast
        bash -e "$script"
      fi
    )
  done
}


echo "Source directory is $SRC_DIR"
echo "Output directory is $ZIPS_DIR"

# Ensure all required directories exist
mkdir -p "$SRC_DIR" "$OUT_DIR" "$KEYS_DIR" "$LOGS_DIR" "$ZIPS_DIR"

SSH_PORT=2222

# Set up authorized SSH keys if provided
if [ -n "${PUBLIC_SSH_KEY:-}" ]; then
    echo ">> Configuring SSH access..."
    mkdir -p "$HOME/.ssh"
    echo "$PUBLIC_SSH_KEY" > "$HOME/.ssh/authorized_keys"
    chmod 700 "$HOME/.ssh"
    chmod 600 "$HOME/.ssh/authorized_keys"
fi

# Start the SSH server on the unprivileged port
echo ">> Starting SSH server on port $SSH_PORT..."
/usr/sbin/sshd -D -p "$SSH_PORT" &
SSH_PID=$!

# KernelSU install script download and removal (for clean kernel sources state)
# Only if KERNEL_DIR is specified
if [ -n "${KERNEL_DIR:-}" ]; then
    curl -LSs "https://raw.githubusercontent.com/KernelSU-Next/KernelSU-Next/next/kernel/setup.sh" > /tmp/kernelsu_setup.sh
    if [ -d "$SRC_DIR/$KERNEL_DIR" ]; then
        cd "$SRC_DIR/$KERNEL_DIR"
        echo ">> Cleaning up KernelSU..."
        bash -e /tmp/kernelsu_setup.sh --cleanup || true
    fi
else
    echo ">> Skipping KernelSU (KERNEL_DIR not specified)"
fi

cd "$SRC_DIR"

# Initialize and sync repository
if [ ! -d .repo ]; then
    echo ">> Initializing repo..."
    repo init -u "$MANIFEST_URL" -b "$BRANCH_NAME" --git-lfs
fi

# Copy custom manifests if present
if [ -d "$MANIFESTS_DIR" ] && [ "$(ls -A "$MANIFESTS_DIR")" ]; then
    echo ">> Copying custom manifests to .repo/local_manifests..."
    mkdir -p .repo/local_manifests
    rm -R .repo/local_manifests/*.xml || true
    cp -v "$MANIFESTS_DIR"/*.xml .repo/local_manifests/
fi

run_hooks preSync

echo ">> Syncing repo..."
repo sync -j$(nproc) -c --force-sync --no-clone-bundle --no-tags --optimized-fetch

run_hooks postSync

# Optionally clean before building
if [ "${CLEAN:-false}" = "true" ]; then
    echo ">> Cleaning out directory..."
    rm -rf "$OUT_DIR"
    mkdir -p "$OUT_DIR"
    echo ">> Cleaning up old logs..."
    rm -f "$LOGS_DIR"/*.log || true
fi

# Set up signing keys if SIGN_BUILDS is true
if [ "${SIGN_BUILDS:-false}" = "true" ]; then
    # Generate keys if they do not exist
    cd "$KEYS_DIR"
    for c in bluetooth media networkstack nfc platform releasekey sdk_sandbox shared testkey verity; do
      if [ ! -f "$c.pk8" ]; then
        echo ">> Generating key for $c..."
        /make_key.sh "$KEYS_DIR/$c" "${KEYS_SUBJECT:-/CN=Android}" <<< '' > /dev/null
      fi
    done

    # For older ROMs that require symbolic links:
    for c in cyngn-priv-app cyngn-app testkey; do
        for e in pk8 x509.pem; do
            ln -sf releasekey.$e "$KEYS_DIR/$c.$e" 2> /dev/null || true
        done
    done
fi

cd "$SRC_DIR"

# Source environment
echo ">> Sourcing build environment..."
set +eu
. build/envsetup.sh
set -eu

# Add KernelSU (https://kernelsu.org/guide/how-to-build.html)
# Only if KERNEL_DIR is specified
if [ -n "${KERNEL_DIR:-}" ]; then
    echo ">> Setting up KernelSU in $KERNEL_DIR..."
    cd "$SRC_DIR/$KERNEL_DIR"
    bash -e /tmp/kernelsu_setup.sh
    cd "$SRC_DIR"
else
    echo ">> Skipping KernelSU setup (KERNEL_DIR not specified)"
fi

# Detect optimal build parallelism
. /detect_build_jobs.sh

# Start the build
LOGFILE="$LOGS_DIR/build-$(date +%Y.%m.%d-%H:%M:%S).log"
echo ">> Starting build for $DEVICE_CODENAME on branch $BRANCH_NAME (parallelism: -j${BUILD_JOBS})"
echo ">> Build log: $LOGFILE"
set +eu
brunch "$DEVICE_CODENAME" "userdebug" -j${BUILD_JOBS} > "$LOGFILE" 2>&1
rc=$?
set -eu

if [ $rc -eq 0 ]; then
   echo ">> Build completed successfully!"
   echo "success" > /tmp/status
   target_dir="$ZIPS_DIR/$DEVICE_CODENAME/$(date +%Y.%m.%d)"
   echo ">> Removing any previous artifacts..."
   rm -rf "$ZIPS_DIR/$DEVICE_CODENAME"/*
   echo ">> Moving build artifacts to $target_dir..."
   mkdir -p "$target_dir"
   mv -v "$OUT_DIR"/target/product/"$DEVICE_CODENAME"/*{".zip",".img"} "$target_dir/" || true
else
   echo ">> Build failed! See $LOGFILE for details."
   echo "failed" > /tmp/status
fi

echo ">> Build finished. SSH server remains active for downloading results."
echo ">> Waiting for shutdown signal (touch /tmp/shutdown) to exit gracefully."
while [ ! -f /tmp/shutdown ]; do
    sleep 10
done

echo ">> Shutdown signal detected. Exiting gracefully."
exit 0
