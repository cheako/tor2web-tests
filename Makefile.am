## @start 1
## Makefile.am -- Process this file with automake to produce Makefile.in
## @end 1
## Copyright (C) 2017 Mike Mestnik
##
## This program is free software: you can redistribute it and/or modify
## it under the terms of the GNU Affero General Public License as
## published by the Free Software Foundation, either version 3 of the
## License, or (at your option) any later version.
##
## This program is distributed in the hope that it will be useful,
## but WITHOUT ANY WARRANTY; without even the implied warranty of
## MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
## GNU Affero General Public License for more details.
##
## You should have received a copy of the GNU Affero General Public License
## along with this program.  If not, see <http://www.gnu.org/licenses/>.

MAINTAINERCLEANFILES	= Makefile.in

SUBDIRS = tx

TEST_LOG_DRIVER = env AM_TAP_AWK='$(AWK)' $(SHELL) $(top_srcdir)/.tap-driver.sh
TESTS = A0socks5.t A3socks5.t Zsocks5.t
EXTRA_DIST = $(TESTS)
