//! This file is generated automatically by `scripts/generate.sh`. Please, don't change it.

// Constants

const TILE_NUMBER: u32 = 5;
const ARMY_NUMBER: u32 = 5;

const FACTION_01: felt252 = 'RED';
const FACTION_02: felt252 = 'BLUE';

const INFANTRY: u16 = 1;
const CAVALRY: u16 = 10;
const ARTILLERY: u16 = 100;
const JOCKER: u16 = 1000;

/// Return the card number based on tile number.
/// # Arguments
/// * `id` - The card id.
/// # Returns
/// * The corresponding tile id and unit type.
#[inline(always)]
fn card_number() -> u32 {
    // Tile number + 5% if > 20, otherwise add 1
    if TILE_NUMBER > 20 {
        TILE_NUMBER + 5 * TILE_NUMBER / 100
    } else {
        TILE_NUMBER + 1
    }
}

/// Return the tile id and unit type based on the card id.
/// # Arguments
/// * `id` - The card id.
/// # Returns
/// * The corresponding tile id and unit type.
#[inline(always)]
fn card(id: u8) -> Option<(u8, u16)> {
    // ID cannot be 0
    if id == 0 {
        return Option::None;
    // If extra cards, set special unit type
    } else if TILE_NUMBER < id.into() {
        return Option::Some((id, JOCKER));
    // Otherwise, set unit type based on id
    } else {
        let unit: u16 = if id % 3 == 0 {
            INFANTRY
        } else if id % 3 == 1 {
            CAVALRY
        } else {
            ARTILLERY
        };
        return Option::Some((id, unit));
    }
}

/// Return tile faction based on id.
/// # Arguments
/// * `id` - The tile id.
/// # Returns
/// * The corresponding faction.
#[inline(always)]
fn faction(id: u8) -> Option<felt252> {
    if id < 4 {
        return Option::Some(FACTION_01);
    } else if TILE_NUMBER >= id.into() {
        return Option::Some(FACTION_02);
    } else {
        return Option::None;
    }
}

/// Return the factions as an iterable.
/// # Returns
/// * The factions.
#[inline(always)]
fn factions() -> Span<felt252> {
    array![FACTION_01, FACTION_02].span()
}

/// Return ids per faction.
/// # Arguments
/// * `faction` - The faction id.
/// # Returns
/// * The corresponding ids.
#[inline(always)]
fn ids(faction: felt252) -> Option<Span<u8>> {
    if faction == FACTION_01 {
        return Option::Some(array![1, 2, 3].span());
    } else if faction == FACTION_02 {
        return Option::Some(array![4, 5].span());
    } else {
        return Option::None;
    }
}

/// Return score per faction.
/// # Arguments
/// * `faction` - The faction id.
/// # Returns
/// * The corresponding score.
#[inline(always)]
fn score(faction: felt252) -> Option<u32> {
    match ids(faction) {
        Option::Some(_ids) => { Option::Some((_ids.len() - 1) / 2) },
        Option::None => { Option::None },
    }
}

/// Return tile neighbors based on id.
/// # Arguments
/// * `id` - The tile id.
/// # Returns
/// * The corresponding neighbors.
#[inline(always)]
fn neighbors(id: u8) -> Option<Span<u8>> {
    if id == 1 {
        return Option::Some(array![2].span());
    } else if id == 2 {
        return Option::Some(array![3, 1].span());
    } else if id == 3 {
        return Option::Some(array![4, 5, 2].span());
    } else if id == 4 {
        return Option::Some(array![3, 5].span());
    } else if id == 5 {
        return Option::Some(array![4, 3].span());
    } else {
        return Option::None;
    }
}
