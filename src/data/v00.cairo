//! This file is generated automatically by `scripts/generate.sh`. Please, don't change it.

// Constants

const TILE_NUMBER: u32 = 5;
const ARMY_NUMBER: u32 = 5;
const FACTION_01: felt252 = 'RED';
const FACTION_02: felt252 = 'BLUE';

/// Return tile faction based on id.
/// # Arguments
/// * `id` - The tile id.
/// # Returns
/// * The corresponding faction.
#[inline(always)]
fn faction(id: u8) -> Option<felt252> {
    if id < 3 {
        return Option::Some(FACTION_01);
    } else if TILE_NUMBER > id.into() {
        return Option::Some(FACTION_02);
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
fn neighbors(id: u8) -> Option<Span<u8>> {
    if id == 0 {
        return Option::Some(array![2].span());
    } else if id == 1 {
        return Option::Some(array![2].span());
    } else if id == 2 {
        return Option::Some(array![0, 1, 3, 4].span());
    } else if id == 3 {
        return Option::Some(array![2].span());
    } else if id == 4 {
        return Option::Some(array![2].span());
    } else {
        return Option::None;
    }
}
