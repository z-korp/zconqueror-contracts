//! Hand struct and card management.

// Core imports

use dict::{Felt252Dict, Felt252DictTrait};
use hash::HashStateTrait;
use nullable::{NullableTrait, nullable_from_box, match_nullable, FromNullableResult};
use poseidon::PoseidonTrait;
use traits::{Into, Drop};
use debug::PrintTrait;

// External imports

use alexandria_data_structures::array_ext::{SpanTraitExt, ArrayTraitExt};

// Internal imports

use zrisk::constants::HAND_MAX_SIZE;
use zrisk::config::{INFANTRY, CAVALRY, ARTILLERY, JOCKER, card as config_card};
use zrisk::components::player::Player;
use zrisk::entities::set::{Set, SetTrait};

// Constants

const TWO_POW_8: u128 = 0x100;
const MASK_8: u128 = 0xff;
const SET_SIZE: u32 = 3;

/// Hand struct.
#[derive(Destruct)]
struct Hand {
    cards: Array<u8>,
}

/// Errors module.
mod errors {
    const INVALID_CARD: felt252 = 'Hand: invalid card';
    const INVALID_SET: felt252 = 'Hand: invalid set';
    const MAX_HAND_SIZE_REACHED: felt252 = 'Hand: max hand size reached';
}

/// Trait to initialize and manage a Hand.
trait HandTrait {
    /// Returns a new `Hand` struct.
    /// # Returns
    /// * The initialized `Hand`.
    fn new() -> Hand;
    /// Load a `Hand` struct from a player component.
    /// # Arguments
    /// * `player` - Player component.
    /// # Returns
    /// * The loaded `Hand`.
    fn load(player: @Player) -> Hand;
    /// Dump a `Hand` cards into a u128.
    /// # Arguments
    /// * `self` - The Hand.
    /// # Returns
    /// * The packed cards.
    fn dump(self: @Hand) -> u128;
    /// Check if the cards are owned.
    /// # Arguments
    /// * `self` - The Hand.
    /// * `set` - The Set to check.
    /// # Returns
    /// * The owned status.
    fn check(self: @Hand, set: @Set) -> bool;
    /// Add a card to the Hand.
    /// # Arguments
    /// * `self` - The Hand.
    /// * `card` - The card to add.
    fn add(ref self: Hand, card: u8);
    /// Deploy a set of 3 cards.
    /// # Arguments
    /// * `self` - The Hand.
    /// * `set` - The Set to check.
    /// # Returns
    /// * The corresponding score.
    fn deploy(ref self: Hand, set: @Set) -> u8;
}

/// Implementation of the `HandTrait` trait for the `Hand` struct.
impl HandImpl of HandTrait {
    fn new() -> Hand {
        Hand { cards: array![] }
    }

    fn load(player: @Player) -> Hand {
        let cards: Array<u8> = _unpack(*player.cards);
        Hand { cards }
    }

    fn dump(self: @Hand) -> u128 {
        _pack(self.cards.span())
    }

    fn check(self: @Hand, set: @Set) -> bool {
        let mut cards = set.cards();
        loop {
            match cards.pop_front() {
                Option::Some(item) => {
                    if !self.cards.contains(*item) {
                        break false;
                    }
                },
                Option::None => {
                    break true;
                },
            };
        }
    }

    fn add(ref self: Hand, card: u8) {
        // [Check] Maximum
        assert(self.cards.len() <= HAND_MAX_SIZE.into(), errors::MAX_HAND_SIZE_REACHED);
        self.cards.append(card);
    }

    fn deploy(ref self: Hand, set: @Set) -> u8 {
        // [Check] The set provides a valid score.
        let score = set.score();
        assert(score > 0, errors::INVALID_SET);
        // [Check] Cards are owned.
        assert(self.check(set), errors::INVALID_SET);
        // [Effect] Remove discards from hand.
        let discards = set.cards();
        let mut remaining_cards: Array<u8> = ArrayTrait::new();
        loop {
            match self.cards.pop_front() {
                Option::Some(item) => {
                    if !discards.contains(item) {
                        remaining_cards.append(item);
                    };
                },
                Option::None => {
                    break;
                },
            };
        };
        self.cards = remaining_cards;
        score
    }
}

