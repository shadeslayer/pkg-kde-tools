# Standard Debian KDE 4 cmake flags
_kde4_flags := $(shell cat $(dir $(lastword $(MAKEFILE_LIST)))../../lib/kde4_flags)
DEB_CMAKE_KDE4_FLAGS += $(_kde4_flags)

# Custom KDE 4 global configuration file installation directory
ifdef DEB_CONFIG_INSTALL_DIR
    DEB_CMAKE_KDE4_FLAGS := $(filter-out -DCONFIG_INSTALL_DIR=%,$(DEB_CMAKE_KDE4_FLAGS)) \
                            -DCONFIG_INSTALL_DIR=$(DEB_CONFIG_INSTALL_DIR)
endif

# Skip RPATH if kdelibs5-dev is older than 4:4.4.0
DEB_KDELIBS5_DEV_VER := $(shell dpkg-query -f='$${Version}\n' -W kdelibs5-dev 2>/dev/null)
DEB_KDELIBS5_DEV_VER_OLD := $(shell dpkg --compare-versions $(DEB_KDELIBS5_DEV_VER) lt 4:4.4.0 2>/dev/null && echo yes)
ifeq (yes,$(DEB_KDELIBS5_DEV_VER_OLD))
    DEB_CMAKE_KDE4_FLAGS += -DCMAKE_SKIP_RPATH:BOOL=ON
endif

# Set the DEB_KDE_LINK_WITH_AS_NEEDED to yes to enable linking
# with --as-needed (off by default)
DEB_KDE_LINK_WITH_AS_NEEDED ?= no
ifneq (,$(findstring yes, $(DEB_KDE_LINK_WITH_AS_NEEDED)))
    ifeq (,$(findstring no-as-needed, $(DEB_BUILD_OPTIONS)))
        DEB_KDE_LINK_WITH_AS_NEEDED := yes
        DEB_CMAKE_CUSTOM_FLAGS += \
            -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--no-undefined -Wl,--as-needed" \
            -DCMAKE_MODULE_LINKER_FLAGS="-Wl,--no-undefined -Wl,--as-needed" \
            -DCMAKE_EXE_LINKER_FLAGS="-Wl,--no-undefined -Wl,--as-needed"
    else
        DEB_KDE_LINK_WITH_AS_NEEDED := no
    endif
else
    DEB_KDE_LINK_WITH_AS_NEEDED := no
endif
