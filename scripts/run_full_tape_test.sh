#!/bin/bash

skip=0
nostrict=0
while getopts "s:m:" arg; do
  case $arg in
    m)
      case $OPTARG in
	"nostrict")
          nostrict=1
	  echo "Mode is nostrict - will skip safety checks"
	  ;;
      esac
      ;;
    s)
      case $OPTARG in
	"stage")
	  skip=0
	  ;;
	"write")
          skip=1
	  ;;
	"drop" | "prepare")
          skip=2
	  ;;
	"read")
          skip=3
	  ;;
	"cleanup")
          skip=4
	  ;;
	"reclaim")
          skip=5
	  ;;
      esac
      echo "Skipping to step $skip: $OPTARG"
      ;;
  esac
done
shift $((OPTIND-1))

echo $@

source scripts/set_tape_test_vars.sh $@
if [ $skip -lt 1 ]; then
  source scripts/stage_files_to_eos.sh
fi
if [ $skip -lt 2 ]; then
  source scripts/wait_for_write_session.sh
fi
if [ $skip -lt 3 ]; then
  source scripts/drop_data_from_disk_and_prepare.sh
fi
if [ $skip -lt 4 ]; then
  source scripts/wait_for_read_session.sh
fi
if [ $skip -lt 5 ]; then
  source scripts/cleanup_eos_files.sh
fi
if [ $skip -lt 6 ]; then
  source scripts/reclaim_tape.sh
fi
