#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
mkdir -p build
cd build

cmake .. -DCMAKE_BUILD_TYPE=Release
cmake --build . --config Release
ctest -C Release --output-on-failure
