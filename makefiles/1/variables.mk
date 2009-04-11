# KDE 4 global configuration file installation directory
DEB_CONFIG_INSTALL_DIR ?= /usr/share/kde4/config

# Standard Debian KDE 4 cmake flags
DEB_CMAKE_KDE4_FLAGS += \
        -DCMAKE_BUILD_TYPE=Debian \
        -DKDE4_BUILD_TESTS=false \
        -DKDE_DISTRIBUTION_TEXT="Debian packages" \
        -DCMAKE_SKIP_RPATH=true \
        -DKDE4_USE_ALWAYS_FULL_RPATH=false \
        -DCONFIG_INSTALL_DIR=$(DEB_CONFIG_INSTALL_DIR) \
        -DDATA_INSTALL_DIR=/usr/share/kde4/apps \
        -DHTML_INSTALL_DIR=/usr/share/doc/kde4/HTML \
        -DKCFG_INSTALL_DIR=/usr/share/kde4/config.kcfg \
        -DLIB_INSTALL_DIR=/usr/lib \
        -DSYSCONF_INSTALL_DIR=/etc

# Set the DEB_KDE_LINK_WITH_AS_NEEDED to 'yes' to enable linking
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
