#[derive(Component, Copy, Drop, Serde, SerdeLen)]
struct Game {
    #[key]
    account: felt252,
    id: u32,
    over: bool,
    seed: felt252,
    player_count: u8,
}

trait GameTrait {
    fn new(account: felt252, id: u32, seed: felt252, player_count: u8) -> Game;
    fn set_over(ref self: Game, over: bool);
}

impl GameImpl of GameTrait {
    fn new(account: felt252, id: u32, seed: felt252, player_count: u8) -> Game {
        Game { account, id, over: false, seed, player_count }
    }

    fn set_over(ref self: Game, over: bool) {
        self.over = true;
    }
}
