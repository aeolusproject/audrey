%define app_root %{_datadir}/%{name}

Name:		aeolus-configserver
Version:	@VERSION@
Release:	1%{?dist}%{?extra_release}
Summary:	The Aeolus Config Server

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
Requires(post): chkconfig
Requires(prerun): chkconfig
Requires(prerun): initscripts



%description
The Aeolus Config Server, a service for storing and retrieving VM
configurations.

%prep
%setup -q


#%build


%install
rm -rf $RPM_BUILD_ROOT
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


%changelog
* Fri Apr 09 2011 Greg Blomquist <gblomqui@redhat.com> 0.1.0-1
- Now supporting multi-instance configuration
* Thu Mar 24 2011 Greg Blomquist <gblmoqui@redhat.com> 0.0.2-2
- Added Nokogiri dependency
* Thu Mar 24 2011 Greg Blomquist <gblmoqui@redhat.com> 0.0.2-1
- Version bump for major functionality implementation
* Wed Mar 16 2011 Greg Blomquist <gblmoqui@redhat.com> 0.0.1-1
- Initial spec
