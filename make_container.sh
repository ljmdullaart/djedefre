#!/bin/bash

set -e

echo "=== 1. Build Docker image ==="
sudo docker build --no-cache -t djedefre-base .

echo "=== 2. Start Djedefre ==="
echo 'Kill with:'
echo 'sudo docker kill $(sudo docker ps -q --filter ancestor=djedefre-base)'

# CORRECTE SYNTAX: Alle -p argumenten MOETEN voor 'djedefre-base' staan!
sudo docker run --rm \
  -p 3001:3000 \
  -p 2222:22 \
  -p 2323:23 \
  --name djedefre-container \
  djedefre-base

