#!/bin/bash
set -euo pipefail
mkdir -p output
docker run --privileged --rm -v "$(pwd)/output:/output" -v "$(pwd)/supportFiles:/supportFiles:ro" -w /supportFiles debian:buster bash
