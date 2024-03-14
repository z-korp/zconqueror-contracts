//! Tile struct and methods for managing battles, supply and ownerships.

// Core imports

use array::{ArrayTrait, SpanTrait};
use poseidon::PoseidonTrait;
use hash::HashStateTrait;

// External imports

use alexandria_data_structures::array_ext::SpanTraitExt;
use origami::random::dice::{Dice, DiceTrait};

// Internal imports

use zconqueror::constants::DICE_FACES_NUMBER;
use zconqueror::config;
use zconqueror::events::Battle;
use zconqueror::models::player::Player;

#[derive(Model, Copy, Drop, Serde)]
struct Tile {
    #[key]
    game_id: u32,
    #[key]
    id: u8,
    army: u32,
    owner: u32,
    dispatched: u32,
    to: u8,
    from: u8,
    order: felt252,
}

/// Errors module
mod errors {
    const INVALID_ID: felt252 = 'Tile: invalid id';
    const INVALID_DISPATCHED: felt252 = 'Tile: invalid dispatched';
    const INVALID_ARRAY: felt252 = 'Tile: invalid array';
    const INVALID_OWNER: felt252 = 'Tile: invalid owner';
    const INVALID_ARMY_TRANSFER: felt252 = 'Tile: invalid army transfer';
    const INVALID_NEIGHBOR: felt252 = 'Tile: invalid neighbor';
    const INVALID_DEFENDER: felt252 = 'Tile: invalid defender';
    const INVALID_ATTACKER: felt252 = 'Tile: invalid attacker';
    const INVALID_ORDER_STATUS: felt252 = 'Tile: invalid order status';
    const INVALID_CONNECTION: felt252 = 'Tile: invalid connection';
    const INVALID_SUPPLY: felt252 = 'Tile: invalid supply';
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
    fn new(game_id: u32, id: u8, army: u32, owner: u32) -> Tile;
    /// Check validity.
    /// # Arguments
    /// * `self` - The tile.
    /// # Returns
    /// * Tile validity status.
    fn check(self: @Tile) -> bool;
    /// Assert validity.
    /// # Arguments
    /// * `self` - The tile.
    fn assert(self: @Tile);
    /// Dispatches an army from the tile.
    /// # Arguments
    /// * `self` - The tile.
    /// * `dispatched` - The dispatched army.
    /// * `defender` - The defending tile.
    /// * `order` - The attack order (tx hash).
    fn attack(ref self: Tile, dispatched: u32, ref defender: Tile, order: felt252);
    /// Defends the tile from an attack.
    /// # Arguments
    /// * `self` - The tile.
    /// * `attacker` - The attacking tile.
    /// * `dice` - The dice to use for the battle.
    /// * `order` - The defend order (tx hash).
    /// # Returns
    /// * The defeated status, true if attacker beat the defender, false otherwise.
    fn defend(
        ref self: Tile,
        ref attacker: Tile,
        seed: felt252,
        order: felt252,
        ref battles: Array<Battle>
    ) -> bool;
    /// Supplies the tile with an army.
    /// # Arguments
    /// * `self` - The tile.
    /// * `army` - The army to supply.
    fn supply(ref self: Tile, ref player: Player, army: u32);
    /// Transfers an army from the tile to another tile.
    /// # Arguments
    /// * `self` - The tile.
    /// * `to` - The tile to transfer the army to.
    /// * `army` - The army to transfer.
    /// * `tiles` - The graph of tiles.
    fn transfer(ref self: Tile, ref to: Tile, army: u32, tiles: Span<Tile>);
}

/// Implementation of the `TileTrait` for the `Tile` struct.
impl TileImpl of TileTrait {
    #[inline(always)]
    fn new(game_id: u32, id: u8, army: u32, owner: u32) -> Tile {
        assert(config::TILE_NUMBER >= id.into() && id > 0, errors::INVALID_ID);
        config::neighbors(id).expect(errors::INVALID_ID);
        Tile { game_id, id, army, owner, dispatched: 0, to: 0, from: 0, order: 0 }
    }

    #[inline(always)]
    fn check(self: @Tile) -> bool {
        config::TILE_NUMBER >= (*self.id).into() && *self.id > 0
    }

    #[inline(always)]
    fn assert(self: @Tile) {
        assert(self.check(), errors::INVALID_ID);
    }

    #[inline(always)]
    fn attack(ref self: Tile, dispatched: u32, ref defender: Tile, order: felt252) {
        // [Check] Tile ids
        self.assert();
        defender.assert();
        assert(self.id != defender.id, errors::INVALID_ID);
        // [Check] Order status is valid
        assert(self.order == 0, errors::INVALID_ORDER_STATUS);
        // [Check] Not attacking self
        assert(self.owner != defender.owner, errors::INVALID_OWNER);
        // [Check] Dispatched < army
        assert(dispatched > 0 && dispatched < self.army, errors::INVALID_DISPATCHED);
        // [Check] Attacker not already attacking
        assert(self.to == 0, errors::INVALID_ATTACKER);
        // [Check] Defender not already defending
        assert(defender.from == 0, errors::INVALID_DEFENDER);
        // [Check] Attack a neighbor
        let neighbors = config::neighbors(self.id).expect(errors::INVALID_ID);
        assert(neighbors.contains(defender.id), errors::INVALID_NEIGHBOR);
        // [Effect] Update attacker
        self.army -= dispatched;
        self.dispatched = dispatched;
        self.to = defender.id;
        self.order = order;
        // [Effect] Update defender
        defender.from = self.id;
    }

