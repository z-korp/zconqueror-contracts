// Core imports

use traits::{Into, TryInto};
use core::result::ResultTrait;
use array::{ArrayTrait, SpanTrait};
use option::OptionTrait;
use box::BoxTrait;
use clone::Clone;
use debug::PrintTrait;

// Starknet imports

use starknet::{ContractAddress, syscalls::deploy_syscall};
use starknet::class_hash::{ClassHash, Felt252TryIntoClassHash};

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
use dojo::test_utils::spawn_test_world;

// Internal imports

use zrisk::constants::TILE_NUMBER;
use zrisk::components::game::Game;
use zrisk::components::player::Player;
use zrisk::components::tile::Tile;
use zrisk::tests::setup::setup;

// Constants

const ACCOUNT: felt252 = 'ACCOUNT';
const SEED: felt252 = 'SEED';
const NAME: felt252 = 'NAME';
const PLAYER_COUNT: u8 = 4;

#[test]
#[available_gas(1_000_000_000)]
fn test_create() {
    // [Setup]
    let world = setup::spawn_game();

    // [Create]
    world.execute('create', array![ACCOUNT, SEED, NAME, PLAYER_COUNT.into()]);

    // [Assert] Game
    let game: Game = get!(world, ACCOUNT, (Game));
    assert(game.id == 0, 'Game: wrong id');
    assert(game.seed == SEED, 'Game: wrong seed');
    assert(game.over == false, 'Game: wrong status');
    assert(game.player_count == PLAYER_COUNT, 'Game: wrong player count');

    // [Assert] Players
    let mut player_index: u8 = 0;
    loop {
        if player_index == PLAYER_COUNT {
            break;
        }
        let player: Player = get!(world, (0, player_index).into(), (Player));
        assert(player.game_id == game.id, 'Player: wrong game id');
        assert(player.order == player_index, 'Player: wrong order');
        assert(player.name == player_index.into() || player.name == NAME, 'Player: wrong name');
        player_index += 1;
    };

    // [Assert] Tiles
    let mut tile_index: u8 = 0;
    loop {
        if TILE_NUMBER == tile_index.into() {
            break;
        }
        let tile: Tile = get!(world, (0, tile_index).into(), (Tile));
        assert(tile.game_id == game.id, 'Tile: wrong game id');
        assert(tile.tile_id == tile_index, 'Tile: wrong tile id');
        assert(tile.army > 0, 'Tile: wrong army');
        assert(tile.owner < PLAYER_COUNT.into(), 'Tile: wrong owner');
        assert(tile.dispatched == 0, 'Tile: wrong dispatched');
        tile_index += 1;
    };
}
