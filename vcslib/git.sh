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
    shift $(opt_till_double_dash "$@")

    local tag_path tag_msg
    is_distribution_valid || die "invalid Debian distribution for tagging - $DEB_DISTRIBUTION"
    git_is_working_tree_clean || die "working tree is dirty. Commit changes before tagging."

    tag_path="debian/`git_compat_debver $DEB_VERSION_WO_EPOCH`"
    tag_msg="$DEB_VERSION $DEB_DISTRIBUTION; urgency=$DEB_URGENCY"

    runcmd git tag $tag_path -m "$tag_msg" "$@"
}

git_clone()
{
    local url pushurl
    url="git://git.debian.org/pkg-kde"
    pushurl="git.debian.org:/git/pkg-kde"

    # Parse remaining command line (or -- if any) options
    local name
    while getopts ":u:p:" name; do
        case "$name" in
            u) url="$OPTARG" ;;
            p) pushurl="$OPTARG";;
            ?)  if [ -n "$OPTARG" ]; then OPTIND=$(($OPTIND-1)); fi; break;;
            :)  die "$OPTARG option is missing a required argument" ;;
        esac
    done
    if [ "$OPTIND" -gt 1 ]; then
        shift "$(($OPTIND-1))"
    fi

    local repo dir
    repo="${1%.git}"
    dir="`dirname "$repo"`"
    shift 1 # Shift repo

    shift $(opt_till_double_dash "$@")

    url="${url}/${repo}.git"
    pushurl="${pushurl}/${repo}.git"

    if [ -d "$repo" ]; then
        die "$repo repository already exists locally"
    fi
    if [ ! -d "$dir" ]; then
        die "repository parent directory $dir does not exist on the local filesystem. Create it"
    fi

    info "Cloning $url (pushurl: $pushurl)"
    runcmd git clone "$@" -- "$url" "$repo"

    info "Updating configuration of the new repository"
    cd "$repo"
    runcmd git config remote.origin.pushurl "$pushurl"

    git_update_config
}

git_update_config()
{
    local force

    # Parse remaining command line (or -- if any) options
    local name
    while getopts ":f" name; do
        case "$name" in
            f) force="y";;
            ?)  if [ -n "$OPTARG" ]; then OPTIND=$(($OPTIND-1)); fi; break;;
            :)  die "$OPTARG option is missing a required argument" ;;
        esac
    done
    if [ "$OPTIND" -gt 1 ]; then
        shift "$(($OPTIND-1))"
    fi

    if [ -n "$force" ] || ! git config --get-all remote.origin.push "$@" > /dev/null; then
        info "[ok] Setting up repository to push master and debian tags by default."
        runcmd git config --replace-all remote.origin.push "refs/heads/master"
        runcmd git config --add remote.origin.push "refs/tags/debian/*"
    else
        info "[skip] Push specs already present."
    fi

    if [ -n "$DEBFULLNAME" ]; then
        if [ "$force" = "y" ] || ! git config --file=.git/config --get "user.name" "$@" >/dev/null 2>&1; then
            info "[ok] Setting user.name to the value of the DEBFULLNAME environment variable: $DEBFULLNAME."
            runcmd git config user.name "$DEBFULLNAME"
        else
            info "[skip] user.name configuration option is already set"
        fi
    else
        info "[skip] DEBFULLNAME environment variable is not set. Not setting user.name."
    fi

    if [ -n "$DEBEMAIL" ]; then
        if [ "$force" = "y" ] || ! git config --file=.git/config --get "user.email" "$@" >/dev/null 2>&1; then
            info "[ok] Setting user.email to the value of the DEBEMAIL environment variable: $DEBEMAIL."
            runcmd git config user.email "$DEBEMAIL"
        else
            info "[skip] user.email configuration option is already set"
        fi
    else
        info "[skip] DEBEMAIL environment variable is not set. Not setting user.email."
    fi
}

git_compat_debver()
{
    echo "$1" | tr "~" "-"
}

git_is_working_tree_clean()
{
    git update-index --refresh > /dev/null && git diff-index --quiet HEAD
}

# Get subcommand name
test "$#" -gt 0  || die "subcommand is NOT specified"
subcmd="$1"; shift

subcmd_needs_package_root="1"
if [ "$subcmd" = "clone" ]; then
    subcmd_needs_package_root=""
fi

# Do some envinronment sanity checks first
git_is_bare="$(git rev-parse --is-bare-repository 2>/dev/null)"
if [ "$?" -eq 0 ]; then
    if [ "$git_is_bare" = "true" ]; then
        die "bare Git repositories are not supported."
    fi

    PACKAGE_ROOT="$(readlink -f "$(git rev-parse --git-dir)/..")"

    if [ -z "$subcmd_needs_package_root" ]; then
        is_valid_package_root "$PACKAGE_ROOT" &&
            die "$subcmd should not be executed inside a valid debian packaging repository"
    else
        is_valid_package_root "$PACKAGE_ROOT" ||
            die "$PACKAGE_ROOT does NOT appear to be a valid debian packaging repository"

        # Get info about debian package
        get_debian_package_info "$PACKAGE_ROOT"
    fi
else
    if [ -n "$subcmd_needs_package_root" ]; then
        die "$subcmd should be executed inside a valid debian packaging git repository"
    fi
fi

# Execute subcommand
case "$subcmd" in
    tag)
        git_tag "$@"
        ;;
    clone)
        git_clone "$@"
        ;;
    update_config|update-config)
        git_update_config "$@"
        ;;
    *)
        die "unsupported pkgkde-vcs Git subcommand: $subcmd. Commands available: clone, tag, update-config"
        ;;
esac

exit 0
