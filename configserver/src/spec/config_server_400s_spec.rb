require 'spec_helper'

describe 'Config Server 400s' do

  before(:each) do
    ApplicationHelper.class_eval { def authenticated?; true end }
  end

  it "should return 404 from get /notrealuri" do
    get '/notrealuri'
    last_response.status.should == 404
  end

  it "should return 404 from get /ip/:version/:uuid" do
    get '/ip/1/fakeUUID', {}, {'HTTP_ACCEPT' => "text/plain"}
    last_response.status.should == 404
  end

  it "should return 404 from get /configs/:version/:uuid when asked for text" do
    get '/configs/1/fakeUUID', {}, {'HTTP_ACCEPT' => "text/plain"}
    last_response.status.should == 404
  end

  it "should return 404 from get /configs/:version/:uuid when asked for xml" do
    get '/configs/1/fakeUUID', {}, {'HTTP_ACCEPT' => "application/xml"}
    last_response.status.should == 404
  end

  it "should return 404 from get /configs/:version/:uuid" do
    get '/configs/1/fakeUUID'
    last_response.status.should == 404
  end

  it "should return 400 from post /configs/:version/:uuid" do
    post '/configs/1/aFakelUUID', {:data=>'Not Real Data'}
    last_response.status.should == 400
  end

  it "should return 404 from delete /configs/:version/:uuid" do
    delete '/configs/1/fakeUUID'
    last_response.status.should == 404
  end

  it "should return 404 from get /files/:version/:uuid" do
    get '/files/1/fakeUUID'
    last_response.status.should == 404
  end

  it "should return 404 from get /files/INVALID_VERSION/:uuid" do
    get '/files/invalid/fakeUUID'
    last_response.status.should == 404
  end

  it "should return 404 from put /files/:version/:uuid" do
    put '/files/1/fakeUUID'
    last_response.status.should == 404
  end

  it "should return 404 from get /params/:version/:uuid when asked for xml" do
    get '/params/1/fakeUUID', {}, {'HTTP_ACCEPT' => "application/xml"}
    last_response.status.should == 404
  end

  it "should return 404 from get /params/:version/:uuid when asked for text" do
    get '/params/1/fakeUUID', {}, {'HTTP_ACCEPT' => "text/plain"}
    last_response.status.should == 404
  end

  it "should return 404 from put /params/:version/:uuid" do
    put '/params/1/fakeUUID'
    last_response.status.should == 404
  end
end
