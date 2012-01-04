require 'spec_helper'

instance_uuid = '039901bc-1c51-11e1-bae2-0019b91a7f08'
deployment_uuid = '038f5572-1c51-11e1-bae2-0019b91a7f08'
# there's probably a better place to put this?
data = '''<?xml version="1.0"?>
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

describe 'Config Server' do

  before(:all) do
    ApplicationHelper.class_eval { def authenticated?; true end }
  end

  it "should return html from get /version" do
    get '/version'
    last_response.body.should.start_with? '<html>'
  end

  it "should return xml from get /version when asked for xml" do
    get '/version', {}, {'HTTP_ACCEPT' => "application/xml"}
    last_response.body.should.start_with? '<config-server>'
  end

  it "should return text from get /version when asked for text" do
    get '/version', {}, {'HTTP_ACCEPT' => "text/plain"}
    last_response.body.should.start_with? '<config-server>'
  end

  it "should return 200 from post /configs/:version/:uuid" do
    Net::HTTP.stub!(:new).and_return(FakeHttp.new)
    post '/configs/1/' + instance_uuid, {:data=>data}
    last_response.body.should == ''
  end

  it "should return 202 from get /configs/:version/:uuid" do
    get '/configs/1/' + instance_uuid
    last_response.status.should == 202
  end

  it "should return 202 from put /params/:version/:uuid with blank data on first put" do
    # the first HTTP PUT should be allowed to be empty
    put '/params/1/' + instance_uuid, {:audrey_data=>"|&|"}
    last_response.status.should == 202
  end

  it "should return 202 from put /params/:version/:uuid with param 1/2" do
    put '/params/1/' + instance_uuid, {:audrey_data=>"|ipaddress&0.0.0.0|"}
    last_response.status.should == 202
  end

  it "should return 200 from put /params/:version/:uuid with param 2/2" do
    put '/params/1/' + instance_uuid, {:audrey_data=>"|hostname&example.com|"}
    last_response.status.should == 200
  end

  it "should return 200 from put /params/:version/:uuid with blank data" do
    put '/params/1/' + instance_uuid, {:audrey_data=>"|&|"}
    last_response.should.be.ok
  end

  it "should return 200 from get /configs/:version/:uuid" do
    get '/configs/1/' + instance_uuid
    last_response.should.be.ok
  end

  it "should return 200 from get /configs/:version/:uuid when asked for text" do
    get '/configs/1/' + instance_uuid, {}, {'HTTP_ACCEPT' => "application/xml"}
    last_response.should.be.ok
  end

  it "should return 200 from get /configs/:version/:uuid when asked for xml" do
    get '/configs/1/' + instance_uuid, {}, {'HTTP_ACCEPT' => "text/plain"}
    last_response.should.be.ok
  end

  it "should return 200 from get /params/:version/:uuid" do
    get '/params/1/' + instance_uuid, {}, {'HTTP_ACCEPT' => "application/xml"}
    last_response.body.should == "<parameters>\n\n</parameters>"
  end

  it "should return 200 from get /params/:version/:uuid" do
    get '/params/1/' + instance_uuid, {}, {'HTTP_ACCEPT' => "text/plain"}
    last_response.body.should == '||'
  end

  it "should return 200 from get /ip/:version/:uuid" do
    get '/ip/1/' + instance_uuid, {}, {'HTTP_ACCEPT' => "text/html"}
    last_response.should.be.ok
  end

  it "should return 200 from get /ip/:version/:uuid" do
    get '/ip/1/' + instance_uuid, {}, {'HTTP_ACCEPT' => "text/plain"}
    last_response.should.be.ok
  end

  it "should return 200 from get /files/:version/:uuid" do
    get '/files/1/' + instance_uuid
    last_response.should.be.ok
  end

  it "should return 200 from put /files/:version/:uuid" do
    put '/files/1/' + instance_uuid
    last_response.should.be.ok
  end

  it "should return 200 from delete /deployments/:version/:uuid" do
    delete '/deployment/1/' + deployment_uuid
    last_response.should.be.ok
  end

end
