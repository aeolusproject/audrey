require 'spec_helper'

instance_uuid = '039901bc-1c51-11e1-bae2-0019b91a7f08'
deployment_uuid = '038f5572-1c51-11e1-bae2-0019b91a7f08'
# there's probably a better place to put this?
data = '<instance-config id="039901bc-1c51-11e1-bae2-0019b91a7f08" name="apache" secret="TgAAgcBg2h7l8xt8G6vkXyMpLnTQdMaC3OBRuungdG"><deployable name="Wordpress Multi-Instance Deployable" id="038f5572-1c51-11e1-bae2-0019b91a7f08"/></instance-config>'

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
    post '/configs/1/' + instance_uuid, {:data=>data}
    last_response.body.should == ''
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

  it "should return 200 from put /params/:version/:uuid" do
    put '/params/1/' + instance_uuid, {:audrey_data=>"||"}
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

  it "should return 200 from delete /configs/:version/:uuid" do
    delete '/configs/1/' + instance_uuid
    last_response.should.be.ok
  end

  it "should return 200 from delete /deployments/:version/:uuid" do
    delete '/deployment/1/' + deployment_uuid
    last_response.should.be.ok
  end

end
