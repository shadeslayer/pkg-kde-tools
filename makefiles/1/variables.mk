# KDE 4 global configuration file installation directory
DEB_CONFIG_INSTALL_DIR ?= /usr/share/kde4/config

# Standard Debian KDE 4 cmake flags
DEB_CMAKE_KDE4_FLAGS += \
        -DCMAKE_BUILD_TYPE=Debian \
        -DKDE4_ENABLE_FINAL=$(KDE4-ENABLE-FINAL) \
        -DKDE4_BUILD_TESTS=false \
        -DKDE_DISTRIBUTION_TEXT="Debian packages" \
        -DKDE_DEFAULT_HOME=.kde4 \
        -DCMAKE_SKIP_RPATH=true \
        -DKDE4_USE_ALWAYS_FULL_RPATH=false \
        -DCONFIG_INSTALL_DIR=$(DEB_CONFIG_INSTALL_DIR) \
        -DDATA_INSTALL_DIR=/usr/share/kde4/apps \
        -DHTML_INSTALL_DIR=/usr/share/doc/kde4/HTML \
        -DKCFG_INSTALL_DIR=/usr/share/kde4/config.kcfg \
        -DLIB_INSTALL_DIR=/usr/lib \
        -DSYSCONF_INSTALL_DIR=/etc
