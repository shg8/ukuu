#!/usr/bin/env bash
# notice.sh - desktop notification client
# Brian K. White <b.kenyon.w@gmail.com>
# https://github.com/bkw777/notice.sh
# license GPL3
# https://specifications.freedesktop.org/notification-spec/notification-spec-latest.html
# this copy slightly stripped down for github.com/bkw777/mainline

set +H
shopt -u extglob

tself="${0//\//_}"
TMP="${XDG_RUNTIME_DIR:-/tmp}"
${DEBUG:=false} && {
	export DEBUG
	e="${TMP}/${tself}.${$}.e"
	echo "$0 debug logging to $e" >&2
	exec 2>"$e"
	set -x
	ARGV=("$0" "$@")
	trap "set >&2" 0
}

VERSION="2.2-mainline"
GDBUS_ARGS=(--session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications)

typeset -i ID=0 TTL=-1 KI=0
typeset -a ACMDS=()
unset ID_FILE ICON SUMMARY BODY AKEYS HINTS
APP_NAME="$0"
FORCE_CLOSE=false
CLOSE=false
ACTION_DAEMON=false

typeset -Ar HINT_TYPES=(
	[action-icons]=boolean
	[category]=string
	[desktop-entry]=string
	[image-path]=string
	[resident]=boolean
	[sound-file]=string
	[sound-name]=string
	[suppress-sound]=boolean
	[transient]=boolean
	[x]=int32
	[y]=int32
	[urgency]=byte
)

typeset -r ifs="${IFS}"

help () { echo "$0 [-Nnsbhaitfcv? ...] [--] [summary]
 -N \"Application Name\" - sending applications formal name
 -n icon_name_or_path  - icon
 -s \"summary text\"     - summary - same as non-option args
 -b \"body text\"        - body
 -h \"hint:value\"       - hint
 -a \"label:command\"    - button-action
 -a \":command\"         - default-action
 -a \"command\"          - close-action
 -i #                  - notification ID number
 -i @filename          - write ID to & read ID from filename
 -t #                  - time to live in seconds
 -f                    - force close after ttl or action
 -c                    - close notification specified by -i
 -v                    - version
 -?                    - this help"
}

abrt () { echo "$0: $@" >&2 ; exit 1 ; }

########################################################################
# action daemon
#

# TODO: Can we make this more elegant by just sending a signal
# to the parent process, it traps the signal to exit itself,
# and it's child gdbus process exits itself naturally on HUP?

kill_obsolete_daemons () {
	local f d x n ;local -i i p
	n=$1 ;shift
	for f in $@ ;do
		[[ -s $f ]] || continue
		[[ $f -ot $n ]] || continue
		read d i p x < $f
		[[ "$d" == "${DISPLAY}" ]] || continue
		((i==ID)) || continue
		((p>1)) || continue
		rm -f $f
		kill $p
	done
}

kill_current_daemon () {
	[[ -s $1 ]] || exit 0
	local d x ;local -i i p
	read d i p x < $1
	rm -f $1
	((p>1)) || exit
	kill $p
}

