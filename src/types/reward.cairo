// Starknet imports

use starknet::ContractAddress;

// Internal imports

use zconqueror::constants;

// Constants

const PLAYER_SHARE: u256 = 75_000;
const DEV_SHARE: u256 = 24_000;
const DAO_SHARE: u256 = 1_000;
const TOTAL_SHARE: u256 = 100_000;

const FIRST_SHARE_4P: u256 = 65_000;
const SECOND_SHARE_4P: u256 = 35_000;
const FIRST_SHARE_5P: u256 = 50_000;
const SECOND_SHARE_5P: u256 = 30_000;
const THIRD_SHARE_5P: u256 = 20_000;
const FIRST_SHARE_6P: u256 = 50_000;
const SECOND_SHARE_6P: u256 = 30_000;
const THIRD_SHARE_6P: u256 = 20_000;

#[derive(Copy, Drop)]
struct Reward {
    recipient: ContractAddress,
    amount: u256,
}

#[generate_trait]
impl RewardImpl of RewardTrait {
    #[inline(always)]
    fn rewards(
        player_count: u8,
        amount: u256,
        first: ContractAddress,
        second: ContractAddress,
        third: ContractAddress
    ) -> Span<Reward> {
        let mut rewards: Array<Reward> = array![];

        // Dev reward
        let dev_amount = amount * DEV_SHARE / TOTAL_SHARE;
        rewards.append(Reward { recipient: constants::DEV_ADDRESS(), amount: dev_amount, });

        // Dao reward
        let dao_amount = amount * DAO_SHARE / TOTAL_SHARE;
        rewards.append(Reward { recipient: constants::DAO_ADDRESS(), amount: dao_amount, });

        // Player rewards
        let player_amount = amount - dev_amount - dao_amount;

        // Case 2 and 3 players
        if player_count < 4 {
            rewards.append(Reward { recipient: first, amount: player_amount, });

            return rewards.span();
        }

        // Case 4 players
        if player_count == 4 {
            let second_amount = player_amount * SECOND_SHARE_4P / TOTAL_SHARE;
            let first_amount = player_amount - second_amount;
            rewards.append(Reward { recipient: first, amount: first_amount, });
            rewards.append(Reward { recipient: second, amount: second_amount, });

            return rewards.span();
        }

        // Case 5+ players
        let third_amount = player_amount * THIRD_SHARE_5P / TOTAL_SHARE;
        let second_amount = player_amount * SECOND_SHARE_5P / TOTAL_SHARE;
        let first_amount = player_amount - second_amount - third_amount;
        rewards.append(Reward { recipient: first, amount: first_amount, });
        rewards.append(Reward { recipient: second, amount: second_amount, });
        rewards.append(Reward { recipient: third, amount: third_amount, });
        return rewards.span();
    }
}
