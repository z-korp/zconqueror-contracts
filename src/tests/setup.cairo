mod setup {
    // Core imports

    use core::debug::PrintTrait;

    // Starknet imports

    use starknet::ContractAddress;
    use starknet::testing::set_contract_address;

    // Dojo imports

    use dojo::world::{IWorldDispatcherTrait, IWorldDispatcher};
    use dojo::test_utils::{spawn_test_world, deploy_contract};

    // Internal imports

    use zconqueror::tests::mocks::erc20::{
        IERC20Dispatcher, IERC20DispatcherTrait, IERC20FaucetDispatcher,
        IERC20FaucetDispatcherTrait, ERC20
    };
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

    fn ANYONE() -> ContractAddress {
        starknet::contract_address_const::<'ANYONE'>()
    }

    #[derive(Drop)]
    struct Systems {
        host: IHostDispatcher,
        play: IPlayDispatcher,
    }

    #[derive(Drop)]
    struct Context {
        erc20: IERC20Dispatcher,
    }

    fn deploy_erc20() -> IERC20Dispatcher {
        let (address, _) = starknet::deploy_syscall(
            ERC20::TEST_CLASS_HASH.try_into().expect('Class hash conversion failed'),
            0,
            array![].span(),
            false
        )
            .expect('ERC20 deploy failed');
        IERC20Dispatcher { contract_address: address }
    }

    fn spawn_game() -> (IWorldDispatcher, Systems, Context) {
        // [Setup] World
        let mut models = array::ArrayTrait::new();
        models.append(game::TEST_CLASS_HASH);
        models.append(player::TEST_CLASS_HASH);
        models.append(tile::TEST_CLASS_HASH);
        let world = spawn_test_world(models);
        let erc20 = deploy_erc20();

        // [Setup] Systems
        let host_address = deploy_contract(host::TEST_CLASS_HASH, array![].span());
        let play_address = deploy_contract(play::TEST_CLASS_HASH, array![].span());
        let systems = Systems {
            host: IHostDispatcher { contract_address: host_address },
            play: IPlayDispatcher { contract_address: play_address },
        };

        // [Setup] Context
        let context = Context { erc20 };
        let faucet = IERC20FaucetDispatcher { contract_address: erc20.contract_address };
        set_contract_address(ANYONE());
        faucet.mint();
        erc20.approve(host_address, ERC20::FAUCET_AMOUNT);
        erc20.approve(play_address, ERC20::FAUCET_AMOUNT);
        set_contract_address(PLAYER());
        faucet.mint();
        erc20.approve(host_address, ERC20::FAUCET_AMOUNT);
        erc20.approve(play_address, ERC20::FAUCET_AMOUNT);
        set_contract_address(HOST());
        faucet.mint();
        erc20.approve(host_address, ERC20::FAUCET_AMOUNT);
        erc20.approve(play_address, ERC20::FAUCET_AMOUNT);

        // [Return]
        (world, systems, context)
    }
}
