#[derive(Drop, Serde)]
struct Tile {
    id: u8,
    army: u8,
    owner: u8,
}

trait TileTrait {
    fn new(id: u8, army: u8, owner: u8) -> Tile;
    fn get_id(ref self: Tile) -> u8;
    fn get_army(ref self: Tile) -> u8;
    fn get_owner(ref self: Tile) -> u8;
    fn defend(ref self: Tile, tile: Tile);
    fn supply(ref self: Tile, army: u8);
}

impl TileImpl of TileTrait {
    fn new(id: u8, army: u8, owner: u8) -> Tile {
        Tile { id, army, owner }
    }

    fn get_id(ref self: Tile) -> u8 {
        self.id
    }

    fn get_army(ref self: Tile) -> u8 {
        self.army
    }

    fn get_owner(ref self: Tile) -> u8 {
        self.owner
    }

    fn defend(ref self: Tile, tile: Tile) {
        if tile.army < self.army {
            self.army -= tile.army;
        } else {
            self.army = 0;
            self.owner = tile.owner;
        };
    }

    fn supply(ref self: Tile, army: u8) {
        self.army += army;
    }
}