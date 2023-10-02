//! Map struct and methods for managing lands.

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
use zrisk::entities::land::{Land, LandTrait};

// Constants

const MULTIPLIER: u128 = 10_000;

/// Map struct.
#[derive(Destruct)]
struct Map {
    realms: Felt252Dict<Nullable<Span<Land>>>,
}

/// Errors module
mod errors {
    const INVALID_ARMY_COUNT: felt252 = 'Map: Invalid army count';
    const LANDS_EMPTY: felt252 = 'Map: Lands empty';
    const INVALID_LAND_NUMBER: felt252 = 'Map: Invalid land number';
    const LANDS_UNBOX_ISSUE: felt252 = 'Lands: unbox issue';
}

/// Trait to initialize and manage land from the Map.
trait MapTrait {
    /// Returns a new `Map` struct.
    /// # Arguments
    /// * `seed` - A seed to generate the map.
    /// * `player_count` - The number of players.
    /// * `land_count` - The number of lands.
    /// * `army_count` - The number of army of each player.
    /// # Returns
    /// * The initialized `Map`.
    fn new(seed: felt252, player_count: u32, land_count: u32, army_count: u32) -> Map;
    /// Returns the `Map` struct according to the lands.
    /// # Arguments
    /// * `player_count` - The number of players.
    /// * `lands` - The lands.
    /// # Returns
    /// * The initialized `Map`.
    fn from_lands(player_count: u32, lands: Span<Land>) -> Map;
    /// Returns the player lands.
    /// # Arguments
    /// * `self` - The map.
    /// * `player_index` - The player index.
    /// # Returns
    /// * The player lands.
    fn player_lands(ref self: Map, player_index: u32) -> Span<Land>;
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
    fn new(seed: felt252, player_count: u32, land_count: u32, army_count: u32) -> Map {
        // [Check] There is enough army to supply at least 1 unit per land
        assert(player_count * army_count >= land_count, errors::INVALID_ARMY_COUNT);
        // [Compute] Seed in u256 for futher operations
        let base_seed: u256 = seed.into();
        // Use the deck mechanism to shuffle the lands
        let mut deck = DeckTrait::new(seed, land_count);
        // Each player draw R/N where R is the remaining cards and N the number of players left
        let mut realms: Felt252Dict<Nullable<Span<Land>>> = Default::default();
        let mut player_index: u32 = 0;
        loop {
            if player_index == player_count {
                break;
            }
            let turns_count = deck.remaining / (player_count - player_index);
            // [Check] At least 1 land per player
            assert(turns_count > 0, errors::INVALID_LAND_NUMBER);
            let mut turn_index = 0;
            // Draw the lands for the current player with a single unit army
            let mut remaining_army = army_count;
            let mut lands: Array<Land> = array![];
            loop {
                if turn_index == turns_count {
                    break;
                }
                let land_id = deck.draw();
                let land = LandTrait::new(land_id, 1, player_index);
                lands.append(land);
                remaining_army -= 1;
                turn_index += 1;
            };
            // Spread army on the lands
            let mut remaining_army = army_count - turns_count;
            let mut nonce = 0;
            loop {
                if remaining_army == 0 {
                    break;
                }
                // Random number between 0 or 1
                let (unit, new_nonce) = _random(seed, nonce);
                nonce = new_nonce;
                // Increase army of the current land with the unit
                let mut land: Land = lands.pop_front().expect(errors::LANDS_EMPTY);
                // TODO: Check if it is better to conditonate the following lines
                land.army += unit.into();
                remaining_army -= unit.into();
                lands.append(land);
            };
            // Store the player lands
            realms.insert(player_index.into(), nullable_from_box(BoxTrait::new(lands.span())));
            player_index += 1;
        };
        Map { realms }
    }

    fn from_lands(player_count: u32, lands: Span<Land>) -> Map {
        let mut realms: Felt252Dict<Nullable<Span<Land>>> = Default::default();
        let mut player_index = 0;
        loop {
            if player_index == player_count {
                break;
            };
            let mut player_lands: Array<Land> = array![];
            let mut land_index = 0;
            loop {
                if land_index == lands.len() {
                    break;
                };
                let land = lands.at(land_index);
                if land.owner == @player_index {
                    player_lands.append(*land);
                };
                land_index += 1;
            };
            realms
                .insert(player_index.into(), nullable_from_box(BoxTrait::new(player_lands.span())));
            player_index += 1;
        };
        Map { realms }
    }

    fn player_lands(ref self: Map, player_index: u32) -> Span<Land> {
        match match_nullable(self.realms.get(player_index.into())) {
            FromNullableResult::Null => panic(array![errors::LANDS_UNBOX_ISSUE]),
            FromNullableResult::NotNull(status) => status.unbox(),
        }
    }

    fn score(ref self: Map, player_index: u32) -> u32 {
        // [Compute] Player lands count
        let mut player_lands = self.player_lands(player_index);
        let mut score = player_lands.len();

        // [Compute] Convert player lands from span into array for efficiency
        let mut player_ids: Array<u8> = array![];
        loop {
            match player_lands.pop_front() {
                Option::Some(land) => {
                    player_ids.append(*land.id);
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
                    let mut land_ids: Array<u8> = array![];
                    loop {
                        match player_lands.pop_front() {
                            Option::Some(land) => {
                                if land.faction == faction {
                                    land_ids.append(*land.id);
                                } else {
                                    player_ids.append(*land.id);
                                };
                            },
                            Option::None => {
                                break;
                            },
                        };
                    };
                    // [Effect] Increase score
                    let faction_ids = config::ids(*faction).unwrap();
                    if faction_ids.len() == land_ids.len() {
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
    use zrisk::entities::land::{Land, LandTrait};

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
    fn test_map_from_lands() {
        let mut lands: Array<Land> = array![];
        lands.append(LandTrait::new(1, 0, PLAYER_1));
        lands.append(LandTrait::new(2, 0, PLAYER_1));
        MapTrait::from_lands(PLAYER_NUMBER, lands.span());
    }

    #[test]
    #[available_gas(18_000_000)]
    fn test_map_player_lands() {
        let mut lands: Array<Land> = array![];
        lands.append(LandTrait::new(1, 0, PLAYER_1));
        lands.append(LandTrait::new(2, 0, PLAYER_1));
        lands.append(LandTrait::new(3, 0, PLAYER_1));
        lands.append(LandTrait::new(4, 0, PLAYER_2));
        lands.append(LandTrait::new(5, 0, PLAYER_2));
        let mut map = MapTrait::from_lands(PLAYER_NUMBER, lands.span());
        assert(map.player_lands(PLAYER_1).len() == 3, 'Map: wrong player lands');
        assert(map.player_lands(PLAYER_2).len() == 2, 'Map: wrong player lands');
    }

    #[test]
    #[available_gas(18_000_000)]
    fn test_map_score_full() {
        let mut lands: Array<Land> = array![];
        lands.append(LandTrait::new(1, 0, PLAYER_1));
        lands.append(LandTrait::new(2, 0, PLAYER_1));
        lands.append(LandTrait::new(3, 0, PLAYER_1));
        lands.append(LandTrait::new(4, 0, PLAYER_1));
        lands.append(LandTrait::new(5, 0, PLAYER_1));
        let mut map = MapTrait::from_lands(PLAYER_NUMBER, lands.span());
        assert(map.score(PLAYER_1) >= 5, 'Map: wrong score');
    }
}
