#[system]
mod finish {
    // Dojo imports

    use dojo::world::{Context, IWorld};

    // Components imports

    use zrisk::components::game::{Game, GameTrait, Turn};
    use zrisk::components::player::Player;
    use zrisk::components::tile::Tile;

    // Entities imports

    use zrisk::config;
    use zrisk::entities::deck::DeckTrait;
    use zrisk::entities::map::{Map, MapTrait};
    use zrisk::entities::land::{Land, LandTrait};
    use zrisk::entities::hand::{Hand, HandTrait};

    // Internal imports

    use zrisk::config::TILE_NUMBER;

    // Errors

    mod errors {
        const INVALID_PLAYER: felt252 = 'Finish: invalid player';
        const INVALID_SUPPLY: felt252 = 'Finish: invalid supply';
    }

    fn execute(ctx: Context, account: felt252) {
        // [Command] Game entity
        let mut game: Game = get!(ctx.world, account, (Game));

        // [Command] Player entity
        let player_key = (game.id, game.player());
        let mut player: Player = get!(ctx.world, player_key.into(), (Player));

        // [Check] Caller is player
        assert(player.address == ctx.origin, errors::INVALID_PLAYER);

        // [Check] Player supply is empty
        assert(player.supply == 0, errors::INVALID_SUPPLY);

        // [Command] Update next player supply if next turn is supply
        if game.next_turn() == Turn::Supply {
            let player_key = (game.id, game.next_player());
            let mut player: Player = get!(ctx.world, player_key.into(), (Player));

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

            // [Compute] Draw card if conqueror
            if player.conqueror {
                // Setup deck
                let mut deck = DeckTrait::new(game.seed, config::card_number(), game.nonce);
                let mut player_index = 0;
                loop {
                    if player_index >= game.player_count {
                        break;
                    }
                    let player_key = (game.id, player_index);
                    let mut player: Player = get!(ctx.world, player_key.into(), (Player));
                    let hand = HandTrait::load(@player);
                    deck.remove(hand.cards.span());
                    player_index += 1;
                };
                // Draw
                let mut hand = HandTrait::load(@player);
                hand.add(deck.draw());
                player.cards = hand.dump();
            }

            // [Compute] New supply
            let mut map = MapTrait::from_lands(game.player_count.into(), lands.span());
            player.conqueror = false;
            player.supply = map.score(player.index);
            set!(ctx.world, (player));
        }

        // [Command] Update game
        game.increment();
        set!(ctx.world, (game));
    }
}