/// Pack u8 items in a u128.
/// # Arguments
/// * `unpacked` - The unpacked items.
/// # Returns
/// * The packed items.
fn _pack(mut unpacked: Span<u8>) -> u128 {
    let len = unpacked.len();
    let mut packed: u128 = 0;
    let mut index = len;
    loop {
        if index == 0 {
            break;
        }
        index -= 1;
        let item = unpacked.at(index);
        packed = (packed * TWO_POW_8) + (*item).into();
    };
    (packed * TWO_POW_8) + len.into()
}

/// Unpack u8 items packed in a u128.
/// # Arguments
/// * `packed` - The packed items.
/// # Returns
/// * The unpacked items.
fn _unpack(mut packed: u128) -> Array<u8> {
    let mut unpacked: Array<u8> = ArrayTrait::new();
    let mut len = packed & MASK_8;
    loop {
        if len == 0 {
            break;
        }
        packed /= TWO_POW_8;
        let item = packed & MASK_8;
        unpacked.append(item.try_into().unwrap());
        len -= 1;
    };
    unpacked
}

/// Returns the best score according to the given cards.
/// # Arguments
/// * `cards` - The cards.
/// # Returns
/// * The best score and the types to dispatch.
fn _score(mut cards: Span<u8>) -> (u32, Span<u16>) {
    let mut discards: Array<u16> = array![];

    // [Case] Not enough card
    if cards.len() < SET_SIZE {
        return (0, discards.span());
    }

    // [Compute] Card types
    let mut types: Felt252Dict<u8> = Default::default();
    loop {
        match cards.pop_front() {
            Option::Some(card) => {
                let (_, _type) = config_card(*card).expect(errors::INVALID_CARD);
                let key: felt252 = _type.into();
                types.insert(key, types.get(key) + 1);
            },
            Option::None => {
                break;
            },
        };
    };
    let artillery_count = types.get(ARTILLERY.into());
    let cavalry_count = types.get(CAVALRY.into());
    let infantry_count = types.get(INFANTRY.into());
    let jocker_count = types.get(JOCKER.into());

    // [Case] All different without jocker
    if artillery_count > 0 && cavalry_count > 0 && infantry_count > 0 {
        discards.append(ARTILLERY);
        discards.append(CAVALRY);
        discards.append(INFANTRY);
        return (10, discards.span());
    }

    // [Case] All differnt with 1 jocker
    if jocker_count == 1 {
        if artillery_count > 0 && cavalry_count > 0 {
            discards.append(JOCKER);
            discards.append(ARTILLERY);
            discards.append(CAVALRY);
            return (10, discards.span());
        } else if artillery_count > 0 && infantry_count > 0 {
            discards.append(JOCKER);
            discards.append(ARTILLERY);
            discards.append(INFANTRY);
            return (10, discards.span());
        } else if cavalry_count > 0 && infantry_count > 0 {
            discards.append(JOCKER);
            discards.append(CAVALRY);
            discards.append(INFANTRY);
            return (10, discards.span());
        }
    }

    // [Case] All diffrent with 2 jockers
    if jocker_count == 2 {
        if artillery_count > 0 {
            discards.append(JOCKER);
            discards.append(JOCKER);
            discards.append(ARTILLERY);
            return (10, discards.span());
        } else if cavalry_count > 0 {
            discards.append(JOCKER);
            discards.append(JOCKER);
            discards.append(CAVALRY);
            return (10, discards.span());
        } else if infantry_count > 0 {
            discards.append(JOCKER);
            discards.append(JOCKER);
            discards.append(INFANTRY);
            return (10, discards.span());
        }
    }

    // [Case] All diffrent with 3+ Jockers
    if jocker_count > 2 {
        discards.append(JOCKER);
        discards.append(JOCKER);
        discards.append(JOCKER);
        return (10, discards.span());
    }

    // [Case] All same without jocker
    if artillery_count.into() > SET_SIZE {
        discards.append(ARTILLERY);
        discards.append(ARTILLERY);
        discards.append(ARTILLERY);
        return (8, discards.span());
    } else if cavalry_count.into() > SET_SIZE {
        discards.append(CAVALRY);
        discards.append(CAVALRY);
        discards.append(CAVALRY);
        return (6, discards.span());
    } else if infantry_count.into() > SET_SIZE {
        discards.append(INFANTRY);
        discards.append(INFANTRY);
        discards.append(INFANTRY);
        return (4, discards.span());
    }

    // [Case] All same with 1 jocker
    if artillery_count.into() + jocker_count.into() > SET_SIZE {
        discards.append(JOCKER);
        discards.append(ARTILLERY);
        discards.append(ARTILLERY);
        return (8, discards.span());
    } else if cavalry_count.into() + jocker_count.into() > SET_SIZE {
        discards.append(JOCKER);
        discards.append(CAVALRY);
        discards.append(CAVALRY);
        return (6, discards.span());
    } else if infantry_count.into() + jocker_count.into() > SET_SIZE {
        discards.append(JOCKER);
        discards.append(INFANTRY);
        discards.append(INFANTRY);
        return (4, discards.span());
    }

    // [Case] Not valid set
    return (0, discards.span());
}


