#[system]
mod create {
    // Dojo imports

    use dojo::world::{Context, IWorld};

    // Components imports

    use zrisk::components::game::{Game, GameTrait};
    use zrisk::components::player::{Player, PlayerTrait};
    use zrisk::components::tile::Tile;

    // Entities imports

    use zrisk::entities::map::MapTrait;
    use zrisk::entities::deck::DeckTrait;
    use zrisk::entities::tile::TileTrait;

    // Internal imports

    use zrisk::config::{TILE_NUMBER, ARMY_NUMBER};

    // Errors

    mod errors {
        const TILES_UNBOX_ISSUE: felt252 = 'Tiles: unbox issue';
    }

    fn execute(ctx: Context, account: felt252, seed: felt252, name: felt252, player_count: u8) {
        // [Command] Game component
        let game_id = ctx.world.uuid();
        let mut game = GameTrait::new(account, game_id, seed, player_count);
        set!(ctx.world, (game));

        // [Command] Tile components
        let mut map = MapTrait::new(
            seed: game.seed,
            player_count: game.player_count.into(),
            tile_count: TILE_NUMBER,
            army_count: ARMY_NUMBER
        );
        let mut player_index = 0;
        loop {
            if player_index == game.player_count {
                break;
            }
            let mut player_tiles = map.player_tiles(player_index.into());
            loop {
                match player_tiles.pop_front() {
                    Option::Some(tile) => {
                        let tile: Tile = tile.dump(game.id);
                        set!(ctx.world, (tile));
                    },
                    Option::None => {
                        break;
                    },
                };
            };
            player_index += 1;
        };

        // [Command] Player components
        // Use the deck mechanism to define the player order, human player is 1
        // First player got his supply set
        let mut deck = DeckTrait::new(game.seed, game.player_count.into());
        let mut player_index = 0;
        loop {
            if player_index == game.player_count {
                break;
            }
            let card = deck.draw() - 1;
            let mut player = if card == 1 {
                PlayerTrait::new(game_id, player_index.into(), address: ctx.origin, name: name)
            } else {
                PlayerTrait::new(
                    game_id, player_index.into(), address: ctx.origin, name: card.into()
                )
            };
            if player_index == 0 {
                let player_score = map.score(player_index.into());
                player.supply = if player_score < 3 {
                    3
                } else {
                    player_score
                };
            }
            set!(ctx.world, (player));
            player_index += 1;
        };
    }
}
