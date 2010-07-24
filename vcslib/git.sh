# Copyright (C) 2009 Modestas Vainius <modax@debian.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>
# Tag debian package release

# Git library for pkgkde-vcs

git_tag()
{
    local tag_path tag_msg

    is_distribution_valid || die "invalid Debian distribution for tagging - $DEB_DISTRIBUTION"
    git_is_working_tree_clean || die "working tree is dirty. Commit changes before tagging."

    tag_path="debian/`git_compat_debver $DEB_VERSION_WO_EPOCH`"
    tag_msg="$DEB_VERSION $DEB_DISTRIBUTION; urgency=$DEB_URGENCY"

    runcmd git tag $tag_path -m "$tag_msg" "$@"
}

git_compat_debver()
{
    echo "$1" | tr "~" "-"
}

git_is_working_tree_clean()
{
    git update-index --refresh > /dev/null && git diff-index --quiet HEAD
}


PACKAGE_ROOT="$(readlink -f "$(git rev-parse --git-dir)/..")"

# Do some envinronment sanity checks first
if [ "$(git rev-parse --is-bare-repository)" = "true" ]; then
    die "bare Git repositories are not supported."
fi

is_valid_package_root "$PACKAGE_ROOT" || 
    die "$PACKAGE_ROOT does NOT appear to be a a valid debian packaging repository"

# Get subcommand name
test "$#" -gt 0  || die "subcommand is NOT specified"
subcmd="$1"; shift

# Get info about debian package
get_debian_package_info "$PACKAGE_ROOT"

# Parse remaining command line (or -- if any) options
while getopts ":" name; do
    case "$name" in
        ?)  if [ -n "$OPTARG" ]; then OPTIND=$(($OPTIND-1)); fi; break;;
        :)  die "$OPTARG option is missing a required argument" ;;
    esac
done

if [ "$OPTIND" -gt 1 ]; then
    shift "$(($OPTIND-1))"
fi

# Execute subcommand
case "$subcmd" in
    tag)
        git_tag "$@"
        ;;
    *)
        die "unsupported pkgkde-vcs Git subcommand: $subcmd"
        ;;
esac

exit 0
