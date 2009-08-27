# Include default KDE 4 cmake configuration variables
include /usr/share/pkg-kde-tools/makefiles/1/variables.mk

# Check if debhelper (>= 7.3) is installed
DEB_DH_VERSION := $(shell perl -MDebian::Debhelper::Dh_Version -e \
    'my $$v=$$Debian::Debhelper::Dh_Version::version;\
     my @v=split(/\./,$$v); \
     print (($$v[0]>7 || $$v[0]==7 && $$v[1]>=3) ? "ok" : $$v), "\n";' 2>/dev/null)
ifneq ($(DEB_DH_VERSION),ok)
    $(error Debhelper is too old ($(DEB_DH_VERSION)) on your system. Upgrade to 7.3.0 or later)
endif

$(warning This kde.mk make snippet is deprecated. Please use kde sequence addon and/or kde buildsystem)

# Configure with KDE cmake flags by default.
DEB_KDE_OVERRIDE_DH_AUTO_CONFIGURE ?= override_dh_auto_configure
$(DEB_KDE_OVERRIDE_DH_AUTO_CONFIGURE):
	dh_auto_configure -- $(DEB_CMAKE_KDE4_FLAGS) $(DEB_CMAKE_CUSTOM_FLAGS)

%:
	dh $@
