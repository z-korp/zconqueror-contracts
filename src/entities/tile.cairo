//! Tile struct and methods for managing battles, supply and ownerships.

// Core imports

use array::{ArrayTrait, SpanTrait};

// External imports

use alexandria_data_structures::array_ext::SpanTraitExt;

// Internal imports

use zrisk::entities::faction;
use zrisk::entities::dice::{Dice, DiceTrait};
use zrisk::components::tile::{Tile as TileComponent};

/// Tile struct.
#[derive(Drop, Copy, Serde)]
struct Tile {
    id: u8,
    army: u8,
    owner: u32,
    dispatched: u8,
    faction: felt252,
    neighbors: Span<u8>
}

/// Errors module
mod errors {
    const INVLID_ID: felt252 = 'Tile: invalid id';
    const INVALID_DISPATCHED: felt252 = 'Tile: invalid dispatched';
    const INVALID_ARRAY: felt252 = 'Tile: invalid array';
    const INVALID_OWNER: felt252 = 'Tile: invalid owner';
    const INVALID_ARMY_TRANSFER: felt252 = 'Tile: invalid army transfer';
    const INVALID_NEIGHBOR: felt252 = 'Tile: invalid neighbor';
}

/// Trait to initialize and manage army from the Tile.
trait TileTrait {
    /// Returns a new `Tile` struct.
    /// # Arguments
    /// * `id` - The territory id.
    /// * `army` - The initial army supply.
    /// * `owner` - The owner id of the territory.
    /// # Returns
    /// * The initialized `Tile`.
    fn new(id: u8, army: u8, owner: u32) -> Tile;
    /// Returns a new `Option<Tile>` struct.
    /// # Arguments
    /// * `id` - The territory id.
    /// * `army` - The initial army supply.
    /// * `owner` - The owner id of the territory.
    /// # Returns
    /// * The initialized `Option<Tile>`.
    fn try_new(id: u8, army: u8, owner: u32) -> Option<Tile>;
    /// Convert Tile into TileComponent.
    /// # Arguments
    /// * `self` - The tile.
    /// * `game_id` - The game id.
    fn convert(self: @Tile, game_id: u32) -> TileComponent;
    /// Dispatches an army from the tile.
    /// # Arguments
    /// * `self` - The tile.
    /// * `dispatched` - The dispatched army.
    /// * `defender` - The defending tile.
    fn attack(ref self: Tile, dispatched: u8, ref defender: Tile);
    /// Defends the tile from an attack.
    /// # Arguments
    /// * `self` - The tile.
    /// * `attacker` - The attacking tile.
    /// * `dice` - The dice to use for the battle.
    fn defend(ref self: Tile, ref attacker: Tile, ref dice: Dice);
    /// Supplies the tile with an army.
    /// # Arguments
    /// * `self` - The tile.
    /// * `army` - The army to supply.
    fn supply(ref self: Tile, army: u8);
    /// Transfers an army from the tile to another tile.
    /// # Arguments
    /// * `self` - The tile.
    /// * `to` - The tile to transfer the army to.
    /// * `army` - The army to transfer.
    fn transfer(ref self: Tile, ref to: Tile, army: u8);
}

/// Implementation of the `TileTrait` for the `Tile` struct.
impl TileImpl of TileTrait {
    fn new(id: u8, army: u8, owner: u32) -> Tile {
        let faction = _faction(id).expect(errors::INVLID_ID);
        let neighbors = _neighbors(id).expect(errors::INVLID_ID);
        Tile { id, army, owner, dispatched: 0, faction, neighbors: neighbors }
    }

    fn try_new(id: u8, army: u8, owner: u32) -> Option<Tile> {
        let wrapped_faction = _faction(id);
        let wrapped_neighbors = _neighbors(id);
        match wrapped_faction {
            Option::Some(faction) => {
                match wrapped_neighbors {
                    Option::Some(neighbors) => {
                        let tile = Tile {
                            id, army, owner, dispatched: 0, faction, neighbors: neighbors
                        };
                        Option::Some(tile)
                    },
                    Option::None => Option::None,
                }
            },
            Option::None => Option::None,
        }
    }

    fn convert(self: @Tile, game_id: u32) -> TileComponent {
        TileComponent {
            game_id: game_id,
            tile_id: *self.id,
            army: *self.army,
            owner: *self.owner,
            dispatched: *self.dispatched,
        }
    }

