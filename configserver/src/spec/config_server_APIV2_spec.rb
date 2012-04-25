require 'spec_helper'

describe 'Config Server API V2' do
  it "should return 200 from post /configs/:version/:uuid with service dependancy" do
    Net::HTTP.stub!(:new).and_return(FakeHttp.new)
    post '/configs/2/' + INSTANCE_UUID, {:data=>INSTANCE_DATA_INLINE}
    last_response.body.should == ''
    last_response.status.should == 200

    post '/configs/2/' + INSTANCE2_UUID, {:data=>INSTANCE_DATA_W_SRVDEP}
    last_response.body.should == ''
    last_response.status.should == 200
  end

  it "should return 202 from put /params/:version/:uuid with service" do
    put '/params/2/' + INSTANCE_UUID, {:audrey_data=>"||test_service&0|"}
    last_response.status.should == 202
  end

  it "should return 200 from put /params/:version/:uuid with service" do
    put '/params/2/' + INSTANCE_UUID, {:audrey_data=>"|hostname&#{"localhost".to_b64}|ipaddress&#{"127.0.0.1".to_b64}|"}
    last_response.status.should == 200
  end

  it "should return 200 from get /configs/:version/:uuid when asked for xml" do
    get "/configs/2/#{INSTANCE2_UUID}/test_service", {}, {'HTTP_ACCEPT' => "application/xml"}
    last_response.body.should.include 'service_ref_test'
  end

  it "should return 200 from get /configs/:version/:uuid when asked for text" do
    get "/configs/2/#{INSTANCE2_UUID}/test_service", {}, {'HTTP_ACCEPT' => "text/plain"}
    last_response.body.should.include 'service_ref_test'
  end

  it "should return 200 from get /params/:version/:uuid" do
    get '/params/2/' + INSTANCE_UUID, {}, {'HTTP_ACCEPT' => "text/plain"}
    last_response.body.should == '||test_service|'
  end
end
