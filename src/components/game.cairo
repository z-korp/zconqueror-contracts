#[derive(Component, Copy, Drop, Serde, SerdeLen)]
struct Game {
    #[key]
    account: felt252,
    id: u32,
    over: bool,
    seed: felt252,
    player_count: u8,
    nonce: u8,
}

trait GameTrait {
    fn new(account: felt252, id: u32, seed: felt252, player_count: u8) -> Game;
    fn get_player_index(self: @Game) -> u8;
    fn get_next_player_index(self: @Game) -> u8;
    fn set_over(ref self: Game, over: bool);
}

impl GameImpl of GameTrait {
    fn new(account: felt252, id: u32, seed: felt252, player_count: u8) -> Game {
        Game { account, id, over: false, seed, player_count, nonce: 0 }
    }

    fn get_player_index(self: @Game) -> u8 {
        *self.nonce % *self.player_count
    }

    fn get_next_player_index(self: @Game) -> u8 {
        (*self.nonce + 1) % *self.player_count
    }

    fn set_over(ref self: Game, over: bool) {
        self.over = true;
    }
}
