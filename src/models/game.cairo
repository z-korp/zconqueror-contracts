// Core imports

use hash::HashStateTrait;
use poseidon::PoseidonTrait;

// Starknet imports

use starknet::ContractAddress;

// Constants

const TURN_COUNT: u8 = 3;

#[derive(Model, Copy, Drop, Serde)]
struct Game {
    #[key]
    id: u32,
    host: ContractAddress,
    over: bool,
    seed: felt252,
    player_count: u8,
    slots: u8,
    nonce: u8,
}

#[derive(Drop, PartialEq)]
enum Turn {
    Supply,
    Attack,
    Transfer,
}

mod errors {
    const GAME_NO_REMAINING_SLOTS: felt252 = 'Game: no remaining slots';
    const GAME_NOT_ENOUGH_PLAYERS: felt252 = 'Game: not enough players';
    const GAME_IS_FULL: felt252 = 'Game: is full';
    const GAME_IS_NOT_FULL: felt252 = 'Game: is not full';
    const GAME_IS_EMPTY: felt252 = 'Game: is empty';
    const GAME_IS_OVER: felt252 = 'Game: is over';
    const GAME_HAS_STARTED: felt252 = 'Game: has started';
    const GAME_DOES_NOT_EXSIST: felt252 = 'Game: does not exsist';
}

trait GameTrait {
    fn new(id: u32, host: ContractAddress, player_count: u8) -> Game;
    fn real_player_count(self: @Game) -> u8;
    fn player(self: @Game) -> u8;
    fn turn(self: @Game) -> Turn;
    fn next_player(self: @Game) -> u8;
    fn next_turn(self: @Game) -> Turn;
    /// Joins a game and returns the player index.
    /// # Arguments
    /// * `self` - The Game.
    /// # Returns
    /// * The new index of the player.
    fn join(ref self: Game) -> u8;
    /// Leaves a game and returns the last player index.
    /// # Arguments
    /// * `self` - The Game.
    /// * `account` - The player address.
    /// # Returns
    /// * The last index of the last registered player.
    fn leave(ref self: Game, account: ContractAddress) -> u8;
    fn start(ref self: Game, players: Span<ContractAddress>);
    fn increment(ref self: Game);
    fn pass(ref self: Game);
}

impl GameImpl of GameTrait {
    #[inline(always)]
    fn new(id: u32, host: ContractAddress, player_count: u8) -> Game {
        assert(player_count > 1, errors::GAME_NOT_ENOUGH_PLAYERS);
        Game { id, host, over: false, seed: 0, player_count, slots: player_count, nonce: 0 }
    }

    #[inline(always)]
    fn real_player_count(self: @Game) -> u8 {
        *self.player_count - *self.slots
    }

    #[inline(always)]
    fn player(self: @Game) -> u8 {
        *self.nonce / TURN_COUNT % *self.player_count
    }

    #[inline(always)]
    fn turn(self: @Game) -> Turn {
        let turn_id = *self.nonce % TURN_COUNT;
        turn_id.into()
    }

    #[inline(always)]
    fn next_player(self: @Game) -> u8 {
        (*self.nonce / TURN_COUNT + 1) % *self.player_count
    }

    #[inline(always)]
    fn next_turn(self: @Game) -> Turn {
        let turn_id = (*self.nonce + 1) % TURN_COUNT;
        turn_id.into()
    }

    #[inline(always)]
    fn join(ref self: Game) -> u8 {
        assert(self.player_count > 0, errors::GAME_DOES_NOT_EXSIST);
        assert(!self.over, errors::GAME_IS_OVER);
        assert(self.seed == 0, errors::GAME_HAS_STARTED);
        assert(self.slots > 0, errors::GAME_IS_FULL);
        let index = self.player_count - self.slots;
        self.slots -= 1;
        index.into()
    }

    #[inline(always)]
    fn leave(ref self: Game, account: ContractAddress) -> u8 {
        assert(self.player_count > 0, errors::GAME_DOES_NOT_EXSIST);
        assert(!self.over, errors::GAME_IS_OVER);
        assert(self.seed == 0, errors::GAME_HAS_STARTED);
        assert(self.slots < self.player_count, errors::GAME_IS_EMPTY);
        if account == self.host {
            self.over = account == self.host;
        }
        self.slots += 1;
        let last_index = self.player_count - self.slots;
        last_index.into()
    }

