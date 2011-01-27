define configure_commands
	dh_testdir
	dh_auto_configure
endef

define build_commands
	dh_testdir
	dh_auto_build
	dh_auto_test
endef

define clean_commands
	dh_testdir
	dh_auto_clean
	dh_clean
endef

define install_commands
	dh_testroot
	dh_prep
	dh_installdirs
	dh_auto_install

	dh_install
	dh_installdocs
	dh_installchangelogs
	dh_installexamples
	dh_installman

	dh_installcatalogs
	dh_installcron
	dh_installdebconf
	dh_installemacsen
	dh_installifupdown
	dh_installinfo
	dh_installinit
	dh_installmenu
	dh_installmime
	dh_installmodules
	dh_installlogcheck
	dh_installlogrotate
	dh_installpam
	dh_installppp
	dh_installudev
	dh_installwm
	dh_installxfonts
	dh_bugfiles
	dh_lintian
	dh_gconf
	dh_icons
	dh_perl
	dh_usrlocal

	dh_link
	dh_compress
	dh_fixperms
endef

define binary-indep_commands
	dh_installdeb
	dh_gencontrol
	dh_md5sums
	dh_builddeb
endef

define binary-arch_commands
	dh_strip
	dh_makeshlibs
	dh_shlibdeps
    $(binary-indep_commands)
endef

define binary_commands
    $(binary-arch_commands)
endef
