mod constants;
mod store;

mod data {
    mod v00;
    mod v01;
}

mod bot {
    mod simple;
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
    mod create;
// mod supply;
// mod attack;
// mod defend;
// mod transfer;
// mod finish;
}

use zconqueror::data::v00 as config;
