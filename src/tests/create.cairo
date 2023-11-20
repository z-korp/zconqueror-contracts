// Core imports

use debug::PrintTrait;

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports

use zconqueror::config::TILE_NUMBER;
use zconqueror::store::{Store, StoreTrait};
use zconqueror::components::game::{Game, GameTrait};
use zconqueror::components::player::Player;
use zconqueror::components::tile::Tile;
use zconqueror::systems::player::IActionsDispatcherTrait;
use zconqueror::tests::setup::{setup, setup::Systems, setup::PLAYER};

// Constants

const ACCOUNT: felt252 = 'ACCOUNT';
const SEED: felt252 = 'SEED';
const NAME: felt252 = 'NAME';
const PLAYER_COUNT: u8 = 4;

#[test]
#[available_gas(1_000_000_000)]
fn test_create() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    systems.player_actions.create(world, ACCOUNT, SEED, NAME, PLAYER_COUNT);

    // [Assert] Game
    let game: Game = store.game(ACCOUNT);
    assert(game.id == 0, 'Game: wrong id');
    assert(game.seed == SEED, 'Game: wrong seed');
    assert(game.over == false, 'Game: wrong status');
    assert(game.player_count == PLAYER_COUNT, 'Game: wrong player count');
    assert(game.player() >= 0, 'Game: wrong player index');
    assert(game.turn().into() == 0_u8, 'Game: wrong player index');

    // [Assert] Players
    let mut player_index: u8 = 0;
    loop {
        if player_index == PLAYER_COUNT {
            break;
        }
        let player: Player = store.player(game, player_index.into());
        let player_name: u256 = player.name.into();
        assert(player.game_id == game.id, 'Player: wrong game id');
        assert(player.index == player_index.into(), 'Player: wrong order');
        assert(player.address.is_zero() || player.address == PLAYER(), 'Player: wrong address');
        assert(player_name < PLAYER_COUNT.into() || player.name == NAME, 'Player: wrong name');
        assert(
            player.supply == 0 || (game.player().into() == player.index && player.supply > 0),
            'Player: wrong supply'
        );
        player_index += 1;
    };

    // [Assert] Tiles
    let mut tile_index: u8 = 1;
    loop {
        if TILE_NUMBER == tile_index.into() {
            break;
        }
        let tile: Tile = store.tile(game, tile_index.into());
        assert(tile.game_id == game.id, 'Tile: wrong game id');
        assert(tile.index == tile_index, 'Tile: wrong tile id');
        assert(tile.army > 0, 'Tile: wrong army');
        assert(tile.owner < PLAYER_COUNT.into(), 'Tile: wrong owner');
        assert(tile.dispatched == 0, 'Tile: wrong dispatched');
        tile_index += 1;
    };
}
