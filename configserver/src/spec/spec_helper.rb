require 'test/spec'
require 'rspec'
require 'rack/test'
require 'logger'
require 'nokogiri'

begin
  require 'ruby-debug'
rescue Exception=>e
  puts 'Debugging disabled, require ruby-debug failed'
end

# Add cwd to ruby path
# ruby 1.9 compat
$: << "."

##
## Setup the Sinatra App

ENV['INSTANCE_CONFIG_RNG'] = '../schema/instance-config.rng'
require 'common_config'
# HACK, see config.in.ru for details
set :environment, :test

require 'lib/model'

$LOGGER = Logger.new('DEBUG')

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
  conf.after(:all) do
    FileUtils.rm_rf(Dir[settings.storage_dir])
  end
end

def app
  Sinatra::Application
end


##
## Custom rspec matchers
require 'date'
class Time
  # From O'Reilly's "Ruby Cookbook"
  # Recipe 3.9: Converting between time and datetime objects
  def to_datetime
    # Convert seconds + microseconds into a fractional number of seconds
    seconds = sec + Rational(usec, 10**6)

    # Convert a UTC offset measured in minutes to one measured in a
    # fraction of a day.
    offset = Rational(utc_offset, 60 * 60 * 24)
    DateTime.new(year, month, day, hour, min, seconds, offset)
  end
end

def to_datetime obj
  if obj.respond_to? :tr
    # convert from string
    begin
      DateTime.parse obj
    rescue
    end
  elsif obj.respond_to? :to_datetime
    obj.to_datetime
  else
    DateTime.now
  end
end


RSpec::Matchers.define :be_the_same_date_as do |expected|
  match do |actual|
    expected_dt = to_datetime expected
    actual_dt   = to_datetime actual
    expected_dt and actual_dt and expected_dt == actual_dt
  end

  failure_message_for_should do |actual|
    "expected that #{actual} would be the same date as #{expected}"
  end

  failure_message_for_should_not do |actual|
    "expected that #{actual} would not be the same date as #{expected}"
  end

  description do
    "be the same date as #{expected}"
  end
end


##
## Mocks

# Mock up the OAuth Signature verify method

OAuth::Signature.class_eval do
  def self.verify(request, options = {}, &block)
    request_proxy = FakeRequestProxy.new
    request_proxy.consumer_key=INSTANCE_UUID
    block.call(request_proxy=request_proxy)
  end
end


# Mock HTTP object helpers

class FakeHttp
  attr_accessor :use_ssl

  def start
    self
  end
  def code
    "200"
  end
  def body
    'fake download file body'
  end
end

class FakeRequestProxy
  attr_accessor :consumer_key
end


##
## Helpful test data

INSTANCE_UUID = '039901bc-1c51-11e1-bae2-0019b91a7f08'
INSTANCE2_UUID = '039901bc-1c51-11e1-bae2-0019b91a7f09'
DEPLOYMENT_UUID = '038f5572-1c51-11e1-bae2-0019b91a7f08'

INSTANCE_DATA_W_SRVDEP = """<?xml version='1.0'?>
<instance-config id='#{INSTANCE2_UUID}' name='mysql' secret='fakesecret'>
  <deployable name='Wordpress Multi-Instance Deployable' id='#{DEPLOYMENT_UUID}'/>
  <provided-parameters>
    <provided-parameter name='ipaddress'/>
  </provided-parameters>
  <services>
    <service name='test_service'>
      <executable url='http://localhost/example.sh'/>
      <files>
        <file url='http://localhost/example.xml'/>
      </files>
      <parameters>
        <parameter name='test1'>
          <value><![CDATA[test1]]></value>
        </parameter>
        <parameter name='test2'>
          <value><![CDATA[test2]]></value>
        </parameter>
        <parameter name='ref_test'>
          <reference assembly='#{INSTANCE_UUID}' provided-parameter='ipaddress'/>
        </parameter>
        <parameter name='service_ref_test'>
          <reference assembly='#{INSTANCE_UUID}' service-parameter='test_service'/>
        </parameter>
      </parameters>
    </service>
  </services>
</instance-config>"""

