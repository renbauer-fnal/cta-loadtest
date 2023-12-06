#!/bin/bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
	dir=$(dirname $0)
	source ${dir}/set_tape_test_vars.sh $@
fi

echo -n "Ensuring tape occupancy is 3.XT:"
while [ $(XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab cta-admin tape ls -v $tape_vid | grep -E  "[34]\.[0-9]T" | wc -l) -ne "1" ] && [ $nostrict -eq 0 ]; do
	echo -n "."
	sleep 10
done
echo ""

# Disable tape to drop data from disk
XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab cta-admin tape ch -v $tape_vid -s "DISABLED" -r "Staging Data"
echo "Tape $tape_vid DISABLED"

# Drop files from disk and issue prepare request
# Loop over files
echo -n "Starting threads to drop files: "
sizedir=${EOSDIR}${file_size}
for thread in $(seq 1 $num_threads); do
	(
		missing_files=0
		threaddir="${sizedir}/${thread}"
		thousanddir="${threaddir}/0"
		for (( filenum = 1; filenum <= $files_per_thread; filenum++ )); do
			XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab runuser -u cta eos fileinfo "${sizedir}/stop" &> /dev/null
			stop_found=$?
			if [ $stop_found -eq 0 ]; then
				"Stop request from another thread found. Exiting thread ${thread}."
				XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab runuser -u cta eos touch "${threaddir}/done"
				exit 1
			fi
			if [ $(($filenum % 1000)) -eq 0 ]; then
				thousanddir="${threaddir}/$(($filenum / 1000))"
			fi
			fn="${thousanddir}/random_${filenum}"
			retry=0
			eos_ls_ret=1
			while [ $eos_ls_ret -gt 0 ]; do
				file_ls=$(eos ls -y $fn)
				eos_ls_ret=$?
				if [ $eos_ls_ret -eq 2 ]; then  # rc 2 is 'file not found' - we're done
					break
				elif [ $eos_ls_ret -gt 0 ] && [ $retry -gt 0 ]; then
					echo "eos ls failed - mgm unhappy? retry wait: ${retry}"
					sleep $retry
				elif [ $retry -lt 100 ]; then
					retry=$(($retry + 1 + ($RANDOM % 10)))
				fi
			done
			if [ $(echo "$file_ls" | grep "d1::t1" | wc -l) -eq "1" ]; then
				fs=$(XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab runuser -u cta eos fileinfo ${fn} | grep storagedev201 | awk '{print $2}')
				# Drop from disk
				eos file drop ${fn} ${fs}
				# Issue prepare
				XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab xrdfs root://localhost prepare -s ${fn}
			elif [ $(echo "$file_ls" | grep "d0::t1" | wc -l) -eq "1" ]; then
				echo "$fn already dropped from tape - not dropping, but sending prepare"
				XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab xrdfs root://localhost prepare -s ${fn}
			else
				echo "$fn not found replicated to tape!"
				if [ $(XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab cta-admin tape ls -v $tape_vid | grep -E  "[34]\.[0-9]T" | wc -l) -eq "1" ]; then
					echo "There is 3.0T on tape, attempting to resolve file:"
					fxid="$(eos attr get $fn | awk -F\" '{print $2}')"
					XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab cta-admin tapefile ls -v $tape_vid -I $fxid
					if [ $? ]; then
						echo "File found. Marking as replicated and dropping."
						fs=$(XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab runuser -u cta eos fileinfo ${fn} | grep storagedev201 | awk '{print $2}')
						eos file tag ${fn} +65535
						eos file drop ${fn} ${fs}
						xrdfs root://localhost prepare -s ${fn}
					fi
				else
					echo "Tape occupancy is low. Quitting before disk copies are dropped. Thread ${thread}."
					XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab runuser -u cta eos touch "${sizedir}/stop"
					XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab runuser -u cta eos touch "${threaddir}/done"
					exit 1
				fi
			fi
		done
		# Mark Done
		XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab runuser -u cta eos touch "${threaddir}/done"
		exit
	) & echo -n "$thread "
done
echo "\nDone"

echo -n "Waiting for all threads to finish dropping: "
all_threads_done=1
stopping=0
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
	XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab runuser -u cta eos fileinfo "${sizedir}/stop" &> /dev/null
	stop_requested=$?
	if [ $stop_requested -eq 0 ] && [ $stopping -eq 0 ]; then
		echo "Drop thread stop request found. Waiting for all threads to stop:"
		stopping=1
	fi
done
for thread in $(seq 1 $num_threads); do
	threaddir="${sizedir}/${thread}"
	eos rm "${threaddir}/done" 2> /dev/null
done
eos rm "${sizedir}/stop" 2> /dev/null
echo ""
echo "done"
if [ $stopping -gt 0 ]; then
	echo "Exiting due to drop thread stop request."
	exit 1
fi

