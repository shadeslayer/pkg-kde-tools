# Copyright © 2003 Colin Walters <walters@debian.org>
# Copyright © 2005-2011 Jonas Smedegaard <dr@jones.dk>
# Copyright © 2010-2011 Modestas Vainius <modax@debian.org>
# Description: Defines various random rules, including a list-missing rule
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation; either version 2, or (at
# your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

ifdef dqk_dir

list-missing:
	@if test -d debian/tmp; then \
	  echo "=== Start list-missing"; \
	  (cd debian/tmp && find . -type f -o -type l | grep -v '/DEBIAN/' | sort) > debian/dhmk-install-list; \
	  (for package in $(shell dh_listpackages); do \
	     (cd debian/$$package && find . -type f -o -type l); \
	   done; \
	   test -e debian/not-installed && grep -v '^#' debian/not-installed; \
	   ) | sort -u > debian/dhmk-package-list; \
	  diff -u debian/dhmk-install-list debian/dhmk-package-list | sed '1,2d' | egrep '^-' || true; \
	  echo "=== End list-missing"; \
	else \
	  echo "=== Start list-missing"; \
	  echo "=== End list-missing"; \
	  echo "All files were installed into debian/$(shell dh_listpackages | head -n1)."; \
	fi

check-not-installed:
	@test -e debian/not-installed && \
	(for i in $(shell grep -v '^#' debian/not-installed); do \
		test -e debian/tmp/$$i || printf "File $$i not found in debian/tmp \n"; \
	done;) \
	|| printf "ERROR: debian/not-installed not found.\n"


post_clean:
	rm -f debian/dhmk-install-list debian/dhmk-package-list

.PHONY: list-missing check-not-installed

endif
