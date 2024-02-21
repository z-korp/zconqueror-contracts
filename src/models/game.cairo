use core::zeroable::Zeroable;
// Core imports

use hash::HashStateTrait;
use poseidon::PoseidonTrait;

// Internal imports

use zconqueror::models::player::{Player, PlayerTrait};

// Constants

const MINIMUM_PLAYER_COUNT: u8 = 2;
const MAXIMUM_PLAYER_COUNT: u8 = 6;
const TURN_COUNT: u8 = 3;

#[derive(Model, Copy, Drop, Serde)]
struct Game {
    #[key]
    id: u32,
    host: felt252,
    over: bool,
    seed: felt252,
    player_count: u8,
    nonce: u8,
    price: u256,
}

#[derive(Drop, PartialEq)]
enum Turn {
    Supply,
    Attack,
    Transfer,
}

mod errors {
    const GAME_NOT_HOST: felt252 = 'Game: user is not the host';
    const GAME_IS_HOST: felt252 = 'Game: user is the host';
    const GAME_TRANSFER_SAME_HOST: felt252 = 'Game: transfer to the same host';
    const GAME_TOO_MANY_PLAYERS: felt252 = 'Game: too many players';
    const GAME_TOO_FEW_PLAYERS: felt252 = 'Game: too few players';
    const GAME_IS_FULL: felt252 = 'Game: is full';
    const GAME_NOT_FULL: felt252 = 'Game: not full';
    const GAME_IS_EMPTY: felt252 = 'Game: is empty';
    const GAME_NOT_ONLY_ONE: felt252 = 'Game: not only one';
    const GAME_IS_OVER: felt252 = 'Game: is over';
    const GAME_NOT_OVER: felt252 = 'Game: not over';
    const GAME_NOT_STARTED: felt252 = 'Game: not started';
    const GAME_HAS_STARTED: felt252 = 'Game: has started';
    const GAME_NOT_EXISTS: felt252 = 'Game: does not exist';
    const GAME_DOES_EXIST: felt252 = 'Game: does exist';
    const GAME_INVALID_HOST: felt252 = 'Game: invalid host';
}

#[generate_trait]
impl GameImpl of GameTrait {
    #[inline(always)]
    fn new(id: u32, host: felt252, price: u256) -> Game {
        // [Check] Host is valid
        assert(host != 0, errors::GAME_INVALID_HOST);

        // [Return] Default game
        Game { id, host, over: false, seed: 0, player_count: 0, nonce: 0, price }
    }

    #[inline(always)]
    fn reward(self: Game) -> u256 {
        // [Check] Game is over
        self.assert_is_over();

        // [Return] Calculated reward
        self.price * (self.player_count).into()
    }

    #[inline(always)]
    fn player(self: Game) -> u32 {
        let index = self.nonce / TURN_COUNT % self.player_count;
        index.into()
    }

    #[inline(always)]
    fn turn(self: Game) -> Turn {
        let turn_id = self.nonce % TURN_COUNT;
        turn_id.into()
    }

    #[inline(always)]
    fn next_player(self: Game) -> u32 {
        let index = (self.nonce / TURN_COUNT + 1) % self.player_count;
        index.into()
    }

    #[inline(always)]
    fn next_turn(self: Game) -> Turn {
        let turn_id = (self.nonce + 1) % TURN_COUNT;
        turn_id.into()
    }

    /// Joins a game and returns the player index.
    /// # Arguments
    /// * `self` - The Game.
    /// # Returns
    /// * The new index of the player.
    #[inline(always)]
    fn join(ref self: Game) -> u8 {
        self.assert_exists();
        self.assert_not_over();
        self.assert_not_started();
        self.assert_not_full();
        let index = self.player_count;
        self.player_count += 1;
        index
    }