    fn attack(ref self: Tile, dispatched: u8, ref defender: Tile) {
        // [Check] Dispatched < army
        assert(dispatched < self.army, errors::INVALID_DISPATCHED);
        // [Check] Attack a neighbor
        assert(self.neighbors.contains(defender.id), errors::INVALID_NEIGHBOR);
        // [Effect] Update attacker
        self.army -= dispatched;
        self.dispatched = dispatched;
    }

    fn defend(ref self: Tile, ref attacker: Tile, ref dice: Dice) {
        // [Check] Attack from neighbor
        assert(self.neighbors.contains(attacker.id), errors::INVALID_NEIGHBOR);
        // [Compute] Battle and get survivors
        let (defensive_survivors, offensive_survivors) = _battle(
            self.army, attacker.dispatched, ref dice
        );
        // [Effect] Apply losses and update ownership
        self.army = defensive_survivors;
        attacker.dispatched = offensive_survivors;
        if self.army == 0 {
            self.owner = attacker.owner;
            self.army = attacker.dispatched;
            attacker.dispatched = 0;
        };
    }

    fn supply(ref self: Tile, army: u8) {
        self.army += army;
    }

    fn transfer(ref self: Tile, ref to: Tile, army: u8) {
        // [Check] Both tiles are owned by the same player
        assert(self.owner == to.owner, errors::INVALID_OWNER);
        // [Check] From tile army is greater than the transfered army
        assert(self.army > army, errors::INVALID_ARMY_TRANSFER);
        // [Check] Both tiles are connected by a owned path
        // TODO: when neighbors are defined and implemented
        self.army -= army;
        to.army += army;
    }
}

/// Return tile faction based on id.
/// # Arguments
/// * `id` - The tile id.
/// # Returns
/// * The corresponding faction.
#[inline(always)]
fn _faction(id: u8) -> Option<felt252> {
    if id < 6 {
        return Option::Some(faction::FACTION_01);
    } else if id < 14 {
        return Option::Some(faction::FACTION_02);
    } else if id < 19 {
        return Option::Some(faction::FACTION_03);
    } else if id < 26 {
        return Option::Some(faction::FACTION_04);
    } else if id < 32 {
        return Option::Some(faction::FACTION_05);
    } else if id < 36 {
        return Option::Some(faction::FACTION_06);
    } else if id < 41 {
        return Option::Some(faction::FACTION_07);
    } else if id < 50 {
        return Option::Some(faction::FACTION_08);
    } else {
        return Option::None;
    }
}

/// Return tile neighbors based on id.
/// # Arguments
/// * `id` - The tile id.
/// # Returns
/// * The corresponding neighbors.
#[inline(always)]
fn _neighbors(id: u8) -> Option<Span<u8>> {
    if id == 0 {
        return Option::Some(array![1].span());
    } else if id == 1 {
        return Option::Some(array![0, 2].span());
    } else if id == 2 {
        return Option::Some(array![1, 2, 3, 4].span());
    } else if id == 3 {
        return Option::Some(array![2, 4].span());
    } else if id == 4 {
        return Option::Some(array![3, 2, 5].span());
    } else if id == 5 {
        return Option::Some(array![4, 2].span());
    } else if id == 6 {
        return Option::Some(array![3, 7, 8].span());
    } else if id == 7 {
        return Option::Some(array![6, 8, 11].span());
    } else if id == 8 {
        return Option::Some(array![6, 7, 11, 9].span());
    } else if id == 9 {
        return Option::Some(array![8, 10].span());
    } else if id == 10 {
        return Option::Some(array![9, 12, 14, 41].span());
    } else if id == 11 {
        return Option::Some(array![8, 7, 12].span());
    } else if id == 12 {
        return Option::Some(array![10, 11, 13, 15].span());
    } else if id == 13 {
        return Option::Some(array![12, 15, 16, 24].span());
    } else if id == 14 {
        return Option::Some(array![10, 15].span());
    } else if id == 15 {
        return Option::Some(array![14, 12, 13, 16, 17].span());
    } else if id == 16 {
        return Option::Some(array![15, 13].span());
    } else if id == 17 {
        return Option::Some(array![15, 18].span());
    } else if id == 18 {
        return Option::Some(array![17, 19, 22].span());
    } else if id == 19 {
        return Option::Some(array![18, 20, 21].span());
    } else if id == 20 {
        return Option::Some(array![19, 20].span());
    } else if id == 21 {
        return Option::Some(array![19, 22].span());
    } else if id == 22 {
        return Option::Some(array![18, 21, 23, 30].span());
    } else if id == 23 {
        return Option::Some(array![22, 24, 25].span());
    } else if id == 24 {
        return Option::Some(array![13, 23].span());
    } else if id == 25 {
        return Option::Some(array![4, 23, 26].span());
    } else if id == 26 {
        return Option::Some(array![25, 27].span());
    } else if id == 27 {
        return Option::Some(array![5, 26, 28].span());
    } else if id == 28 {
        return Option::Some(array![27, 29].span());
    } else if id == 29 {
        return Option::Some(array![30, 28].span());
    } else if id == 30 {
        return Option::Some(array![20, 22, 29, 31].span());
    } else if id == 31 {
        return Option::Some(array![49, 30, 32].span());
    } else if id == 32 {
        return Option::Some(array![31, 33, 34, 36].span());
    } else if id == 33 {
        return Option::Some(array![32].span());
    } else if id == 34 {
        return Option::Some(array![32, 35].span());
    } else if id == 35 {
        return Option::Some(array![34].span());
    } else if id == 36 {
        return Option::Some(array![32, 38, 37].span());
    } else if id == 37 {
        return Option::Some(array![36, 38].span());
    } else if id == 38 {
        return Option::Some(array![36, 37, 39, 40, 45].span());
    } else if id == 39 {
        return Option::Some(array![38].span());
    } else if id == 40 {
        return Option::Some(array![38, 42].span());
    } else if id == 41 {
        return Option::Some(array![10, 42].span());
    } else if id == 42 {
        return Option::Some(array![40, 41, 43].span());
    } else if id == 43 {
        return Option::Some(array![44, 42, 45].span());
    } else if id == 44 {
        return Option::Some(array![43].span());
    } else if id == 45 {
        return Option::Some(array![38, 43, 46].span());
    } else if id == 46 {
        return Option::Some(array![47, 45, 48].span());
    } else if id == 47 {
        return Option::Some(array![46].span());
    } else if id == 48 {
        return Option::Some(array![49, 46].span());
    } else if id == 49 {
        return Option::Some(array![31, 48].span());
    } else {
        return Option::None;
    }
}

