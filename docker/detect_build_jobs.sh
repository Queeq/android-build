#!/usr/bin/env bash
# Detects optimal BUILD_JOBS value based on container memory limits
# Sources this script to set BUILD_JOBS variable

if [ "${BUILD_JOBS:-auto}" = "auto" ]; then
    # Auto-detect from cgroup memory limit
    MEMORY_LIMIT_BYTES=0

    # Try cgroup v2 first (newer systems)
    if [ -f /sys/fs/cgroup/memory.max ]; then
        LIMIT=$(cat /sys/fs/cgroup/memory.max)
        if [ "$LIMIT" != "max" ]; then
            MEMORY_LIMIT_BYTES=$LIMIT
        fi
    fi

    # Fall back to cgroup v1 (older systems)
    if [ "$MEMORY_LIMIT_BYTES" -eq 0 ] && [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
        LIMIT=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes)
        # Very large number (max int64) means no limit
        if [ "$LIMIT" -lt 9223372036854771712 ]; then
            MEMORY_LIMIT_BYTES=$LIMIT
        fi
    fi

    if [ "$MEMORY_LIMIT_BYTES" -gt 0 ]; then
        # Convert to GB and calculate jobs (memory_GB / 5)
        MEMORY_GB=$((MEMORY_LIMIT_BYTES / 1024 / 1024 / 1024))
        BUILD_JOBS=$((MEMORY_GB / 5))
        # Ensure at least 4 jobs, cap at 20
        [ "$BUILD_JOBS" -lt 4 ] && BUILD_JOBS=4
        [ "$BUILD_JOBS" -gt 20 ] && BUILD_JOBS=20
        echo ">> Auto-detected container memory: ${MEMORY_GB}GB, setting BUILD_JOBS=$BUILD_JOBS"
    else
        # No cgroup limit detected, use conservative default
        BUILD_JOBS=8
        echo ">> No container memory limit detected, using BUILD_JOBS=$BUILD_JOBS (default)"
    fi
else
    echo ">> Using configured BUILD_JOBS=$BUILD_JOBS"
fi

export BUILD_JOBS