#[cfg(test)]
mod tests {
    // Core imports

    use debug::PrintTrait;

    // Internal imports

    use zrisk::components::player::Player;
    use zrisk::entities::set::{Set, SetTrait};

    // Local imports

    use super::{HandTrait, _pack, _unpack};

    #[test]
    #[available_gas(1_000_000)]
    fn test_hand_pack_unpack() {
        let unpacked: Span<u8> = array![0, 7, 4, 1, 2, 5, 8, 9, 6, 3].span();
        let packed = _pack(unpacked);
        assert(_unpack(packed).span() == unpacked, 'Hand: wrong pack/unpack');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_hand_unpack_pack() {
        let packed: u128 = 0x0a09080605040302010b;
        let unpacked = _unpack(packed);
        assert(_pack(unpacked.span()) == packed, 'Hand: wrong unpack/pack');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_hand_new() {
        let hand = HandTrait::new();
        assert(hand.cards == array![], 'Hand: wrong initialization');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_hand_load() {
        let mut player: Player = Default::default();
        player.cards = 0x0a09080605040302010b;
        let hand = HandTrait::load(@player);
        assert(hand.cards == _unpack(0x0a09080605040302010b), 'Hand: wrong load');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_hand_dump() {
        let mut player: Player = Default::default();
        player.cards = 0x0a09080605040302010b;
        let hand = HandTrait::load(@player);
        let cards = hand.dump();
        assert(cards == player.cards, 'Hand: wrong dump');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_hand_add() {
        let mut hand = HandTrait::new();
        hand.add(1);
        hand.add(2);
        let cards = hand.dump();
        assert(cards == 0x020102, 'Hand: wrong add');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_hand_check() {
        let mut player: Player = Default::default();
        player.cards = 0x01020303;
        let hand = HandTrait::load(@player);
        let set = SetTrait::new(1, 2, 3);
        assert(hand.check(@set), 'Hand: wrong check');
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_hand_uncheck() {
        let mut player: Player = Default::default();
        player.cards = 0x10202;
        let hand = HandTrait::load(@player);
        let set = SetTrait::new(1, 2, 3);
        assert(!hand.check(@set), 'Hand: wrong uncheck');
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Hand: invalid set',))]
    fn test_hand_deploy_invalid_set_not_owned() {
        let mut player: Player = Default::default();
        player.cards = 0x10202;
        let mut hand = HandTrait::load(@player);
        let set = SetTrait::new(1, 2, 3);
        hand.deploy(@set);
    }

    #[test]
    #[available_gas(1_000_000)]
    #[should_panic(expected: ('Hand: invalid set',))]
    fn test_hand_deploy_invalid_set_not_scored() {
        let mut player: Player = Default::default();
        player.cards = 0x1020203;
        let mut hand = HandTrait::load(@player);
        let set = SetTrait::new(1, 2, 2);
        hand.deploy(@set);
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_hand_deploy() {
        let mut player: Player = Default::default();
        player.cards = 0x1020303;
        let mut hand = HandTrait::load(@player);
        let set = SetTrait::new(1, 2, 3);
        let score = hand.deploy(@set);
        assert(score > 0, 'Hand: wrong score');
    }
}
