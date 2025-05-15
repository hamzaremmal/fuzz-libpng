#!/usr/bin/env bash
set -Eeuo pipefail

###################################################################################################
############################## CONFIGURE A TEMPORARY WORK DIRECTORY ###############################
###################################################################################################
export WORKDIR="$(mktemp -d)"
echo "Using temp directory: $WORKDIR"

cleanup() {
    echo "cleaning the working directory: $WORKDIR"
    rm -rf "$WORKDIR";
}
trap cleanup EXIT

cd "$WORKDIR"

###################################################################################################
###################################### CONFIGURE THE SCRIPT #######################################
###################################################################################################

# configure the script
export PROJECT=libpng
export CORPUS="$WORKDIR/build/out/corpus"
export HARNESS=libpng_read_fuzzer
export REPOSITORY=https://github.com/hamzaremmal/fuzz-libpng.git
export DURATION=14400  # 4 hours in seconds (4 * 60 * 60)

###################################################################################################
########################################## FUZZING SCRIPT #########################################
###################################################################################################

# Make sure the corpus directory exists
echo "Making sure the corpus directory exists"
mkdir -p "$CORPUS"

# clone the oss-fuzz repository with corpus
echo "Cloning the oss-fuzz tree from $REPOSITORY"
git clone --depth 1 "$REPOSITORY" -b with-corpus/oss-fuzz oss-fuzz
cd oss-fuzz

# build the image for libpng
# NOTE: this builds for the host architecture anyways
echo "Building images for project: $PROJECT"
python3 infra/helper.py build_image "$PROJECT"

# build the fuzzers for libpng
echo "Building fuzzers for project: $PROJECT"
python3 infra/helper.py build_fuzzers \
    --clean \
    "$PROJECT"

# run the fuzzer for 4 hours
echo "Running fuzzer for project '$PROJECT' with harness '$HARNESS'"
python3 infra/helper.py run_fuzzer \
    --corpus-dir "$CORPUS" \
    "$PROJECT" "$HARNESS" \
    -e FUZZER_ARGS=-max_total_time=$DURATION \

# build the fuzzer for coverage
echo "Building the coverage fuzzer for project: $PROJECT"
python3 infra/helper.py build_fuzzers \
    --sanitizer coverage \
    "$PROJECT"

# build the coverage
echo "Building the coverage for project '$PROJECT' for harness '$HARNESS'"
python3 infra/helper.py coverage \
    --corpus-dir "$CORPUS" \
    --fuzz-target "$HARNESS" \
    --no-corpus-download \
    "$PROJECT"
