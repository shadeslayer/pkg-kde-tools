PERLLIBDIR := $(shell perl -MConfig -e 'print $$Config{vendorlib}')
SYMBOLSHELPER_DIR := symbolshelper
DEBHELPER_DIR := debhelper

BINDIR := $(DESTDIR)/usr/bin
MANDIR := $(DESTDIR)/usr/share/man
#DATADIR := $(DESTDIR)/usr/share/pkg-kde-tools

build:
	# Nothing do build

install:
	install -d $(BINDIR) $(MANDIR)
	
	# symbolshelper
	cd $(SYMBOLSHELPER_DIR) && find Debian -type f -name "*.pm" -exec \
	    install -D -m 0644 {} $(DESTDIR)/$(PERLLIBDIR)/{} \;
	install -m 0755 $(SYMBOLSHELPER_DIR)/pkgkde-symbolshelper-basic $(DESTDIR)/usr/bin/pkgkde-symbolshelper
	
	# Custom debhelper commands
	install -d $(MANDIR)/man1
	pod2man $(DEBHELPER_DIR)/dh_sameversiondep > $(MANDIR)/man1/dh_sameversiondep.1
	install -m 0755 $(DEBHELPER_DIR)/dh_sameversiondep $(BINDIR)
	
	# Debhelper addons
	cd $(DEBHELPER_DIR) && find Debian -type f -name "*.pm" -exec \
	    install -D -m 0644 {} $(DESTDIR)/$(PERLLIBDIR)/{} \;
