PERLLIBDIR := $(shell perl -MConfig -e 'print $$Config{vendorlib}')
SYMBOLSHELPER_DIR := symbolshelper
DEBHELPER_DIR := debhelper
VCS_DIR := vcs

BINDIR := $(DESTDIR)/usr/bin
MANDIR := $(DESTDIR)/usr/share/man
DATADIR := $(DESTDIR)/usr/share/pkg-kde-tools

build:
	# Nothing do build

install:
	install -d $(DATADIR) $(BINDIR) $(MANDIR) $(MANDIR)/man1
	
	# symbolshelper
	cd $(SYMBOLSHELPER_DIR) && find Debian -type f -name "*.pm" -exec \
	    install -D -m 0644 {} $(DESTDIR)/$(PERLLIBDIR)/{} \;
	install -m 0755 $(SYMBOLSHELPER_DIR)/pkgkde-symbolshelper $(BINDIR)/pkgkde-symbolshelper
	install -m 0755 $(SYMBOLSHELPER_DIR)/pkgkde-debs2symbols $(BINDIR)/pkgkde-debs2symbols
	
	# Improved Dpkg::Shlibs and dpkg-gensymbols
	cd $(SYMBOLSHELPER_DIR) && find Dpkg -type f -name "*.pm" -exec \
	    install -D -m 0644 {} $(DATADIR)/{} \;
	install -m 0755 $(SYMBOLSHELPER_DIR)/pkgkde-gensymbols $(BINDIR)
	install -m 0755 $(SYMBOLSHELPER_DIR)/dpkg-gensymbols.1 $(MANDIR)/man1/pkgkde-gensymbols.1
	install -m 0755 $(SYMBOLSHELPER_DIR)/dpkg-gensymbols.pl $(DATADIR)
	install -d $(DATADIR)/bin
	# Make it possible to transparently replace dpkg-gensymbols with
	# pkgkde-gensymbols
	ln -sf /usr/bin/pkgkde-gensymbols $(DATADIR)/bin/dpkg-gensymbols
	
	# Custom debhelper commands
	pod2man $(DEBHELPER_DIR)/dh_sameversiondep > $(MANDIR)/man1/dh_sameversiondep.1
	install -m 0755 $(DEBHELPER_DIR)/dh_sameversiondep $(BINDIR)
	
	# Debhelper addons
	cd $(DEBHELPER_DIR) && find Debian -type f -name "*.pm" -exec \
	    install -D -m 0644 {} $(DESTDIR)/$(PERLLIBDIR)/{} \;
	
	# pkgkde-vcs
	install -d $(DATADIR)/vcs
	install -m 0755 $(VCS_DIR)/pkgkde-vcs $(BINDIR)
	install -m 0644 $(VCS_DIR)/pkgkde-vcs.1 $(MANDIR)/man1
	cd $(VCS_DIR)/vcslib && find . -type f -exec install -D -m 0644 {} $(DATADIR)/vcs/{} \;