    fn start(ref self: Game, mut players: Span<ContractAddress>) {
        assert(self.player_count > 0, errors::GAME_DOES_NOT_EXSIST);
        assert(!self.over, errors::GAME_IS_OVER);
        assert(self.seed == 0, errors::GAME_HAS_STARTED);
        assert(self.slots == 0, errors::GAME_IS_NOT_FULL);
        let mut state = PoseidonTrait::new();
        state = state.update(self.id.into());
        loop {
            match players.pop_front() {
                Option::Some(player) => { state = state.update((*player).into()); },
                Option::None => { break; },
            };
        };
        self.seed = state.finalize();
    }

    #[inline(always)]
    fn increment(ref self: Game) {
        self.nonce += 1;
    }

    #[inline(always)]
    fn pass(ref self: Game) {
        let turn = self.nonce % TURN_COUNT;
        self.nonce += TURN_COUNT - turn;
    }
}

impl U8IntoTurn of Into<u8, Turn> {
    #[inline(always)]
    fn into(self: u8) -> Turn {
        assert(self < 3, 'U8IntoTurn: invalid turn');
        if self == 0 {
            Turn::Supply
        } else if self == 1 {
            Turn::Attack
        } else {
            Turn::Transfer
        }
    }
}

impl TurnIntoU8 of Into<Turn, u8> {
    #[inline(always)]
    fn into(self: Turn) -> u8 {
        match self {
            Turn::Supply => 0,
            Turn::Attack => 1,
            Turn::Transfer => 2,
        }
    }
}

#[cfg(test)]
mod tests {
    // Local imports

    use super::{Game, GameTrait, Turn, TURN_COUNT};

    // Constants

    const ID: u32 = 0;
    const SEED: felt252 = 'SEED';
    const PLAYER_COUNT: u8 = 4;

    fn HOST() -> starknet::ContractAddress {
        starknet::contract_address_const::<'HOST'>()
    }

    fn PLAYER() -> starknet::ContractAddress {
        starknet::contract_address_const::<'PLAYER'>()
    }

    fn ZERO() -> starknet::ContractAddress {
        starknet::contract_address_const::<0>()
    }

    #[test]
    #[available_gas(100_000)]
    fn test_game_new() {
        let game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        assert(game.host == HOST(), 'Game: wrong account');
        assert(game.id == ID, 'Game: wrong id');
        assert(game.over == false, 'Game: wrong over');
        assert(game.seed == 0, 'Game: wrong seed');
        assert(game.player_count == PLAYER_COUNT, 'Game: wrong player_count');
        assert(game.slots == PLAYER_COUNT, 'Game: wrong slots');
        assert(game.nonce == 0, 'Game: wrong nonce');
    }

    #[test]
    #[available_gas(100_000)]
    #[should_panic(expected: ('Game: not enough players',))]
    fn test_game_new_revert_not_enough_players() {
        let game = GameTrait::new(ID, HOST(), 0);
    }

