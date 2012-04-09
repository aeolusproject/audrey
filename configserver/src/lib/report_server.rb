#
#   Copyright [2011] [Red Hat, Inc.]
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#  limitations under the License.
#

require 'nokogiri'

module ConfigServer
  class ReportServer
    def initialize(settings)
      @settings = settings
      @logger = $LOGGER
    end

    # Produces a report for the given deployment uuid:
    #
    # <deployment uuid="DEPLOYMENT_UUID" status="success/incomplete/error">
    #   <registered>Timestamp (date/time)</registered>
    #   <completed>Timestamp (date/time)</registered> <!-- only present when all
    #                                                      services have
    #                                                      completed -->
    #   <instances>
    #     <instance uuid="INSTANCE_UUID" assembly="name"
    #         status="success/incomplete/error"/>
    #     <instance uuid="INSTANCE_UUID" assembly="name"
    #         status="success/incomplete/error"/>
    #   </instances>
    # </deployment>
    #
    def deployment_report(uuid)
      deployable = Model::Deployable.find(uuid)
      if deployable
        deployment_report_generator(deployable)
      end
    end


    #  Produces a report for the given instance uuid:
    #
    #  <instance uuid="UUID" assembly="original_assembly_name" status="success/incomplete/error">
    #    <registered>Timestamp (date/time)</registered>
    #    <first-contacted>Timestamp (date/time)</first-contacted>
    #    <last-contacted>Timestamp (date/time)</last-contacted>
    #    <completed>Timestamp (date/time)</completed>  <!-- only present when
    #                                                       all services have
    #                                                       completed -->
    #    <services>
    #      <service name="NAME" status="success/incomplete/error">
    #        <configuration-started>Timestamp (date/time)</configuration-started>
    #        <configuration-ended>Timestamp (date/time)</configuration-ended>
    #        <completed>Timestamp (date/time)</completed>  <!-- only present
    #                                                           when the service
    #                                                           has completed
    #                                                           -->
    #        <completion-status>EXIT_CODE</completion-status>
    #        <unresolved-service-parameters>
    #          <service-parameter name="PARAM_NAME">
    #            <source-assembly uuid="SOURCE_ASSEMBLY_UUID" name="SOURCE_ASSEMBLY_NAME"/>
    #            <source-parameter name="SOURCE_RETURN_PARAMETER_NAME"/>
    #          </service-parameter>
    #        </unresolved-service-parameters>
    #        <pending-return-parameters>
    #          <return-parameter name="PARAM_NAME"/>
    #        </pending-return-parameters>
    #      </service>
    #    </services>
    #  </instance>
    def instance_report(uuid)
      instance = Model::Instance.find(uuid)
      if instance
        instance_report_generator(instance)
      end
    end

    private

    # The report generator methods use the Nokogiri::XML::Builder object to
    # create the XML documents.  It's worth reading:
    # http://nokogiri.org/Nokogiri/XML/Builder.html
    #
    # The methods stick to the convention of assigning each level of XML
    # building a specific "handle".  For instance, the first level is given
    # "_root" as a handle.  For the deployment_report_generator method, the next
    # level is given a handle of "_dep" referring to the <deployment> XML
    # element.  Hopefully, this makes the report building a little easier to
    # read.

    def deployment_report_generator(deployable)
      builder = Nokogiri::XML::Builder.new do |_root|
        _root.deployment_ :uuid => deployable.uuid, :status => deployable.status {|_dep|
          _dep.registered_ deployable.registered_timestamp
          completed_ts = deployable.completed_timestamp
          if completed_ts
            _dep.completed completed_ts
          end
          instances = deployable.instances
          _dep.instances_ {|_instances|
            instances.each do |instance|
              _instances.instance_ :uuid => instance.uuid,
                                   :assembly => instance.assembly_name,
                                   :status => instance.status
            end
          }
        }
      end
      builder.to_xml
    end

    def instance_report_generator(instance)
      builder = Nokogiri::XML::Builder.new do |_root|
        #FIXME: implement instance report generator
      end
      builder.to_xml
    end
  end
end
