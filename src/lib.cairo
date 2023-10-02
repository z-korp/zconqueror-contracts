mod constants;

mod data {
    mod v00;
    mod v01;
}

mod entities {
    mod land;
    mod dice;
    mod deck;
    mod map;
}

mod components {
    mod game;
    mod player;
    mod tile;
}

mod systems {
    mod create;
    mod supply;
    mod attack;
    mod defend;
    mod transfer;
    mod finish;
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
