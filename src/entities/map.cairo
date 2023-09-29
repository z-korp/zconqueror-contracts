//! Map struct and methods for managing tiles.

// Core imports

use dict::{Felt252Dict, Felt252DictTrait};
use array::{ArrayTrait, SpanTrait};
use nullable::{NullableTrait, nullable_from_box, match_nullable, FromNullableResult};
use poseidon::PoseidonTrait;
use hash::HashStateTrait;
use debug::PrintTrait;

// Internal imports

use zrisk::entities::deck::{Deck, DeckTrait};
use zrisk::entities::tile::{Tile, TileTrait};

// Constants

const MULTIPLIER: u128 = 10_000;

/// Map struct.
#[derive(Destruct)]
struct Map {
    id: u8,
    realms: Felt252Dict<Nullable<Span<Tile>>>,
}

/// Errors module
mod errors {
    const INVALID_ARMY_COUNT: felt252 = 'Map: Invalid army count';
    const TILES_EMPTY: felt252 = 'Map: Tiles empty';
    const INVALID_TILE_NUMBER: felt252 = 'Map: Invalid tile number';
}

/// Trait to initialize and manage tile from the Map.
trait MapTrait {
    /// Returns a new `Map` struct.
    /// # Arguments
    /// * `id` - The territory id.
    /// * `seed` - A seed to generate the map.
    /// * `player_count` - The number of players.
    /// * `tile_count` - The number of tiles.
    /// * `army_count` - The number of army of each player.
    /// # Returns
    /// * The initialized `Map`.
    fn new(id: u8, seed: felt252, player_count: u32, tile_count: u32, army_count: u32) -> Map;
}

/// Implementation of the `TileTrait` for the `Tile` struct.
impl MapImpl of MapTrait {
    fn new(id: u8, seed: felt252, player_count: u32, tile_count: u32, army_count: u32) -> Map {
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
                tile.army += unit;
                remaining_army -= unit.into();
                tiles.append(tile);
            };
            // Store the player tiles
            realms.insert(player_index.into(), nullable_from_box(BoxTrait::new(tiles.span())));
            player_index += 1;
        };
        Map { id, realms }
    }
}

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

    // Local imports

    use super::{Map, MapTrait, _random};

    // Constants

    const SEED: felt252 = 'seed';
    const PLAYER_NUMBER: u32 = 4;
    const NONCE: u32 = 0;

    #[test]
    #[available_gas(100_000)]
    fn test_map_random() {
        let (unit, nonce) = _random(SEED, NONCE);
        assert(unit == 0 || unit == 1, 'Map: Invalid random unit');
        assert(nonce == NONCE + 1, 'Map: Invalid nonce');
    }

    #[test]
    #[available_gas(18_000_000)]
    fn test_map_new() {
        let map = MapTrait::new(1, SEED, PLAYER_NUMBER, config::TILE_NUMBER, config::ARMY_NUMBER);
    }
}