    #[inline(always)]
    fn defend(
        ref self: Tile,
        ref attacker: Tile,
        seed: felt252,
        order: felt252,
        ref battles: Array<Battle>
    ) -> bool {
        // [Check] Tile ids
        self.assert();
        attacker.assert();
        assert(self.id != attacker.id, errors::INVALID_ID);
        // [Check] Order status is valid
        assert(attacker.order != order, errors::INVALID_ORDER_STATUS);
        // [Check] Not defending self
        assert(self.owner != attacker.owner, errors::INVALID_OWNER);
        // [Check] Defended from
        assert(self.from == attacker.id && attacker.to == self.id, errors::INVALID_ATTACKER);
        // [Check] Attack from neighbor
        let neighbors = config::neighbors(self.id).expect(errors::INVALID_ID);
        assert(neighbors.contains(attacker.id), errors::INVALID_NEIGHBOR);
        // [Compute] Battle and get survivors
        let mut state = PoseidonTrait::new();
        state = state.update(seed);
        state = state.update(attacker.order);
        let mut dice = DiceTrait::new(DICE_FACES_NUMBER, state.finalize());
        let (defensive_survivors, offensive_survivors) = _battle(
            self.army, attacker.dispatched, ref dice, ref battles,
        );
        // [Effect] Apply losses and update ownership
        self.army = defensive_survivors;
        attacker.dispatched = offensive_survivors;
        let defeated = self.army == 0;
        if defeated {
            self.owner = attacker.owner;
            self.army = attacker.dispatched;
            attacker.dispatched = 0;
        };
        // [Effect] Update attacker
        attacker.order = 0;
        attacker.to = 0;
        // [Effect] Update defended
        self.from = 0;

        // [Return] Defeated status
        defeated
    }

    #[inline(always)]
    fn supply(ref self: Tile, ref player: Player, army: u32) {
        // [Check] Tile ids
        self.assert();
        // [Check] Available supply
        assert(player.supply >= army, errors::INVALID_SUPPLY);
        // [Effect] Update army
        self.army += army;
        // [Effect] Update supply
        player.supply -= army;
    }

    #[inline(always)]
    fn transfer(ref self: Tile, ref to: Tile, army: u32, tiles: Span<Tile>) {
        // [Check] Tile ids
        self.assert();
        to.assert();
        assert(self.id != to.id, errors::INVALID_ID);
        // [Check] Both tiles are owned by the same player
        assert(self.owner == to.owner, errors::INVALID_OWNER);
        // [Check] From tile army is greater than the transfered army
        assert(self.army > army, errors::INVALID_ARMY_TRANSFER);
        // [Check] Both tiles are connected by a owned path
        let mut visiteds: Array<u8> = ArrayTrait::new();
        let connection = _connected(self.id, to.id, @self.owner, tiles, ref visiteds);
        assert(connection, errors::INVALID_CONNECTION);
        // [Effect] Update armies
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
fn _battle(
    mut defensives: u32, mut offensives: u32, ref dice: Dice, ref battles: Array<Battle>
) -> (u32, u32) {
    // [Compute] Losses
    let mut battle_id: u32 = 0;
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
        } else {
            offensives
        };
        let (defensive_losses, offensive_losses) = _round(
            defensive, offensive, ref dice, battle_id, ref battles
        );
        defensives -= defensive_losses;
        offensives -= offensive_losses;
        battle_id += 1;
    };
    (defensives, offensives)
}

/// Resolves a round between two sorted arrays of values.
/// # Arguments
/// * `defensive` - The defensive values.
/// * `offensive` - The offensive values.
/// # Returns
/// * The defensive and offensive losses.
fn _round(
    defensive: u32, offensive: u32, ref dice: Dice, battle_id: u32, ref battles: Array<Battle>
) -> (u32, u32) {
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
    _duel(ref sorted_defensive_values, ref sorted_offensive_values, battle_id, ref battles)
}

