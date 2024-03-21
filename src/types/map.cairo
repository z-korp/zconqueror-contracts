//! Map struct and methods for managing tiles.

// Core imports

use core::dict::{Felt252Dict, Felt252DictTrait};
use core::array::{ArrayTrait, SpanTrait};
use core::nullable::{NullableTrait, nullable_from_box, match_nullable, FromNullableResult};
use core::poseidon::PoseidonTrait;
use core::hash::HashStateTrait;

// External imports

use alexandria_data_structures::array_ext::ArrayTraitExt;
use origami::random::deck::{Deck, DeckTrait};

// Internal imports

use zconqueror::config;
use zconqueror::models::tile::{Tile, TileTrait};
use zconqueror::types::set::{Set, SetTrait};

// Constants

const MULTIPLIER: u128 = 10_000;

/// Map struct.
#[derive(Destruct)]
struct Map {
    realms: Felt252Dict<Nullable<Span<Tile>>>,
}

/// Errors module
mod errors {
    const INVALID_ARMY_COUNT: felt252 = 'Map: Invalid army count';
    const TILES_EMPTY: felt252 = 'Map: Tiles empty';
    const INVALID_TILE_NUMBER: felt252 = 'Map: Invalid tile number';
    const INVALID_TILE_ID: felt252 = 'Map: Invalid tile id';
    const TILES_UNBOX_ISSUE: felt252 = 'Tiles: unbox issue';
    const INVALID_CARD_ID: felt252 = 'Map: Invalid card id';
}

/// Trait to initialize and manage tile from the Map.
trait MapTrait {
    /// Returns a new `Map` struct.
    /// # Arguments
    /// * `game_id` - The game id.
    /// * `seed` - A seed to generate the map.
    /// * `player_count` - The number of players.
    /// * `tile_count` - The number of tiles.
    /// * `army_count` - The number of army of each player.
    /// # Returns
    /// * The initialized `Map`.
    fn new(game_id: u32, seed: felt252, player_count: u32, tile_count: u32, army_count: u32) -> Map;
    /// Returns the `Map` struct according to the tiles.
    /// # Arguments
    /// * `player_count` - The number of players.
    /// * `tiles` - The tiles.
    /// # Returns
    /// * The initialized `Map`.
    fn from_tiles(player_count: u32, tiles: Span<Tile>) -> Map;
    /// Returns the `Map` struct according to the tiles.
    /// # Arguments
    /// * `player_count` - The number of players.
    /// * `tiles` - The tiles.
    /// # Returns
    /// * The initialized `Map`.
    fn player_tiles(ref self: Map, player_index: u32) -> Span<Tile>;
    /// Computes the score of a player.
    /// # Arguments
    /// * `self` - The map.
    /// * `player_index` - The player index for whom to calculate the score.
    /// # Returns
    /// * The score.
    fn player_score(ref self: Map, player_index: u32) -> u32;
    fn faction_score(ref self: Map, player_index: u32) -> u32;
    /// Add supply for each owned tiles in the set.
    /// # Arguments
    /// * `self` - The map.
    /// * `player_index` - The player index for whom to calculate the score.
    /// * `set` - The set of cards.
    /// # Returns
    /// * The supplied tiles.
    fn deploy(ref self: Map, player_index: u32, set: @Set) -> Span<Tile>;
}

/// Implementation of the `MapTrait` for the `Map` struct.
impl MapImpl of MapTrait {
    fn new(
        game_id: u32, seed: felt252, player_count: u32, tile_count: u32, army_count: u32
    ) -> Map {
        // [Check] There is enough army to supply at least 1 unit per tile
        assert(player_count * army_count >= tile_count, errors::INVALID_ARMY_COUNT);
        // Use the deck mechanism to shuffle the tiles
        let mut deck = DeckTrait::new(seed, tile_count);
        // Each player draw R/N where R is the remaining cards and N the number of players left
        let mut realms: Felt252Dict<Nullable<Span<Tile>>> = Default::default();
        let mut player_index: u32 = 0;
        loop {
            if player_index == player_count {
                break;
            }
            let turns_count = deck.remaining / (player_count - player_index);
            // [Check] At least 1 tile per player
            assert(turns_count > 0, errors::INVALID_TILE_NUMBER);
            let mut turn_index = 0;
            // Draw the tiles for the current player with a single unit army
            let mut remaining_army = army_count;
            let mut tiles: Array<Tile> = array![];
            loop {
                if turn_index == turns_count {
                    break;
                }
                let tile_id = deck.draw();
                let tile = TileTrait::new(game_id, tile_id, 1, player_index);
                tiles.append(tile);
                remaining_army -= 1;
                turn_index += 1;
            };
            // Spread army on the tiles
            let mut remaining_army = army_count - turns_count;
            let mut nonce = 0;
            loop {
                if remaining_army == 0 {
                    break;
                }
                // Random number between 0 or 1
                let (unit, new_nonce) = _random(seed, nonce);
                nonce = new_nonce;
                // Increase army of the current tile with the unit
                let mut tile: Tile = tiles.pop_front().expect(errors::TILES_EMPTY);
                // TODO: Check if it is better to conditonate the following lines
                tile.army += unit.into();
                remaining_army -= unit.into();
                tiles.append(tile);
            };
            // Store the player tiles
            realms.insert(player_index.into(), nullable_from_box(BoxTrait::new(tiles.span())));
            player_index += 1;
        };
        Map { realms }
    }

