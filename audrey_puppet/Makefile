# Copyright (C) 2011 Red Hat, Inc.
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; version 2 of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
# MA  02110-1301, USA.  A copy of the GNU General Public License is
# also available at http://www.gnu.org/copyleft/gpl.html.

AUDREY_PUPPET_CACHE_DIR	?= $(HOME)/audrey_puppet-cache

VERSION = 0.3.0

# For Release: 0..., set _audrey_puppet_dev=1 so that we get extra_release.GIT-
# annotated rpm version strings.
_audrey_puppet_dev =  $(shell grep -q '^[[:space:]]*Release:[[:space:]]*0' \
   aeolus-audrey_puppet.spec.in && echo 1 || :)

# use $(shell...) here to collect the git head and date *once* per make target.
# that ensures that if multiple actions happen in the same target (like the
# multiple RPM builds in the rpms target), they all use the same date
git_head	= $(shell git log -1 --pretty=format:%h)
date		= $(shell date --utc +%Y%m%d%H%M%S)
GIT_RELEASE	= $(date)git$(git_head)
RPMDIR		= $$(rpm --eval '%{_rpmdir}')
# RPM_FLAGS	= --define "audrey_puppet_cache_dir $(AUDREY_PUPPET_CACHE_DIR)"
# RPM_FLAGS	+= $(if $(_audrey_puppet_dev),--define "extra_release .$(GIT_RELEASE)")

dist:
	sed -e 's/@VERSION@/$(VERSION)/' aeolus-audrey_puppet.spec.in > aeolus-audrey_puppet.spec
	mkdir -p dist/aeolus-audrey_puppet-$(VERSION)
	cp -a aeolus-audrey_puppet.spec COPYING Makefile modules nodes run manifests node \
		dist/aeolus-audrey_puppet-$(VERSION)
	tar -C dist -zcvf aeolus-audrey_puppet-$(VERSION).tar.gz aeolus-audrey_puppet-$(VERSION)

rpms: dist
	rpmbuild -ta aeolus-audrey_puppet-$(VERSION).tar.gz

srpms: dist
	rpmbuild -ts aeolus-audrey_puppet-$(VERSION).tar.gz

clean:
	rm -rf dist aeolus-audrey_puppet-$(VERSION).tar.gz aeolus-audrey_puppet.spec

.PHONY: dist rpms srpms
