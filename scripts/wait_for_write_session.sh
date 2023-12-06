#!/bin/bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
	dir=$(dirname $0)
	source ${dir}/set_tape_test_vars.sh $@
fi

echo -n "Waiting for request queue to show 3.XT: "
request_queue="0"
while [ $request_queue != "1" ] && [ $nostrict -eq 0 ]; do
	sleep 10
	echo -n "."
	request_queue=$(XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/ctafrontend_client_sss.keytab cta-admin sq | grep "ArchiveForUser ctasfatest${test_type}" | grep "[34]\.[0-9]T" | wc -l)
done
echo ""
echo "Done"

# Active tape to begin writes
XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab cta-admin tape ch -v $tape_vid -s "ACTIVE"
echo "Tape $tape_vid ACTIVE"

# Get session # from cta-admin tape ls and record
session=""
echo -n "Waiting for ArchiveForUser session to start: "
while [ -z $session ]; do
	sleep 10
	echo -n "."
	session=$(XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/ctafrontend_client_sss.keytab cta-admin dr ls | grep $tape_vid | grep "Transfer" | grep "ArchiveForUser" | awk '{print $14}')
done
echo ""
echo "SESSION IS: $session"
echo "write $session" > $session_file

# Wait for session # to complete (?)
still_running=1
echo -n "Waiting for session to complete: "
while [[ $still_running -gt 0 ]]; do
	sleep 10
	still_running=$(XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/ctafrontend_client_sss.keytab cta-admin dr ls | grep $session | wc -l)
	echo -n "."
done

echo ""
echo "Session complete"
