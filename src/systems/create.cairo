#[system]
mod create {
    // Core imports

    use core::dict::Felt252DictTrait;
    use array::{ArrayTrait, SpanTrait};
    use traits::Into;
    use nullable::{NullableTrait, nullable_from_box, match_nullable, FromNullableResult};

    // Dojo imports

    use dojo::world::{Context, IWorld};

    // Components imports

    use zrisk::components::game::{Game, GameTrait};
    use zrisk::components::player::{Player, PlayerTrait};
    use zrisk::components::tile::{Tile as TileComponent};

    // Entities imports

    use zrisk::entities::map::{Map, MapTrait};
    use zrisk::entities::deck::{Deck, DeckTrait};
    use zrisk::entities::tile::{Tile, TileTrait};

    // Internal imports

    use zrisk::constants::{TILE_NUMBER, ARMY_NUMBER};

    // Errors

    mod errors {
        const TILES_UNBOX_ISSUE: felt252 = 'Tiles unbox issue';
    }

    fn execute(ctx: Context, player: felt252, seed: felt252, name: felt252, number: u8) {
        // [Command] Game entity
        let game_id = ctx.world.uuid();
        let mut game = GameTrait::new(player, game_id, seed, number);
        set!(ctx.world, (game));

        // [Command] Player entities
        // Use the deck mechanism to define the player order, human player is 1
        let mut deck = DeckTrait::new(game.seed, game.number.into());
        let mut index = 0;
        loop {
            if index == game.number {
                break;
            }
            let card = deck.draw() - 1;
            let player = if card == 1 {
                PlayerTrait::new(game_id, card, name)
            } else {
                PlayerTrait::new(game_id, card, card.into())
            };
            set!(ctx.world, (player));
        };

        // [Command] Tile entities
        let mut map = MapTrait::new(
            id: 1,
            seed: game.seed,
            player_number: game.number.into(),
            tile_number: TILE_NUMBER,
            army_number: ARMY_NUMBER
        );
        let mut player_index = 0;
        loop {
            if player_index == game.number {
                break;
            }
            let mut tiles = match match_nullable(map.realms.get(player_index.into())) {
                FromNullableResult::Null => panic(array![errors::TILES_UNBOX_ISSUE]),
                FromNullableResult::NotNull(status) => status.unbox(),
            };
            loop {
                match tiles.pop_front() {
                    Option::Some(tile) => {
                        let tile: TileComponent = tile.convert(game.game_id);
                        set!(ctx.world, (tile));
                    },
                    Option::None => {
                        break;
                    },
                };
            };
            player_index += 1;
        };
    }
}