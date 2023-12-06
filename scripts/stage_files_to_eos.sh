#!/bin/bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
	dir=$(dirname $0)
	source ${dir}/set_tape_test_vars.sh $@
fi

XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab cta-admin tape ch -v $tape_vid -s "DISABLED" -r "Staging Data"
echo "Tape $tape_vid DISABLED"

# eos cp num_files of size file_size from /dev/urandom into eos
echo -n "launching threads: "
sizedir=${EOSDIR}${file_size}
eos mkdir $sizedir
for thread in $(seq 1 $num_threads); do
	(
		# File_might_exist is used to skip files that have already been created.
		# As long as it is 1, the previous file is already in EOS, so the current file might be as well
		# It is set to 0 once we find two files in a row that do not exist, and we stop checking EOS
		threaddir="${sizedir}/${thread}"
		eos mkdir $threaddir
		thousanddir="${threaddir}/0"
		eos mkdir $thousanddir
	        file_might_exist=2
		for (( filenum = 1; filenum <= $files_per_thread; filenum++ )); do
			if [ $(($filenum % 1000)) -eq 0 ]; then
				thousanddir="${threaddir}/$(($filenum / 1000))"
				eos mkdir $thousanddir
			fi
			tmpfile="/mnt/sfa_test_filespace/rand_${tape_pool}_${thread}_${filenum}"
			# eosfile="${EOSDIR}myfile_random_${file_size}_${thread}_${filenum}"
			eosfile="${thousanddir}/random_${filenum}"
			if [ $file_might_exist -gt 0 ]; then
				eos ls $eosfile
				ret=$?
				if [ $ret -eq 64 ]; then
					sleep 1
					filenum=$(($filenum - 1))
				elif [ $ret -gt 0 ]; then
					echo $ret >> /tmp/eos_ret_values
					file_might_exist=$(($file_might_exist - 1))
				else
					file_might_exist=2
				fi
			fi
			if [ $file_might_exist -lt 2 ]; then
				dd if=/dev/urandom of=$tmpfile bs=$dd_bs count=$dd_count
				XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab runuser -u cta eos cp $tmpfile $eosfile
				ret=$?
				if [ $ret -eq 0 ] || [ $ret -eq 239 ]; then # 239 = File Exists, move on
					rm $tmpfile
				else
					echo $ret >> /tmp/eos_ret_values
					filenum=$(($filenum - 1))
				fi
			fi
		done
		XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab runuser -u cta eos touch "${threaddir}/done"
		exit
	) & echo -n "$thread "
done
echo ""
echo "done"

# Get session # from cta-admin tape ls and record
echo -n "Waiting for all threads to finish writing: "
all_threads_done=1
while [ $all_threads_done -gt 0 ]; do
	sleep 10
	echo -n "."
	for thread in $(seq 1 $num_threads); do
		threaddir="${sizedir}/${thread}"
		XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab runuser -u cta eos fileinfo "${threaddir}/done" &> /dev/null
		all_threads_done=$?
		if [ $all_threads_done -gt 0 ]; then
			break;
		fi
	done
done
for thread in $(seq 1 $num_threads); do
	threaddir="${sizedir}/${thread}"
	eos rm "${threaddir}/done"
done
echo ""
echo "done"
