// Core imports

use debug::PrintTrait;

// Starknet imports

use starknet::testing::set_contract_address;

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Internal imports

use zconqueror::config::TILE_NUMBER;
use zconqueror::store::{Store, StoreTrait};
use zconqueror::models::game::{Game, GameTrait};
use zconqueror::models::player::Player;
use zconqueror::models::tile::Tile;
use zconqueror::systems::host::IHostDispatcherTrait;
use zconqueror::systems::play::IPlayDispatcherTrait;
use zconqueror::tests::setup::{setup, setup::{Systems, HOST, PLAYER}};

// Constants

const ACCOUNT: felt252 = 'ACCOUNT';
const NAME: felt252 = 'NAME';
const PLAYER_COUNT: u8 = 4;

#[test]
#[available_gas(1_000_000_000)]
fn test_create() {
    // [Setup]
    let (world, systems) = setup::spawn_game();
    let mut store = StoreTrait::new(world);

    // [Create]
    let game_id = systems.host.create(world, PLAYER_COUNT, NAME);
    systems.host.start(world, game_id);

    // [Assert] Game
    let game: Game = store.game(0);
    assert(game.id == 0, 'Game: wrong id');
    assert(game.seed != 0, 'Game: wrong seed');
    assert(game.over == false, 'Game: wrong status');
    assert(game.player_count == PLAYER_COUNT, 'Game: wrong player count');
    assert(game.player() >= 0, 'Game: wrong player index');
    assert(game.turn().into() == 0_u8, 'Game: wrong player index');

    // [Assert] Players
    let mut player_index: u8 = 0;
    let mut supply = 0;
    loop {
        if player_index == PLAYER_COUNT {
            break;
        }
        let player: Player = store.player(game, player_index.into());
        let player_name: u256 = player.name.into();
        assert(player.game_id == game.id, 'Player: wrong game id');
        assert(player.index == player_index.into(), 'Player: wrong order');
        assert(player.address.is_zero() || player.address == HOST(), 'Player: wrong address');
        assert(player_name < PLAYER_COUNT.into() || player.name == NAME, 'Player: wrong name');
        assert(
            player.supply == 0 || (game.player().into() == player.index && player.supply > 0),
            'Player: wrong supply'
        );
        supply += player.supply;
        player_index += 1;
    };
    assert(supply > 0, 'Player: wrong total supply');

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
