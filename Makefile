build-stamp:
clean:
install:
	@echo installing data to the dir: '$(DESTDIR)'
	mkdir -p $(DESTDIR)/etc/lnbackup.d/
	cp conf.d/00global 	  $(DESTDIR)/etc/lnbackup.d/
	cp conf.d/01localhost $(DESTDIR)/etc/lnbackup.d/
	cp conf.d/30windows   $(DESTDIR)/etc/lnbackup.d/
	cp conf.d/09pcb 	  $(DESTDIR)/etc/lnbackup.d/
	mkdir -p $(DESTDIR)/usr/bin
	cp bin/* 	  		  $(DESTDIR)/usr/bin/
	mkdir -p $(DESTDIR)/usr/lib/ruby/1.8/
	cp -r lib/*  		  $(DESTDIR)/usr/lib/ruby/1.8/
