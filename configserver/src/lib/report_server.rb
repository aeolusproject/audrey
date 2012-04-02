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
    # create the XML documents: http://nokogiri.org/Nokogiri/XML/Builder.html

    def deployment_report_generator(deployable)
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.deployment_(:uuid => deployable.uuid, :status => deployable.status) {
          xml.registered_ deployable.registered_timestamp
          completed_ts = deployable.completed_timestamp
          if completed_ts
            xml.completed_ completed_ts
          end
          instances = deployable.instances
          if not instances.empty?
            xml.instances_ {
              instances.each do |instance|
                xml.instance_ :uuid => instance.uuid,
                                     :assembly => instance.assembly_name,
                                     :status => instance.status
              end
            }
          end
        }
      end
      builder.to_xml
    end

    def instance_report_generator(instance)
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.instance_(:uuid => instance.uuid,
                      :assembly => instance.assembly_name,
                      :status => instance.status) {
          xml.registered_ instance.registered_timestamp
          first_contacted_ts = instance.first_contacted
          if first_contacted_ts
            xml.send('first-contacted', first_contacted_ts)
          end
          last_contacted_ts = instance.last_contacted
          if last_contacted_ts
            xml.send('last-contacted', last_contacted_ts)
          end
          completed_ts = instance.completed_timestamp
          if completed_ts
            xml.completed_ completed_ts
          end
          services = instance.services
          if not services.empty?
            xml.services_ {
              services.each do |service|
                xml.service_(:name => "FIXME", :status => "FIXME") {
                  xml.send('configuration-started', "FIXME")
                  xml.send('configuration-ended', "FIXME")
                  xml.send('completed', "FIXME")
                  xml.send('completion-status', "FIXME")
                  xml.send('unresolved-service-parameters') {
                    xml.send('service-parameter', :name => "FIXME") {
                      xml.send('source-assembly', :uuid => "FIXME",
                               :name => "FIXME")
                      xml.send('source-parameter', :name => "FIXME")
                    }
                  }
                  xml.send('pending-return-parameters') {
                    xml.send('return-parameter', :name => "FIXME")
                  }
                }
              end
            }
          end
        }
      end
      builder.to_xml
    end
  end
end
