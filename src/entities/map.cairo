//! Map struct and methods for managing tiles.

// Core imports

use array::{ArrayTrait, SpanTrait};

// Internal imports

use zrisk::entities::tile::{Tile, TileTrait};

/// Map struct.
#[derive(Drop, Serde)]
struct Map {
    id: u8,
    tiles: Span<Tile>,
}

/// Errors module
mod errors {
    const INVALID_DISPATCHED: felt252 = 'Tile: invalid dispatched';
}

/// Trait to initialize and manage tile from the Map.
trait MapTrait {
    /// Returns a new `Map` struct.
    /// # Arguments
    /// * `id` - The territory id.
    /// # Returns
    /// * The initialized `Map`.
    fn new(id: u8) -> Map;
}

/// Implementation of the `TileTrait` for the `Tile` struct.
impl MapImpl of MapTrait {
    fn new(id: u8) -> Map {
        let mut tiles: Array::<Tile> = array![];
        let mut id: u8 = 0;
        loop {
            match TileTrait::try_new(id, 0, 0) {
                Option::Some(tile) => {
                    tiles.append(tile);
                    id += 1;
                },
                Option::None => {
                    break;
                },
            };
        };
        Map { id, tiles: tiles.span() }
    }
}

#[cfg(test)]
mod tests {
    // Core imports

    use debug::PrintTrait;

    // Local imports

    use super::{Map, MapTrait};

    #[test]
    #[available_gas(1_300_000)]
    fn test_map_new() {
        let map = MapTrait::new(1);
    }
}