    #[test]
    #[available_gas(100_000)]
    fn test_game_real_player_count() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        assert(game.real_player_count() == 0, 'Game: wrong count');
    }

    #[test]
    #[available_gas(100_000)]
    fn test_game_join() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        game.join();
        let index = game.join();
        assert(game.real_player_count() == 2, 'Game: wrong count');
        assert(index == 1, 'Game: wrong index');
    }

    #[test]
    #[available_gas(100_000)]
    #[should_panic(expected: ('Game: does not exsist',))]
    fn test_game_join_revert_does_not_exist() {
        let mut game = Game {
            id: 0, host: ZERO(), over: false, seed: 0, player_count: 0, slots: 0, nonce: 0
        };
        game.join();
    }

    #[test]
    #[available_gas(100_000)]
    #[should_panic(expected: ('Game: is over',))]
    fn test_game_join_revert_is_over() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        game.over = true;
        game.join();
    }

    #[test]
    #[available_gas(100_000)]
    #[should_panic(expected: ('Game: has started',))]
    fn test_game_join_revert_has_started() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        game.seed = 1;
        game.join();
    }

    #[test]
    #[available_gas(100_000)]
    #[should_panic(expected: ('Game: is full',))]
    fn test_game_join_revert_no_remaining_slots() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        let mut index = PLAYER_COUNT + 1;
        loop {
            if index == 0 {
                break;
            }
            index -= 1;
            game.join();
        }
    }

    #[test]
    #[available_gas(100_000)]
    fn test_game_leave() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        game.join();
        let index = game.leave(PLAYER());
        assert(game.real_player_count() == 0, 'Game: wrong count');
        assert(index == 0, 'Game: wrong index');
    }

    #[test]
    #[available_gas(100_000)]
    fn test_game_leave_host() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        game.join();
        game.leave(HOST());
        assert(game.over, 'Game: wrong status');
    }

    #[test]
    #[available_gas(100_000)]
    #[should_panic(expected: ('Game: does not exsist',))]
    fn test_game_leave_revert_does_not_exist() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        game.join();
        game.player_count = 0;
        game.leave(PLAYER());
    }

    #[test]
    #[available_gas(100_000)]
    #[should_panic(expected: ('Game: is over',))]
    fn test_game_leave_revert_over() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        game.join();
        game.join();
        game.leave(HOST());
        game.leave(PLAYER());
    }

    #[test]
    #[available_gas(100_000)]
    #[should_panic(expected: ('Game: has started',))]
    fn test_game_leave_revert_has_started() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        game.seed = 1;
        game.join();
        game.leave(PLAYER());
    }

    #[test]
    #[available_gas(100_000)]
    #[should_panic(expected: ('Game: is empty',))]
    fn test_game_leave_revert_is_empty() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        game.join();
        game.leave(PLAYER());
        game.leave(PLAYER());
    }

    #[test]
    #[available_gas(200_000)]
    fn test_game_start() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        let mut index = PLAYER_COUNT;
        loop {
            if index == 0 {
                break;
            }
            index -= 1;
            game.join();
        };
        let players = array![HOST(), PLAYER()];
        game.start(players.span());
        assert(game.seed != 0, 'Game: wrong seed');
    }

    #[test]
    #[available_gas(200_000)]
    #[should_panic(expected: ('Game: does not exsist',))]
    fn test_game_start_revert_does_not_exist() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        game.player_count = 0;
        let players = array![HOST(), PLAYER()];
        game.start(players.span());
    }

    #[test]
    #[available_gas(200_000)]
    #[should_panic(expected: ('Game: is over',))]
    fn test_game_start_revert_is_over() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        game.over = true;
        let players = array![HOST(), PLAYER()];
        game.start(players.span());
    }

    #[test]
    #[available_gas(200_000)]
    #[should_panic(expected: ('Game: has started',))]
    fn test_game_start_revert_has_started() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        game.seed = 1;
        let players = array![HOST(), PLAYER()];
        game.start(players.span());
    }

    #[test]
    #[available_gas(200_000)]
    #[should_panic(expected: ('Game: is not full',))]
    fn test_game_start_revert_is_not_full() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        let players = array![HOST(), PLAYER()];
        game.start(players.span());
    }

    #[test]
    #[available_gas(100_000)]
    fn test_game_get_player_index() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        assert(game.player() == 0, 'Game: wrong player index 0+0');
        game.nonce += 1;
        assert(game.player() == 0, 'Game: wrong player index 1+0');
        game.nonce += TURN_COUNT;
        assert(game.player() == 1, 'Game: wrong player index 1+3');
        game.nonce += TURN_COUNT;
        assert(game.player() == 2, 'Game: wrong player index 1+6');
        game.nonce += TURN_COUNT;
        assert(game.player() == 3, 'Game: wrong player index 1+9');
        game.nonce += TURN_COUNT;
        assert(game.player() == 0, 'Game: wrong player index 1+12');
        game.nonce += TURN_COUNT;
    }

    #[test]
    #[available_gas(100_000)]
    fn test_game_get_next_player_index() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        assert(game.player() == 0, 'Game: wrong player index 0+0');
        assert(game.next_player() == 1, 'Game: wrong next player 0+0');
        game.nonce += TURN_COUNT;
        assert(game.player() == 1, 'Game: wrong player index 0+3');
        assert(game.next_player() == 2, 'Game: wrong next player 0+3');
    }

    #[test]
    #[available_gas(100_000)]
    fn test_game_get_turn_index() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        assert(game.turn().into() == 0_u8, 'Game: wrong turn index 0');
        game.nonce += 1;
        assert(game.turn().into() == 1_u8, 'Game: wrong turn index 1');
        game.nonce += 1;
        assert(game.turn().into() == 2_u8, 'Game: wrong turn index 2');
        game.nonce += 1;
        assert(game.turn().into() == 0_u8, 'Game: wrong turn index 3');
        game.nonce += 1;
    }

    #[test]
    #[available_gas(100_000)]
    fn test_game_pass() {
        let mut game = GameTrait::new(ID, HOST(), PLAYER_COUNT);
        game.pass();
        assert(game.player() == 1, 'Game: wrong player');
        game.nonce += 1;
        game.pass();
        assert(game.player() == 2, 'Game: wrong player');
        game.nonce += 1;
        game.nonce += 1;
        game.pass();
        assert(game.player() == 3, 'Game: wrong player');
    }
}
