#!/bin/bash

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
OPT_UPDATE=

while getopts "h?u" opt; do
    case "$opt" in
    h|\?)
        echo "$(basename ""$0"") [-h|-?] [-u]"
        exit 0
        ;;
	u)	OPT_UPDATE=1
		;;
    esac
done

shift $((OPTIND-1))

[ "${1:-}" = "--" ] && shift

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

if [[ $OPT_UPDATE ]] || [ ! -x "$(command -v ndrseeder)" ]; then
    if [ ! -d "$SEEDER_PATH" ]; then
        git clone --branch mvp $SEEDER_REPO $SEEDER_PATH
        cd $SEEDER_PATH
    elif [[ $OPT_UPDATE ]]; then
        cd $SEEDER_PATH
        git pull
    fi
    glide update
    go install
    cd -
fi

if [[ $OPT_UPDATE ]] || ! $SSH $SSH_USER@$SEED_IP stat /usr/local/bin/ndrseeder \> /dev/null 2\>\&1; then
    $SCP "$(command -v ndrseeder)" $SSH_USER@$SEED_IP:/usr/local/bin/
fi
