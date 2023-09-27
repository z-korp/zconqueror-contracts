//! Tile struct and methods for managing battles, supply and ownerships.

// Core imports

use array::{ArrayTrait, SpanTrait};

// Internal imports

use zrisk::entities::dice::{Dice, DiceTrait};

/// Tile struct.
#[derive(Drop, Serde)]
struct Tile {
    id: u8,
    army: u8,
    owner: u8,
    dispatched: u8,
}

/// Errors module
mod errors {
    const INVALID_DISPATCHED: felt252 = 'Tile: invalid dispatched';
    const INVALID_ARRAY: felt252 = 'Tile: invalid array';
    const INVALID_OWNER: felt252 = 'Tile: invalid owner';
    const INVALID_ARMY_TRANSFER: felt252 = 'Tile: invalid army transfer';
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
    fn new(id: u8, army: u8, owner: u8) -> Tile;
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
    fn new(id: u8, army: u8, owner: u8) -> Tile {
        Tile { id, army, owner, dispatched: 0 }
    }

    fn attack(ref self: Tile, dispatched: u8, ref defender: Tile) {
        // [Check] Dispatched < army
        assert(dispatched < self.army, errors::INVALID_DISPATCHED);
        self.army -= dispatched;
        self.dispatched = dispatched;
    }

    fn defend(ref self: Tile, ref attacker: Tile, ref dice: Dice) {
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
mod Tests {
    // Core imports

    use array::{ArrayTrait, SpanTrait};
    use debug::PrintTrait;

    // Local imports

    use zrisk::entities::dice::{Dice, DiceTrait};
    use zrisk::entities::tile::{Tile, TileTrait, _sort, _battle, _round, _duel};

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
