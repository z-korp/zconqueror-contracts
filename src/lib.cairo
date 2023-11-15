mod constants;
mod datastore;

mod data {
    mod v00;
    mod v01;
}

mod bot {
    mod simple;
}

mod entities {
    mod dice;
    mod deck;
    mod hand;
    mod land;
    mod map;
    mod set;
}

mod components {
    mod game;
    mod player;
    mod tile;
}

mod systems {
    mod player;
}

#[cfg(test)]
mod tests {
    mod setup;
    mod create;
    mod supply;
    mod attack;
    mod defend;
    mod transfer;
    mod finish;
}

use zrisk::data::v01 as config;
