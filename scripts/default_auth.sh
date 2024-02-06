#!/bin/bash
set -euo pipefail
pushd $(dirname "$0")/..

export WORLD_ADDRESS=$(cat ./target/dev/manifest.json | jq -r '.world.address')
export HOST_ADDRESS=$(cat ./target/dev/manifest.json | jq -r '.contracts[] | select(.name == "zconqueror::systems::host::host" ).address')
export PLAY_ADDRESS=$(cat ./target/dev/manifest.json | jq -r '.contracts[] | select(.name == "zconqueror::systems::play::play" ).address')

# enable system -> model authorizations

MODELS=("Game" "Player" "Tile")
for model in ${MODELS[@]}; do
    sozo auth writer $model $HOST_ADDRESS --world $WORLD_ADDRESS
    sleep 1
    sozo auth writer $model $PLAY_ADDRESS --world $WORLD_ADDRESS
    sleep 1
done

echo "Default authorizations have been successfully set."