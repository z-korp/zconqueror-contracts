mod constants;

mod data {
    mod v00;
    mod v01;
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
    mod attack;
    mod create;
    mod defend;
    mod discard;
    mod finish;
    mod supply;
    mod transfer;
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

use zrisk::data::v00 as config;
