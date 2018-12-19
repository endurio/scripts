#!/bin/bash

# CONFIG
SSH_USER=root

# COMMAND SHORTCUTS
SSH="ssh -oStrictHostKeyChecking=no -o BatchMode=yes"
SCP="scp -oStrictHostKeyChecking=no -o BatchMode=yes"
PSCP="parallel-scp -OStrictHostKeyChecking=no -OBatchMode=yes"
SSH_COPY_ID="ssh-copy-id -f"

# DNS SEEDER
SEED_IP=149.28.131.66
SEEDER_REPO=https://github.com/endurio/ndrseeder.git
SEEDER_PATH=$GOPATH/src/github.com/endurio/ndrseeder

if ! $SSH $SSH_USER@$SEED_IP stat /usr/local/bin/ndrseeder \> /dev/null 2\>\&1; then
    if [ ! -x "$(command -v ndrseeder)" ]; then
        if [ ! -d "$SEEDER_DIR" ]; then
            git clone --branch mvp $SEEDER_REPO $SEEDER_PATH
            cd $SEEDER_PATH
            glide update
            go install
            cd -
        fi
    fi

    $SCP "$(command -v ndrseeder)" $SSH_USER@$SEED_IP:/usr/local/bin/
fi
