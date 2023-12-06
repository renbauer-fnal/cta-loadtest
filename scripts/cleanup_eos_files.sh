#!/bin/bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
	dir=$(dirname $0)
	source ${dir}/set_tape_test_vars.sh $@
fi

# eos rm -r $EOSDIR/*
# eos rm -r $sizedir
files_exist=0
while [ $nostrict -eq "0" ] && [ $files_exist=0 ]; do
	echo "Ensuring files are back on disk:"
	files_exist=1
	for thread in $(seq 1 $num_threads); do
		threaddir="${sizedir}/${thread}"
		if [ $files_exist -eq 1 ]; then
			for thousand in $(seq 0 $(($files_per_thread / 1000))); do
				thousanddir="${threaddir}/$thousand"
				thousand_files=$(eos ls -y $thousanddir | wc -l)
				disk_files=$(eos ls -y $thousanddir | grep "d1::t" | wc -l)
				if [ $disk_files <= $(($thousand_files * 0.92)) ]; then
					files_exist=0
					break
				fi
			done
			if [ $files_exist -eq 0 ]; then
				echo "It seems not all files have made it back to disk. Leaving EOS directories intact."
				echo "$thousanddir $files: $thousand_files, files on disk: $disk_files."
			fi
		fi
	done
	sleep 10
done

echo -n "Starting threads to rm files: "
for thread in $(seq 1 $num_threads); do
	(
		threaddir="${sizedir}/${thread}"
		thousanddir="${threaddir}/0"
		for (( filenum = 1; filenum <= $files_per_thread; filenum++ )); do
			if [ $(($filenum % 1000)) -eq 0 ]; then
				thousanddir="${threaddir}/$(($filenum / 1000))"
			fi
			fn="${thousanddir}/random_${filenum}"
			retry=0
			eos_rm_ret=1
			while [ $eos_rm_ret -gt 0 ]; do
				eos rm $fn
				eos_rm_ret=$?
				if [ $eos_rm_ret -eq 2 ]; then  # rc 2 is 'file not found' - we're done
					break
				elif [ $eos_rm_ret -gt 0 ] && [ $retry -gt 0 ]; then
					echo "eos rm failed - mgm unhappy? return code: ${eos_rm_ret}; retry wait: ${retry}"
					sleep $retry
				elif [ $retry -lt 100 ]; then
					echo $eos_rm_ret
					retry=$(($retry + 1 + $RANDOM % 10))
				fi
			done
		done
		# Mark Done
		XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab runuser -u cta eos touch "${threaddir}/done"
		exit
	) & echo -n "$thread "
done
echo "\nDone"

echo -n "Waiting for all threads to finish rming: "
all_threads_done=1
while [ $all_threads_done -gt 0 ]; do
        sleep 10
        echo -n "."
        for thread in $(seq 1 $num_threads); do
                threaddir="${sizedir}/${thread}"
                checkfile="${threaddir}/done"
                XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab runuser -u cta eos fileinfo "${checkfile}" &> /dev/null
                all_threads_done=$?
                if [ $all_threads_done -gt 0 ]; then
                        break;
                fi
        done
done
for thread in $(seq 1 $num_threads); do
        threaddir="${sizedir}/${thread}"
        eos rm "${threaddir}/done" 2> /dev/null
done
echo ""
echo "done"

# rm sizedir
eos rm -r ${sizedir}
