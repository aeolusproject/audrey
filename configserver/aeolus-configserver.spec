%define app_root %{_datadir}/%{name}

Name:		aeolus-configserver
Version:	@VERSION@
Release:	5%{?extra_release}%{?dist}
Summary:	The Aeolus Config Server
BuildArch:  noarch

Group:		Applications/System
License:	GPLv2+ and MIT and BSD
URL:		http://aeolusproject.org
Source0:	aeolus-configserver-%{version}.tgz
BuildRoot:	%(mktemp -ud %{_tmppath}/%{name}-%{version}-%{release}-XXXXXX)

BuildRequires:	ruby
BuildRequires:	ruby-devel
Requires:	    ruby >= 1.8.1
Requires:       ruby-nokogiri
Requires:       rubygem(sinatra)
Requires:       rubygem(thin)
requires:       rubygem(archive-tar-minitar)
requires:       rubygem(activesupport)
Requires(post): chkconfig
Requires(preun): chkconfig
Requires(preun): initscripts


%description
The Aeolus Config Server, a service for storing and retrieving VM
configurations.

##
## aeolus-configserver-proxy package
##
%package proxy
Summary:    Proxy support for Aeolus Config Server
Group:      Application/System
Requires:   aeolus-configserver
Requires:   httpd
Requires:   mod_ssl
Requires:   puppet
License:    GPLv2+ and MIT and BSD
URL:        http://aeolusproject.org

%description proxy
The Aeolus Config Server proxy provides a script to configure ProxyPass, SSL
Termination, and Basic Authentication.

%prep
%setup -q

#%build

%install
rm -rf $RPM_BUILD_ROOT

##
# aeolus-configserver
##
%{__mkdir} -p %{buildroot}
%{__mkdir} -p %{buildroot}%{app_root}
%{__mkdir} -p %{buildroot}%{_initrddir}
%{__mkdir} -p %{buildroot}%{_sysconfdir}/sysconfig
%{__mkdir} -p %{buildroot}%{_sysconfdir}/%{name}
%{__mkdir} -p %{buildroot}%{_localstatedir}/lib/%{name}/schema
%{__mkdir} -p %{buildroot}%{_localstatedir}/log/%{name}
%{__mkdir} -p %{buildroot}%{_localstatedir}/run/%{name}

# copy over all of the src directory...
%{__cp} -R src/* %{buildroot}/%{app_root}

# copy init script and configs
%{__cp} conf/%{name} %{buildroot}/%{_initrddir}
%{__cp} conf/%{name}.sysconf %{buildroot}%{_sysconfdir}/sysconfig/%{name}

# copy relaxNG schema files
%{__cp} schema/*.rng %{buildroot}%{_localstatedir}/lib/%{name}/schema/

##
# proxy
##
%{__mkdir} -p %{buildroot}%{app_root}/configure
%{__mkdir} -p %{buildroot}%{_bindir}

# copy over all puppet scripts and bin files
%{__cp} -R configure/puppet %{buildroot}%{app_root}/configure/
%{__cp} configure/bin/config_httpd.sh %{buildroot}%{_bindir}/aeolus-configserver-setup-httpd
%{__cp} conf/%{name}-proxy.sysconf %{buildroot}%{_sysconfdir}/sysconfig/%{name}-proxy


%clean
rm -rf $RPM_BUILD_ROOT

%pre
# Ensure the aeolus user/group is created (same IDs as in aeolus-conductor)
getent group aeolus >/dev/null || \
    /usr/sbin/groupadd -g 451 -r aeolus 2>/dev/null || :
getent passwd aeolus >/dev/null || \
    /usr/sbin/useradd -u 451 -g aeolus -c "aeolus" \
    -s /sbin/nologin -r -d /var/aeolus aeolus 2> /dev/null || :

%post
# Register the service
/sbin/chkconfig --add %{name}

%preun
# stop and unregister the service before package deletion
if [ $1 = 0 ]; then
/sbin/service %{name} stop > /dev/null 2>&1
/sbin/chkconfig --del %{name}
fi


%files
%defattr(-,root,root,-)
%{app_root}
%dir %{_sysconfdir}/%{name}
%{_initrddir}/%{name}
%config(noreplace) %{_sysconfdir}/sysconfig/%{name}
%attr(-, aeolus, aeolus) %{_localstatedir}/lib/%{name}
%attr(-, aeolus, aeolus) %{_localstatedir}/run/%{name}
%attr(-, aeolus, aeolus) %{_localstatedir}/log/%{name}
%doc COPYING

%files proxy
%defattr(-, root, root, -)
%{_bindir}/aeolus-configserver-setup-httpd
%{_sysconfdir}/sysconfig/%{name}-proxy
%{app_root}/configure


%changelog
* Tue Oct 25 2011 Greg Blomquist <gblomqui@redhat.com> 0.2.3-5
- Explicitly require mod_ssl for proxy package
* Wed Oct 05 2011 Greg Blomquist <gblomqui@redhat.com> 0.2.3-4
- Fix rakefile to build on f16, and fixup extrarelease and dist tags in the version
* Wed Sep 07 2011 Greg Blomquist <gblomqui@redhat.com> 0.2.3-3
- Fix service to return 202 when configs are not complete
* Thu Aug 18 2011 Greg Blomquist <gblomqui@redhat.com> 0.2.3-2
- Fix syntax in spec
* Tue Aug 16 2011 Greg Blomquist <gblomqui@redhat.com> 0.2.3-1
- Updated data format for Config Server -> Audrey client API
* Wed Jul 27 2011 Greg Blomquist <gblomqui@redhat.com> 0.2.2-3
- Ability to read tarball from instance-config
- Added minitar dependency
* Tue Jul 12 2011 Greg Blomquist <gblomqui@redhat.com> 0.2.1-5
- Adding ability to upload and download a tarball for instances
* Mon Jun 27 2011 Greg Blomquist <gblomqui@redhat.com> 0.2.0-1
- Add the "proxy" sub-package
* Thu May 26 2011 Greg Blomquist <gblomqui@redhat.com> 0.1.2-2
- Kludge release that allows guests to PUT to invalid UUIDs (RHEV-M)
* Mon May 09 2011 Greg Blomquist <gblomqui@redhat.com> 0.1.2-1
- Fixed POST bug that allowed POSTing no data
* Wed May 04 2011 Greg Blomquist <gblomqui@redhat.com> 0.1.1-3
- Fixed IP storage bugs
* Wed May 04 2011 Greg Blomquist <gblomqui@redhat.com> 0.1.1-2
- Removed arch requirement from rpm spec
* Wed May 04 2011 Greg Blomquist <gblomqui@redhat.com> 0.1.1-1
- Storing IP address of instances that check-in
* Fri Apr 09 2011 Greg Blomquist <gblomqui@redhat.com> 0.1.0-1
- Now supporting multi-instance configuration
* Thu Mar 24 2011 Greg Blomquist <gblmoqui@redhat.com> 0.0.2-2
- Added Nokogiri dependency
* Thu Mar 24 2011 Greg Blomquist <gblmoqui@redhat.com> 0.0.2-1
- Version bump for major functionality implementation
* Wed Mar 16 2011 Greg Blomquist <gblmoqui@redhat.com> 0.0.1-1
- Initial spec
