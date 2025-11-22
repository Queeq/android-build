#!/usr/bin/env bash
#
# Example Post-Sync Hook
#
# This hook runs after repo sync completes, before the build starts.
# Use it to apply patches, create shims, or configure the source tree.
#
# Available environment variables:
#   DEVICE_CODENAME - Device codename (e.g., "cheetah", "dm1q")
#   MANIFEST_URL    - ROM source repository URL
#   BRANCH_NAME     - Branch being built
#   KERNEL_DIR      - Path to kernel directory
#   SRC_DIR         - Source root (/build/src)
#
# Hook execution:
#   - Hooks run in alphabetical order (use numeric prefixes: 10-first.sh, 20-second.sh)
#   - Hooks run with 'set -e' in entrypoint.sh, so any error will stop the build
#   - Current directory is the source root (SRC_DIR)
#
# Common use cases:
#   1. Apply patches to source tree
#   2. Create product configuration shims
#   3. Adjust partition sizes in BoardConfig.mk
#   4. Generate missing build files
#   5. Clone additional repositories
#

set -e  # Exit on any error

echo ">> Running example post-sync hook for device: ${DEVICE_CODENAME}"

# Example 1: Apply a patch to a specific project
# if [ -d "frameworks/base" ]; then
#     echo ">> Applying custom patch to frameworks/base"
#     cd frameworks/base
#     git am < /build/patches/0001-custom-feature.patch
#     cd "${SRC_DIR}"
# fi

# Example 2: Create a product configuration if it doesn't exist
# DEVICE_TREE="device/manufacturer/${DEVICE_CODENAME}"
# if [ -d "${DEVICE_TREE}" ] && [ ! -f "${DEVICE_TREE}/lineage_${DEVICE_CODENAME}.mk" ]; then
#     echo ">> Creating lineage_${DEVICE_CODENAME}.mk"
#     cat > "${DEVICE_TREE}/lineage_${DEVICE_CODENAME}.mk" <<EOF
# \$(call inherit-product, device/manufacturer/${DEVICE_CODENAME}/aosp_${DEVICE_CODENAME}.mk)
# PRODUCT_NAME := lineage_${DEVICE_CODENAME}
# PRODUCT_DEVICE := ${DEVICE_CODENAME}
# PRODUCT_BRAND := manufacturer
# PRODUCT_MODEL := Device Name
# PRODUCT_MANUFACTURER := manufacturer
# EOF
# fi

# Example 3: Increase partition size for larger builds
# BOARD_CONFIG="${DEVICE_TREE}/BoardConfig.mk"
# if [ -f "${BOARD_CONFIG}" ]; then
#     if ! grep -q "BOARD_PRODUCTIMAGE_PARTITION_SIZE.*3221225472" "${BOARD_CONFIG}"; then
#         echo ">> Increasing product partition size"
#         sed -i 's/BOARD_PRODUCTIMAGE_PARTITION_SIZE.*/BOARD_PRODUCTIMAGE_PARTITION_SIZE := 3221225472/' "${BOARD_CONFIG}"
#     fi
# fi

# Example 4: Clone an additional repository
# if [ ! -d "vendor/custom/package" ]; then
#     echo ">> Cloning custom vendor package"
#     git clone --depth=1 https://github.com/example/vendor-package vendor/custom/package
# fi

# Example 5: Generate a stub file to satisfy build dependencies
# STUB_FILE="hardware/optional/optional.mk"
# if [ ! -f "${STUB_FILE}" ]; then
#     echo ">> Creating stub for ${STUB_FILE}"
#     mkdir -p "$(dirname "${STUB_FILE}")"
#     cat > "${STUB_FILE}" <<'EOF'
# # This is an auto-generated stub
# EOF
# fi

echo ">> Example hook completed successfully"
