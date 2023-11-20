#[derive(Model, Copy, Drop, Serde)]
struct Tile {
    #[key]
    game_id: u32,
    #[key]
    index: u8,
    army: u32,
    owner: u32,
    dispatched: u32,
    to: u8,
    from: u8,
    order: felt252,
}
