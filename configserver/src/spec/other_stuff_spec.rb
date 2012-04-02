require 'spec_helper'

describe 'Things the functional tests missed' do

  it "should properly create a InvalidInstanceConfigError" do
    x = ConfigServer::Model::InvalidInstanceConfigError.new(errors=0)
    x.to_s
  end

  it "should assign content to instance_config" do
    # need to stub out the instance_config_schema_location b/c
    # this test bypasses the ApplicationHelper.configs method
    ConfigServer::Model.stub!(:instance_config_schema_location).and_return(ENV['INSTANCE_CONFIG_RNG'])
    Net::HTTP.stub!(:new).and_return(FakeHttp.new)
    x = ConfigServer::Model::Instance.new(INSTANCE_UUID)
    x.instance_config = INSTANCE_DATA_W_URL
  end

  it "should fail to get contents of instance_config that has a url" do
    # need to stub out the instance_config_schema_location b/c
    # this test bypasses the ApplicationHelper.configs method
    ConfigServer::Model.stub!(:instance_config_schema_location).and_return(ENV['INSTANCE_CONFIG_RNG'])
    x = ConfigServer::Model::Instance.new(INSTANCE_UUID)
    x.stub!(:download_file).and_return({:code => "404"})
    x.instance_config = INSTANCE_DATA_W_URL
  end

  it "should base64 encode a string" do
    'a string'.to_b64
  end

  it "should fail to get a validator from a non-existant ng file" do
    ConfigServer::Model.stub!(:instance_config_schema_location).and_return('/not/real/file')
    ConfigServer::Model::Instance.class_eval {class_variable_set :@@validator, nil}
    lambda {ConfigServer::Model::Instance.get_validator}.should raise_error
  end

  it "should fail to get a validator from a non-existant ng url" do
    ConfigServer::Model.stub!(:instance_config_schema_location).and_return('http://localhost:99999/')
    ConfigServer::Model::Instance.class_eval {class_variable_set :@@validator, nil}
    lambda {ConfigServer::Model::Instance.get_validator}.should raise_error
  end

  it "should make sure that instances_with_assembly_dependencies coerces the assembly name to a list" do
    x = ConfigServer::Model::Deployable.new(DEPLOYMENT_UUID)
    x.instances_with_assembly_dependencies('')
  end

end
