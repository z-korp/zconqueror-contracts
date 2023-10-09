// Constants

const TURN_COUNT: u8 = 3;

#[derive(Model, Copy, Drop, Serde)]
struct Game {
    #[key]
    key: felt252,
    id: u32,
    over: bool,
    seed: felt252,
    player_count: u8,
    nonce: u8,
}

#[derive(Drop, PartialEq)]
enum Turn {
    Supply,
    Attack,
    Transfer,
}

trait GameTrait {
    fn new(account: felt252, id: u32, seed: felt252, player_count: u8) -> Game;
    fn player(self: @Game) -> u8;
    fn turn(self: @Game) -> Turn;
    fn next_player(self: @Game) -> u8;
    fn next_turn(self: @Game) -> Turn;
    fn increment(ref self: Game);
    fn decrement(ref self: Game);
    fn roll(ref self: Game);
}

impl GameImpl of GameTrait {
    fn new(account: felt252, id: u32, seed: felt252, player_count: u8) -> Game {
        Game { key: account, id, over: false, seed, player_count, nonce: 0 }
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

    fn increment(ref self: Game) {
        self.nonce += 1;
    }

    fn decrement(ref self: Game) {
        self.nonce -= 1;
    }

    fn roll(ref self: Game) {
        self.nonce += TURN_COUNT;
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
        let game = GameTrait::new(ACCOUNT, ID, SEED, PLAYER_COUNT);
        assert(game.key == ACCOUNT, 'Game: wrong account');
        assert(game.id == ID, 'Game: wrong id');
        assert(game.over == false, 'Game: wrong over');
        assert(game.seed == SEED, 'Game: wrong seed');
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
