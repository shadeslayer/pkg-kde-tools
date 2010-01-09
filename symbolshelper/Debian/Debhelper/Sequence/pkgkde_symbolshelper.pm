use constant PKGKDE_BINDIR => '/usr/share/pkg-kde-tools/bin';

# Add /usr/share/pkg-kde-tools/bin to $PATH
if (! grep { PKGKDE_BINDIR eq $_ } split(":", $ENV{PATH})) {
    $ENV{PATH} = PKGKDE_BINDIR . ":" . $ENV{PATH};
}

insert_before("dh_makeshlibs", "dh_pkgkde-symbolshelper_symbolfile");
insert_after("dh_clean", "dh_pkgkde-symbolshelper_clean");

1;
