#!/usr/bin/env bash

set -euo pipefail

ROOT=$(git rev-parse --show-toplevel)
: ${LOCALSTACK_API_KEY:? This script requires a BYO Localstack Pro key. }

docker-compose --project-name repro down --remove-orphans
docker-compose --project-name repro --file ${ROOT}/docker-compose.yml up
