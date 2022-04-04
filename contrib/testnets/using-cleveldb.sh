#!/bin/bash

make install GAIA_BUILD_OPTIONS="cleveldb"

kid init "t6" --home ./t6 --chain-id t6

kid unsafe-reset-all --home ./t6

mkdir -p ./t6/data/snapshots/metadata.db

kid keys add validator --keyring-backend test --home ./t6

kid add-genesis-account $(kid keys show validator -a --keyring-backend test --home ./t6) 100000000stake --keyring-backend test --home ./t6

kid gentx validator 100000000stake --keyring-backend test --home ./t6 --chain-id t6

kid collect-gentxs --home ./t6

kid start --db_backend cleveldb --home ./t6
