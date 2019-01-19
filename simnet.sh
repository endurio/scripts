#!/bin/sh
#

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
remove=0
daemon=1
wallet=1
first=0
loglevel=

while getopts "h?frdwl:" opt; do
    case "$opt" in
    h|\?)
        echo "$(basename ""$0"") [-h] [-?] [-f|-r] [-d|-w] [-l loglevel] nodes_count"
        exit 0
        ;;
	r)	remove=1
		;;
	f)	first=1
		remove=1
		;;
	d)	wallet=0
		;;
	w)	daemon=0
		;;
	l)	loglevel=$OPTARG
		;;
    esac
done

shift $((OPTIND-1))

[ "${1:-}" = "--" ] && shift

# addresses and keys
MINING_ADDR=ame7CaXCbBV4YvpLUX3fNsGSd7y3ryBfKf
MINING_SKEY=Fw28Hpjon65S4XT8uyfh7w7UFxWVExTs8oDyQZXwB1fTgwwzxnVY

# command shortcuts
CTL="ndrctl --simnet --rpcuser=a --rpcpass=a --skipverify"
CTLW="$CTL --wallet"
BTCD="btcd --simnet --rpcuser=a --rpcpass=a --miningkey=$MINING_SKEY"
BTCW="btcwallet --simnet --connect=localhost --username=a --password=a --createtemp"

# function
function START {
	"$@" >/dev/null &
	#start "$@"
}

# stop running daemon
if [[ $wallet -ne 0 ]]; then
	$CTLW stop 2>/dev/null | grep stopping && sleep 3s
fi
$CTL stop 2>/dev/null | grep stopping && sleep 3s

# process OPTs
if [[ $remove -ne 0 ]]; then
	rm -rf "$LOCALAPPDATA/btcd/data/simnet"
	rm -rf "$LOCALAPPDATA/btcd/logs/simnet"
	rm -rf "$LOCALAPPDATA/btcwallet/simnet"
	rm -rf "$LOCALAPPDATA/btcwallet/logs/simnet"
fi
rm -rf "$LOCALAPPDATA/btcwalletTMP/simnet"
rm -rf "$LOCALAPPDATA/btcwalletTMP/logs/simnet"

if [[ ! -z "$loglevel" ]]; then
	BTCD="$BTCD --debuglevel=$loglevel"
	BTCW="$BTCW --debuglevel=$loglevel"
fi

if [[ $daemon -ne 0 ]]; then
	START $BTCD

	if [[ $first -ne 0 ]]; then
		START $BTCW --appdata="$LOCALAPPDATA/btcwallet"
		sleep 5
		WALLET_ADDR=`$CTLW getnewaddress`
		$CTLW stop

		START $BTCW --appdata="$LOCALAPPDATA/btcwalletTMP"
		sleep 5
		$CTLW walletpassphrase "password" 0
		$CTLW importprivkey $MINING_SKEY

		ACC=imported
		$CTLW sendfrom $ACC $WALLET_ADDR 6 NDR
		$CTLW sendfrom $ACC $WALLET_ADDR 13 STB
		$CTL generate 1
		$CTLW stop
	fi

	# restart the daemon for persistent test
	$CTL stop && sleep 3s
	START $BTCD
fi

if [[ $wallet -ne 0 ]]; then
	sleep 2
	START $BTCW --appdata="$LOCALAPPDATA/btcwallet"
	sleep 5
	$CTLW walletpassphrase "password" 0

	aa=""
	bb=""
	for i in {0..10}; do
		aa="$aa\"`$CTLW getnewaddress`\":0.$((RANDOM%3+3)),"
		bb="$bb\"`$CTLW getnewaddress`\":0.$((RANDOM%3+3)),"
	done
	$CTLW sendmany default {${aa::-1}} NDR
	$CTLW sendmany default {${bb::-1}} STB
	$CTL generate 1

	for i in {0..9}; do
		$CTLW ask 0.$((RANDOM%5))$((RANDOM%9+1)) 2.$((RANDOM%2))$((RANDOM%10))
		$CTLW bid 0.$((RANDOM%5))$((RANDOM%9+1)) 1.$((RANDOM%2+8))$((RANDOM%10))
	done
fi

# idle waiting for Ctrl-D from user
echo "Ctrl-D to finish and stop all daemons.."
$(</dev/stdin)

# stop running daemons
if [[ $wallet -ne 0 ]]; then
	$CTLW stop 2>/dev/null | grep stopping && sleep 3s
fi
$CTL stop 2>/dev/null | grep stopping && sleep 3s
