//! Store struct and component management methods.

// Straknet imports

use starknet::ContractAddress;

// Dojo imports

use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

// Components imports

use zconqueror::models::game::{Game, GameTrait};
use zconqueror::models::player::{Player, PlayerTrait};
use zconqueror::models::tile::Tile;

// Internal imports

use zconqueror::config;

/// Store struct.
#[derive(Drop)]
struct Store {
    world: IWorldDispatcher
}

/// Trait to initialize, get and set models from the Store.
trait StoreTrait {
    fn new(world: IWorldDispatcher) -> Store;
    fn game(ref self: Store, id: u32) -> Game;
    fn player(ref self: Store, game: Game, index: u8) -> Player;
    fn players(ref self: Store, game: Game) -> Array<Player>;
    fn current_player(ref self: Store, game: Game) -> Player;
    fn next_player(ref self: Store, game: Game) -> Player;
    fn find_player(ref self: Store, game: Game, account: ContractAddress) -> Option<Player>;
    fn tile(ref self: Store, game: Game, index: u8) -> Tile;
    fn tiles(ref self: Store, game: Game) -> Array<Tile>;
    fn set_game(ref self: Store, game: Game);
    fn set_player(ref self: Store, player: Player);
    fn set_players(ref self: Store, players: Span<Player>);
    fn set_tile(ref self: Store, tile: Tile);
    fn set_tiles(ref self: Store, tiles: Span<Tile>);
}

/// Implementation of the `StoreTrait` trait for the `Store` struct.
impl StoreImpl of StoreTrait {
    fn new(world: IWorldDispatcher) -> Store {
        Store { world: world }
    }

    fn game(ref self: Store, id: u32) -> Game {
        get!(self.world, id, (Game))
    }

    fn player(ref self: Store, game: Game, index: u8) -> Player {
        get!(self.world, (game.id, index), (Player))
    }

    fn players(ref self: Store, game: Game) -> Array<Player> {
        let mut index = game.player_count;
        let mut players: Array<Player> = array![];
        loop {
            if index == 0 {
                break;
            };
            index -= 1;
            players.append(self.player(game, index.into()));
        };
        players
    }

    fn current_player(ref self: Store, game: Game) -> Player {
        let player_key = (game.id, game.player());
        get!(self.world, player_key.into(), (Player))
    }

    fn next_player(ref self: Store, game: Game) -> Player {
        let player_key = (game.id, game.next_player());
        get!(self.world, player_key.into(), (Player))
    }

    fn find_player(ref self: Store, game: Game, account: ContractAddress) -> Option<Player> {
        let mut index: u32 = game.real_player_count().into();
        loop {
            index -= 1;
            let player_key = (game.id, index);
            let player = get!(self.world, player_key.into(), (Player));
            if player.address == account {
                break Option::Some(player);
            }
            if index == 0 {
                break Option::None;
            };
        }
    }

    fn tile(ref self: Store, game: Game, index: u8) -> Tile {
        let tile_key = (game.id, index);
        get!(self.world, tile_key.into(), (Tile))
    }

    fn tiles(ref self: Store, game: Game) -> Array<Tile> {
        let mut index: u8 = config::TILE_NUMBER.try_into().unwrap();
        let mut tiles: Array<Tile> = array![];
        loop {
            if index == 0 {
                break;
            };
            tiles.append(self.tile(game, index));
            index -= 1;
        };
        tiles
    }

    fn set_game(ref self: Store, game: Game) {
        set!(self.world, (game));
    }

    fn set_player(ref self: Store, player: Player) {
        set!(self.world, (player));
    }

    fn set_players(ref self: Store, mut players: Span<Player>) {
        loop {
            match players.pop_front() {
                Option::Some(player) => self.set_player(*player),
                Option::None => { break; },
            };
        };
    }

    fn set_tile(ref self: Store, tile: Tile) {
        set!(self.world, (tile));
    }

    fn set_tiles(ref self: Store, mut tiles: Span<Tile>) {
        loop {
            match tiles.pop_front() {
                Option::Some(tile) => self.set_tile(*tile),
                Option::None => { break; },
            };
        };
    }
}
