//! DataStore struct and component management methods.

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Components imports

use zconqueror::components::game::{Game, GameTrait};
use zconqueror::components::player::{Player, PlayerTrait};
use zconqueror::components::tile::Tile;

// Internal imports

use zconqueror::config;

/// DataStore struct.
#[derive(Drop)]
struct DataStore {
    world: IWorldDispatcher
}

/// Trait to initialize, get and set components from the DataStore.
trait DataStoreTrait {
    fn new(world: IWorldDispatcher) -> DataStore;
    fn game(ref self: DataStore, account: felt252) -> Game;
    fn player(ref self: DataStore, game: Game, index: u8) -> Player;
    fn players(ref self: DataStore, game: Game) -> Span<Player>;
    fn current_player(ref self: DataStore, game: Game) -> Player;
    fn next_player(ref self: DataStore, game: Game) -> Player;
    fn tile(ref self: DataStore, game: Game, index: u8) -> Tile;
    fn tiles(ref self: DataStore, game: Game) -> Span<Tile>;
    fn set_game(ref self: DataStore, game: Game);
    fn set_player(ref self: DataStore, player: Player);
    fn set_players(ref self: DataStore, players: Span<Player>);
    fn set_tile(ref self: DataStore, tile: Tile);
    fn set_tiles(ref self: DataStore, tiles: Span<Tile>);
}

/// Implementation of the `DataStoreTrait` trait for the `DataStore` struct.
impl DataStoreImpl of DataStoreTrait {
    fn new(world: IWorldDispatcher) -> DataStore {
        DataStore { world: world }
    }

    fn game(ref self: DataStore, account: felt252) -> Game {
        get!(self.world, account, (Game))
    }

    fn player(ref self: DataStore, game: Game, index: u8) -> Player {
        get!(self.world, (game.id, index), (Player))
    }

    fn players(ref self: DataStore, game: Game) -> Span<Player> {
        let mut index = game.player_count;
        let mut players: Array<Player> = array![];
        loop {
            if index == 0 {
                break;
            };
            index -= 1;
            players.append(self.player(game, index.into()));
        };
        players.span()
    }

    fn current_player(ref self: DataStore, game: Game) -> Player {
        let player_key = (game.id, game.player());
        get!(self.world, player_key.into(), (Player))
    }

    fn next_player(ref self: DataStore, game: Game) -> Player {
        let player_key = (game.id, game.next_player());
        get!(self.world, player_key.into(), (Player))
    }

    fn tile(ref self: DataStore, game: Game, index: u8) -> Tile {
        let tile_key = (game.id, index);
        get!(self.world, tile_key.into(), (Tile))
    }

    fn tiles(ref self: DataStore, game: Game) -> Span<Tile> {
        let mut index: u8 = config::TILE_NUMBER.try_into().unwrap();
        let mut tiles: Array<Tile> = array![];
        loop {
            if index == 0 {
                break;
            };
            tiles.append(self.tile(game, index));
            index -= 1;
        };
        tiles.span()
    }

    fn set_game(ref self: DataStore, game: Game) {
        set!(self.world, (game));
    }

    fn set_player(ref self: DataStore, player: Player) {
        set!(self.world, (player));
    }

    fn set_players(ref self: DataStore, mut players: Span<Player>) {
        loop {
            match players.pop_front() {
                Option::Some(player) => self.set_player(*player),
                Option::None => { break; },
            };
        };
    }

    fn set_tile(ref self: DataStore, tile: Tile) {
        set!(self.world, (tile));
    }

    fn set_tiles(ref self: DataStore, mut tiles: Span<Tile>) {
        loop {
            match tiles.pop_front() {
                Option::Some(tile) => self.set_tile(*tile),
                Option::None => { break; },
            };
        };
    }
}
