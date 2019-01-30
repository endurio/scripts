#!/bin/bash
#

# A POSIX variable
OPTIND=1         # Reset in case getopts has been used previously in the shell.

# Initialize our own variables:
clear=0
daemon=1
wallet=1
first=0
loglevel=

while getopts "h?frdwl:" opt; do
    case "$opt" in
    h|\?)
        echo "$(basename ""$0"") [-h] [-?] [-f|-c] [-d|-w] [-l loglevel] nodes_count"
        exit 0
        ;;
	c)	clear=1
		;;
	f)	first=1
		clear=1
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

# CONFIGS
: ${NDRD_DIR:=/tmp/ndrd}
: ${NDRW_DIR:=/tmp/ndrw}
: ${NDRW_TMP_DIR:=/tmp/ndrw_tmp}

# addresses and keys
MINING_ADDR=SsjBm7VwPmzG9LF1NJp8NjgHuHp8RqnVNCa
MINING_SKEY=PsURc5Lzk5GZhPeTkjzXsGpWS7yEkR6y8VuEaxB5PDpA8Lmrz2JPU

# command shortcuts
#NDRD="ndrd --simnet -ua -Pa --miningkey=$MINING_SKEY"
NDRD="ndrd --simnet -ua -Pa -A$NDRD_DIR --miningaddr=$MINING_ADDR --notls"
NDRW="ndrw --simnet -ua -Pa -A$NDRW_DIR --createtemp --noservertls --noclienttls"
NDRW_TMP="ndrw --simnet -ua -Pa -A$NDRW_TMP_DIR --createtemp --noservertls --noclienttls"
CTL="ndrctl --simnet -ua -Pa --notls --skipverify"
CTLW="ndrctl --simnet -ua -Pa --notls --skipverify --wallet"

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
if [[ $clear -ne 0 ]]; then
	rm -rf "$NDRD_DIR/data/simnet"
	rm -rf "$NDRD_DIR/logs/simnet"
	rm -rf "$NDRW_DIR/simnet"
	rm -rf "$NDRW_DIR/logs/simnet"
fi
rm -rf "$NDRW_TMP_DIR"

if [[ ! -z "$loglevel" ]]; then
	NDRD="$NDRD --debuglevel=$loglevel"
	NDRW="$NDRW --debuglevel=$loglevel"
fi

if [[ $daemon -ne 0 ]]; then
	START $NDRD
	sleep 1
	$CTL generate 18

	if [[ $first -ne 0 ]]; then
		START $NDRW
		sleep 5
		WALLET_ADDR=`$CTLW getnewaddress`
		$CTLW stop

		START $NDRW_TMP
		sleep 5
		$CTLW walletpassphrase password 0
		$CTLW importprivkey $MINING_SKEY

		$CTLW getbalance
		$CTLW listunspent

		ACC=imported
		$CTLW sendfrom $ACC $WALLET_ADDR 13
		$CTL generate 1
		$CTLW stop
	fi

	# restart the daemon for persistent test
	$CTL stop && sleep 3s
	START $NDRD
fi

if [[ $wallet -ne 0 ]]; then
	sleep 2
	START $NDRW
	sleep 5
	$CTLW walletpassphrase "password" 0

	aa=""
	#bb=""
	for i in {0..10}; do
		aa="$aa\"`$CTLW getnewaddress`\":0.$((RANDOM%3+3)),"
		#bb="$bb\"`$CTLW getnewaddress`\":0.$((RANDOM%3+3)),"
	done
	$CTLW sendmany default {${aa::-1}}
	#$CTLW sendmany default {${bb::-1}} STB
	$CTL generate 1

	# for i in {0..9}; do
	# 	$CTLW ask 0.$((RANDOM%5))$((RANDOM%9+1)) 2.$((RANDOM%2))$((RANDOM%10))
	# 	$CTLW bid 0.$((RANDOM%5))$((RANDOM%9+1)) 1.$((RANDOM%2+8))$((RANDOM%10))
	# done
fi

# idle waiting for Ctrl-D from user
echo "Ctrl-D to finish and stop all daemons.."
$(</dev/stdin)

# tail the log
#grc -c grc.conf tail -F {$NDRD_DIR,$NDRW_DIR,$NDRW_TMP_DIR}/logs/simnet/ndr*.log

# stop running daemons
if [[ $wallet -ne 0 ]]; then
	$CTLW stop 2>/dev/null | grep stopping && sleep 3s
fi
$CTL stop 2>/dev/null | grep stopping && sleep 3s
