// Internal imports

use zconqueror::config;
use zconqueror::models::game::{Game, GameTrait};
use zconqueror::models::player::{Player, PlayerTrait};
use zconqueror::models::tile::Tile;
use zconqueror::entities::land::{Land, LandTrait};
use zconqueror::entities::map::{Map, MapTrait};

// Errors

mod errors {}

#[generate_trait]
impl SimpleImpl of SimpleTrait {
    fn supply(game: Game, mut player: Player, tiles: Span<Tile>) -> (Player, Span<Tile>) {
        let mut map: Map = MapTrait::from_tiles(game.player_count.into(), tiles);
        let lands = map.player_lands(player.index);
        let mut land = *lands.at(0); // TODO: Manage the case where there is no land
        land.supply(ref player, player.supply);
        (player, array![land.dump(game.id)].span())
    }
}
