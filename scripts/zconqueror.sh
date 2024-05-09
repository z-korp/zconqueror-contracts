#!/bin/bash
set -euo pipefail
pushd $(dirname "$0")/..

export STARKNET_RPC_URL="https://api.cartridge.gg/x/zconqueror/katana";

export DOJO_WORLD_ADDRESS=$(cat ./manifests/prod/manifest.json | jq -r '.world.address')

export HOST_ADDRESS=$(cat ./manifests/prod/manifest.json | jq -r '.contracts[] | select(.name == "zconqueror::systems::host::host" ).address')
export PLAY_ADDRESS=$(cat ./manifests/prod/manifest.json | jq -r '.contracts[] | select(.name == "zconqueror::systems::play::play" ).address')

echo "---------------------------------------------------------------------------"
echo world : $DOJO_WORLD_ADDRESS 
echo " "
echo host : $HOST_ADDRESS
echo play : $PLAY_ADDRESS
echo "---------------------------------------------------------------------------"

# enable system -> model authorizations

MODELS=("Game" "Player" "Tile")
ACTIONS=($HOST_ADDRESS $PLAY_ADDRESS)

command="sozo auth grant writer "
for model in "${MODELS[@]}"; do
    for action in "${ACTIONS[@]}"; do
        command+="$model,$action "
    done
done
eval "$command"

echo "Default authorizations have been successfully set."