/// Resolves a duel between two sorted arrays of values.
/// # Arguments
/// * `defensive` - The defensive values.
/// * `offensive` - The offensive values.
/// # Returns
/// * The defensive and offensive losses.
fn _duel(
    ref defensive: Span<u8>, ref offensive: Span<u8>, battle_id: u32, ref battles: Array<Battle>
) -> (u32, u32) {
    let mut defensive_losses = 0;
    let mut offensive_losses = 0;
    let mut duel_id = 0;
    loop {
        if offensive.is_empty() || defensive.is_empty() {
            break;
        };
        let defensive_value = *defensive.pop_front().unwrap();
        let offensive_value = *offensive.pop_front().unwrap();
        if defensive_value < offensive_value {
            defensive_losses += 1;
        } else {
            offensive_losses += 1;
        };
        let battle = Battle {
            game_id: 0,
            battle_id: battle_id,
            tx_hash: 0,
            duel_id: duel_id,
            attacker_index: 0,
            defender_index: 0,
            attacker_troops: 0,
            defender_troops: 0,
            attacker_value: offensive_value,
            defender_value: defensive_value,
        };
        battles.append(battle);
        duel_id += 1;
    };

    loop {
        if offensive.is_empty() {
            break;
        };
        let offensive_value = *offensive.pop_front().unwrap();
        let battle = Battle {
            game_id: 0,
            battle_id: battle_id,
            tx_hash: 0,
            duel_id: duel_id,
            attacker_index: 0,
            defender_index: 0,
            attacker_troops: 0,
            defender_troops: 0,
            attacker_value: offensive_value,
            defender_value: 0,
        };
        battles.append(battle);
    };

    loop {
        if defensive.is_empty() {
            break;
        };
        let defensive_value = *defensive.pop_front().unwrap();
        let battle = Battle {
            game_id: 0,
            battle_id: battle_id,
            tx_hash: 0,
            duel_id: duel_id,
            attacker_index: 0,
            defender_index: 0,
            attacker_troops: 0,
            defender_troops: 0,
            attacker_value: 0,
            defender_value: defensive_value,
        };
        battles.append(battle);
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

/// Returns true if 2 tiles are connected by an owned path of tiles.
/// # Arguments
/// * `source` - The tile id to start with.
/// * `target` - The tile id to find out.
/// * `owner` - The owner id of the path.
/// * `tiles` - The tiles including their respective owner.
/// * `visiteds` - The visited tiles.
/// # Returns
/// * The connection status.
fn _connected(
    source: u8, target: u8, owner: @u32, tiles: Span<Tile>, ref visiteds: Array<u8>
) -> bool {
    if source == target {
        return true;
    };
    let mut neighbors = config::neighbors(source).expect(errors::INVALID_ID);
    let mut unvisiteds = _owned_dedup(ref neighbors, tiles, visiteds.span(), owner);
    visiteds.append(source);
    _connected_iter(target, owner, tiles, ref visiteds, ref unvisiteds)
}

/// The connected sub function used for recursion.
/// # Arguments
/// * `target` - The tile id to find out.
/// * `owner` - The owner id of the path.
/// * `tiles` - The tiles including their respective owner.
/// * `visiteds` - The visited tiles.
/// * `unvisiteds` - The unvisited tiles.
/// # Returns
/// * The connection status.
fn _connected_iter(
    target: u8, owner: @u32, tiles: Span<Tile>, ref visiteds: Array<u8>, ref unvisiteds: Span<u8>
) -> bool {
    match unvisiteds.pop_front() {
        Option::Some(neighbour) => {
            if _connected(*neighbour, target, owner, tiles, ref visiteds) {
                return true;
            }
            return _connected_iter(target, owner, tiles, ref visiteds, ref unvisiteds);
        },
        Option::None => {
            return false;
        },
    }
}

/// Returns the input array without the drop and not owned elements.
/// # Arguments
/// * `array` - The array to dedup.
/// * `tiles` - The tiles including their respective owner.
/// * `drops` - The specification of elements to drop.
/// * `owner` - The owner to match.
/// # Returns
/// * The deduped array.
fn _owned_dedup(ref array: Span<u8>, tiles: Span<Tile>, drops: Span<u8>, owner: @u32) -> Span<u8> {
    // [Check] Drops is not empty, otherwise return the input array
    if drops.is_empty() {
        return array;
    };
    let mut result: Array<u8> = array![];
    loop {
        match array.pop_front() {
            Option::Some(value) => {
                let element = *value;
                let tile = tiles.at(element.into() - 1);
                if !drops.contains(element) && tile.owner == owner {
                    result.append(element);
                };
            },
            Option::None => {
                break;
            },
        };
    };
    result.span()
}

#[cfg(test)]
mod tests {
    // External imports

    use alexandria_data_structures::array_ext::SpanTraitExt;
    use origami::random::dice::{Dice, DiceTrait};

    // Internal imports

    use zconqueror::constants::DICE_FACES_NUMBER;
    use zconqueror::config;
    use zconqueror::models::player::Player;
    use zconqueror::events::Battle;

    // Local imports

    use super::{Tile, TileTrait, _sort, _battle, _round, _duel, _connected, _owned_dedup};

    // Constants

    const GAME_ID: u32 = 0;
    const SEED: felt252 = 'seed';
    const PLAYER_1: u32 = 0;
    const PLAYER_2: u32 = 1;

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid id',))]
    fn test_tile_new_invalid_id() {
        let invalid_id = config::TILE_NUMBER.try_into().unwrap() + 1;
        TileTrait::new(GAME_ID, invalid_id, 4, PLAYER_1);
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_supply() {
        let mut player: Player = Zeroable::zero();
        player.supply = 5;
        let mut tile = TileTrait::new(GAME_ID, 2, 4, PLAYER_1);
        assert(tile.army == 4, 'Tile: wrong tile army');
        tile.supply(ref player, 2);
        assert(tile.army == 6, 'Tile: wrong tile army');
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid id',))]
    fn test_tile_supply_invalid_id() {
        let invalid_id = config::TILE_NUMBER.try_into().unwrap() + 1;
        let mut player: Player = Zeroable::zero();
        player.supply = 4;
        let mut tile = TileTrait::new(GAME_ID, invalid_id, 4, PLAYER_1);
        tile.supply(ref player, 2);
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid supply',))]
    fn test_tile_supply_invalid_supply() {
        let mut player: Player = Zeroable::zero();
        player.supply = 1;
        let mut tile = TileTrait::new(GAME_ID, 1, 4, PLAYER_1);
        tile.supply(ref player, 2);
    }

    #[test]
    #[available_gas(5_000_000)]
    fn test_tile_transfer() {
        let mut from = TileTrait::new(GAME_ID, 1, 4, PLAYER_1);
        let mut to = TileTrait::new(GAME_ID, 2, 2, PLAYER_1);
        let mut tiles: Array<Tile> = array![];
        let mut tile_index: u8 = 1;
        loop {
            if config::TILE_NUMBER < tile_index.into() {
                break;
            };
            tiles.append(TileTrait::new(GAME_ID, tile_index, 0, PLAYER_1));
            tile_index += 1;
        };
        from.transfer(ref to, 2, tiles.span());
        assert(from.army == 2, 'Tile: wrong from army');
        assert(to.army == 4, 'Tile: wrong to army');
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid owner',))]
    fn test_tile_transfer_invalid_owner() {
        let mut from = TileTrait::new(GAME_ID, 1, 4, PLAYER_1);
        let mut to = TileTrait::new(GAME_ID, 2, 2, PLAYER_2);
        from.transfer(ref to, 2, array![].span());
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid id',))]
    fn test_tile_transfer_invalid_from_id() {
        let invalid_id: u8 = config::TILE_NUMBER.try_into().unwrap() + 1;
        let mut from = TileTrait::new(GAME_ID, invalid_id, 4, PLAYER_1);
        let mut to = TileTrait::new(GAME_ID, 2, 2, PLAYER_1);
        from.transfer(ref to, 2, array![].span());
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid id',))]
    fn test_tile_transfer_invalid_to_id() {
        let invalid_id: u8 = config::TILE_NUMBER.try_into().unwrap() + 1;
        let mut from = TileTrait::new(GAME_ID, 1, 4, PLAYER_1);
        let mut to = TileTrait::new(GAME_ID, invalid_id, 2, PLAYER_1);
        from.transfer(ref to, 2, array![].span());
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid id',))]
    fn test_tile_transfer_invalid_id() {
        let mut from = TileTrait::new(GAME_ID, 1, 4, PLAYER_1);
        let mut to = TileTrait::new(GAME_ID, 1, 2, PLAYER_1);
        from.transfer(ref to, 2, array![].span());
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid army transfer',))]
    fn test_tile_transfer_invalid_army_transfer() {
        let mut from = TileTrait::new(GAME_ID, 1, 4, PLAYER_1);
        let mut to = TileTrait::new(GAME_ID, 2, 2, PLAYER_1);
        from.transfer(ref to, 5, array![].span());
    }

    #[test]
    #[available_gas(5_000_000)]
    #[should_panic(expected: ('Tile: invalid connection',))]
    fn test_tile_transfer_invalid_connection() {
        let mut from = TileTrait::new(GAME_ID, 1, 4, PLAYER_1);
        // [Compute] Not connected tile
        let mut neighbors = config::neighbors(from.id).expect('Tile: invalid id');
        let neighbor = neighbors.pop_front().expect('Tile: no neighbors');
        let mut connected = TileTrait::new(GAME_ID, *neighbor, 2, PLAYER_2);
        let mut foreigners = config::neighbors(connected.id).expect('Tile: invalid id');
        let index = loop {
            match foreigners.pop_front() {
                Option::Some(index) => {
                    if index != @from.id && !neighbors.contains(*index) {
                        break index;
                    };
                },
                Option::None => {
                    panic(array!['Tile: foreigner not found']);
                },
            };
        };
        let mut to = TileTrait::new(GAME_ID, *index, 2, PLAYER_1);
        // [Compute] Graph of tiles
        let mut tiles: Array<Tile> = array![];
        let mut tile_index: u8 = 1;
        loop {
            if config::TILE_NUMBER < tile_index.into() {
                break;
            };
            tiles.append(TileTrait::new(GAME_ID, tile_index, 0, PLAYER_2));
            tile_index += 1;
        };
        from.transfer(ref to, 2, tiles.span());
    }

    #[test]
    #[available_gas(1_200_000)]
    fn test_tile_attack_and_defend_lose() {
        let mut battles: Array<Battle> = array![];
        let mut attacker = TileTrait::new(GAME_ID, 1, 10, PLAYER_1);
        let mut neighbors = config::neighbors(attacker.id).expect('Tile: invalid id');
        let neighbor = neighbors.pop_front().expect('Tile: no neighbors');
        let mut defender = TileTrait::new(GAME_ID, *neighbor, 2, PLAYER_2);
        assert(attacker.army == 10, 'Tile: wrong attacker army');
        assert(defender.army == 2, 'Tile: wrong defender army');
        assert(defender.owner == PLAYER_2, 'Tile: wrong defender owner');
        attacker.attack(3, ref defender, 'ATTACK');
        assert(attacker.to == defender.id, 'Tile: wrong attacker to');
        assert(defender.from == attacker.id, 'Tile: wrong defender from');
        let defeated = defender.defend(ref attacker, SEED, 'DEFEND', ref battles);
        assert(attacker.to == 0, 'Tile: wrong attacker to');
        assert(attacker.army == 7, 'Tile: wrong attacker army');
        assert(defender.from == 0, 'Tile: wrong defender from');
        assert(defender.army == 2, 'Tile: wrong defender army');
        assert(defender.owner == PLAYER_2, 'Tile: wrong defender owner');
        assert(!defeated, 'Tile: wrong defender defeated');
    }

    #[test]
    #[available_gas(2_000_000)]
    fn test_tile_attack_and_defend_win() {
        let mut battles: Array<Battle> = array![];
        let mut attacker = TileTrait::new(GAME_ID, 1, 10, PLAYER_1);
        let mut neighbors = config::neighbors(attacker.id).expect('Tile: invalid id');
        let neighbor = neighbors.pop_front().expect('Tile: no neighbors');
        let mut defender = TileTrait::new(GAME_ID, *neighbor, 2, PLAYER_2);
        assert(attacker.army == 10, 'Tile: wrong attacker army');
        assert(defender.army == 2, 'Tile: wrong defender army');
        assert(defender.owner == PLAYER_2, 'Tile: wrong defender owner');
        attacker.attack(9, ref defender, 'ATTACK');
        assert(attacker.to == defender.id, 'Tile: wrong attacker to');
        assert(defender.from == attacker.id, 'Tile: wrong defender from');
        let defeated = defender.defend(ref attacker, SEED, 'DEFEND', ref battles);
        assert(attacker.to == 0, 'Tile: wrong attacker to');
        assert(attacker.army == 1, 'Tile: wrong attacker army');
        assert(defender.from == 0, 'Tile: wrong defender from');
        assert(defender.army == 5, 'Tile: wrong defender army');
        assert(defender.owner == PLAYER_1, 'Tile: wrong defender owner');
        assert(defeated, 'Tile: wrong defender defeated');
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid id',))]
    fn test_tile_attack_invalid_attacker_id() {
        let invalid_id = config::TILE_NUMBER.try_into().unwrap() + 1;
        let mut attacker = TileTrait::new(GAME_ID, invalid_id, 4, PLAYER_1);
        let mut neighbors = config::neighbors(attacker.id).expect('Tile: invalid id');
        let neighbor = neighbors.pop_front().expect('Tile: no neighbors');
        let mut defender = TileTrait::new(GAME_ID, *neighbor, 2, PLAYER_2);
        attacker.attack(3, ref defender, 'ATTACK');
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid id',))]
    fn test_tile_attack_invalid_defender_id() {
        let invalid_id = config::TILE_NUMBER.try_into().unwrap() + 1;
        let mut attacker = TileTrait::new(GAME_ID, 1, 4, PLAYER_1);
        let mut defender = TileTrait::new(GAME_ID, invalid_id, 2, PLAYER_2);
        attacker.attack(3, ref defender, 'ATTACK');
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid id',))]
    fn test_tile_attack_invalid_id() {
        let mut attacker = TileTrait::new(GAME_ID, 1, 4, PLAYER_1);
        attacker.attack(3, ref attacker, 'ATTACK');
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid order status',))]
    fn test_tile_attack_invalid_order() {
        let mut defender = TileTrait::new(GAME_ID, 1, 4, PLAYER_1);
        let mut neighbors = config::neighbors(defender.id).expect('Tile: invalid id');
        let neighbor = neighbors.pop_front().expect('Tile: no neighbors');
        let mut attacker = TileTrait::new(GAME_ID, *neighbor, 2, PLAYER_2);
        let mut allies = config::neighbors(attacker.id).expect('Tile: invalid id');
        let index = loop {
            match allies.pop_front() {
                Option::Some(index) => {
                    if index != @defender.id {
                        break index;
                    };
                },
                Option::None => {
                    panic(array!['Tile: ally not found']);
                },
            };
        };
        let mut ally = TileTrait::new(GAME_ID, *index, 2, PLAYER_1);
        attacker.attack(1, ref defender, 'ATTACK');
        attacker.attack(1, ref ally, 'ATTACK');
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid owner',))]
    fn test_tile_attack_invalid_owner_self_attack() {
        let mut attacker = TileTrait::new(GAME_ID, 1, 4, PLAYER_1);
        let mut neighbors = config::neighbors(attacker.id).expect('Tile: invalid id');
        let neighbor = neighbors.pop_front().expect('Tile: no neighbors');
        let mut defender = TileTrait::new(GAME_ID, *neighbor, 2, PLAYER_1);
        attacker.attack(3, ref defender, 'ATTACK');
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid dispatched',))]
    fn test_tile_attack_invalid_dispatched() {
        let mut attacker = TileTrait::new(GAME_ID, 1, 4, PLAYER_1);
        let mut neighbors = config::neighbors(attacker.id).expect('Tile: invalid id');
        let neighbor = neighbors.pop_front().expect('Tile: no neighbors');
        let mut defender = TileTrait::new(GAME_ID, *neighbor, 2, PLAYER_2);
        attacker.attack(4, ref defender, 'ATTACK');
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid dispatched',))]
    fn test_tile_attack_invalid_no_dispatched() {
        let mut attacker = TileTrait::new(GAME_ID, 1, 4, PLAYER_1);
        let mut neighbors = config::neighbors(attacker.id).expect('Tile: invalid id');
        let neighbor = neighbors.pop_front().expect('Tile: no neighbors');
        let mut defender = TileTrait::new(GAME_ID, *neighbor, 2, PLAYER_2);
        attacker.attack(0, ref defender, 'ATTACK');
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid attacker',))]
    fn test_tile_attack_invalid_attacker() {
        let mut attacker = TileTrait::new(GAME_ID, 1, 4, PLAYER_1);
        let mut neighbors = config::neighbors(attacker.id).expect('Tile: invalid id');
        let neighbor = neighbors.pop_front().expect('Tile: no neighbors');
        let mut defender = TileTrait::new(GAME_ID, *neighbor, 2, PLAYER_2);
        attacker.attack(2, ref defender, 0);
        attacker.attack(1, ref defender, 0);
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid defender',))]
    fn test_tile_attack_invalid_defender() {
        let mut attacker = TileTrait::new(GAME_ID, 2, 4, PLAYER_1);
        let mut neighbors = config::neighbors(attacker.id).expect('Tile: invalid id');
        let neighbor = neighbors.pop_front().expect('Tile: no neighbors');
        let mut defender = TileTrait::new(GAME_ID, *neighbor, 2, PLAYER_2);
        let mut neighbors = config::neighbors(defender.id).expect('Tile: invalid id');
        let neighbor = neighbors.pop_front().expect('Tile: no neighbors');
        let mut mercenary = TileTrait::new(GAME_ID, *neighbor, 2, PLAYER_1);
        attacker.attack(3, ref defender, 'ATTACK');
        mercenary.attack(1, ref defender, 'ATTACK');
    }

    #[test]
    #[available_gas(5_000_000)]
    #[should_panic(expected: ('Tile: invalid neighbor',))]
    fn test_tile_attack_invalid_neighbor() {
        let mut attacker = TileTrait::new(GAME_ID, 2, 4, PLAYER_1);
        let mut neighbors = config::neighbors(attacker.id).expect('Tile: invalid id');
        let neighbor = neighbors.pop_front().expect('Tile: no neighbors');
        let mut defender = TileTrait::new(GAME_ID, *neighbor, 2, PLAYER_2);
        let mut allies = config::neighbors(defender.id).expect('Tile: invalid id');
        let index = loop {
            match allies.pop_front() {
                Option::Some(index) => {
                    if index != @attacker.id && !neighbors.contains(*index) {
                        break index;
                    };
                },
                Option::None => {
                    panic(array!['Tile: foreigner not found']);
                },
            };
        };
        let mut foreigner = TileTrait::new(GAME_ID, *index, 2, PLAYER_2);
        attacker.attack(3, ref foreigner, 'ATTACK');
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid order status',))]
    fn test_tile_attack_and_defend_invalid_order() {
        let mut battles: Array<Battle> = array![];
        let mut attacker = TileTrait::new(GAME_ID, 1, 4, PLAYER_1);
        let mut neighbors = config::neighbors(attacker.id).expect('Tile: invalid id');
        let neighbor = neighbors.pop_front().expect('Tile: no neighbors');
        let mut defender = TileTrait::new(GAME_ID, *neighbor, 2, PLAYER_2);
        attacker.attack(3, ref defender, 'ATTACK');
        defender.defend(ref attacker, SEED, 'ATTACK', ref battles);
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid id',))]
    fn test_tile_attack_and_defend_invalid_attacker_id() {
        let mut battles: Array<Battle> = array![];
        let invalid_id = config::TILE_NUMBER.try_into().unwrap() + 1;
        let mut attacker = TileTrait::new(GAME_ID, invalid_id, 4, PLAYER_1);
        let mut defender = TileTrait::new(GAME_ID, 1, 2, PLAYER_1);
        defender.defend(ref attacker, SEED, 'DEFEND', ref battles);
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid id',))]
    fn test_tile_attack_and_defend_invalid_defender_id() {
        let mut battles: Array<Battle> = array![];
        let invalid_id = config::TILE_NUMBER.try_into().unwrap() + 1;
        let mut attacker = TileTrait::new(GAME_ID, 1, 4, PLAYER_1);
        let mut defender = TileTrait::new(GAME_ID, invalid_id, 2, PLAYER_1);
        defender.defend(ref attacker, SEED, 'DEFEND', ref battles);
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid id',))]
    fn test_tile_attack_and_defend_invalid_id() {
        let mut battles: Array<Battle> = array![];
        let mut attacker = TileTrait::new(GAME_ID, 2, 4, PLAYER_1);
        attacker.defend(ref attacker, SEED, 'DEFEND', ref battles);
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid attacker',))]
    fn test_tile_attack_and_defend_invalid_attacker_self_attack() {
        let mut battles: Array<Battle> = array![];
        let mut attacker = TileTrait::new(GAME_ID, 1, 4, PLAYER_1);
        let mut neighbors = config::neighbors(attacker.id).expect('Tile: invalid id');
        let neighbor = neighbors.pop_front().expect('Tile: no neighbors');
        let mut defender = TileTrait::new(GAME_ID, *neighbor, 2, PLAYER_2);
        defender.defend(ref attacker, SEED, 'DEFEND', ref battles);
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid owner',))]
    fn test_tile_attack_and_defend_invalid_owner_self_attack() {
        let mut battles: Array<Battle> = array![];
        let mut attacker = TileTrait::new(GAME_ID, 1, 4, PLAYER_1);
        let mut neighbors = config::neighbors(attacker.id).expect('Tile: invalid id');
        let neighbor = neighbors.pop_front().expect('Tile: no neighbors');
        let mut defender = TileTrait::new(GAME_ID, *neighbor, 2, PLAYER_2);
        attacker.attack(3, ref defender, 'ATTACK');
        defender.owner = PLAYER_1;
        defender.defend(ref attacker, SEED, 'DEFEND', ref battles);
    }

    #[test]
    #[available_gas(5_000_000)]
    #[should_panic(expected: ('Tile: invalid neighbor',))]
    fn test_tile_attack_and_defend_invalid_neighbor() {
        let mut battles: Array<Battle> = array![];
        let mut defender = TileTrait::new(GAME_ID, 2, 4, PLAYER_1);
        let mut neighbors = config::neighbors(defender.id).expect('Tile: invalid id');
        let neighbor = neighbors.pop_front().expect('Tile: no neighbors');
        let mut attacker = TileTrait::new(GAME_ID, *neighbor, 2, PLAYER_2);
        let mut allies = config::neighbors(attacker.id).expect('Tile: invalid id');
        let mut index = loop {
            match allies.pop_front() {
                Option::Some(index) => {
                    if index != @defender.id && !neighbors.contains(*index) {
                        break index;
                    };
                },
                Option::None => {
                    panic(array!['Tile: ally not found']);
                },
            };
        };
        attacker.attack(1, ref defender, 'ATTACK');
        attacker.id = *index; // Attacker is now at the foreigner location
        defender.from = attacker.id;
        defender.defend(ref attacker, SEED, 'DEFEND', ref battles);
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
        _sort(array.span());
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Tile: invalid array',))]
    fn test_tile_sort_revert_len_4() {
        let array = array![1, 2, 3, 4];
        _sort(array.span());
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_duel_draw() {
        let mut battles: Array<Battle> = array![];
        let mut defensives = array![2, 1].span();
        let mut offsensives = array![2, 1].span();
        let (defensive_losses, offensive_losses) = _duel(
            ref defensives, ref offsensives, 0, ref battles
        );
        assert(defensive_losses == 0, 'Tile: wrong defensive losses');
        assert(offensive_losses == 2, 'Tile: wrong offensive losses');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_duel_conquered() {
        let mut battles: Array<Battle> = array![];
        let mut defensives = array![2, 1].span();
        let mut offsensives = array![3, 2].span();
        let (defensive_losses, offensive_losses) = _duel(
            ref defensives, ref offsensives, 0, ref battles
        );
        assert(defensive_losses == 2, 'Tile: wrong defensive losses');
        assert(offensive_losses == 0, 'Tile: wrong offensive losses');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_duel_repelled() {
        let mut battles: Array<Battle> = array![];
        let mut defensives = array![3, 2].span();
        let mut offsensives = array![2, 1].span();
        let (defensive_losses, offensive_losses) = _duel(
            ref defensives, ref offsensives, 0, ref battles
        );
        assert(defensive_losses == 0, 'Tile: wrong defensive losses');
        assert(offensive_losses == 2, 'Tile: wrong offensive losses');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_duel_tight() {
        let mut battles: Array<Battle> = array![];
        let mut defensives = array![3, 1].span();
        let mut offsensives = array![2, 2].span();
        let (defensive_losses, offensive_losses) = _duel(
            ref defensives, ref offsensives, 0, ref battles
        );
        assert(defensive_losses == 1, 'Tile: wrong defensive losses');
        assert(offensive_losses == 1, 'Tile: wrong offensive losses');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_round() {
        let mut battles: Array<Battle> = array![];
        let mut dice = DiceTrait::new(DICE_FACES_NUMBER, SEED);
        let defensive = 2;
        let offensive = 3;
        let (defensive_losses, offensive_losses) = _round(
            defensive, offensive, ref dice, 0, ref battles
        );
        assert(defensive_losses == 1, 'Tile: wrong defensive losses');
        assert(offensive_losses == 1, 'Tile: wrong offensive losses');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_tile_battle_small() {
        let mut battles: Array<Battle> = array![];
        let mut dice = DiceTrait::new(DICE_FACES_NUMBER, SEED);
        let defensive = 2;
        let offensive = 3;
        let (defensive_survivors, offensive_survivors) = _battle(
            defensive, offensive, ref dice, ref battles
        );
        assert(defensive_survivors == 0, 'Tile: wrong defensive survivors');
        assert(offensive_survivors == 2, 'Tile: wrong offensive survivors');
    }

    #[test]
    #[available_gas(10_000_000)]
    fn test_tile_battle_big_conquered() {
        let mut battles: Array<Battle> = array![];
        let mut dice = DiceTrait::new(DICE_FACES_NUMBER, SEED);
        let defensive = 20;
        let offensive = 30;
        let (defensive_survivors, offensive_survivors) = _battle(
            defensive, offensive, ref dice, ref battles
        );
        assert(defensive_survivors == 0, 'Tile: wrong defensive survivors');
        assert(offensive_survivors == 13, 'Tile: wrong offensive survivors');
    }

    #[test]
    #[available_gas(10_000_000)]
    fn test_tile_battle_big_repelled() {
        let mut battles: Array<Battle> = array![];
        let mut dice = DiceTrait::new(DICE_FACES_NUMBER, SEED);
        let defensive = 30;
        let offensive = 20;
        let (defensive_survivors, offensive_survivors) = _battle(
            defensive, offensive, ref dice, ref battles
        );
        assert(defensive_survivors == 9, 'Tile: wrong defensive survivors');
        assert(offensive_survivors == 0, 'Tile: wrong offensive survivors');
    }

    #[test]
    #[available_gas(500_000)]
    fn test_tile_dedup() {
        let mut tiles: Array<Tile> = array![];
        tiles.append(TileTrait::new(GAME_ID, 2, 0, PLAYER_1));
        tiles.append(TileTrait::new(GAME_ID, 3, 0, PLAYER_1));
        tiles.append(TileTrait::new(GAME_ID, 4, 0, PLAYER_1));
        let mut array = array![1, 2, 3].span();
        let mut drops = array![2, 3].span();
        let deduped = _owned_dedup(ref array, tiles.span(), drops, @PLAYER_1);
        assert(deduped == array![1].span(), 'Tile: wrong dedup');
    }

    #[test]
    #[available_gas(500_000)]
    fn test_tile_dedup_not_owned() {
        let mut tiles: Array<Tile> = array![];
        tiles.append(TileTrait::new(GAME_ID, 1, 0, PLAYER_2));
        tiles.append(TileTrait::new(GAME_ID, 2, 0, PLAYER_1));
        tiles.append(TileTrait::new(GAME_ID, 3, 0, PLAYER_1));
        let mut array = array![1, 2, 3].span();
        let mut drops = array![2, 3].span();
        let deduped = _owned_dedup(ref array, tiles.span(), drops, @PLAYER_1);
        assert(deduped == array![].span(), 'Tile: wrong dedup');
    }

    #[test]
    #[available_gas(500_000)]
    fn test_tile_dedup_no_intersection() {
        let mut tiles: Array<Tile> = array![];
        tiles.append(TileTrait::new(GAME_ID, 1, 0, PLAYER_1));
        tiles.append(TileTrait::new(GAME_ID, 2, 0, PLAYER_1));
        tiles.append(TileTrait::new(GAME_ID, 3, 0, PLAYER_1));
        let mut array = array![1, 2, 3].span();
        let mut drops = array![4, 5, 6].span();
        let deduped = _owned_dedup(ref array, tiles.span(), drops, @PLAYER_1);
        assert(deduped == array![1, 2, 3].span(), 'Tile: wrong dedup');
    }

    #[test]
    #[available_gas(500_000)]
    fn test_tile_dedup_array_empty() {
        let mut tiles: Array<Tile> = array![];
        let mut array = array![].span();
        let mut drops = array![3, 4, 5].span();
        let deduped = _owned_dedup(ref array, tiles.span(), drops, @PLAYER_1);
        assert(deduped == array![].span(), 'Tile: wrong dedup');
    }

    #[test]
    #[available_gas(500_000)]
    fn test_tile_dedup_drops_empty() {
        let mut tiles: Array<Tile> = array![];
        tiles.append(TileTrait::new(GAME_ID, 1, 0, PLAYER_1));
        tiles.append(TileTrait::new(GAME_ID, 2, 0, PLAYER_1));
        tiles.append(TileTrait::new(GAME_ID, 3, 0, PLAYER_1));
        let mut array = array![1, 2, 3].span();
        let mut drops = array![].span();
        let deduped = _owned_dedup(ref array, tiles.span(), drops, @PLAYER_1);
        assert(deduped == array![1, 2, 3].span(), 'Tile: wrong dedup');
    }

    #[test]
    #[available_gas(150_000_000)]
    fn test_tile_connected() {
        let tile_count: u8 = config::TILE_NUMBER.try_into().unwrap();
        let mut tiles: Array<Tile> = array![];
        let mut index = 1;
        loop {
            if index > tile_count {
                break;
            };
            tiles.append(TileTrait::new(GAME_ID, index, 0, PLAYER_1));
            index += 1;
        };
        let mut visiteds = array![];
        let connection = _connected(1, tile_count, @PLAYER_1, tiles.span(), ref visiteds);
        assert(connection, 'Tile: wrong connection status');
    }

    #[test]
    #[available_gas(150_000_000)]
    fn test_tile_not_connected() {
        let tile_count: u8 = config::TILE_NUMBER.try_into().unwrap();
        let mut tiles: Array<Tile> = array![];
        tiles.append(TileTrait::new(GAME_ID, 1, 0, PLAYER_1));
        tiles.append(TileTrait::new(GAME_ID, 2, 0, PLAYER_1));
        let mut index = 3;
        loop {
            if index > tile_count {
                break;
            };
            tiles.append(TileTrait::new(GAME_ID, index, 0, PLAYER_2));
            index += 1;
        };
        let mut visiteds = array![];
        let connection = _connected(1, tile_count, @PLAYER_1, tiles.span(), ref visiteds);
        assert(!connection, 'Tile: wrong connection status');
    }
}
