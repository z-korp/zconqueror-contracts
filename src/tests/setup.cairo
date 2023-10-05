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
    use zrisk::systems::create::{create, ICreateDispatcher};
    use zrisk::systems::supply::{supply, ISupplyDispatcher};
    use zrisk::systems::discard::{discard, IDiscardDispatcher};
    use zrisk::systems::attack::{attack, IAttackDispatcher};
    use zrisk::systems::defend::{defend, IDefendDispatcher};
    use zrisk::systems::transfer::{transfer, ITransferDispatcher};
    use zrisk::systems::finish::{finish, IFinishDispatcher};

    #[derive(Drop)]
    struct Systems {
        create: ICreateDispatcher,
        supply: ISupplyDispatcher,
        attack: IAttackDispatcher,
        defend: IDefendDispatcher,
        transfer: ITransferDispatcher,
        finish: IFinishDispatcher,
    }

    fn spawn_game() -> (IWorldDispatcher, Systems) {
        // [Setup] World
        let mut components = array::ArrayTrait::new();
        components.append(game::TEST_CLASS_HASH);
        components.append(player::TEST_CLASS_HASH);
        components.append(tile::TEST_CLASS_HASH);
        let world = spawn_test_world(components);

        // [Setup] Systems
        let create_address = deploy_contract(create::TEST_CLASS_HASH, array![].span());
        let supply_address = deploy_contract(supply::TEST_CLASS_HASH, array![].span());
        let attack_address = deploy_contract(attack::TEST_CLASS_HASH, array![].span());
        let defend_address = deploy_contract(defend::TEST_CLASS_HASH, array![].span());
        let transfer_address = deploy_contract(transfer::TEST_CLASS_HASH, array![].span());
        let finish_address = deploy_contract(finish::TEST_CLASS_HASH, array![].span());
        let systems = Systems {
            create: ICreateDispatcher { contract_address: create_address },
            supply: ISupplyDispatcher { contract_address: supply_address },
            attack: IAttackDispatcher { contract_address: attack_address },
            defend: IDefendDispatcher { contract_address: defend_address },
            transfer: ITransferDispatcher { contract_address: transfer_address },
            finish: IFinishDispatcher { contract_address: finish_address },
        };

        // [Return]
        (world, systems)
    }
}
