PERLLIBDIR := $(shell perl -MConfig -e 'print $$Config{vendorlib}')
SYMBOLSHELPER_DIR := symbolshelper

install:
	install -d $(DESTDIR)/usr/bin
	cd $(SYMBOLSHELPER_DIR) && find Debian -type f -name "*.pm" -exec \
	    install -D -m 0644 {} $(DESTDIR)/$(PERLLIBDIR)/{} \;
	install -m 0755 $(SYMBOLSHELPER_DIR)/pkgkde-symbolshelper $(DESTDIR)/usr/bin