/// Resolves a battle between two armies.
/// # Arguments
/// * `defensives` - The defensive army.
/// * `offensives` - The offensive army.
/// # Returns
/// * The defensive and offensive survivors.
fn _battle(mut defensives: u8, mut offensives: u8, ref dice: Dice) -> (u8, u8) {
    // [Compute] Losses
    let mut index = 0;
    loop {
        if defensives == 0 || offensives == 0 {
            break;
        };
        let defensive = if defensives > 1 {
            2
        } else {
            1
        };
        let offensive = if offensives > 2 {
            3
        } else if offensives > 1 {
            2
        } else {
            1
        };
        let (defensive_losses, offensive_losses) = _round(defensive, offensive, ref dice);
        defensives -= defensive_losses;
        offensives -= offensive_losses;
    };
    (defensives, offensives)
}

/// Resolves a round between two sorted arrays of values.
/// # Arguments
/// * `defensive` - The defensive values.
/// * `offensive` - The offensive values.
/// # Returns
/// * The defensive and offensive losses.
fn _round(defensive: u8, offensive: u8, ref dice: Dice) -> (u8, u8) {
    // [Compute] Defensive dice roll values
    let mut defensive_values: Array<u8> = ArrayTrait::new();
    let mut index = 0;
    loop {
        if index == defensive {
            break;
        };
        defensive_values.append(dice.roll());
        index += 1;
    };
    let mut sorted_defensive_values = _sort(defensive_values.span());

    // [Compute] Offensive dice roll values
    let mut offensive_values: Array<u8> = ArrayTrait::new();
    index = 0;
    loop {
        if index == offensive {
            break;
        };
        offensive_values.append(dice.roll());
        index += 1;
    };
    let mut sorted_offensive_values = _sort(offensive_values.span());

    // [Compute] Resolve duel and return losses
    _duel(ref sorted_defensive_values, ref sorted_offensive_values)
}

/// Resolves a duel between two sorted arrays of values.
/// # Arguments
/// * `defensive` - The defensive values.
/// * `offensive` - The offensive values.
/// # Returns
/// * The defensive and offensive losses.
fn _duel(ref defensive: Span<u8>, ref offensive: Span<u8>) -> (u8, u8) {
    let mut defensive_losses = 0;
    let mut offensive_losses = 0;

    loop {
        if offensive.is_empty() || defensive.is_empty() {
            break;
        };
        if *defensive.pop_front().unwrap() < *offensive.pop_front().unwrap() {
            defensive_losses += 1;
        } else {
            offensive_losses += 1;
        };
    };

    (defensive_losses, offensive_losses)
}

