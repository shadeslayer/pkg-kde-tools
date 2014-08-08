{
    package Debian::Debhelper::Sequence::kf5;
    use Debian::Debhelper::Dh_Version;
    use Debian::Debhelper::Dh_Lib qw(error);

    sub ensure_debhelper_version {
        my @v = split(/\./, $Debian::Debhelper::Dh_Version::version);
        if ($v[0] > $_[0]) {
            return 1;
        }
        elsif ($v[0] == $_[0]) {
            if ($v[1] > $_[1]) {
                return 1;
            }
            elsif ($v[1] == $_[1]) {
                return $1 >= $_[2] if ($v[2] =~ /^(\d+)/);
            }
        }
        return 0;
    }
    unless (ensure_debhelper_version(7, 3, 16)) {
        error "debhelper addon 'kf5' requires debhelper 7.3.16 or later";
    }

    1;
}

# Build with kf5 buildsystem by default
add_command_options("dh_auto_configure", "--buildsystem=kf5");
add_command_options("dh_auto_build", "--buildsystem=kf5");
add_command_options("dh_auto_test", "--buildsystem=kf5");
add_command_options("dh_auto_install", "--buildsystem=kf5");
add_command_options("dh_auto_clean", "--buildsystem=kf5");

# Omit libkdeinit5_* from dh_makeshlibs by default
add_command_options("dh_makeshlibs", "-Xusr/lib/libkdeinit5_*");

# Exclude kf5 documentation from dh_compress by default
add_command_options("dh_compress",
    qw(-X.dcl -X.docbook -X-license -X.tag -X.sty -X.el));

insert_after("dh_install", "dh_movelibkdeinit");

1;
