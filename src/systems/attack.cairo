#[system]
mod attack {
    // Starknet imports

    use starknet::get_tx_info;

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
        const INVALID_TILE_INDEX: felt252 = 'Attack: invalid tile index';
        const INVALID_PLAYER: felt252 = 'Attack: invalid player';
        const INVALID_DISATCHED: felt252 = 'Attack: invalid dispatched';
        const INVALID_OWNER: felt252 = 'Attack: invalid owner';
    }

    fn execute(
        ctx: Context, account: felt252, source_index: u8, target_index: u8, dispatched: u32
    ) {
        // [Check] Tile indexes are valid
        assert(TILE_NUMBER > source_index.into(), errors::INVALID_TILE_INDEX);
        assert(TILE_NUMBER > target_index.into(), errors::INVALID_TILE_INDEX);

        // [Check] Dispatched is not null
        assert(dispatched > 0, errors::INVALID_DISATCHED);

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

        // [Check] Tiles owner
        assert(source.owner == player.index.into(), errors::INVALID_OWNER);

        // [Compute] Attack
        let mut attacker = TileEntityTrait::load(@source);
        let mut defender = TileEntityTrait::load(@target);
        let order = get_tx_info().unbox().transaction_hash;
        attacker.attack(dispatched, ref defender, order);

        // [Command] Update source army
        let source = attacker.dump(game.id);
        set!(ctx.world, (source));

        // [Command] Update target army
        let target = defender.dump(game.id);
        set!(ctx.world, (target));
    }
}
