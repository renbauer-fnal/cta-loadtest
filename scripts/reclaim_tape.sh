#!/bin/bash
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]
then
	dir=$(dirname $0)
	source ${dir}/set_tape_test_vars.sh $@
fi

# Set tape full
XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab cta-admin tape ch -v $tape_vid -f true

# Reclaim tape
XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab cta-admin tape reclaim -v $tape_vid
