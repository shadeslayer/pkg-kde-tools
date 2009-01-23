PERLLIBDIR := $(shell perl -MConfig -e 'print $$Config{vendorlib}')
SYMBOLSHELPER_DIR := symbolshelper

BINDIR := $(DESTDIR)/usr/bin
MANDIR := $(DESTDIR)/usr/share/man

install:
	install -d $(BINDIR) $(MANDIR)
	
	# symbolshelper
	cd $(SYMBOLSHELPER_DIR) && find Debian -type f -name "*.pm" -exec \
	    install -D -m 0644 {} $(DESTDIR)/$(PERLLIBDIR)/{} \;
	install -m 0755 $(SYMBOLSHELPER_DIR)/pkgkde-symbolshelper $(DESTDIR)/usr/bin
	
	# dh_sameversiondep
	install -d $(MANDIR)/man1
	pod2man dh_sameversiondep > $(MANDIR)/man1/dh_sameversiondep.1
	install -m 0755 dh_sameversiondep $(BINDIR)
