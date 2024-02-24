#!/bin/bash
set -euo pipefail
pushd $(dirname "$0")/..

export RPC_URL="http://localhost:5050";
# export RPC_URL="https://api.cartridge.gg/x/zconqueror/katana";

export WORLD_ADDRESS=$(cat ./target/dev/manifest.json | jq -r '.world.address')
export HOST_ADDRESS=$(cat ./target/dev/manifest.json | jq -r '.contracts[] | select(.name == "zconqueror::systems::host::host" ).address')
export PLAY_ADDRESS=$(cat ./target/dev/manifest.json | jq -r '.contracts[] | select(.name == "zconqueror::systems::play::play" ).address')

echo "---------------------------------------------------------------------------"
echo world : $WORLD_ADDRESS 
echo " "
echo host : $HOST_ADDRESS
echo play : $PLAY_ADDRESS
echo "---------------------------------------------------------------------------"

# enable system -> model authorizations

MODELS=("Game" "Player" "Tile")
CONTRACTS=($HOST_ADDRESS $PLAY_ADDRESS)
for model in ${MODELS[@]}; do
    for contract in ${CONTRACTS[@]}; do
        sozo auth writer $model $contract --world $WORLD_ADDRESS --rpc-url $RPC_URL
        sleep 1
    done
done

echo "Default authorizations have been successfully set."