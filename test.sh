dd if=/dev/zero of=test.img bs=20480 count=20480
sudo losetup -f test.img 
sudo mkfs.ext4 /dev/loop0
sudo tune2fs -L MUFF2 /dev/loop0
sudo ruby -I lib/ bin/lnbackup --test  -l /tmp/log -c ./conf.d/ -v debug --backup
