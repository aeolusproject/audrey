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

AUDREY_STARTUP_CACHE_DIR	?= $(HOME)/audrey-agent-cache

VERSION = 0.4.0

# For Release: 0..., set _audrey-agent_dev=1 so that we get extra_release.GIT-
# annotated rpm version strings.
_audrey-agent_dev =  $(shell grep -q '^[[:space:]]*Release:[[:space:]]*0' \
   aeolus-audrey-agent.spec.in && echo 1 || :)

# use $(shell...) here to collect the git head and date *once* per make target.
# that ensures that if multiple actions happen in the same target (like the
# multiple RPM builds in the rpms target), they all use the same date
git_head	= $(shell git log -1 --pretty=format:%h)
date		= $(shell date --utc +%Y%m%d%H%M%S)
GIT_RELEASE	= $(date)git$(git_head)
RPMDIR		= $$(rpm --eval '%{_rpmdir}')
RELEASE		= $(shell grep ^Release: aeolus-audrey-agent.spec.in | \
			sed -e 's/Release:[ ,	]*//' | sed -e 's/%.*//')
# RPM_FLAGS	= --define "audrey-agent_cache_dir $(AUDREY_STARTUP_CACHE_DIR)"
# RPM_FLAGS	+= $(if $(_audrey-agent_dev),--define "extra_release .$(GIT_RELEASE)")
man_section = 8

dist: audrey.$(man_section)
	sed -e 's/@VERSION@/$(VERSION)/' aeolus-audrey-agent.spec.in > aeolus-audrey-agent.spec
	sed -e 's/@VERSION@/$(VERSION).$(RELEASE)/' audrey_startup.in.py > audrey_startup.py
	mkdir -p dist/aeolus-audrey-agent-$(VERSION)
	cp -a aeolus-audrey-agent.spec COPYING Makefile audrey_startup.py \
                audrey.$(man_section) \
		test_audrey_startup.py dist/aeolus-audrey-agent-$(VERSION)
	tar -C dist -zcvf aeolus-audrey-agent-$(VERSION).tar.gz aeolus-audrey-agent-$(VERSION)
	
audrey: audrey_startup.in.py
	cp $< $@

audrey.$(man_section): audrey
	help2man --name='Aeolus startup agent' --section $(man_section) \
	    --no-discard-stderr --no-info \
	  ./$< > $@-t
	mv $@-t $@

check:
	python test_audrey_startup.py

rpms: check dist
	rpmbuild -ta aeolus-audrey-agent-$(VERSION).tar.gz

srpms: check dist
	rpmbuild -ts aeolus-audrey-agent-$(VERSION).tar.gz

clean:
	rm -rf dist aeolus-audrey-agent-$(VERSION).tar.gz \
	aeolus-audrey-agent.spec audrey.$(man_section) audrey \
	audrey.log audrey_startup.py audrey_startup.pyc \
	test_toolinglog test_toolinguser \
	toolinglog toolinguser

.PHONY: dist check rpms srpms
