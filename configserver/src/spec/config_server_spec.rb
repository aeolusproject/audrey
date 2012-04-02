require 'spec_helper'

describe 'Config Server Version & Auth' do

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

  it "should return xml from get /version when given api_compat param" do
    get '/version?api_compat=1-2', {}, {'HTTP_ACCEPT' => "application/xml"}
    last_response.body.should.include? '<api-version>2</api-version>'
  end

  it "should return 200 from /auth" do
    get '/auth'
    last_response.should.be.ok
  end
end
