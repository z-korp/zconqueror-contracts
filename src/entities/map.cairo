//! Map struct and methods for managing tiles.

// Core imports

use dict::{Felt252Dict, Felt252DictTrait};
use array::{ArrayTrait, SpanTrait};
use nullable::{NullableTrait, nullable_from_box, match_nullable, FromNullableResult};
use poseidon::PoseidonTrait;
use hash::HashStateTrait;
use debug::PrintTrait;

// Internal imports

use zrisk::config;
use zrisk::entities::deck::{Deck, DeckTrait};
use zrisk::entities::tile::{Tile, TileTrait};

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
    const TILES_UNBOX_ISSUE: felt252 = 'Tiles: unbox issue';
}

/// Trait to initialize and manage tile from the Map.
trait MapTrait {
    /// Returns a new `Map` struct.
    /// # Arguments
    /// * `seed` - A seed to generate the map.
    /// * `player_count` - The number of players.
    /// * `tile_count` - The number of tiles.
    /// * `army_count` - The number of army of each player.
    /// # Returns
    /// * The initialized `Map`.
    fn new(seed: felt252, player_count: u32, tile_count: u32, army_count: u32) -> Map;
    /// Returns the `Map` struct according to the tiles.
    /// # Arguments
    /// * `player_count` - The number of players.
    /// * `tiles` - The tiles.
    /// # Returns
    /// * The initialized `Map`.
    fn from_tiles(player_count: u32, tiles: Span<Tile>) -> Map;
    /// Returns the player tiles.
    /// # Arguments
    /// * `self` - The map.
    /// * `player_index` - The player index.
    /// # Returns
    /// * The player tiles.
    fn player_tiles(ref self: Map, player_index: u32) -> Span<Tile>;
    /// Computes the score of a player.
    /// # Arguments
    /// * `self` - The map.
    /// * `player_index` - The player index for whom to calculate the score.
    /// # Returns
    /// * The score.
    fn score(ref self: Map, player_index: u32) -> u32;
}

/// Implementation of the `MapTrait` for the `Map` struct.
impl MapImpl of MapTrait {
    fn new(seed: felt252, player_count: u32, tile_count: u32, army_count: u32) -> Map {
        // [Check] There is enough army to supply at least 1 unit per tile
        assert(player_count * army_count >= tile_count, errors::INVALID_ARMY_COUNT);
        // [Compute] Seed in u256 for futher operations
        let base_seed: u256 = seed.into();
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
                let tile_id = deck.draw() - 1;
                let tile = TileTrait::new(tile_id, 1, player_index);
                tiles.append(tile);
                remaining_army -= 1;
                turn_index += 1;
            };
            // Spread army on the tiles
            let mut remaining_army = army_count - turns_count;
            let mut tile_index = 0;
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

    fn player_tiles(ref self: Map, player_index: u32) -> Span<Tile> {
        match match_nullable(self.realms.get(player_index.into())) {
            FromNullableResult::Null => panic(array![errors::TILES_UNBOX_ISSUE]),
            FromNullableResult::NotNull(status) => status.unbox(),
        }
    }

    fn score(ref self: Map, player_index: u32) -> u32 {
        // [Compute] Player tiles count
        let mut player_tiles = self.player_tiles(player_index);
        let mut score = player_tiles.len();

        // [Compute] Convert player tiles from span into array for efficiency
        let mut player_ids: Array<u8> = array![];
        loop {
            match player_tiles.pop_front() {
                Option::Some(tile) => {
                    player_ids.append(*tile.id);
                },
                Option::None => {
                    break;
                },
            };
        };

        // [Compute] Increase score for each full owned factions
        let mut factions: Span<felt252> = config::factions();
        loop {
            match factions.pop_front() {
                Option::Some(faction) => {
                    let mut tile_ids: Array<u8> = array![];
                    loop {
                        match player_tiles.pop_front() {
                            Option::Some(tile) => {
                                if tile.faction == faction {
                                    tile_ids.append(*tile.id);
                                } else {
                                    player_ids.append(*tile.id);
                                };
                            },
                            Option::None => {
                                break;
                            },
                        };
                    };
                    // [Effect] Increase score
                    let faction_ids = config::ids(*faction).unwrap();
                    if faction_ids.len() == tile_ids.len() {
                        score += config::score(*faction).unwrap();
                    };
                },
                Option::None => {
                    break;
                },
            };
        };

        // [Return] Score
        score
    }
}

/// Generates a random number between 0 or 1.
/// # Arguments
/// * `seed` - The seed.
/// * `nonce` - The nonce.
/// # Returns
/// * The random number.
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

    use debug::PrintTrait;

    // Internal imports

    use zrisk::config;
    use zrisk::entities::tile::{Tile, TileTrait};

    // Local imports

    use super::{Map, MapTrait, _random};

    // Constants

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
        MapTrait::new(SEED, PLAYER_NUMBER, config::TILE_NUMBER, config::ARMY_NUMBER);
    }

    #[test]
    #[available_gas(18_000_000)]
    fn test_map_from_tiles() {
        let mut tiles: Array<Tile> = array![];
        tiles.append(TileTrait::new(0, 0, PLAYER_1));
        tiles.append(TileTrait::new(1, 0, PLAYER_1));
        MapTrait::from_tiles(PLAYER_NUMBER, tiles.span());
    }

    #[test]
    #[available_gas(18_000_000)]
    fn test_map_player_tiles() {
        let mut tiles: Array<Tile> = array![];
        tiles.append(TileTrait::new(0, 0, PLAYER_1));
        tiles.append(TileTrait::new(1, 0, PLAYER_1));
        tiles.append(TileTrait::new(2, 0, PLAYER_1));
        tiles.append(TileTrait::new(3, 0, PLAYER_2));
        tiles.append(TileTrait::new(4, 0, PLAYER_2));
        let mut map = MapTrait::from_tiles(PLAYER_NUMBER, tiles.span());
        assert(map.player_tiles(PLAYER_1).len() == 3, 'Map: wrong player tiles');
        assert(map.player_tiles(PLAYER_2).len() == 2, 'Map: wrong player tiles');
    }

    #[test]
    #[available_gas(18_000_000)]
    fn test_map_score_full() {
        let mut tiles: Array<Tile> = array![];
        tiles.append(TileTrait::new(0, 0, PLAYER_1));
        tiles.append(TileTrait::new(1, 0, PLAYER_1));
        tiles.append(TileTrait::new(2, 0, PLAYER_1));
        tiles.append(TileTrait::new(3, 0, PLAYER_1));
        tiles.append(TileTrait::new(4, 0, PLAYER_1));
        let mut map = MapTrait::from_tiles(PLAYER_NUMBER, tiles.span());
        assert(map.score(PLAYER_1) >= 5, 'Map: wrong score');
    }
}
