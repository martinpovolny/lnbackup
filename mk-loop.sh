umount /mnt/test_loop
dd if=/dev/zero of=/var/tmp/ln-loop.img bs=1M count=10
/sbin/mkfs.ext3 -F /var/tmp/ln-loop.img
#mount -o loop /var/tmp/ln-loop.img /mnt/test_loop
mount /mnt/test_loop
