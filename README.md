# Aeolus Audrey
This is the Aeolus Audrey code, of which there are two parts:
* The Config Server
* The Audrey Start Agent

The Config Server runs in conjunction with the Aeolus Conductor. It
makes tooling and parameters available to launching instances and
coordinates the sharing of parameters between multiple launching
instances.

The Audrey Start Agent, if built into an image, is invoked at launch
time via rc.local, contacts the Config Server, accepts available
tooling and parameters and returns values for requested parameters.
To do the the Audrey Start Agent invokes the tooling, passing it
the parameters. Currently Puppet Facter is used to gather values
for the requested parameters.

## Licensing
This code is licensed under Apache License ASL2.0 See the COPYING
files in the source tree for terms and conditions for use.

## Developer Contact Information
Mailing list: aeolus-devel@fedorahosted.org
Project web site: https://www.aeolusproject.org/audrey.html
Bug tracker: https://bugzilla.redhat.com/

Required to build: <code>help2man</code>

Summary of how to build the software:

    % cd <repo>/agent
    % make rpms
    % cd <repo>/configserver
    % rake rpm
