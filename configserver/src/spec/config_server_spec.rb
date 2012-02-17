require 'spec_helper'

describe 'Config Server' do

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

  it "should return 200 from /auth" do
    get '/auth'
    last_response.should.be.ok
  end

  it "should return 200 from post /configs/:version/:uuid with inline" do
    Net::HTTP.stub!(:new).and_return(FakeHttp.new)
    post '/configs/1/' + INSTANCE_UUID, {:data=>INSTANCE_DATA_INLINE}
    last_response.body.should == ''
  end

  it "should return 200 from post /configs/:version/:uuid with url" do
    Net::HTTP.stub!(:new).and_return(FakeHttp.new)
    post '/configs/1/' + INSTANCE_UUID, {:data=>INSTANCE_DATA_W_URL}
    last_response.body.should == ''
  end

  it "should return 202 from get /configs/:version/:uuid" do
    get '/configs/1/' + INSTANCE_UUID
    last_response.status.should == 202
  end

  it "should return 202 from put /params/:version/:uuid with blank data on first put" do
    # the first HTTP PUT should be allowed to be empty
    put '/params/1/' + INSTANCE_UUID, {:audrey_data=>"|&|"}
    last_response.status.should == 202
  end

  it "should return 202 from put /params/:version/:uuid with param 1/2" do
    put '/params/1/' + INSTANCE_UUID, {:audrey_data=>"|ipaddress&0.0.0.0|"}
    last_response.status.should == 202
  end

  it "should return 200 from put /params/:version/:uuid with param 2/2" do
    put '/params/1/' + INSTANCE_UUID, {:audrey_data=>"|hostname&example.com|"}
    last_response.status.should == 200
  end

  it "should return 200 from put /params/:version/:uuid with blank data" do
    put '/params/1/' + INSTANCE_UUID, {:audrey_data=>"|&|"}
    last_response.should.be.ok
  end

  it "should return 200 from get /configs/:version/:uuid" do
    get '/configs/1/' + INSTANCE_UUID
    last_response.should.be.ok
  end

  it "should return 200 from get /configs/:version/:uuid when asked for text" do
    get '/configs/1/' + INSTANCE_UUID, {}, {'HTTP_ACCEPT' => "application/xml"}
    last_response.should.be.ok
  end

  it "should return 200 from get /configs/:version/:uuid when asked for xml" do
    get '/configs/1/' + INSTANCE_UUID, {}, {'HTTP_ACCEPT' => "text/plain"}
    last_response.should.be.ok
  end

  it "should return 200 from get /params/:version/:uuid" do
    get '/params/1/' + INSTANCE_UUID, {}, {'HTTP_ACCEPT' => "text/plain"}
    last_response.body.should == '||'
  end

  it "should return 200 from get /ip/:version/:uuid" do
    get '/ip/1/' + INSTANCE_UUID, {}, {'HTTP_ACCEPT' => "text/html"}
    last_response.should.be.ok
  end

  it "should return 200 from get /ip/:version/:uuid" do
    get '/ip/1/' + INSTANCE_UUID, {}, {'HTTP_ACCEPT' => "text/plain"}
    last_response.should.be.ok
  end

  it "should return 200 from get /files/:version/:uuid" do
    get '/files/1/' + INSTANCE_UUID
    last_response.should.be.ok
  end

  it "should return 200 from put /files/:version/:uuid with file" do
    put '/files/1/' + INSTANCE_UUID, "file" => Rack::Test::UploadedFile.new("config.ru")
    last_response.should.be.ok
  end

  it "should return 200 from put /files/:version/:uuid with out file" do
    put '/files/1/' + INSTANCE_UUID
    last_response.should.be.ok
  end

  it "should return 200 from delete /deployments/:version/:uuid" do
    delete '/deployment/1/' + DEPLOYMENT_UUID
    last_response.should.be.ok
  end

end
