//! This file is generated automatically by `scripts/generate.sh`. Please, don't change it.

// constants

const TILE_NUMBER: u32 = 50;
const ARMY_NUMBER: u32 = 30;
const FACTION_01: felt252 = 'GREEN';
const FACTION_02: felt252 = 'RED';
const FACTION_03: felt252 = 'PURPLE';
const FACTION_04: felt252 = 'ORANGE';
const FACTION_05: felt252 = 'YELLOW';
const FACTION_06: felt252 = 'CYAN';
const FACTION_07: felt252 = 'BLUE';
const FACTION_08: felt252 = 'PINK';

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
    // Tile number + 5% if > 20, otherwise add 1
    let count = card_number();

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
    if id < 7 {
        return Option::Some(FACTION_01);
    } else if id < 15 {
        return Option::Some(FACTION_02);
    } else if id < 20 {
        return Option::Some(FACTION_03);
    } else if id < 27 {
        return Option::Some(FACTION_04);
    } else if id < 33 {
        return Option::Some(FACTION_05);
    } else if id < 37 {
        return Option::Some(FACTION_06);
    } else if id < 42 {
        return Option::Some(FACTION_07);
    } else if TILE_NUMBER >= id.into() {
        return Option::Some(FACTION_08);
    } else {
        return Option::None;
    }
}

/// Return the factions as an iterable.
/// # Returns
/// * The factions.
#[inline(always)]
fn factions() -> Span<felt252> {
    array![
        FACTION_01,
        FACTION_02,
        FACTION_03,
        FACTION_04,
        FACTION_05,
        FACTION_06,
        FACTION_07,
        FACTION_08
    ]
        .span()
}

/// Return ids per faction.
/// # Arguments
/// * `faction` - The faction id.
/// # Returns
/// * The corresponding ids.
#[inline(always)]
fn ids(faction: felt252) -> Option<Span<u8>> {
    if faction == FACTION_01 {
        return Option::Some(array![1, 2, 3, 4, 5, 6].span());
    } else if faction == FACTION_02 {
        return Option::Some(array![7, 8, 9, 10, 11, 12, 13, 14].span());
    } else if faction == FACTION_03 {
        return Option::Some(array![15, 16, 17, 18, 19].span());
    } else if faction == FACTION_04 {
        return Option::Some(array![20, 21, 22, 23, 24, 25, 26].span());
    } else if faction == FACTION_05 {
        return Option::Some(array![27, 28, 29, 30, 31, 32].span());
    } else if faction == FACTION_06 {
        return Option::Some(array![33, 34, 35, 36].span());
    } else if faction == FACTION_07 {
        return Option::Some(array![37, 38, 39, 40, 41].span());
    } else if faction == FACTION_08 {
        return Option::Some(array![42, 43, 44, 45, 46, 47, 48, 49,].span());
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
        return Option::Some(array![1, 3].span());
    } else if id == 3 {
        return Option::Some(array![2, 4, 5, 6].span());
    } else if id == 4 {
        return Option::Some(array![3, 5, 7].span());
    } else if id == 5 {
        return Option::Some(array![4, 3, 6].span());
    } else if id == 6 {
        return Option::Some(array![5, 3, 28].span());
    } else if id == 7 {
        return Option::Some(array![4, 8, 9].span());
    } else if id == 8 {
        return Option::Some(array![7, 9, 12].span());
    } else if id == 9 {
        return Option::Some(array![7, 8, 12, 10].span());
    } else if id == 10 {
        return Option::Some(array![9, 11].span());
    } else if id == 11 {
        return Option::Some(array![10, 13, 15, 42].span());
    } else if id == 12 {
        return Option::Some(array![9, 8, 13].span());
    } else if id == 13 {
        return Option::Some(array![11, 12, 14, 16].span());
    } else if id == 14 {
        return Option::Some(array![13, 16, 17, 25].span());
    } else if id == 15 {
        return Option::Some(array![11, 16].span());
    } else if id == 16 {
        return Option::Some(array![15, 13, 14, 17, 18].span());
    } else if id == 17 {
        return Option::Some(array![16, 14].span());
    } else if id == 18 {
        return Option::Some(array![16, 19].span());
    } else if id == 19 {
        return Option::Some(array![18, 20, 23].span());
    } else if id == 20 {
        return Option::Some(array![19, 21, 22].span());
    } else if id == 21 {
        return Option::Some(array![20, 21].span());
    } else if id == 22 {
        return Option::Some(array![20, 23].span());
    } else if id == 23 {
        return Option::Some(array![19, 22, 24, 31].span());
    } else if id == 24 {
        return Option::Some(array![23, 25, 26].span());
    } else if id == 25 {
        return Option::Some(array![14, 24].span());
    } else if id == 26 {
        return Option::Some(array![5, 24, 27].span());
    } else if id == 27 {
        return Option::Some(array![26, 28].span());
    } else if id == 28 {
        return Option::Some(array![6, 27, 29].span());
    } else if id == 29 {
        return Option::Some(array![28, 30].span());
    } else if id == 30 {
        return Option::Some(array![31, 29].span());
    } else if id == 31 {
        return Option::Some(array![21, 23, 30, 32].span());
    } else if id == 32 {
        return Option::Some(array![50, 31, 33].span());
    } else if id == 33 {
        return Option::Some(array![32, 34, 35, 37].span());
    } else if id == 34 {
        return Option::Some(array![33].span());
    } else if id == 35 {
        return Option::Some(array![33, 36].span());
    } else if id == 36 {
        return Option::Some(array![35].span());
    } else if id == 37 {
        return Option::Some(array![33, 37, 38].span());
    } else if id == 38 {
        return Option::Some(array![37, 39].span());
    } else if id == 39 {
        return Option::Some(array![37, 38, 40, 41, 46].span());
    } else if id == 40 {
        return Option::Some(array![39].span());
    } else if id == 41 {
        return Option::Some(array![39, 43].span());
    } else if id == 42 {
        return Option::Some(array![11, 43].span());
    } else if id == 43 {
        return Option::Some(array![41, 42, 44].span());
    } else if id == 44 {
        return Option::Some(array![45, 43, 46].span());
    } else if id == 45 {
        return Option::Some(array![44].span());
    } else if id == 46 {
        return Option::Some(array![39, 44, 47].span());
    } else if id == 47 {
        return Option::Some(array![48, 46, 49].span());
    } else if id == 48 {
        return Option::Some(array![47].span());
    } else if id == 49 {
        return Option::Some(array![50, 48].span());
    } else if id == 50 {
        return Option::Some(array![32, 49].span());
    } else {
        return Option::None;
    }
}
