# cta-loadtest
## Scripts for running loadtests against CTAEOS

### Included load test scripts (in order of execution):
1. set_tape_test_vars.sh
Sets variables used in later test scripts, including:
* Tape pool (from args)
* Tape name (from cta-admin via tapepool)
* Number of threads (Max of 1TB/filesize and 100)
* Files per thread (ceil(3TB/thread_count))
* Number of dd blocks per file (file size / 1M)
2. stage_files_to_eos.sh
Disables tape
In each of up to 100 threads:
* Skips any files that already exist in EOS
* Uses dd to generate files from /dev/urandom in a scratch directory (mnt/sfa_test_filespace/)
* Uses eos cp to copy as many files to eos as necessary
* Subirectories in eos are created for each 1k files
* Writes a 'done' marker to EOS to signify thread is complete
Waits for all 100 threads to finish
3. wait_for_write_session.sh
Waits for CTA to show 3TB+ Archive Queue
Enables tape
Waits for a write session to tapepool to begin
Records write session ID in session file
Waits for write session to finish
4. drop_data_from_disk_and_prepare.sh
Disables tape
Waits for tape occupancy to show 3TB+
In each of up to 100 threads:
* Checks to make sure most files are on tape according to EOS
* Skips any files that have already been dropped from disk
* For each file that isn't on tape according to EOS, checks to see if it is on tape according to CTA
* For each file that is on tape according to CTA but not EOS, updates EOS to show a copy on tape by adding a copy on fs 65535
* Finds the disk fs of each file using `eos fileinfo`
* Drops each file from EOS using `eos drop`
* Issues a prepare for each file using `xrdcp prepare`
* Creates a 'done' marker in EOS to signify thread is complete
Waits for all threads to finish
5. wait_for_read_session.sh
Waits for CTA to show 3TB+ Retrieve Queue
Enables tape
Waits for a read session from tapepool to begin
Records read session ID in session file
Waits for read session to finish
6. cleanup_eos_files.sh
Waits for each EOS directory to show at least 92% of files are back on disk
In each of up to 100 threads:
* Loops over each EOS file and removes them with `eos rm`
* Creates a 'done' marker in EOS to signify thread is complete
* (This will also lead to them being marked deleted in CTA)
Waits for all threads to finish
7. reclaim_tape.sh
Sets tape to 'full'
Issues reclaim command for tape with `cta-admin tape reclaim`
(This sets tape occupancy to 0 and resets the tape to not full)

### Other scripts:
1. regenerate_eos_file.sh
This was a test script, it takes a file name and file size, deletes the file from eos and regenerates it.

### Usage:
1. Using run_full_tape_test.sh

./run_full_tape_test.sh \[-s stage\] \[-m nostrict\] &lt;tapepool&gt; &lt;filesize&gt;

-s stage: skip to the specified stage of the loadtest. Valid stages are:
* stage
* write
* drop / prepare
* read
* cleanup
* reclaim

-m nostrict: skip certain sanity checks during loadtest (i.e. don't wait for all files to get back to EOS)

tapepool - SUFFIX of the tapepool you want to read/write to. 'ctasfatest' is prepended to compute full tapepool name in set_tape_test_vars.sh.
Tests assume there is only one tape per tapepool.

filesize - Size of each file to be written to CTAEOS. Enough files are generated and written for AT LEAST 3TB of data to go to tape.
If your file size is not a factor of 3TB/(number of threads(usually 100)), each thread will overshoot and you will end up with more than 3.0TB.

This will run the scripts in order above, executing an end-to-end loadtest.

2. Individual Scripts

Each script can be run individually. Example:

./stage_files_to_eos.sh &lt;tapepool&gt; &lt;filesize&gt;

Running in this mode will invoke set_tape_test_vars.sh before the script is run (this is the first thing each script does if/when it is invoked directly).
Each script is highly dependent on the state left over from the script before it, which must have been run with exactly the same arguments.
As such, running individual scripts is generally not recommended unless.
If there is an issue in the middle of a loadtest, it is usually best to continue with ./run_full_tape_test.sh -s &lt;stage&gt; to continue and finish the loadtest.
