mod constants;

mod data {
    mod v00;
    mod v01;
}

mod entities {
    mod tile;
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
}

#[cfg(test)]
mod tests {
    mod setup;
    mod create;
}

use zrisk::data::v00 as config;
