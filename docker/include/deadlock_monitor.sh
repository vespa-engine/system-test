#!/bin/sh

proton_pid=$1
errcnt=0
if [ "$proton_pid" = "" ]; then
	echo "Usage: $0 {proton pid}" >&2
	exit 1
fi

seq 8640 | while read cnt; do
	sleep 10
	if ps -p "$proton_pid" | grep proton >/dev/null; then
		: ok
	else
		printf 'warning\tNot a proton process for %s: %s\n' "$0" "$proton_pid"
		exit 1
	fi
	stackdump1=$stackdump2
	stackdump2=$stackdump3
	stackdump3=$stackdump4
	stackdump4=$stackdump5
	stackdump5=$stackdump6
	stackdump6=$stackdump7
	stackdump7=$(eu-stack -p "$proton_pid" 2>&1)
	# eu-stack exits 1 on partial backtraces (common, still useful); 2 means no stacks at all
	if [ $? -ge 2 ]; then
		errcnt=$((errcnt + 1))
		if [ $errcnt -gt 100 ]; then
			exit 1
		fi
	fi
	if tail -n 1000 /opt/vespa/logs/vespa/vespa.log | grep 'doomOvertime=[1-9][0-9]' > /dev/null; then
		printf "warning\tobserved too high doomOvertime, dumping stacks\n"
		printf "info\tstack 1 ::: "
		echo "$stackdump1"
		printf "info\tstack 2 ::: "
		echo "$stackdump2"
		printf "info\tstack 3 ::: "
		echo "$stackdump3"
		printf "info\tstack 4 ::: "
		echo "$stackdump4"
		printf "info\tstack 5 ::: "
		echo "$stackdump5"
		printf "info\tstack 6 ::: "
		echo "$stackdump6"
		printf "info\tstack 7 ::: "
		echo "$stackdump7"
		printf "info\tend ::: stacks\n"
		exit 1
	fi
done
