#!/bin/bash

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
OPT_UPDATE=
OPT_SEEDER=

while getopts "h?us" opt; do
	case "$opt" in
	h|\?)
		echo "$(basename ""$0"") [-h|-?] [-u]"
		exit 0
		;;
	u)	OPT_UPDATE=1
		;;
	s)	OPT_SEEDER=1
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

# PREPARATION
MINER_IP=45.76.148.89

if ! command -v scrypt; then
	export DEBIAN_FRONTEND=noninteractive
	apt-get -yq install scrypt
fi
MINER_KEY=`scrypt dec ~/keys/ANxpQRnzNGhWEL3qvfn8siWsi1ai846fWr.s`
if [ -z "$MINER_KEY" ]; then
	>&2 echo "Mining key not provided."
	exit -1
fi

# SEEDER
if [[ $OPT_SEEDER ]]; then
	DNS_SEEDER=seed.endur.io
	SEEDER_HOST=vps.endur.io
	SEEDER_REPO=https://github.com/endurio/ndrseeder.git
	SEEDER_PATH=$GOPATH/src/github.com/endurio/ndrseeder
	SEEDER_PORT=53

	#$SSH $SSH_USER@$SEEDER_HOST killall -q --signal SIGINT ndrseeder
	$SSH $SSH_USER@$SEEDER_HOST killall ndrseeder

	if [[ $OPT_UPDATE ]] || ! $SSH $SSH_USER@$SEEDER_HOST stat iptables.sh \> /dev/null 2\>\&1; then
		$SCP iptables.sh $SSH_USER@$SEEDER_HOST:./
	fi
	$SSH $SSH_USER@$SEEDER_HOST bash iptables.sh 22tcp ${SEEDER_PORT}udp

	if [[ $OPT_UPDATE ]] || ! command -v ndrseeder; then
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

	if [[ $OPT_UPDATE ]] || ! $SSH $SSH_USER@$SEEDER_HOST command -v ndrseeder \> /dev/null 2\>\&1; then
		if command -v strip; then
			strip -s "$(command -v ndrseeder)"
		fi
		$SCP "$(command -v ndrseeder)" $SSH_USER@$SEEDER_HOST:/usr/local/bin/
	fi

	$SSH $SSH_USER@$SEEDER_HOST "nohup ndrseeder -H$DNS_SEEDER -n$SEEDER_HOST -l:$SEEDER_PORT -s$MINER_IP >ndrseeder.log 2>&1 &"
fi

# MINER
MINER_REPO=git@gitlab.com:Zergity/ndrd.git
MINER_PATH=$GOPATH/src/github.com/btcsuite/btcd
MINER_PORT=8333

if [[ $OPT_UPDATE ]] || ! $SSH $SSH_USER@$MINER_IP "stat iptables.sh >/dev/null 2>&1"; then
	$SCP iptables.sh $SSH_USER@$MINER_IP:./
fi
$SSH $SSH_USER@$MINER_IP bash iptables.sh 22tcp $MINER_PORT

if [[ $OPT_UPDATE ]] || ! command -v btcd; then
	if [ ! -d "$MINER_PATH" ]; then
		git clone --branch mvp $MINER_REPO $MINER_PATH
		cd $MINER_PATH
	elif [[ $OPT_UPDATE ]]; then
		cd $MINER_PATH
		git pull
	fi
	glide update
	go install . ./cmd/...
	cd -
fi

if [[ $OPT_UPDATE ]] || ! $SSH $SSH_USER@$MINER_IP "command -v btcd >/dev/null 2>&1"; then
	if command -v strip; then
		strip -s "$(command -v btcd)"
		strip -s "$(command -v ndrctl)"
	fi
	$SCP "$(command -v btcd)" $SSH_USER@$MINER_IP:/usr/local/bin/
	$SCP "$(command -v ndrctl)" $SSH_USER@$MINER_IP:/usr/local/bin/
fi

$SSH $SSH_USER@$MINER_IP ndrctl --rpcuser=a --rpcpass=a --skipverify stop
sleep 3s
$SSH $SSH_USER@$MINER_IP "nohup btcd --generate --rpcuser=a --rpcpass=a --miningkey=$MINER_KEY >btcd.log 2>&1 &"
