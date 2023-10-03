//! Set struct and score management.

// Internal imports

use zrisk::config::{INFANTRY, CAVALRY, ARTILLERY, JOCKER, card as config_card};

/// Set struct.
#[derive(Drop)]
struct Set {
    first: u8,
    second: u8,
    third: u8,
}

/// Errors module.
mod errors {
    const INVALID_CARD: felt252 = 'Set: invalid card';
}

/// Trait to initialize and manage a Set.
trait SetTrait {
    /// Returns a new `Set` struct.
    /// # Arguments
    /// * `first` - The first card.
    /// * `second` - The second card.
    /// * `third` - The third card.
    /// # Returns
    /// * The initialized `Set`.
    fn new(first: u8, second: u8, third: u8) -> Set;
    /// Return the set score.
    /// # Arguments
    /// * `self` - The set.
    /// # Returns
    /// * The corresponding score.
    fn score(self: @Set) -> u8;
    /// Return the cards.
    /// # Arguments
    /// * `self` - The set.
    /// # Returns
    /// * The set cards.
    fn cards(self: @Set) -> Span<u8>;
}

/// Implementation of the `SetTrait` trait for the `Set` struct.
impl SetImpl of SetTrait {
    fn new(first: u8, second: u8, third: u8) -> Set {
        Set { first: first, second: second, third: third, }
    }

    fn score(self: @Set) -> u8 {
        // [Compute] Sum of types
        let (_, first_type) = config_card(*self.first).expect(errors::INVALID_CARD);
        let (_, second_type) = config_card(*self.second).expect(errors::INVALID_CARD);
        let (_, third_type) = config_card(*self.third).expect(errors::INVALID_CARD);
        let sum = first_type + second_type + third_type;

        // [Case] All differents without jocker
        if sum == ARTILLERY + CAVALRY + INFANTRY {
            return 10;
        }

        // [Case] All differents with 1 jocker
        if sum == JOCKER + ARTILLERY + CAVALRY {
            return 10;
        } else if sum == JOCKER + ARTILLERY + INFANTRY {
            return 10;
        } else if sum == JOCKER + CAVALRY + INFANTRY {
            return 10;
        }

        // [Case] All differents with 2 jocker
        if sum == 2 * JOCKER + ARTILLERY {
            return 10;
        } else if sum == 2 * JOCKER + CAVALRY {
            return 10;
        } else if sum == 2 * JOCKER + INFANTRY {
            return 10;
        }

        // [Case] All differents with 3 jocker
        if sum == 3 * JOCKER {
            return 10;
        }

        // [Case] All the same without jocker
        if sum == 3 * ARTILLERY {
            return 8;
        } else if sum == 3 * CAVALRY {
            return 6;
        } else if sum == 3 * INFANTRY {
            return 4;
        }

        // [Case] All the same with 1 jocker
        if sum == JOCKER + 2 * ARTILLERY {
            return 8;
        } else if sum == JOCKER + 2 * CAVALRY {
            return 6;
        } else if sum == JOCKER + 2 * INFANTRY {
            return 4;
        }

        // [Case] Not a valid set
        0
    }

    fn cards(self: @Set) -> Span<u8> {
        array![*self.first, *self.second, *self.third].span()
    }
}

#[cfg(test)]
mod tests {
    // Core imports

    use debug::PrintTrait;

    // Internal imports

    use zrisk::config::{INFANTRY, CAVALRY, ARTILLERY, JOCKER, TILE_NUMBER};

    // Local imports

    use super::SetTrait;

    #[test]
    #[available_gas(200_000)]
    fn test_set_score_different() {
        let set = SetTrait::new(1, 2, 3);
        assert(set.score() > 0, 'Set: wrong score');
    }

    #[test]
    #[available_gas(200_000)]
    fn test_set_score_same() {
        let set = SetTrait::new(1, 1, 1);
        assert(set.score() > 0, 'Set: wrong score');
    }

    #[test]
    #[available_gas(200_000)]
    fn test_set_score_no_case() {
        let set = SetTrait::new(1, 1, 2);
        assert(set.score() == 0, 'Set: wrong score');
    }

    #[test]
    #[available_gas(200_000)]
    fn test_set_score_different_with_jocker() {
        let jocker_id: u8 = TILE_NUMBER.try_into().unwrap() + 1;
        let set = SetTrait::new(1, 2, jocker_id);
        assert(set.score() == 10, 'Set: wrong score');
    }

    #[test]
    #[available_gas(200_000)]
    fn test_set_score_same_with_jocker() {
        let jocker_id: u8 = TILE_NUMBER.try_into().unwrap() + 1;
        let set = SetTrait::new(1, 1, jocker_id);
        assert(set.score() > 0, 'Set: wrong score');
    }

    #[test]
    #[available_gas(200_000)]
    fn test_set_cards() {
        let set = SetTrait::new(1, 2, 3);
        assert(set.cards() == array![1, 2, 3].span(), 'Set: wrong cards');
    }
}
