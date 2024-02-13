mod constants;
mod store;

mod data {
    mod v00;
    mod v01;
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
    mod attack;
    mod defend;
    mod transfer;
    // mod discard;
    mod finish;
}

use zconqueror::data::v00 as config;