/// Sorts an array of values.
/// This function is not implemented generic to reduce the gas cost.
/// # Arguments
/// * `values` - The values to sort.
/// # Returns
/// * The sorted values.
#[inline(always)]
fn _sort(values: Span<u8>) -> Span<u8> {
    // [Check] Values len is between 1 and 3
    assert(values.len() >= 1 && values.len() <= 3, errors::INVALID_ARRAY);
    // [Case] Values len is 1
    if values.len() == 1 {
        return values;
    };
    // [Case] Values len is 2
    let mut array: Array<u8> = array![];
    if values.len() == 2 {
        let left = *values[0];
        let right = *values[1];
        if left > right {
            array.append(left);
            array.append(right);
        } else {
            array.append(right);
            array.append(left);
        };
        return array.span();
    }
    // [Case] Values len is 3
    let mut left = *values[0];
    let mut middle = *values[1];
    let mut right = *values[2];
    if left < middle {
        let temp = left;
        left = middle;
        middle = temp;
    };
    if middle < right {
        let temp = middle;
        middle = right;
        right = temp;
    };
    if left < middle {
        let temp = left;
        left = middle;
        middle = temp;
    };
    array.append(left);
    array.append(middle);
    array.append(right);
    array.span()
}

#[cfg(test)]
mod tests {
    // Core imports

    use debug::PrintTrait;

    // Internal imports

    use zrisk::entities::dice::{Dice, DiceTrait};

    // Local imports

