// Internal imports

use zrisk::config;
use zrisk::components::game::{Game, GameTrait};
use zrisk::components::player::{Player, PlayerTrait};
use zrisk::components::tile::Tile;
use zrisk::entities::land::{Land, LandTrait};
use zrisk::entities::map::{Map, MapTrait};

// Errors

mod errors {}

#[generate_trait]
impl SimpleImpl of SimpleTrait {
    fn supply(game: Game, mut player: Player, tiles: Span<Tile>) -> (Player, Span<Tile>) {
        let mut map: Map = MapTrait::from_tiles(game.player_count.into(), tiles);
        let lands = map.player_lands(player.index);
        let mut land = *lands.at(0);
        land.supply(ref player, player.supply);
        (player, array![land.dump(game.id)].span())
    }
}
