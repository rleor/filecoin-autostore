#!/bin/bash
# export FULLNODE_API_INFO and MINER_API_INFO environment variables

# export below two environment variables
#export FULLNODE_API_INFO=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJBbGxvdyI6WyJyZWFkIiwid3JpdGUiLCJzaWduIiwiYWRtaW4iXX0.rJ07vdajyLo58b9XssVgTH6lcVd74aJfdrtji7YVVFM:/ip4/10.10.0.105/tcp/1234/http
#export MINER_API_INFO=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJBbGxvdyI6WyJyZWFkIiwid3JpdGUiLCJzaWduIiwiYWRtaW4iXX0.9JwnmThpKqjqGKfSv6lw_tXFpHV94FpwP6_bovh9V6s:/ip4/10.10.0.101/tcp/2345/http

total=1
start_seq=0
lotus_output=$PWD/lotus_output
file_size=262144
lotus_user=
lotus_host=
miner_id=t01000
raw_filename=data.bin

total_seq=$(expr start_seq + total)
for(( i=$start_seq; i < $total_seq; i++ ))
do
	# 1. generate file on lotus
	# local
	./generate_file.sh $i $lotus_output $file_size
	# remote 
	# ssh $lotus_user@$lotus_host "./generate_file.sh $i $lotus_output $file_size"

	# 2. import file
	echo "$i: importing file $lotus_output/$raw_filename..."
	import_result=$(lotus client import $lotus_output/$raw_filename)
	cid=$(echo $import_result | cut -f4 -d' ')
	echo "$i: imported file $lotus_output/$raw_filename: $cid"

	# 3. make deal
	echo "$i: deal..."
	deal_id=$(lotus client deal $cid $miner_id 0.000000001 1036800)
	echo "$i: deal id: $deal_id"
done
