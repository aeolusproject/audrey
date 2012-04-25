require 'spec_helper'

describe 'Things the functional tests missed' do

  it "should properly create a InvalidInstanceConfigError" do
    x = ConfigServer::Model::InvalidInstanceConfigError.new(errors=0)
    x.to_s
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

end
