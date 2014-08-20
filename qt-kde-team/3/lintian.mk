# Copyright © 2013 Philip Muskovac <yofel@kubuntu.org>
# Description: Defines a lintian rule that prints the lintian messages.
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

lintian:
	dpkg-genchanges > ../.pkg-kde-lintian.changes
	@echo "=== Start lintian"
	@-lintian ../.pkg-kde-lintian.changes
	@echo "=== End lintian"
	rm ../.pkg-kde-lintian.changes

.PHONY: lintian

endif
