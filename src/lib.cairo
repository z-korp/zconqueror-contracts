mod constants;
mod store;
mod events;

mod data {
    mod v00;
    mod v01;
    mod v02;
}

mod helpers {
    mod extension;
}

mod models {
    mod game;
    mod player;
    mod tile;
}

mod types {
    mod hand;
    mod map;
    mod set;
    mod reward;
}

mod systems {
    mod host;
    mod play;
}

#[cfg(test)]
mod tests {
    mod setup;
    mod host;
    mod supply;
    mod emote;
    mod attack;
    mod defend;
    mod transfer;
    mod finish;
    mod surrender;
    mod banish;

    mod mocks {
        mod erc20;
    }
}

use zconqueror::data::v00 as config;
// use zconqueror::data::v01 as config;

