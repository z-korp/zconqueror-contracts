#[system]
mod attack {
    // Starknet imports

    use starknet::get_tx_info;

    // Dojo imports

    use dojo::world::{Context, IWorld};

    // Components imports

    use zrisk::components::game::{Game, GameTrait, Turn};
    use zrisk::components::player::Player;
    use zrisk::components::tile::Tile;

    // Entities imports

    use zrisk::entities::land::LandTrait;

    // Internal imports

    use zrisk::config::TILE_NUMBER;

    // Errors

    mod errors {
        const INVALID_TURN: felt252 = 'Attack: invalid turn';
        const INVALID_PLAYER: felt252 = 'Attack: invalid player';
        const INVALID_OWNER: felt252 = 'Attack: invalid owner';
    }

    fn execute(
        ctx: Context, account: felt252, attacker_index: u8, defender_index: u8, dispatched: u32
    ) {
        // [Command] Game component
        let mut game: Game = get!(ctx.world, account, (Game));

        // [Check] Turn
        assert(game.turn() == Turn::Attack, errors::INVALID_TURN);

        // [Command] Player component
        let player_key = (game.id, game.player());
        let mut player: Player = get!(ctx.world, player_key.into(), (Player));

        // [Check] Caller is player
        assert(player.address == ctx.origin, errors::INVALID_PLAYER);

        // [Command] Tile components
        let attacker_key = (game.id, attacker_index);
        let mut attacker_tile: Tile = get!(ctx.world, attacker_key.into(), (Tile));
        let defender_key = (game.id, defender_index);
        let mut defender_tile: Tile = get!(ctx.world, defender_key.into(), (Tile));

        // [Check] Tiles owner
        assert(attacker_tile.owner == player.index.into(), errors::INVALID_OWNER);

        // [Compute] Attack
        let mut attacker_land = LandTrait::load(@attacker_tile);
        let mut defender_land = LandTrait::load(@defender_tile);
        let order = get_tx_info().unbox().transaction_hash;
        attacker_land.attack(dispatched, ref defender_land, order);

        // [Command] Update attacker army
        let attacker_tile = attacker_land.dump(game.id);
        set!(ctx.world, (attacker_tile));

        // [Command] Update defender army
        let defender_tile = defender_land.dump(game.id);
        set!(ctx.world, (defender_tile));
    }
}
