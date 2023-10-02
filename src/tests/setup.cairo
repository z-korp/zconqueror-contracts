mod setup {
    // Core imports

    use core::traits::Into;
    use array::ArrayTrait;

    // Starknet imports

    use starknet::ContractAddress;

    // Dojo imports

    use dojo::world::{IWorldDispatcherTrait, IWorldDispatcher};
    use dojo::test_utils::spawn_test_world;

    // Internal imports

    use zrisk::components::game::{game, Game};
    use zrisk::components::player::{player, Player};
    use zrisk::components::tile::{tile, Tile};
    use zrisk::systems::create::create;
    use zrisk::systems::supply::supply;
    use zrisk::systems::attack::attack;
    use zrisk::systems::transfer::transfer;

    fn spawn_game() -> IWorldDispatcher {
        // [Setup] Components
        let mut components = array::ArrayTrait::new();
        components.append(game::TEST_CLASS_HASH);
        components.append(player::TEST_CLASS_HASH);
        components.append(tile::TEST_CLASS_HASH);

        // [Setup] Systems
        let mut systems = array::ArrayTrait::new();
        systems.append(create::TEST_CLASS_HASH);
        systems.append(supply::TEST_CLASS_HASH);
        systems.append(attack::TEST_CLASS_HASH);
        systems.append(transfer::TEST_CLASS_HASH);

        // [Deploy]
        spawn_test_world(components, systems)
    }
}
