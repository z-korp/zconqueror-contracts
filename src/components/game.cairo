#[derive(Component, Copy, Drop, Serde, SerdeLen)]
struct Game {
    #[key]
    game_id: u32,
    over: bool,
    seed: felt252,
    number: u8,
}

trait GameTrait {
    fn new(player: felt252, game_id: u32, seed: felt252, number: u8) -> Game;
    fn set_over(ref self: Game, over: bool);
}

impl GameImpl of GameTrait {
    fn new(player: felt252, game_id: u32, seed: felt252, number: u8) -> Game {
        Game { game_id: game_id, over: false, seed: seed, number: number }
    }

    fn set_over(ref self: Game, over: bool) {
        self.over = true;
    }
}
