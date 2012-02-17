require 'test/spec'
require 'rspec'
require 'rack/test'
require 'ruby-debug'
require 'logger'

ENV['INSTANCE_CONFIG_RNG'] = '../schema/instance-config.rng'
require 'common_config'
# HACK, see config.in.ru for details
set :environment, :test

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

OAuth::Signature.class_eval do
  def self.verify(request, options = {}, &block)
    request_proxy = FakeRequestProxy.new
    request_proxy.consumer_key=INSTANCE_UUID
    block.call(request_proxy=request_proxy)
  end
end

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

INSTANCE_UUID = '039901bc-1c51-11e1-bae2-0019b91a7f08'
DEPLOYMENT_UUID = '038f5572-1c51-11e1-bae2-0019b91a7f08'
INSTANCE_DATA_W_URL = '''<?xml version="1.0"?>
<instance-config id="039901bc-1c51-11e1-bae2-0019b91a7f08" name="mysql" secret="fakesecret">
  <deployable name="Wordpress Multi-Instance Deployable" id="038f5572-1c51-11e1-bae2-0019b91a7f08"/>
  <provided-parameters>
    <provided-parameter name="hostname"/>
    <provided-parameter name="ipaddress"/>
  </provided-parameters>
  <services>
    <service name="test_service">
      <executable url="http://localhost/example.sh"/>
      <files>
        <file url="http://localhost/example.xml"/>
      </files>
      <parameters>
        <parameter name="test1">
          <value><![CDATA[test1]]></value>
        </parameter>
        <parameter name="test2">
          <value><![CDATA[test2]]></value>
        </parameter>
        <parameter name="ref_test">
          <reference assembly="039901bc-1c51-11e1-bae2-0019b91a7f08" provided-parameter="ipaddress"/>
        </parameter>
      </parameters>
    </service>
  </services>
</instance-config>'''

INSTANCE_DATA_INLINE = '''<?xml version="1.0"?>
<instance-config id="039901bc-1c51-11e1-bae2-0019b91a7f08" name="mysql" secret="fakesecret">
  <deployable name="Wordpress Multi-Instance Deployable" id="038f5572-1c51-11e1-bae2-0019b91a7f08"/>
  <provided-parameters>
    <provided-parameter name="hostname"/>
    <provided-parameter name="ipaddress"/>
  </provided-parameters>
  <services>
    <service name="test_service">
      <executable url="http://localhost/example.sh"/>
      <files>
        <file>
          <contents filename="test-inline-file">
            <![CDATA[ #!/bin/bash echo "hello" ]]>
          </contents>
        </file>
      </files>
    </service>
  </services>
</instance-config>'''
