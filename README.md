# cta-loadtest
Scripts for running loadtests against CTAEOS

Included scripts (in order of execution):
1. set_tape_test_vars.sh
1. stage_files_to_eos.sh
1. wait_for_write_session.sh
1. drop_data_from_disk_and_prepare.sh
1. wait_for_read_session.sh
1. cleanup_eos_files.sh
1. reclaim_tape.sh

Bonus utility scripts:
1. regenerate_eos_file.sh

Usage:
1. Using run_full_tape_test.sh
./run_full_tape_test.sh [-s stage] [-m nostrict] &lt;tapepool&gt; &lt;filesize &gt;

1. Individual Scripts
