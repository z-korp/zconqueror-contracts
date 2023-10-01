#[system]
mod transfer {
    // Dojo imports

    use dojo::world::{Context, IWorld};

    // Components imports

    use zrisk::components::game::{Game, GameTrait};
    use zrisk::components::player::Player;
    use zrisk::components::tile::Tile;

    // Entities imports

    use zrisk::entities::tile::{Tile as TileEntity, TileTrait as TileEntityTrait};

    // Internal imports

    use zrisk::config::TILE_NUMBER;

    // Errors

    mod errors {
        const INVALID_TILE_INDEX: felt252 = 'Transfer: invalid tile index';
        const INVALID_PLAYER: felt252 = 'Transfer: invalid player';
        const INVALID_ARMY: felt252 = 'Transfer: invalid source army';
        const INVALID_OWNER: felt252 = 'Transfer: invalid owner';
        const INVALID_CONNECTION: felt252 = 'Transfer: invalid connection';
    }

    fn execute(ctx: Context, account: felt252, source_index: u8, target_index: u8, army: u32) {
        // [Check] Tile indexes are valid
        assert(TILE_NUMBER > source_index.into(), errors::INVALID_TILE_INDEX);
        assert(TILE_NUMBER > target_index.into(), errors::INVALID_TILE_INDEX);

        // [Command] Game entity
        let mut game: Game = get!(ctx.world, account, (Game));

        // [Command] Player entity
        let player_key = (game.id, game.get_player_index());
        let mut player: Player = get!(ctx.world, player_key.into(), (Player));

        // [Check] Caller is player
        assert(player.address == ctx.origin, errors::INVALID_PLAYER);

        // [Command] Tile entities
        let source_key = (game.id, source_index);
        let mut source: Tile = get!(ctx.world, source_key.into(), (Tile));
        let target_key = (game.id, target_index);
        let mut target: Tile = get!(ctx.world, target_key.into(), (Tile));

        // [Check] Source tile has enough army
        assert(source.army > army, errors::INVALID_ARMY);

        // [Check] Tiles owner
        assert(source.owner == player.index.into(), errors::INVALID_OWNER);
        assert(target.owner == player.index.into(), errors::INVALID_OWNER);

        // [Check] Tiles are connected somehow by an owned path
        let mut tiles: Array<TileEntity> = array![];
        let mut tile_index = 0;
        loop {
            if tile_index == TILE_NUMBER {
                break;
            }
            let tile_key = (game.id, tile_index);
            let tile = get!(ctx.world, tile_key.into(), (Tile));
            tiles.append(TileEntityTrait::load(@tile));
            tile_index += 1;
        };
        let source_tile = TileEntityTrait::load(@source);
        let target_tile = TileEntityTrait::load(@target);
        assert(source_tile.is_connected(@target_tile, tiles.span()), errors::INVALID_CONNECTION);

        // [Command] Update source army
        source.army -= army;
        set!(ctx.world, (source));

        // [Compute] Update target army
        target.army += army;
        set!(ctx.world, (target));
    }
}
