#[system]
mod discard {
    // Dojo imports

    use dojo::world::{Context, IWorld};

    // Components imports

    use zrisk::components::game::{Game, GameTrait, Turn};
    use zrisk::components::player::Player;
    use zrisk::components::tile::Tile;

    // Entities imports

    use zrisk::entities::land::{Land, LandTrait};
    use zrisk::entities::hand::HandTrait;
    use zrisk::entities::set::SetTrait;
    use zrisk::entities::map::MapTrait;

    // Internal imports

    use zrisk::config::TILE_NUMBER;

    // Errors

    mod errors {
        const INVALID_TURN: felt252 = 'Supply: invalid turn';
        const INVALID_PLAYER: felt252 = 'Supply: invalid player';
        const INVALID_OWNER: felt252 = 'Supply: invalid owner';
    }

    fn execute(ctx: Context, account: felt252, card_one: u8, card_two: u8, card_three: u8) {
        // [Command] Game component
        let mut game: Game = get!(ctx.world, account, (Game));

        // [Check] Turn
        assert(game.turn() == Turn::Supply, errors::INVALID_TURN);

        // [Command] Player component
        let player_key = (game.id, game.player());
        let mut player: Player = get!(ctx.world, player_key.into(), (Player));

        // [Check] Caller is player
        assert(player.address == ctx.origin, errors::INVALID_PLAYER);

        // [Compute] Set supply
        let mut hand = HandTrait::load(@player);
        let set = SetTrait::new(card_one, card_two, card_three);
        let supply = hand.deploy(@set);

        // [Compute] Map tiles
        let mut lands: Array<Land> = array![];
        let mut tile_index = 1;
        loop {
            if tile_index > TILE_NUMBER {
                break;
            }
            let tile_key = (game.id, tile_index);
            let tile = get!(ctx.world, tile_key.into(), (Tile));
            lands.append(LandTrait::load(@tile));
            tile_index += 1;
        };

        // [Compute] Additional supplies for owned lands
        let mut map = MapTrait::from_lands(game.player_count.into(), lands.span());
        let mut player_lands = map.deploy(player.index, @set);

        // [Command] Update player tiles
        loop {
            match player_lands.pop_front() {
                Option::Some(land) => {
                    let tile: Tile = land.dump(game.id);
                    set!(ctx.world, (tile));
                },
                Option::None => {
                    break;
                },
            };
        };

        // [Command] Update player
        player.supply += supply.into();
        set!(ctx.world, (player));
    }
}
