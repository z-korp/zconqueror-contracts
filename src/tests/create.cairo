// Core imports

use debug::PrintTrait;

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports

use zrisk::config::TILE_NUMBER;
use zrisk::components::game::{Game, GameTrait};
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
    assert(game.player() == 0, 'Game: wrong player index');
    assert(game.turn().into() == 0_u8, 'Game: wrong player index');

    // [Assert] Players
    let mut player_index: u8 = 0;
    loop {
        if player_index == PLAYER_COUNT {
            break;
        }
        let player: Player = get!(world, (game.id, player_index).into(), (Player));
        let player_name: u256 = player.name.into();
        assert(player.game_id == game.id, 'Player: wrong game id');
        assert(player.index == player_index.into(), 'Player: wrong order');
        assert(player.address.is_zero(), 'Player: wrong address');
        assert(player_name < PLAYER_COUNT.into() || player.name == NAME, 'Player: wrong name');
        assert(
            (player_index != 0 && player.supply == 0) || player.supply > 0, 'Player: wrong supply'
        );
        player_index += 1;
    };

    // [Assert] Tiles
    let mut tile_index: u8 = 1;
    loop {
        if TILE_NUMBER == tile_index.into() {
            break;
        }
        let tile: Tile = get!(world, (game.id, tile_index).into(), (Tile));
        assert(tile.game_id == game.id, 'Tile: wrong game id');
        assert(tile.index == tile_index, 'Tile: wrong tile id');
        assert(tile.army > 0, 'Tile: wrong army');
        assert(tile.owner < PLAYER_COUNT.into(), 'Tile: wrong owner');
        assert(tile.dispatched == 0, 'Tile: wrong dispatched');
        tile_index += 1;
    };
}
