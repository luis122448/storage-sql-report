#!/bin/sh
set -e

# Start Minio server in the background
minio server /data --console-address :9001 &
MINIO_PID=$!

# Wait for Minio to be ready
# The `mc` commands need to wait for the Minio server to start.
# We'll use a loop to try connecting until it's successful.
until mc alias set myminio http://localhost:9000 ${MINIO_ROOT_USER} ${MINIO_ROOT_PASSWORD}; do
    echo "Waiting for Minio server to start..."
    sleep 5
done

# It's possible that the bucket does not exist when the container starts for the first time.
# This script assumes that the bucket is created by some other service or manually.
# If the bucket is not present, the policy will not be applied.

# Apply lifecycle policy to all buckets
# We need to get the list of buckets and apply the policy to each one.
for BUCKET in $(mc ls myminio | awk '{print $4}' | grep -v '^$'); do
    echo "Applying lifecycle policy to bucket: $BUCKET"
    mc ilm import myminio/$BUCKET /etc/minio/lifecycle.json
done

# Wait for the Minio server process to exit to keep the container running
wait $MINIO_PID
