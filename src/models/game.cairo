// Core imports

use hash::HashStateTrait;
use poseidon::PoseidonTrait;

// Starknet imports

use starknet::ContractAddress;

// Internal imports

use zconqueror::models::player::{Player, PlayerTrait};

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
    const GAME_EMPTY_LOBBY: felt252 = 'Game: empty lobby';
    const GAME_OWNER_CANNOT_JOIN: felt252 = 'Game: owner cannot join';
    const GAME_OWNER_CANNOT_LEAVE: felt252 = 'Game: owner cannot leave';
    const GAME_ALREADY_STARTED: felt252 = 'Game: already started';
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
    /// * `account` - The player address.
    /// # Returns
    /// * The new index of the player.
    fn join(ref self: Game, account: ContractAddress) -> u8;
    /// Leaves a game and returns the last player index.
    /// # Arguments
    /// * `self` - The Game.
    /// * `account` - The player address.
    /// # Returns
    /// * The last index of the last registered player.
    fn leave(ref self: Game, account: ContractAddress) -> u8;
    fn start(ref self: Game, players: Span<Player>);
    fn increment(ref self: Game);
    fn decrement(ref self: Game);
    fn pass(ref self: Game);
}

impl GameImpl of GameTrait {
    fn new(id: u32, host: ContractAddress, player_count: u8) -> Game {
        assert(player_count > 0, errors::GAME_NOT_ENOUGH_PLAYERS);
        Game { id, host, over: false, seed: 0, player_count, slots: player_count, nonce: 0 }
    }

    fn real_player_count(self: @Game) -> u8 {
        *self.player_count - *self.slots
    }

    fn player(self: @Game) -> u8 {
        *self.nonce / TURN_COUNT % *self.player_count
    }

    fn turn(self: @Game) -> Turn {
        let turn_id = *self.nonce % TURN_COUNT;
        turn_id.into()
    }

    fn next_player(self: @Game) -> u8 {
        (*self.nonce / TURN_COUNT + 1) % *self.player_count
    }

    fn next_turn(self: @Game) -> Turn {
        let turn_id = (*self.nonce + 1) % TURN_COUNT;
        turn_id.into()
    }

    fn join(ref self: Game, account: ContractAddress) -> u8 {
        assert(self.player_count > 0, errors::GAME_DOES_NOT_EXSIST);
        assert(self.seed == 0, errors::GAME_ALREADY_STARTED);
        assert(self.slots > 0, errors::GAME_NO_REMAINING_SLOTS);
        assert(self.host != account, errors::GAME_OWNER_CANNOT_JOIN);
        let index = self.player_count - self.slots;
        self.slots -= 1;
        index.into()
    }

    fn leave(ref self: Game, account: ContractAddress) -> u8 {
        assert(self.player_count > 0, errors::GAME_DOES_NOT_EXSIST);
        assert(self.seed == 0, errors::GAME_ALREADY_STARTED);
        assert(self.slots < self.player_count, errors::GAME_EMPTY_LOBBY);
        assert(self.host != account, errors::GAME_OWNER_CANNOT_LEAVE);
        self.slots += 1;
        let last_index = self.player_count - self.slots;
        last_index.into()
    }

    fn start(ref self: Game, mut players: Span<Player>) {
        assert(self.slots == 0, errors::GAME_NOT_ENOUGH_PLAYERS);
        let mut state = PoseidonTrait::new();
        state = state.update(self.id.into());
        loop {
            match players.pop_front() {
                Option::Some(player) => { state = state.update((*player.address).into()); },
                Option::None => { break; },
            };
        };
        self.seed = state.finalize();
    }

    fn increment(ref self: Game) {
        self.nonce += 1;
    }

    fn decrement(ref self: Game) {
        self.nonce -= 1;
    }

    fn pass(ref self: Game) {
        let turn = self.nonce % TURN_COUNT;
        self.nonce += TURN_COUNT - turn;
    }
}

impl U8IntoTurn of Into<u8, Turn> {
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
    use super::{Game, GameTrait, Turn, TURN_COUNT};

    const ACCOUNT: felt252 = 'ACCOUNT';
    const ID: u32 = 0;
    const SEED: felt252 = 'SEED';
    const PLAYER_COUNT: u8 = 4;

    #[test]
    #[available_gas(100_000)]
    fn test_game_new() {
        let game = GameTrait::new(ACCOUNT, ID, PLAYER_COUNT);
        assert(game.key == ACCOUNT, 'Game: wrong account');
        assert(game.id == ID, 'Game: wrong id');
        assert(game.over == false, 'Game: wrong over');
        assert(game.player_count == PLAYER_COUNT, 'Game: wrong player_count');
        assert(game.nonce == 0, 'Game: wrong nonce');
    }

    #[test]
    #[available_gas(100_000)]
    fn test_game_get_player_index() {
        let mut game = GameTrait::new(ACCOUNT, ID, SEED, PLAYER_COUNT);
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
        let mut game = GameTrait::new(ACCOUNT, ID, SEED, PLAYER_COUNT);
        assert(game.player() == 0, 'Game: wrong player index 0+0');
        assert(game.next_player() == 1, 'Game: wrong next player 0+0');
        game.nonce += TURN_COUNT;
        assert(game.player() == 1, 'Game: wrong player index 0+3');
        assert(game.next_player() == 2, 'Game: wrong next player 0+3');
    }

    #[test]
    #[available_gas(100_000)]
    fn test_game_get_turn_index() {
        let mut game = GameTrait::new(ACCOUNT, ID, SEED, PLAYER_COUNT);
        assert(game.turn().into() == 0_u8, 'Game: wrong turn index 0');
        game.nonce += 1;
        assert(game.turn().into() == 1_u8, 'Game: wrong turn index 1');
        game.nonce += 1;
        assert(game.turn().into() == 2_u8, 'Game: wrong turn index 2');
        game.nonce += 1;
        assert(game.turn().into() == 0_u8, 'Game: wrong turn index 3');
        game.nonce += 1;
    }
}
