mod setup {
    // Starknet imports

    use starknet::ContractAddress;
    use starknet::testing::set_contract_address;

    // Dojo imports

    use dojo::world::{IWorldDispatcherTrait, IWorldDispatcher};
    use dojo::test_utils::{spawn_test_world, deploy_contract};

    // Internal imports

    use zconqueror::models::game::{game, Game};
    use zconqueror::models::player::{player, Player};
    use zconqueror::models::tile::{tile, Tile};
    use zconqueror::systems::host::{host, IHostDispatcher};
    use zconqueror::systems::play::{play, IPlayDispatcher};

    // Constants

    fn HOST() -> ContractAddress {
        starknet::contract_address_const::<'HOST'>()
    }

    fn PLAYER() -> ContractAddress {
        starknet::contract_address_const::<'PLAYER'>()
    }

    #[derive(Drop)]
    struct Systems {
        host: IHostDispatcher,
        play: IPlayDispatcher,
    }

    fn spawn_game() -> (IWorldDispatcher, Systems) {
        // [Setup] World
        let mut models = array::ArrayTrait::new();
        models.append(game::TEST_CLASS_HASH);
        models.append(player::TEST_CLASS_HASH);
        models.append(tile::TEST_CLASS_HASH);
        let world = spawn_test_world(models);

        // [Setup] Systems
        let host_address = deploy_contract(host::TEST_CLASS_HASH, array![].span());
        let play_address = deploy_contract(play::TEST_CLASS_HASH, array![].span());
        let systems = Systems {
            host: IHostDispatcher { contract_address: host_address },
            play: IPlayDispatcher { contract_address: play_address },
        };

        // [Return]
        set_contract_address(HOST());
        (world, systems)
    }
}
