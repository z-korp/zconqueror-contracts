#!/bin/bash
set -euo pipefail
pushd $(dirname "$0")/..

export WORLD_ADDRESS="0x45913f69140d1fb00db13514f06cd0503838a75c076637086a25d385e732cbb";
export HOST_ADDRESS="0x9e296cd237ed0ed2f9d65950c6c708c10c4620fdbd76b1a3c1e014a07391f3"
export PLAY_ADDRESS="0x361fc51ac38dde141e478a0f2dde0f5a29797b0e1a3fae9ee3dce9fc681b8a8"

# enable system -> model authorizations

MODELS=("Game" "Player", "Tile")
for model in ${MODELS[@]}; do
    sozo auth writer $model $HOST_ADDRESS --world $WORLD_ADDRESS
    sozo auth writer $model $PLAY_ADDRESS --world $WORLD_ADDRESS
done

echo "Default authorizations have been successfully set."