    use super::{Tile, TileTrait, _sort, _battle, _round, _duel};

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid id',))]
    fn test_tile_new_revert_invalid_id() {
        TileTrait::new(100, 4, 'a');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_try_new() {
        let wrapped_tile = TileTrait::try_new(0, 4, 'a');
        let tile = wrapped_tile.unwrap();
        assert(tile.army == 4, 'Tile: wrong tile army');
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid id',))]
    fn test_tile_try_new_revert_invalid_id() {
        let wrapped_tile = TileTrait::try_new(100, 4, 'a');
        wrapped_tile.expect('Tile: invalid id');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_supply() {
        let mut tile = TileTrait::new(0, 4, 'a');
        assert(tile.army == 4, 'Tile: wrong tile army');
        tile.supply(2);
        assert(tile.army == 6, 'Tile: wrong tile army');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_transfer() {
        let mut from = TileTrait::new(0, 4, 'a');
        let mut to = TileTrait::new(0, 2, 'a');
        from.transfer(ref to, 2);
        assert(from.army == 2, 'Tile: wrong from army');
        assert(to.army == 4, 'Tile: wrong to army');
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid owner',))]
    fn test_tile_transfer_revert_invalid_owner() {
        let mut from = TileTrait::new(0, 4, 'a');
        let mut to = TileTrait::new(0, 2, 'b');
        from.transfer(ref to, 2);
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid army transfer',))]
    fn test_tile_transfer_revert_invalid_army_transfer() {
        let mut from = TileTrait::new(0, 4, 'a');
        let mut to = TileTrait::new(0, 2, 'a');
        from.transfer(ref to, 5);
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_attack_and_defend() {
        let mut dice = DiceTrait::new('seed');
        let mut attacker = TileTrait::new(0, 4, 'a');
        let mut defender = TileTrait::new(1, 2, 'd');
        assert(attacker.army == 4, 'Tile: wrong attacker army');
        assert(defender.army == 2, 'Tile: wrong defender army');
        assert(defender.owner == 'd', 'Tile: wrong defender owner');
        attacker.attack(3, ref defender);
        defender.defend(ref attacker, ref dice);
        assert(attacker.army == 1, 'Tile: wrong attacker army');
        assert(defender.army == 2, 'Tile: wrong defender army');
        assert(defender.owner == 'a', 'Tile: wrong defender owner');
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid dispatched',))]
    fn test_tile_battle_invalid_dispatched() {
        let mut attacker = TileTrait::new(0, 3, 'a');
        let mut defender = TileTrait::new(1, 2, 'd');
        attacker.attack(3, ref defender);
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_sort_len_1() {
        let array = array![1];
        let sorted = _sort(array.span());
        assert(sorted == array.span(), 'Tile: wrong sort');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_sort_len_2() {
        let expected = array![2, 1].span();
        // Case 01
        let array = array![1, 2];
        let sorted = _sort(array.span());
        assert(sorted == expected, 'Tile: wrong sort 01');
        // Case 02
        let array = array![2, 1];
        let sorted = _sort(array.span());
        assert(sorted == expected, 'Tile: wrong sort 02');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_sort_len_3() {
        let expected = array![3, 2, 1].span();
        // Case 01
        let array = array![1, 2, 3];
        let sorted = _sort(array.span());
        assert(sorted == expected, 'Tile: wrong sort 01');
        // Case 02
        let array = array![1, 3, 2];
        let sorted = _sort(array.span());
        assert(sorted == expected, 'Tile: wrong sort 02');
        // Case 03
        let array = array![2, 1, 3];
        let sorted = _sort(array.span());
        assert(sorted == expected, 'Tile: wrong sort 03');
        // Case 04
        let array = array![2, 3, 1];
        let sorted = _sort(array.span());
        assert(sorted == expected, 'Tile: wrong sort 04');
        // Case 05
        let array = array![3, 1, 2];
        let sorted = _sort(array.span());
        assert(sorted == expected, 'Tile: wrong sort 05');
        // Case 06
        let array = array![3, 2, 1];
        let sorted = _sort(array.span());
        assert(sorted == expected, 'Tile: wrong sort 06');
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid array',))]
    fn test_tile_sort_revert_len_0() {
        let array = array![];
        let sorted = _sort(array.span());
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid array',))]
    fn test_tile_sort_revert_len_4() {
        let array = array![1, 2, 3, 4];
        let sorted = _sort(array.span());
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_duel_draw() {
        let mut defensives = array![2, 1].span();
        let mut offsensives = array![2, 1].span();
        let (defensive_losses, offensive_losses) = _duel(ref defensives, ref offsensives);
        assert(defensive_losses == 0, 'Tile: wrong defensive losses');
        assert(offensive_losses == 2, 'Tile: wrong offensive losses');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_duel_conquered() {
        let mut defensives = array![2, 1].span();
        let mut offsensives = array![3, 2].span();
        let (defensive_losses, offensive_losses) = _duel(ref defensives, ref offsensives);
        assert(defensive_losses == 2, 'Tile: wrong defensive losses');
        assert(offensive_losses == 0, 'Tile: wrong offensive losses');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_duel_repelled() {
        let mut defensives = array![3, 2].span();
        let mut offsensives = array![2, 1].span();
        let (defensive_losses, offensive_losses) = _duel(ref defensives, ref offsensives);
        assert(defensive_losses == 0, 'Tile: wrong defensive losses');
        assert(offensive_losses == 2, 'Tile: wrong offensive losses');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_duel_tight() {
        let mut defensives = array![3, 1].span();
        let mut offsensives = array![2, 2].span();
        let (defensive_losses, offensive_losses) = _duel(ref defensives, ref offsensives);
        assert(defensive_losses == 1, 'Tile: wrong defensive losses');
        assert(offensive_losses == 1, 'Tile: wrong offensive losses');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_round() {
        let mut dice = DiceTrait::new('seed');
        let defensive = 2;
        let offensive = 3;
        let (defensive_losses, offensive_losses) = _round(defensive, offensive, ref dice);
        assert(defensive_losses == 1, 'Tile: wrong defensive losses');
        assert(offensive_losses == 1, 'Tile: wrong offensive losses');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_battle_small() {
        let mut dice = DiceTrait::new('seed');
        let defensive = 2;
        let offensive = 3;
        let (defensive_survivors, offensive_survivors) = _battle(defensive, offensive, ref dice);
        assert(defensive_survivors == 0, 'Tile: wrong defensive survivors');
        assert(offensive_survivors == 2, 'Tile: wrong offensive survivors');
    }

    #[test]
    #[available_gas(10_000_000)]
    fn test_tile_battle_big_conquered() {
        let mut dice = DiceTrait::new('seed');
        let defensive = 20;
        let offensive = 30;
        let (defensive_survivors, offensive_survivors) = _battle(defensive, offensive, ref dice);
        assert(defensive_survivors == 0, 'Tile: wrong defensive survivors');
        assert(offensive_survivors == 13, 'Tile: wrong offensive survivors');
    }

    #[test]
    #[available_gas(10_000_000)]
    fn test_tile_battle_big_repelled() {
        let mut dice = DiceTrait::new('seed');
        let defensive = 30;
        let offensive = 20;
        let (defensive_survivors, offensive_survivors) = _battle(defensive, offensive, ref dice);
        assert(defensive_survivors == 9, 'Tile: wrong defensive survivors');
        assert(offensive_survivors == 0, 'Tile: wrong offensive survivors');
    }
}
