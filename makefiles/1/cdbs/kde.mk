include /usr/share/cdbs/1/class/cmake.mk

# Include default KDE 4 cmake configuration variables
include /usr/share/pkg-kde-tools/makefiles/1/variables.mk
# Pass standard KDE 4 flags to cmake via appropriate CDBS variable
DEB_CMAKE_EXTRA_FLAGS += $(DEB_CMAKE_KDE4_FLAGS) $(DEB_CMAKE_CUSTOM_FLAGS)

DEB_COMPRESS_EXCLUDE = .dcl .docbook -license .tag .sty .el

DEB_DH_MAKESHLIBS_ARGS += -Xusr/lib/kde4/

# Skip RPATH if kdelibs5-dev is older than 4:4.4.0
DEB_KDELIBS5_DEV_VER := $(shell dpkg-query -f='$${Version}\n' -W kdelibs5-dev 2>/dev/null)
DEB_KDELIBS5_DEV_VER_OLD := $(shell dpkg --compare-versions $(DEB_KDELIBS5_DEV_VER) lt 4:4.4.0 2>/dev/null && echo yes)
ifeq (yes,$(DEB_KDELIBS5_DEV_VER_OLD))
    DEB_CMAKE_KDE4_FLAGS += -DCMAKE_SKIP_RPATH:BOOL=ON
endif

$(patsubst %,binary-post-install/%,$(DEB_ARCH_PACKAGES)) :: binary-post-install/%:
	dh_movelibkdeinit -p$(cdbs_curpkg) $(DEB_DH_MOVELIBKDEINIT_ARGS)
