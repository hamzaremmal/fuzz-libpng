#!/bin/bash
set -euxo pipefail

# Clone oss-fuzz if not already cloned
if [ ! -d "oss-fuzz" ]; then
  git clone --depth=1 https://github.com/hamzaremmal/fuzz-libpng.git -b part4/oss-fuzz oss-fuzz
fi

cd oss-fuzz

# Download PoC input if not already present
[ -f poc_crash ] || wget -O poc_crash "https://oss-fuzz.com/download?testcase_id=5006459651293184"

# Build image with the vulnerable commit
python3 infra/helper.py build_image libpng

# Build fuzzers with UBSan
python3 infra/helper.py build_fuzzers libpng --sanitizer undefined

# Reproduce crash
python3 infra/helper.py reproduce libpng libpng_read_fuzzer poc_crash
