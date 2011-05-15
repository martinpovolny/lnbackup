build-stamp:
clean:
install:
	cp lnbackup.rb root/usr/sbin/lnbackup
	#cp conf.d/{00global,01localhost,30windows,09pcb} root/etc/lnbackup.d/
	cp conf.d/00global root/etc/lnbackup.d/
	cp conf.d/01localhost root/etc/lnbackup.d/
	cp conf.d/30windows root/etc/lnbackup.d/
	cp conf.d/09pcb root/etc/lnbackup.d/
	@echo installing data to the dir: '$(DESTDIR)'
	if [ -n "$(DESTDIR)" ] ; then cp -a root/* "$(DESTDIR)" ; fi