run () {
	(($#)) && eval setsid -f $@ >&- 2>&- <&-
	${FORCE_CLOSE} && "$0" -i ${ID} -c
}

action_daemon () {
	((ID)) || abrt "no ID"
	local -A c=()
	while (($#)) ;do c[$1]="$2" ;shift 2 ;done
	((${#c[@]})) || abrt "no actions"
	[[ "${DISPLAY}" ]] || abrt "no DISPLAY"
	local f="${TMP}/${tself}.${$}.p" l="${TMP}/${tself}.+([0-9]).p"
	echo -n "${DISPLAY} ${ID} " > $f
	shopt -s extglob
	kill_obsolete_daemons $f $l
	shopt -u extglob
	trap "kill_current_daemon $f" 0
	local e k x ;local -i i
	{
		gdbus monitor ${GDBUS_ARGS[@]} -- & echo ${!} >> $f
	} |while IFS=" :.(),'" read x x x x e x i x k x ;do
		((i==ID)) || continue
		${DEBUG} && printf 'event="%s" key="%s"\n' "$e" "$k" >&2
		case "$e" in
			"NotificationClosed") run "${c[close]}" ;;
			"ActionInvoked") run "${c[$k]}" ;;
		esac
		break
	done
	exit
}

#
# action daemon
########################################################################

close_notification () {
	((ID)) || abrt "no ID"
	((TTL>0)) && sleep ${TTL}
	gdbus call ${GDBUS_ARGS[@]} --method org.freedesktop.Notifications.CloseNotification -- ${ID} >&-
	[[ ${ID_FILE} ]] && rm -f "${ID_FILE}"
	exit
}

add_hint () {
	local -a a ;IFS=: a=($1) ;IFS="${ifs}"
	((${#a[@]}==2 || ${#a[@]}==3)) || abrt "syntax: -h or --hint=\"NAME:VALUE[:TYPE]\""
	local n="${a[0]}" v="${a[1]}" t="${a[2],,}"
	: ${t:=${HINT_TYPES[$n]}}
	[[ $t = string ]] && v="\"$v\""
	((${#HINTS})) && HINTS+=,
	HINTS+="\"$n\":<$t $v>"
}

add_action () {
	local k ;local -a a ;IFS=: a=($1) ;IFS="${ifs}"
	case ${#a[@]} in
		1) k=close a=("" "${a[0]}") ;;
		2) ((${#a[0]})) && k=$((KI++)) || k=default ;((${#AKEYS})) && AKEYS+=, ;AKEYS+="\"$k\",\"${a[0]}\"" ;;
		*) abrt "syntax: -a or --action=\"[[LABEL]:]COMMAND\"" ;;
	esac
	ACMDS+=("$k" "${a[1]}")
}

########################################################################
# parse the commandline
#

OPTIND=1
while getopts 'N:n:s:b:h:a:i:t:fcv%?' x ;do
	case "$x" in
		N) APP_NAME="${OPTARG}" ;;
		n) ICON="${OPTARG}" ;;
		s) SUMMARY="${OPTARG}" ;;
		b) BODY="${OPTARG}" ;;
		a) add_action "${OPTARG}" ;;
		h) add_hint "${OPTARG}" ;;
		i) [[ ${OPTARG:0:1} == '@' ]] && ID_FILE="${OPTARG:1}" || ID=${OPTARG} ;;
		t) TTL=${OPTARG} ;;
		f) FORCE_CLOSE=true ;;
		c) CLOSE=true ;;
		v) echo "$0 ${VERSION}" ;exit 0 ;;
		%) ACTION_DAEMON=true ;;
		'?') help ;exit 0 ;;
		*) help ;exit 1 ;;
	esac
done
shift $((OPTIND-1))

# if we don't have an ID, try ID_FILE
((ID<1)) && [[ -s "${ID_FILE}" ]] && read ID < "${ID_FILE}"

########################################################################
# modes
#

# if we got a close command, then do that now and exit
${CLOSE} && close_notification

# if daemon mode, divert to that
${ACTION_DAEMON} && action_daemon "$@"

########################################################################
# main
#

((${#SUMMARY}<1)) && (($#)) && SUMMARY="$@"
typeset -i t=${TTL} ;((t>0)) && ((t=t*1000))

# send the dbus message, collect the notification ID
x=$(gdbus call ${GDBUS_ARGS[@]} --method org.freedesktop.Notifications.Notify -- \
	"${APP_NAME}" ${ID} "${ICON}" "${SUMMARY}" "${BODY}" "[${AKEYS}]" "{${HINTS}}" "$t")

# process the collected ID
x="${x%,*}" ID="${x#* }"
((ID)) || abrt "invalid notification ID from gdbus"
[[ ${ID_FILE} ]] && echo ${ID} > "${ID_FILE}" || echo ${ID}

# background task to monitor dbus and perform the actions
x= ;${FORCE_CLOSE} && x='-f'
((${#ACMDS[@]})) && setsid -f "$0" -i ${ID} $x -% "${ACMDS[@]}" >&- 2>&- <&-

# background task to wait TTL seconds and then actively close the notification
${FORCE_CLOSE} && ((TTL>0)) && setsid -f "$0" -t ${TTL} -i ${ID} -c >&- 2>&- <&-
