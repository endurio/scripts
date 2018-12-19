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

# MINER
MINER_HOST=miner.endur.io

# DNS SEEDER
SEEDER_HOST=seed.endur.io
SEEDER_NS=ns37.domaincontrol.com
SEEDER_IP=seed.endur.io
SEEDER_REPO=https://github.com/endurio/ndrseeder.git
SEEDER_PATH=$GOPATH/src/github.com/endurio/ndrseeder
SEEDER_PORT=5354

if [[ $OPT_UPDATE ]] || ! $SSH $SSH_USER@$SEEDER_IP stat iptables.sh \> /dev/null 2\>\&1; then
    $SCP iptables.sh $SSH_USER@$SEEDER_IP:./
fi
$SSH $SSH_USER@$SEEDER_IP bash iptables.sh 22tcp $SEEDER_PORT

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

if [[ $OPT_UPDATE ]] || ! $SSH $SSH_USER@$SEEDER_IP command -v ndrseeder \> /dev/null 2\>\&1; then
    if [ -x "$(command -v strip)" ]; then
        strip -s "$(command -v ndrseeder)"
    fi
    $SCP "$(command -v ndrseeder)" $SSH_USER@$SEEDER_IP:/usr/local/bin/
fi

#$SSH $SSH_USER@$SEEDER_IP killall -q --signal SIGINT ndrseeder
$SSH $SSH_USER@$SEEDER_IP killall -q ndrseeder
$SSH $SSH_USER@$SEEDER_IP "nohup ndrseeder -H $SEEDER_HOST -n $SEEDER_NS -s $MINER_HOST >ndrseeder.log 2>&1 &"