    fn from_tiles(player_count: u32, tiles: Span<Tile>) -> Map {
        let mut realms: Felt252Dict<Nullable<Span<Tile>>> = Default::default();
        let mut player_index = 0;
        loop {
            if player_index == player_count {
                break;
            };
            let mut player_tiles: Array<Tile> = array![];
            let mut tile_index = 0;
            loop {
                if tile_index == tiles.len() {
                    break;
                };
                let tile = tiles.at(tile_index);
                if tile.owner == @player_index {
                    player_tiles.append(*tile);
                };
                tile_index += 1;
            };
            realms
                .insert(player_index.into(), nullable_from_box(BoxTrait::new(player_tiles.span())));
            player_index += 1;
        };
        Map { realms }
    }

    #[inline(always)]
    fn player_tiles(ref self: Map, player_index: u32) -> Span<Tile> {
        match match_nullable(self.realms.get(player_index.into())) {
            FromNullableResult::Null => panic(array![errors::TILES_UNBOX_ISSUE]),
            FromNullableResult::NotNull(status) => status.unbox(),
        }
    }

    #[inline(always)]
    fn player_score(ref self: Map, player_index: u32) -> u32 {
        // [Compute] Player tiles count
        self.player_tiles(player_index).len()
    }

    fn faction_score(ref self: Map, player_index: u32) -> u32 {
        // [Compute] Convert player tiles from span into array for efficiency
        let mut player_tiles = self.player_tiles(player_index);
        let mut player_ids: Array<u8> = array![];
        loop {
            match player_tiles.pop_front() {
                Option::Some(tile) => { player_ids.append(*tile.id); },
                Option::None => { break; },
            };
        };

        // [Compute] Increase score for each full owned factions
        let mut score = 0;
        let mut factions: Span<felt252> = config::factions();
        loop {
            match factions.pop_front() {
                Option::Some(faction) => {
                    let mut tile_ids: Array<u8> = array![];
                    let mut index = player_ids.len();
                    loop {
                        if index == 0 {
                            break;
                        }
                        let tile_id = player_ids.pop_front().unwrap();
                        let tile_faction = config::faction(tile_id).expect(errors::INVALID_TILE_ID);
                        if tile_faction == *faction {
                            tile_ids.append(tile_id);
                        } else {
                            player_ids.append(tile_id);
                        };
                        index -= 1;
                    };
                    // [Effect] Increase score
                    let faction_ids = config::ids(*faction).unwrap();
                    if faction_ids.len() == tile_ids.len() {
                        // Multiply by 3 because the score will be devided by 3 to compute the supply
                        score += config::score(*faction).unwrap();
                    };
                },
                Option::None => { break; },
            };
        };

        // [Return] Score
        score
    }

    fn deploy(ref self: Map, player_index: u32, set: @Set) -> Span<Tile> {
        // [Compute] Set tile ids
        let mut tile_ids: Array<u8> = array![];
        let mut cards = set.cards();
        loop {
            match cards.pop_front() {
                Option::Some(card) => {
                    let (tile_id, _) = config::card(*card).expect(errors::INVALID_CARD_ID);
                    tile_ids.append(tile_id);
                },
                Option::None => { break; },
            };
        };
        // [Compute] Update player tiles if tile ids match
        let mut player_tiles = self.player_tiles(player_index);
        let mut updated_tiles = array![];
        loop {
            match player_tiles.pop_front() {
                Option::Some(tile) => {
                    let mut updated_tile = *tile;
                    if tile_ids.contains(*tile.id) {
                        updated_tile.army += 2;
                    };
                    updated_tiles.append(updated_tile);
                },
                Option::None => { break; },
            };
        };
        // [Compute] Update player tiles
        let tiles = updated_tiles.span();
        self.realms.insert(player_index.into(), nullable_from_box(BoxTrait::new(tiles)));
        // [Return] Updated player tiles
        tiles
    }
}

