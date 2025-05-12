#!/bin/bash
set -euxo pipefail

# Clone oss-fuzz if not already cloned
if [ ! -d "oss-fuzz" ]; then
  git clone https://github.com/google/oss-fuzz.git
fi

cd oss-fuzz

# Download PoC input if not already present
[ -f poc_crash ] || wget -O poc_crash "https://oss-fuzz.com/download?testcase_id=5006459651293184"

# Inject vulnerable Dockerfile for libpng
cat > projects/libpng/Dockerfile <<'EOF'
# Copyright 2016 Google Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
################################################################################
FROM gcr.io/oss-fuzz-base/base-builder

RUN apt-get update && \
    apt-get install -y make autoconf automake libtool zlib1g-dev

RUN git clone https://github.com/madler/zlib.git $SRC/zlib
WORKDIR $SRC/zlib
RUN git checkout d476828316d05d54c6fd6a068b121b30c147b5cd

RUN git clone https://github.com/pnggroup/libpng.git $SRC/libpng
WORKDIR $SRC/libpng
RUN git checkout 20f819c29e49f4b8c1d38e3f475b82a9cdce0da6

RUN cp contrib/oss-fuzz/build.sh $SRC
RUN bash $SRC/build.sh
EOF

# Build image with the vulnerable commit
python3 infra/helper.py build_image libpng

# Build fuzzers with UBSan
python3 infra/helper.py build_fuzzers libpng --sanitizer undefined libpng

# Reproduce crash
python3 infra/helper.py reproduce libpng libpng_read_fuzzer poc_crash
