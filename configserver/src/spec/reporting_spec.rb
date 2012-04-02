require 'spec_helper'

describe 'Config Server' do
  require 'nokogiri'

  describe 'deployment reporting' do
    before :all do
      Net::HTTP.stub!(:new).and_return(FakeHttp.new)
      post '/configs/1/' + INSTANCE_UUID, {:data=>INSTANCE_DATA_INLINE}
    end

    after :all do
      delete '/deployment/1/' + DEPLOYMENT_UUID
    end

    it "should return 200 from /reports/deployment/:uuid" do
      get '/reports/1/deployment/' + DEPLOYMENT_UUID
      last_response.should.be.ok
    end

    it "should return XML with deployment information" do
      get '/reports/1/deployment/' + DEPLOYMENT_UUID
      deployment = ConfigServer::Model::Deployable.find(DEPLOYMENT_UUID)
      deployment_xml = Nokogiri::XML(last_response.body).root
      deployment_xml['uuid'].should eq deployment.uuid
      deployment_xml['status'].should eq deployment.status
      (deployment_xml%'registered').content.should be_the_same_date_as deployment.registered_timestamp
    end
  end

  describe 'instance reporting' do
    before :all do
      Net::HTTP.stub!(:new).and_return(FakeHttp.new)
      post '/configs/1/' + INSTANCE_UUID, {:data=>INSTANCE_DATA_INLINE}
    end

    after :all do
      delete '/deployment/1/' + DEPLOYMENT_UUID
    end

    it "should return 200 from /reports/instance/:uuid" do
      get '/reports/1/instance/' + INSTANCE_UUID
      last_response.should.be.ok
    end
  end
end
