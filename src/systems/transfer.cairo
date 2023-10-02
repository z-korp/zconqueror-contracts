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
        const INVALID_PLAYER: felt252 = 'Transfer: invalid player';
        const INVALID_OWNER: felt252 = 'Transfer: invalid owner';
    }

    fn execute(ctx: Context, account: felt252, source_index: u8, target_index: u8, army: u32) {
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

        // [Check] Source Tile ownership
        assert(source.owner == player.index.into(), errors::INVALID_OWNER);

        // [Effect] Transfer
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
        let mut source_tile = TileEntityTrait::load(@source);
        let mut target_tile = TileEntityTrait::load(@target);
        source_tile.transfer(ref target_tile, army, tiles.span());

        // [Command] Update source army
        let source = source_tile.dump(game.id);
        set!(ctx.world, (source));

        // [Compute] Update target army
        let target = target_tile.dump(game.id);
        set!(ctx.world, (target));
    }
}
