#!/usr/bin/env bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

export HOST_GIT_ROOT="$DIR/.."
export GIT_ROOT="/opt/git"

if [ -z "$1" ]; then
    TEST=""
else
    TEST="/$1"
fi

echo "Building test runner Docker image (please be patient first time)..."
TEST_RUNNER_IMAGE_ID="$(docker build -q $DIR)"
echo "Done"

docker run --net host --rm -v /var/run/docker.sock:/var/run/docker.sock \
    -v $HOST_GIT_ROOT:$GIT_ROOT \
    -v /tmp:/tmp \
    --env HOST_GIT_ROOT --env GIT_ROOT \
    $TEST_RUNNER_IMAGE_ID busted -m=$GIT_ROOT/t/lib/?.lua $GIT_ROOT/t/specs$TEST
