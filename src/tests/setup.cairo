mod setup {
    // Starknet imports

    use starknet::ContractAddress;

    // Dojo imports

    use dojo::world::{IWorldDispatcherTrait, IWorldDispatcher};
    use dojo::test_utils::{spawn_test_world, deploy_contract};

    // Internal imports

    use zrisk::components::game::{game, Game};
    use zrisk::components::player::{player, Player};
    use zrisk::components::tile::{tile, Tile};
    use zrisk::systems::player::{actions as player_actions, IActionsDispatcher};

    #[derive(Drop)]
    struct Systems {
        player_actions: IActionsDispatcher,
    }

    fn spawn_game() -> (IWorldDispatcher, Systems) {
        // [Setup] World
        let mut components = array::ArrayTrait::new();
        components.append(game::TEST_CLASS_HASH);
        components.append(player::TEST_CLASS_HASH);
        components.append(tile::TEST_CLASS_HASH);
        let world = spawn_test_world(components);

        // [Setup] Systems
        let player_actions_address = deploy_contract(
            player_actions::TEST_CLASS_HASH, array![].span()
        );
        let systems = Systems {
            player_actions: IActionsDispatcher { contract_address: player_actions_address },
        };

        // [Return]
        (world, systems)
    }
}
