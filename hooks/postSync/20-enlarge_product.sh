#!/usr/bin/env bash
set -euo pipefail

DEVICE_BC=device/samsung/dm1q/BoardConfig.mk
COMMON_BC=device/samsung/sm8550-common/BoardConfigCommon.mk

inc=$((600*1024*1024))            # 600 MiB in bytes

# 1. enlarge BOARD_SUPER_PARTITION_SIZE (tab OR space safe)
orig=$(grep -E '^[[:space:]]*BOARD_SUPER_PARTITION_SIZE[[:space:]:=]+' "$DEVICE_BC" \
       | head -n1 | tr -d '\t' | tr -s ' ' | cut -d' ' -f3 )
[ -z "$orig" ] && { echo "BOARD_SUPER_PARTITION_SIZE not found"; exit 1; }

new=$((orig + inc))
# replace the entire line regardless of spacing
sed -i -E "s|^[[:space:]]*BOARD_SUPER_PARTITION_SIZE[[:space:]:=]+.*|BOARD_SUPER_PARTITION_SIZE := $new|" "$DEVICE_BC"
echo "  super size bumped from $orig to $new bytes"

# 2. ensure single, byte-based reserve lines in common board file
# strip any old duplicates first
sed -i -E '/BOARD_(PRODUCT|SYSTEM_EXT)IMAGE_PARTITION_RESERVED_SIZE/d' "$COMMON_BC"

cat >>"$COMMON_BC" <<'EOF'

# Added by CI: head-room for NikGapps (bytes, not "M")
BOARD_PRODUCTIMAGE_PARTITION_RESERVED_SIZE     := 314572800   # 300 MiB
BOARD_SYSTEM_EXTIMAGE_PARTITION_RESERVED_SIZE  := 157286400   # 150 MiB
EOF
