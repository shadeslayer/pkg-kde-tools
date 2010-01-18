use constant PKGKDE_BINDIR => '/usr/share/pkg-kde-tools/bin';

# Add /usr/share/pkg-kde-tools/bin to $PATH
if (! grep { PKGKDE_BINDIR eq $_ } split(":", $ENV{PATH})) {
    $ENV{PATH} = PKGKDE_BINDIR . ":" . $ENV{PATH};
}

1;
