# Standard Debian KDE 4 cmake flags
_kde4_flags := $(shell cat $(dir $(lastword $(MAKEFILE_LIST)))/kde4_flags)
DEB_CMAKE_KDE4_FLAGS += $(_kde4_flags)

# Custom KDE 4 global configuration file installation directory
ifdef DEB_CONFIG_INSTALL_DIR
    DEB_CMAKE_KDE4_FLAGS := $(filter-out -DCONFIG_INSTALL_DIR=%,$(DEB_CMAKE_KDE4_FLAGS)) \
                            -DCONFIG_INSTALL_DIR=$(DEB_CONFIG_INSTALL_DIR)
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
