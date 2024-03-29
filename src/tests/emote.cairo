// Core imports

use core::debug::PrintTrait;

// Starknet imports

use starknet::testing::set_contract_address;

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports

use zconqueror::config;
use zconqueror::store::{Store, StoreTrait};
use zconqueror::models::game::{Game, GameTrait};
use zconqueror::models::player::Player;
use zconqueror::models::tile::Tile;
use zconqueror::systems::host::IHostDispatcherTrait;
use zconqueror::systems::play::IPlayDispatcherTrait;
use zconqueror::tests::setup::{setup, setup::{Systems, Context, HOST, PLAYER}};

// Constants

const HOST_NAME: felt252 = 'HOST';
const PLAYER_NAME: felt252 = 'PLAYER';
const PRICE: u256 = 1_000_000_000_000_000_000;
const PENALTY: u64 = 60;
const PLAYER_COUNT: u8 = 2;
const PLAYER_INDEX: u32 = 0;
const EMOTE_INDEX: u8 = 12;


#[test]
#[available_gas(1_000_000_000)]
#[should_panic(expected: ('Emote: invalid player', 'ENTRYPOINT_FAILED',))]
fn test_emote_revert_invalid_player() {
    // [Setup]
    let (world, systems, _) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    let game_id = systems.host.create(world, HOST_NAME, PRICE, PENALTY);
    set_contract_address(PLAYER());
    systems.host.join(world, game_id, PLAYER_NAME);
    set_contract_address(HOST());
    systems.host.start(world, game_id);

    // [Emote]
    let game: Game = store.game(game_id);
    let current_player: Player = store.current_player(game);
    let player: Player = store.next_player(game);

    let contract_address = starknet::contract_address_try_from_felt252(player.address);
    set_contract_address(contract_address.unwrap());
    // Execute the emote function
    systems.play.emote(world, game_id, current_player.index, EMOTE_INDEX);
}
