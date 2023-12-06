/eos/ctaeos/cta/sfa_test/l2s/8000000/83/0/random_428
file_size=$1
eosfile=$2

dd_max_bs=1000000 # 1M
dd_bs=$( (( $dd_max_bs <= $file_size )) && echo "$dd_max_bs" || echo "$file_size" )
blocks_per_file=$((file_size/dd_bs))
dd_count=$( (( $blocks_per_file <= 1 )) && echo "1" || echo "$blocks_per_file")

tmpfile=/mnt/sfa_test_filespace/rand_regen_$file_size_$$
eos rm $eosfile
dd if=/dev/urandom of=$tmpfile bs=$dd_bs count=$dd_count
XrdSecPROTOCOL=sss XrdSecSSSKT=/etc/cta/eos.sss.keytab runuser -u cta eos cp $tmpfile $eosfile
rm $tmpfile

echo $(eos ls -y $eosfile)
