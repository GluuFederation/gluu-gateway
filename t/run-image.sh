#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export HOST_GIT_ROOT="$DIR/.."
export GIT_ROOT="/opt/git"

if [ -z "$1" ]; then
    echo "Missed image parameter, Usage: run-image.sh <image> [<test_spec>]"
    exit 1
fi
export GG_IMAGE_ID="$1"

if [ -z "$2" ]; then
    TEST=""
else
    TEST="/$2"
fi

echo "Building test runner Docker image (please be patient first time)..."
TEST_RUNNER_IMAGE_ID="$(docker build -q $DIR)"
if [ -z "$TEST_RUNNER_IMAGE_ID" ]
then
    echo "test runner image build error"
    exit 1
fi
echo "Done"

docker run --net host --rm -v /var/run/docker.sock:/var/run/docker.sock \
    -v $HOST_GIT_ROOT:$GIT_ROOT \
    -v /tmp:/tmp \
    --env HOST_GIT_ROOT --env GIT_ROOT --env GG_IMAGE_ID \
    $TEST_RUNNER_IMAGE_ID busted -m=$GIT_ROOT/t/lib/?.lua $GIT_ROOT/t/specs$TEST
