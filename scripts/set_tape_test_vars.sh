#!/bin/bash

# Read file_size and tape_pool from cmd line
total_write=$3
file_size=$2
test_type=$1
tape_pool="ctasfatest$1"

# total_write=8000000000000 8T
# total_write=2000000000000 # 2T
if [ -z $total_write ]; then
	        total_write=3000000000000 # 3T
fi
scratch_space=1000000000000 # 1T
EOSDIR="/eos/ctaeos/cta/sfa_test/$test_type/"
session_file="sessions/$tape_pool.$file_size"
dd_max_bs=1000000 # 1M
dd_bs=$( (( $dd_max_bs <= $file_size )) && echo "$dd_max_bs" || echo "$file_size" )
blocks_per_file=$((file_size/dd_bs))
dd_count=$( (( $blocks_per_file <= 1 )) && echo "1" || echo "$blocks_per_file")

num_files=$((total_write/file_size))
threads=$((scratch_space/file_size))
max_threads=$( (( $num_files <= 100 )) && echo "$num_files" || echo "100" )
num_threads=$( (( $threads <= $max_threads )) && echo "$threads" || echo "$max_threads" )
# num_threads=10
files_per_thread=$((num_files/num_threads + 1))
# files_per_thread=1

# Get tape based on tapepool
tape_vid=$(XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/ctafrontend_client_sss.keytab cta-admin tape ls -t $tape_pool | awk '{print $1}' | sed -e $'s/\x1b\[[0-9;]*m//g' | tr -d '[:space:]')
echo "TAPE VID: $tape_vid"

sizedir=${EOSDIR}${file_size}
