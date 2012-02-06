# SSH Pub Key Example #

The purpose of this example is to demonstrate how to use Audrey to inject a
public key file into guests.

## Example walkthrough ##

The example uses the following deployable XML file:

    <deployable version="1.0" name="ssh-pubkey-example">
      <description>
        An example to demonstrate configuring a guest for public key
        authentication by injecting a public key into the
        authorized_keys file for root.
      </description>
      <assemblies>
        <assembly name="Instance-1" hwp="large">
          <image id="INSERT IMAGE ID"/>
          <services>
            <service name="install-pubkey">
              <executable>
                <contents><![CDATA[#!/bin/bash
                  mkdir -p /root/.ssh
                  cat pubkey >> /root/.ssh/authorized_keys]]>
                </contents>
              </executable>
              <files>
                <file>
                  <contents filename="pubkey"><![CDATA[INSERT PUBLIC KEY HERE]]></contents>
                </file>
              </files>
            </service>
          </services>
        </assembly>
      </assemblies>
    </deployable>

The core pieces of this examples are

  1. The executable bash script in the "install-pubkey" service.
  2. The "pubkey" file

The executable bash script is a simple two line script that create the .ssh
directory for the root user (if it doesn't already exist) and add the contents
of the "pubkey" file to the end of the authorized\_keys file.

The "pubkey" file takes its contents from the provided public key value supplied
in the body of the <code>&lt;contents&gt;</code> XML element.  When the Audrey Agent
downloads the configuration tooling information from the config server, it will
write the "pubkey" file out to the present working directory of the associated
executable script.  That way, it's safe for the executable script to reference
the pubkey file as simply "pubkey".

## Using this example ##

To use this example, download the ssh-pubkey-deployable.xml example file and
replace the "id" attribute of  <code>&lt;image id="INSERT IMAGE ID"/&gt;</code>
with an actual image Id built and pushed to a cloud provider.  Also, insert the
contents of a public key file at <code>&lt;![CDATA[INSERT PUBLIC KEY
HERE]]&gt;</code>.

After performing the necessary replacements, this deployable XML file can be
used to build a catalog entry in Conductor and launch an instance.
