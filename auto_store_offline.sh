#!/bin/bash
# export FULLNODE_API_INFO and MINER_API_INFO environment variable

# export below two environments
#export FULLNODE_API_INFO=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJBbGxvdyI6WyJyZWFkIiwid3JpdGUiLCJzaWduIiwiYWRtaW4iXX0.rJ07vdajyLo58b9XssVgTH6lcVd74aJfdrtji7YVVFM:/ip4/10.10.0.105/tcp/1234/http
#export MINER_API_INFO=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJBbGxvdyI6WyJyZWFkIiwid3JpdGUiLCJzaWduIiwiYWRtaW4iXX0.9JwnmThpKqjqGKfSv6lw_tXFpHV94FpwP6_bovh9V6s:/ip4/10.10.0.101/tcp/2345/http

total=5
start_seq=0
lotus_output=$PWD/lotus_output
miner_output=$PWD/miner_output
miner_user=
miner_host=
lotus_user=
lotus_host=
file_size=262144
miner_id=t01000

raw_filename=data.bin
for(( i=$start_seq; i < $total; i++ ))
do
	# 1. generate file on lotus
	# local
	./generate_file.sh $i $lotus_output $file_size
	# remote
	# ssh $lotus_user@$lotus_host "./generate_file.sh $i $lotus_output $file_size"

	# 2. import original file
	echo "$i: importing file $lotus_output/$raw_filename..."
	import_result=$(lotus client import $lotus_output/$raw_filename)
	cid=$(echo $import_result | cut -f4 -d' ')
	echo "$i: imported file $lotus_output/$raw_filename: $cid"

	# 3. generate car
	echo "$i: generating car..."
	lotus client generate-car $lotus_output/$raw_filename $lotus_output/$raw_filename.$i.car
	echo "$i: generated car: $lotus_output/$raw_filename $lotus_output/$raw_filename.$i.car"

	# 3. generate piece cid
	echo "$i: calculating piece cid and size..." 
	commp_result=$(lotus client commP $lotus_output/$raw_filename.$i.car)
	piece_cid=$(echo $commp_result | cut -f2 -d' ')
	piece_size_literal=$(echo $commp_result | cut -f5 -d' ')
	piece_size_unit=$(echo $commp_result | cut -f6 -d' ')
	if [ "$piece_size_unit" = "KiB" ]; then
		piece_size=$(expr $piece_size_literal \* 1024)
	fi
	echo "$i: calculate piece cid and size: $piece_cid $piece_size"

	# 4. make deal
	echo "$i: deal..."
	deal_id=$(lotus client deal --manual-piece-cid=$piece_cid --manual-piece-size=$piece_size $cid $miner_id 0.000000001 1036800)
	echo "$i: deal id: $deal_id"

	# 5.5 spin
	deal_state=0
	# wait 5 mins to enter StorageDealCheckForAcceptance
	count=0
	while (( deal_state != 13 && count < 60 ))
	do
		deal_state=$(lotus client get-deal $deal_id | jq -r '."DealInfo: ".State')
		(( count++ ))
		echo "$i: $count deal state $deal_state"
		sleep 5s
	done 

	if (( deal_state == 13 ))
	then
		# 5. transfer car to miner
		# remotely (ANY WAY TO GENERATE CAR FILES BY OUR SELF ON MINER MACHINE?)
		# scp $lotus_output/$raw_filename.$i.car auto@miner_ip:$miner_output/
		# local
		cp $lotus_output/$raw_filename.$i.car $miner_output/
		rm $lotus_output/$raw_filename.$i.car

		# 6. miner import
		echo "$i: import data into miner..."
		lotus-miner storage-deals import-data $deal_id $miner_output/$raw_filename.$i.car

		echo "$i: succeed"
	else
		echo "$i: fail: deal state invalid"
	fi
done