INSTANCE_DATA_W_URL = """<?xml version='1.0'?>
<instance-config id='#{INSTANCE_UUID}' name='mysql' secret='fakesecret'>
  <deployable name='Wordpress Multi-Instance Deployable' id='#{DEPLOYMENT_UUID}'/>
  <provided-parameters>
    <provided-parameter name='hostname'/>
    <provided-parameter name='ipaddress'/>
  </provided-parameters>
  <services>
    <service name='test_service'>
      <executable url='http://localhost/example.sh'/>
      <files>
        <file url='http://localhost/example.xml'/>
      </files>
      <parameters>
        <parameter name='test1'>
          <value><![CDATA[test1]]></value>
        </parameter>
        <parameter name='test2'>
          <value><![CDATA[test2]]></value>
        </parameter>
        <parameter name='ref_test'>
          <reference assembly='#{INSTANCE_UUID}' provided-parameter='ipaddress'/>
        </parameter>
      </parameters>
    </service>
  </services>
</instance-config>"""

INSTANCE_DATA_INLINE = """<?xml version='1.0'?>
<instance-config id='#{INSTANCE_UUID}' name='mysql' secret='fakesecret'>
  <deployable name='single instance deployment' id='#{DEPLOYMENT_UUID}'/>
  <provided-parameters>
    <provided-parameter name='hostname'/>
    <provided-parameter name='ipaddress'/>
  </provided-parameters>
  <services>
    <service name='test_service'>
      <executable url='http://localhost/example.sh'/>
      <files>
        <file>
          <contents filename='test-inline-file'>
            <![CDATA[ #!/bin/bash echo 'hello' ]]>
          </contents>
        </file>
      </files>
    </service>
  </services>
</instance-config>"""


MYSQL_UUID = 'mysql-uuid'
WORDPRESS_UUID = 'wordpress-uuid'
WORDPRESS_DEPL_UUID = 'wordpress_deployment'

INSTANCE_WORDPRESS = """<?xml version='1.0'?>
<instance-config id='#{WORDPRESS_UUID}' name='wordpress' secret='fakesecret'>
  <deployable name='Wordpress Multi-Instance Deployable' id='#{WORDPRESS_DEPL_UUID}'/>
  <provided-parameters>
    <provided-parameter name='hostname'/>
    <provided-parameter name='ipaddress'/>
  </provided-parameters>
  <services>
    <service name='wordpress'>
      <executable url='http://localhost/example.sh'/>
      <parameters>
        <parameter name='wp_name'><value>wordpress</value></parameter>
        <parameter name='wp_user'><value>wordpress</value></parameter>
        <parameter name='wp_pw'><value>wordpress</value></parameter>
        <parameter name='mysql_ip'>
          <reference assembly='#{MYSQL_UUID}' provided-parameter='ipaddress'/>
        </parameter>
        <parameter name='mysql_hostname'>
          <reference assembly='#{MYSQL_UUID}' provided-parameter='hostname'/>
        </parameter>
        <parameter name='mysql_service'>
          <reference assembly='#{MYSQL_UUID}' service-parameter='mysql'/>
        </parameter>
      </parameters>
    </service>
  </services>
</instance-config>"""

INSTANCE_MYSQL = """<?xml version='1.0'?>
<instance-config id='#{MYSQL_UUID}' name='mysql' secret='fakesecret'>
  <deployable name='Wordpress Multi-Instance Deployable' id='#{WORDPRESS_DEPL_UUID}'/>
  <provided-parameters>
    <provided-parameter name='hostname'/>
    <provided-parameter name='ipaddress'/>
  </provided-parameters>
  <services>
    <service name='mysql'>
      <executable url='http://localhost/example.sh'/>
      <parameters>
        <parameter name='wp_name'><value>wordpress</value></parameter>
        <parameter name='wp_user'><value>wordpress</value></parameter>
        <parameter name='wp_pw'><value>wordpress</value></parameter>
        <parameter name='apache_ip'>
          <reference assembly='#{WORDPRESS_UUID}' provided-parameter='ipaddress'/>
        </parameter>
        <parameter name='apahe_hostname'>
          <reference assembly='#{WORDPRESS_UUID}' provided-parameter='hostname'/>
        </parameter>
      </parameters>
    </service>
  </services>
</instance-config>"""


# Helper methods
###

def find_instance(uuid)
  ConfigServer::Model::Instance.find(uuid)
end

def find_deployment(uuid)
  ConfigServer::Model::Deployable.find(uuid)
end

def to_xml(str)
  Nokogiri::XML(str).root
end
