#[system]
mod supply {
    // Dojo imports

    use dojo::world::{Context, IWorld};

    // Components imports

    use zrisk::components::game::{Game, GameTrait};
    use zrisk::components::player::Player;
    use zrisk::components::tile::Tile;

    // Entities imports

    use zrisk::entities::land::LandTrait;

    // Internal imports

    use zrisk::config::TILE_NUMBER;

    // Errors

    mod errors {
        const INVALID_PLAYER: felt252 = 'Supply: invalid player';
        const INVALID_OWNER: felt252 = 'Supply: invalid owner';
    }

    fn execute(ctx: Context, account: felt252, tile_index: u8, supply: u32) {
        // [Command] Game component
        let mut game: Game = get!(ctx.world, account, (Game));

        // [Command] Player component
        let player_key = (game.id, game.get_player_index());
        let mut player: Player = get!(ctx.world, player_key.into(), (Player));

        // [Check] Caller is player
        assert(player.address == ctx.origin, errors::INVALID_PLAYER);

        // [Command] Tile component
        let tile_key = (game.id, tile_index);
        let mut tile: Tile = get!(ctx.world, tile_key.into(), (Tile));

        // [Check] Tile owner
        assert(tile.owner == player.index.into(), errors::INVALID_OWNER);

        // [Compute] Supply
        let mut land = LandTrait::load(@tile);
        land.supply(ref player, supply);

        // [Command] Update player
        set!(ctx.world, (player));

        // [Compute] Update tile
        let tile = land.dump(game.id);
        set!(ctx.world, (tile));
    }
}
