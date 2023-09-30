#[system]
mod supply {
    // Dojo imports

    use dojo::world::{Context, IWorld};

    // Components imports

    use zrisk::components::game::{Game, GameTrait};
    use zrisk::components::player::Player;
    use zrisk::components::tile::Tile;

    // Internal imports

    use zrisk::config::TILE_NUMBER;

    // Errors

    mod errors {
        const INVALID_TILE_INDEX: felt252 = 'Supply: invalid tile index';
        const INVALID_PLAYER: felt252 = 'Supply: invalid player';
        const INVALID_SUPPLY: felt252 = 'Supply: invalid supply';
        const INVALID_OWNER: felt252 = 'Supply: invalid owner';
    }

    fn execute(ctx: Context, account: felt252, tile_index: u8, supply: u32) {
        // [Check] Tile index is valid
        assert(TILE_NUMBER > tile_index.into(), errors::INVALID_TILE_INDEX);

        // [Command] Game entity
        let mut game: Game = get!(ctx.world, account, (Game));

        // [Command] Player entity
        let player_key = (game.id, game.get_player_index());
        let mut player: Player = get!(ctx.world, player_key.into(), (Player));

        // [Check] Caller is player
        assert(player.address == ctx.origin, errors::INVALID_PLAYER);

        // [Check] Player available supply
        assert(player.supply >= supply, errors::INVALID_SUPPLY);

        // [Command] Tile entity
        let tile_key = (game.id, tile_index);
        let mut tile: Tile = get!(ctx.world, tile_key.into(), (Tile));

        // [Check] Tile owner
        assert(tile.owner == player.index.into(), errors::INVALID_OWNER);

        // [Command] Update player supply
        player.supply -= supply;
        set!(ctx.world, (player));

        // [Compute] Update tile army
        tile.army += supply;
        set!(ctx.world, (tile));
    }
}
