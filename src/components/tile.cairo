#[derive(Component, Copy, Drop, Serde, SerdeLen)]
struct Tile {
    #[key]
    game_id: u32,
    #[key]
    tile_id: u8,
    army: u8,
    owner: u32,
    dispatched: u8,
}