/// Generates a random number between 0 or 1.
/// # Arguments
/// * `seed` - The seed.
/// * `nonce` - The nonce.
/// # Returns
/// * The random number.
#[inline(always)]
fn _random(seed: felt252, nonce: u32) -> (u8, u32) {
    let mut state = PoseidonTrait::new();
    state = state.update(seed);
    state = state.update(nonce.into());
    let hash: u256 = state.finalize().into();
    ((hash % 2).try_into().unwrap(), nonce + 1)
}

#[cfg(test)]
mod tests {
    // Core imports

    use core::debug::PrintTrait;

    // Internal imports

    use zconqueror::config;
    use zconqueror::models::tile::{Tile, TileTrait};
    use zconqueror::types::set::{Set, SetTrait};

    // Local imports

    use super::{Map, MapTrait, _random};

    // Constants

    const GAME_ID: u32 = 0;
    const SEED: felt252 = 'seed';
    const PLAYER_NUMBER: u32 = 4;
    const NONCE: u32 = 0;
    const PLAYER_1: u32 = 0;
    const PLAYER_2: u32 = 1;

    #[test]
    #[available_gas(100_000)]
    fn test_map_random() {
        let (unit, nonce) = _random(SEED, NONCE);
        assert(unit == 0 || unit == 1, 'Map: wrong random unit');
        assert(nonce == NONCE + 1, 'Map: wrong nonce');
    }

    #[test]
    #[available_gas(18_000_000)]
    fn test_map_new() {
        MapTrait::new(GAME_ID, SEED, PLAYER_NUMBER, config::TILE_NUMBER, config::ARMY_NUMBER);
    }

    #[test]
    #[available_gas(18_000_000)]
    fn test_map_from_tiles() {
        let mut tiles: Array<Tile> = array![];
        tiles.append(TileTrait::new(GAME_ID, 1, 0, PLAYER_1));
        tiles.append(TileTrait::new(GAME_ID, 2, 0, PLAYER_1));
        MapTrait::from_tiles(PLAYER_NUMBER, tiles.span());
    }

    #[test]
    #[available_gas(18_000_000)]
    fn test_map_player_tiles() {
        let mut tiles: Array<Tile> = array![];
        tiles.append(TileTrait::new(GAME_ID, 1, 0, PLAYER_1));
        tiles.append(TileTrait::new(GAME_ID, 2, 0, PLAYER_1));
        tiles.append(TileTrait::new(GAME_ID, 3, 0, PLAYER_1));
        tiles.append(TileTrait::new(GAME_ID, 4, 0, PLAYER_2));
        tiles.append(TileTrait::new(GAME_ID, 5, 0, PLAYER_2));
        let mut map = MapTrait::from_tiles(PLAYER_NUMBER, tiles.span());
        assert(map.player_tiles(PLAYER_1).len() == 3, 'Map: wrong player tiles');
        assert(map.player_tiles(PLAYER_2).len() == 2, 'Map: wrong player tiles');
    }

    #[test]
    #[available_gas(18_000_000)]
    fn test_map_score_full() {
        let mut tiles: Array<Tile> = array![];
        tiles.append(TileTrait::new(GAME_ID, 1, 0, PLAYER_1));
        tiles.append(TileTrait::new(GAME_ID, 2, 0, PLAYER_1));
        tiles.append(TileTrait::new(GAME_ID, 3, 0, PLAYER_1));
        tiles.append(TileTrait::new(GAME_ID, 4, 0, PLAYER_1));
        tiles.append(TileTrait::new(GAME_ID, 5, 0, PLAYER_1));
        let mut map = MapTrait::from_tiles(PLAYER_NUMBER, tiles.span());
        assert(map.player_score(PLAYER_1) == 5, 'Map: wrong player score');
        assert(map.faction_score(PLAYER_1) > 0, 'Map: wrong faction score');
    }

    #[test]
    #[available_gas(18_000_000)]
    fn test_map_deploy() {
        let mut tiles: Array<Tile> = array![];
        tiles.append(TileTrait::new(GAME_ID, 1, 0, PLAYER_1));
        tiles.append(TileTrait::new(GAME_ID, 2, 0, PLAYER_1));
        tiles.append(TileTrait::new(GAME_ID, 3, 0, PLAYER_2));
        tiles.append(TileTrait::new(GAME_ID, 4, 0, PLAYER_1));
        tiles.append(TileTrait::new(GAME_ID, 5, 0, PLAYER_1));
        let mut map = MapTrait::from_tiles(PLAYER_NUMBER, tiles.span());
        let set = SetTrait::new(1, 2, 3);
        let player_tiles = map.deploy(PLAYER_1, @set);
        assert(player_tiles.at(0).army == @2, 'Map: wrong tile army 0');
        assert(player_tiles.at(1).army == @2, 'Map: wrong tile army 1');
        assert(player_tiles.at(2).army == @0, 'Map: wrong tile army 3');
        assert(player_tiles.at(3).army == @0, 'Map: wrong tile army 4');
    }
}
