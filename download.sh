#!/usr/bin/env bash
set -euo pipefail

# Use the provided environment variables or fallback to these defaults.
: ${NAMESPACE:=android-build}
: ${APP:=android-build}
: ${LOCAL_PORT:=2222}
: ${DOWNLOAD_DIR:=$(pwd)/download}
: ${SSH_USER:=androidbuilder}

echo "Using namespace: ${NAMESPACE}"
echo "Using app label: ${APP}"
echo "Local SSH port: ${LOCAL_PORT}"
echo "Download directory: ${DOWNLOAD_DIR}"

# Look up the pod by the label (assumes the pod is labeled with app=${APP})
POD=$(kubectl get pod -l app=${APP} -n ${NAMESPACE} -o jsonpath='{.items[0].metadata.name}')
if [ -z "$POD" ]; then
    echo "Error: No pod found with label app=${APP} in namespace ${NAMESPACE}"
    exit 1
fi
echo "Found pod: ${POD}"

# Start port-forwarding: map pod's port 2222 to the local port.
echo "Starting port-forward on local port ${LOCAL_PORT}..."
kubectl port-forward pod/${POD} ${LOCAL_PORT}:2222 -n ${NAMESPACE} >/dev/null 2>&1 &
PF_PID=$!
echo "Port-forward PID: ${PF_PID}"

# Ensure the port-forward process is terminated when this script exits.
cleanup() {
    echo "Cleaning up port-forward..."
    kill ${PF_PID} 2>/dev/null || true
}
trap cleanup EXIT

# Wait until the SSH server in the container is available.
echo "Waiting for SSH server to be ready..."
tries=0
max_tries=12
until ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no -p ${LOCAL_PORT} ${SSH_USER}@localhost exit >/dev/null 2>&1; do
    tries=$((tries+1))
    if [ ${tries} -ge ${max_tries} ]; then
        echo "Error: SSH connection not available after $((max_tries * 5)) seconds."
        exit 1
    fi
    sleep 5
done
echo "SSH is up!"

# Read the build status from /tmp/status.
echo "Checking build status..."
STATUS=$(ssh -o StrictHostKeyChecking=no -p ${LOCAL_PORT} ${SSH_USER}@localhost cat /tmp/status 2>/dev/null || echo "unknown")
echo "Build status: ${STATUS}"

# Based on the status, decide which files to download.
if [ "${STATUS}" = "success" ]; then
    echo "Build succeeded; downloading artifacts from /build/zips..."
    REMOTE_DIR="/build/zips/*"
    LOCAL_TARGET_DIR="${DOWNLOAD_DIR}/zips"
elif [ "${STATUS}" = "failed" ]; then
    echo "Build failed; downloading logs from /build/logs..."
    REMOTE_DIR="/build/logs/*"
    LOCAL_TARGET_DIR="${DOWNLOAD_DIR}/logs"
else
    echo "Build status unknown; downloading logs from /build/logs..."
    REMOTE_DIR="/build/logs/*"
    LOCAL_TARGET_DIR="${DOWNLOAD_DIR}/logs"
fi

mkdir -p "${LOCAL_TARGET_DIR}"
echo "Downloading files to ${LOCAL_TARGET_DIR}..."
scp -P ${LOCAL_PORT} -r -o StrictHostKeyChecking=no ${SSH_USER}@localhost:"${REMOTE_DIR}" "${LOCAL_TARGET_DIR}/"
echo "Download complete. Files stored in ${LOCAL_TARGET_DIR}."

echo "Sending shutdown signal to the container..."
ssh -o StrictHostKeyChecking=no -p ${LOCAL_PORT} ${SSH_USER}@localhost "touch /tmp/shutdown"

echo "Waiting for the pod to complete gracefully..."
kubectl wait --for=condition=complete pod/${POD} -n ${NAMESPACE} --timeout=60s
echo "Pod has completed. Exiting download script."

