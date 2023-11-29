mod constants;
mod store;

mod data {
    mod v00;
    mod v01;
}

mod entities {
    mod hand;
    mod land;
    mod map;
    mod set;
}

mod models {
    mod game;
    mod player;
    mod tile;
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
