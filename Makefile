BINDIR := $(DESTDIR)/usr/bin
MANDIR := $(DESTDIR)/usr/share/man
DATADIR := $(DESTDIR)/usr/share/pkg-kde-tools
DATALIBDIR := $(DATADIR)/lib
PERLLIBDIR := $(DESTDIR)/$(shell perl -MConfig -e 'print $$Config{vendorlib}')

BINARIES = \
	dh_movelibkdeinit \
	dh_sameversiondep \
	dh_sodeps \
	pkgkde-debs2symbols \
	pkgkde-gensymbols \
	pkgkde-getbuildlogs \
	pkgkde-override-sc-dev-latest \
	pkgkde-symbolshelper \
	pkgkde-vcs

MANPAGES_1 = \
	man1/pkgkde-vcs.1

PERLPODS_1 = \
	pkgkde-override-sc-dev-latest \
	dh_sameversiondep \
	dh_movelibkdeinit \
	dh_sodeps

build:
	# Nothing do build

install:
	install -d $(DATADIR) $(DATALIBDIR) $(BINDIR) $(MANDIR) $(MANDIR)/man1 $(PERLLIBDIR)
	
	pod2man pkgkde-override-sc-dev-latest > $(MANDIR)/man1/pkgkde-override-sc-dev-latest.1
	install -m 0755 pkgkde-override-sc-dev-latest $(BINDIR)
	
	# Install *lib directories
	install -d $(DATALIBDIR)
	cd datalib && find . -type f -exec install -D -m 0644 {} $(DATALIBDIR)/{} \;
	install -d $(PERLLIBDIR)
	cd perllib && find . -type f -name "*.pm" -exec install -D -m 0644 {} $(PERLLIBDIR)/{} \;
	install -d $(DATADIR)/vcs
	cd vcslib && find . -type f -exec install -D -m 0644 {} $(DATADIR)/vcs/{} \;
	
	# Install binaries
	install -d $(BINDIR)
	install -m 0755 $(BINARIES) $(BINDIR)
	
	# Install manual pages
	install -d $(MANDIR)/man1
	install -m 0644 $(MANPAGES_1) $(MANDIR)/man1
	
	# Install POD based manual packages
	for f in $(PERLPODS_1); do pod2man "$$f" > "$(MANDIR)/man1/$${f%.*}.1"; done
	
	# Special overload of system dpkg-gensymbols
	install -m 0755 dpkg-gensymbols.1 $(MANDIR)/man1/pkgkde-gensymbols.1
	install -d $(DATADIR)/bin
	# Make it possible to transparently replace dpkg-gensymbols with
	# pkgkde-gensymbols
	ln -sf /usr/bin/pkgkde-gensymbols $(DATADIR)/bin/dpkg-gensymbols