    /// Leaves a game and returns the last player index.
    /// # Arguments
    /// * `self` - The Game.
    /// * `account` - The player address.
    /// # Returns
    /// * The last index of the last registered player.
    #[inline(always)]
    fn leave(ref self: Game, address: felt252) -> u32 {
        self.assert_exists();
        self.assert_not_over();
        self.assert_not_started();
        self.assert_not_empty();
        self.assert_not_host(address);
        self.player_count -= 1;
        self.player_count.into()
    }

    #[inline(always)]
    fn kick(ref self: Game, address: felt252) -> u32 {
        self.assert_exists();
        self.assert_not_over();
        self.assert_not_started();
        self.assert_not_empty();
        self.assert_not_host(address);
        self.player_count -= 1;
        self.player_count.into()
    }

    #[inline(always)]
    fn delete(ref self: Game, address: felt252) -> u32 {
        self.assert_exists();
        self.assert_not_over();
        self.assert_not_started();
        self.assert_only_one();
        self.assert_is_host(address);
        self.nullify();
        self.player_count.into()
    }

    #[inline(always)]
    fn transfer(ref self: Game, host: felt252) {
        assert(host != 0, errors::GAME_INVALID_HOST);
        self.assert_not_host(host);
        self.host = host;
    }

    fn start(ref self: Game, mut players: Array<felt252>) {
        // [Check] Game is valid
        self.assert_exists();
        self.assert_not_over();
        self.assert_not_started();
        self.assert_can_start();

        // [Effect] Compute seed
        let mut state = PoseidonTrait::new();
        state = state.update(self.id.into());
        loop {
            match players.pop_front() {
                Option::Some(player) => { state = state.update(player); },
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

    #[inline(always)]
    fn nullify(ref self: Game) {
        self.host = 0;
        self.over = false;
        self.seed = 0;
        self.player_count = 0;
        self.nonce = 0;
        self.price = 0;
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

#[generate_trait]
impl GameAssert of AssertTrait {
    #[inline(always)]
    fn assert_is_host(self: Game, address: felt252) {
        assert(self.host == address, errors::GAME_NOT_HOST);
    }

    #[inline(always)]
    fn assert_not_host(self: Game, address: felt252) {
        assert(self.host != address, errors::GAME_IS_HOST);
    }

    #[inline(always)]
    fn assert_is_over(self: Game) {
        assert(self.over, errors::GAME_NOT_OVER);
    }

    #[inline(always)]
    fn assert_not_over(self: Game) {
        assert(!self.over, errors::GAME_IS_OVER);
    }

    #[inline(always)]
    fn assert_has_started(self: Game) {
        assert(self.seed != 0, errors::GAME_NOT_STARTED);
    }

    #[inline(always)]
    fn assert_not_started(self: Game) {
        assert(self.seed == 0, errors::GAME_HAS_STARTED);
    }

    #[inline(always)]
    fn assert_exists(self: Game) {
        assert(self.is_non_zero(), errors::GAME_NOT_EXISTS);
    }

    #[inline(always)]
    fn assert_not_exists(self: Game) {
        assert(self.is_zero(), errors::GAME_DOES_EXIST);
    }

    #[inline(always)]
    fn assert_is_full(self: Game) {
        assert(MAXIMUM_PLAYER_COUNT == self.player_count.into(), errors::GAME_NOT_FULL);
    }

    #[inline(always)]
    fn assert_not_full(self: Game) {
        assert(MAXIMUM_PLAYER_COUNT != self.player_count.into(), errors::GAME_IS_FULL);
    }

    #[inline(always)]
    fn assert_not_empty(self: Game) {
        assert(0 != self.player_count.into(), errors::GAME_IS_EMPTY);
    }

    #[inline(always)]
    fn assert_only_one(self: Game) {
        assert(1 == self.player_count.into(), errors::GAME_NOT_ONLY_ONE);
    }

    #[inline(always)]
    fn assert_can_start(self: Game) {
        assert(self.player_count >= MINIMUM_PLAYER_COUNT, errors::GAME_TOO_FEW_PLAYERS);
        assert(self.player_count <= MAXIMUM_PLAYER_COUNT, errors::GAME_TOO_MANY_PLAYERS);
    }
}

impl ZeroableGame of Zeroable<Game> {
    #[inline(always)]
    fn zero() -> Game {
        Game { id: 0, host: 0, over: false, seed: 0, player_count: 0, nonce: 0, price: 0, }
    }

    #[inline(always)]
    fn is_zero(self: Game) -> bool {
        0 == self.host
    }

    #[inline(always)]
    fn is_non_zero(self: Game) -> bool {
        !self.is_zero()
    }
}

#[cfg(test)]
mod tests {
    // Core imports

    use debug::PrintTrait;

    // Local imports

    use super::{Game, GameTrait, Turn, TURN_COUNT, MAXIMUM_PLAYER_COUNT, MINIMUM_PLAYER_COUNT};

    // Constants

    const ID: u32 = 0;
    const PRICE: u256 = 1_000_000_000_000_000_000;
    const SEED: felt252 = 'SEED';
    const PLAYER_COUNT: u8 = 4;
    const HOST: felt252 = 'HOST';
    const PLAYER: felt252 = 'PLAYER';

    #[test]
    #[available_gas(100_000)]
    fn test_game_new() {
        let game = GameTrait::new(ID, HOST, PRICE);
        assert(game.host == HOST, 'Game: wrong account');
        assert(game.id == ID, 'Game: wrong id');
        assert(game.over == false, 'Game: wrong over');
        assert(game.seed == 0, 'Game: wrong seed');
        assert(game.player_count == 0, 'Game: wrong player_count');
        assert(game.nonce == 0, 'Game: wrong nonce');
    }

    #[test]
    #[available_gas(100_000)]
    fn test_game_join() {
        let mut game = GameTrait::new(ID, HOST, PRICE);
        game.join();
        let index = game.join();
        assert(game.player_count == 2, 'Game: wrong count');
        assert(index == 1, 'Game: wrong index');
    }

    #[test]
    #[available_gas(100_000)]
    #[should_panic(expected: ('Game: does not exist',))]
    fn test_game_join_revert_does_not_exist() {
        let mut game: Game = Zeroable::zero();
        game.join();
    }

    #[test]
    #[available_gas(100_000)]
    #[should_panic(expected: ('Game: is over',))]
    fn test_game_join_revert_is_over() {
        let mut game = GameTrait::new(ID, HOST, PRICE);
        game.over = true;
        game.join();
    }

    #[test]
    #[available_gas(100_000)]
    #[should_panic(expected: ('Game: has started',))]
    fn test_game_join_revert_has_started() {
        let mut game = GameTrait::new(ID, HOST, PRICE);
        game.seed = 1;
        game.join();
    }

    #[test]
    #[available_gas(150_000)]
    #[should_panic(expected: ('Game: is full',))]
    fn test_game_join_revert_no_remaining_slots() {
        let mut game = GameTrait::new(ID, HOST, PRICE);
        let mut index = MAXIMUM_PLAYER_COUNT + 1;
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
        let mut game = GameTrait::new(ID, HOST, PRICE);
        game.join();
        let index = game.leave(PLAYER);
        assert(game.player_count == 0, 'Game: wrong count');
        assert(index == 0, 'Game: wrong index');
    }

    #[test]
    #[available_gas(100_000)]
    #[should_panic(expected: ('Game: user is the host',))]
    fn test_game_leave_host_revert_host() {
        let mut game = GameTrait::new(ID, HOST, PRICE);
        game.join();
        game.leave(HOST);
        assert(game.over, 'Game: wrong status');
    }

    #[test]
    #[available_gas(100_000)]
    #[should_panic(expected: ('Game: is empty',))]
    fn test_game_leave_revert_does_not_exist() {
        let mut game = GameTrait::new(ID, HOST, PRICE);
        game.join();
        game.player_count = 0;
        game.leave(PLAYER);
    }

    #[test]
    #[available_gas(100_000)]
    #[should_panic(expected: ('Game: is over',))]
    fn test_game_leave_revert_over() {
        let mut game = GameTrait::new(ID, HOST, PRICE);
        game.join();
        game.over = true;
        game.leave(PLAYER);
    }

    #[test]
    #[available_gas(100_000)]
    #[should_panic(expected: ('Game: has started',))]
    fn test_game_leave_revert_has_started() {
        let mut game = GameTrait::new(ID, HOST, PRICE);
        game.seed = 1;
        game.join();
        game.leave(PLAYER);
    }

    #[test]
    #[available_gas(100_000)]
    #[should_panic(expected: ('Game: is empty',))]
    fn test_game_leave_revert_is_empty() {
        let mut game = GameTrait::new(ID, HOST, PRICE);
        game.join();
        game.leave(PLAYER);
        game.leave(PLAYER);
    }

    #[test]
    #[available_gas(200_000)]
    fn test_game_delete_host() {
        let mut game = GameTrait::new(ID, HOST, PRICE);
        game.join();
        game.delete(HOST);
        assert(game.is_zero(), 'Game: not zero');
    }

    #[test]
    #[available_gas(200_000)]
    fn test_game_start() {
        let mut game = GameTrait::new(ID, HOST, PRICE);
        let mut index = PLAYER_COUNT;
        loop {
            if index == 0 {
                break;
            }
            index -= 1;
            game.join();
        };
        let players = array![HOST, PLAYER];
        game.start(players);
        assert(game.seed != 0, 'Game: wrong seed');
    }

    #[test]
    #[available_gas(200_000)]
    #[should_panic(expected: ('Game: too few players',))]
    fn test_game_start_revert_too_few_players() {
        let mut game = GameTrait::new(ID, HOST, PRICE);
        game.player_count = 0;
        let players = array![HOST, PLAYER];
        game.start(players);
    }

    #[test]
    #[available_gas(200_000)]
    #[should_panic(expected: ('Game: is over',))]
    fn test_game_start_revert_is_over() {
        let mut game = GameTrait::new(ID, HOST, PRICE);
        game.over = true;
        let players = array![HOST, PLAYER];
        game.start(players);
    }

    #[test]
    #[available_gas(200_000)]
    #[should_panic(expected: ('Game: has started',))]
    fn test_game_start_revert_has_started() {
        let mut game = GameTrait::new(ID, HOST, PRICE);
        game.seed = 1;
        let players = array![HOST, PLAYER];
        game.start(players);
    }

    #[test]
    #[available_gas(1_000_000)]
    fn test_game_get_player_index() {
        let mut game = GameTrait::new(ID, HOST, PRICE);
        game.player_count = 6;
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
        assert(game.player() == 4, 'Game: wrong player index 1+12');
        game.nonce += TURN_COUNT;
        assert(game.player() == 5, 'Game: wrong player index 1+15');
        game.nonce += TURN_COUNT;
        assert(game.player() == 0, 'Game: wrong player index 1+18');
        game.nonce += TURN_COUNT;
    }

    #[test]
    #[available_gas(100_000)]
    fn test_game_get_next_player_index() {
        let mut game = GameTrait::new(ID, HOST, PRICE);
        game.player_count = 6;
        assert(game.player() == 0, 'Game: wrong player index 0+0');
        assert(game.next_player() == 1, 'Game: wrong next player 0+0');
        game.nonce += TURN_COUNT;
        assert(game.player() == 1, 'Game: wrong player index 0+3');
        assert(game.next_player() == 2, 'Game: wrong next player 0+3');
    }

    #[test]
    #[available_gas(100_000)]
    fn test_game_get_turn_index() {
        let mut game = GameTrait::new(ID, HOST, PRICE);
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
        let mut game = GameTrait::new(ID, HOST, PRICE);
        game.player_count = 6;
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
