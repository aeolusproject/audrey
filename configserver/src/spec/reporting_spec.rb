require 'spec_helper'

describe 'Config Server' do
  describe 'basic deployment reporting' do
    before :each do
      Net::HTTP.stub!(:new).and_return(FakeHttp.new)
    end

    after :all do
      delete '/deployment/1/' + DEPLOYMENT_UUID
    end

    it "should create the instance and instance2 configs" do
      post '/configs/1/' + INSTANCE_UUID, {:data => INSTANCE_DATA_INLINE}
      instance = find_instance(INSTANCE_UUID)
      instance.should_not be nil
      post '/configs/1/' + INSTANCE2_UUID, {:data => INSTANCE_DATA_W_SRVDEP}
      instance = find_instance(INSTANCE2_UUID)
      instance.should_not be nil
    end

    it "should return 200 from /reports/deployment/:uuid" do
      get '/reports/2/deployment/' + DEPLOYMENT_UUID
      last_response.should.be.ok
    end

    it "should return XML with deployment information" do
      get '/reports/2/deployment/' + DEPLOYMENT_UUID
      deployment = ConfigServer::Model::Deployable.find(DEPLOYMENT_UUID)
      deployment_xml = to_xml(last_response.body)
      deployment_xml['uuid'].should eq deployment.uuid
      deployment_xml['status'].should eq deployment.status
      (deployment_xml%'registered').content.should be_the_same_date_as deployment.registered_timestamp
    end
  end

  describe 'basic instance reporting' do
    before :each do
      Net::HTTP.stub!(:new).and_return(FakeHttp.new)
    end

    after :all do
      delete '/deployment/2/' + DEPLOYMENT_UUID
    end

    it "should create the instance and instance2 configs" do
      post '/configs/1/' + INSTANCE_UUID, {:data => INSTANCE_DATA_INLINE}
      instance = find_instance(INSTANCE_UUID)
      instance.should_not be nil
      post '/configs/1/' + INSTANCE2_UUID, {:data => INSTANCE_DATA_W_SRVDEP}
      instance = find_instance(INSTANCE2_UUID)
      instance.should_not be nil
    end

    it "should return 200 from /reports/instance/:uuid" do
      get '/reports/2/instance/' + INSTANCE_UUID
      last_response.should.be.ok
    end

    it "should return XML with instance information" do
      get '/reports/2/instance/' + INSTANCE2_UUID
      instance = find_instance(INSTANCE2_UUID)
      instance_xml = to_xml(last_response.body)
      instance_xml["uuid"].should eq instance.uuid
      instance_xml["status"].should eq instance.status
    end

  end

  @prints_xml = false
  def print_xml(header, report, force=false)
    if @prints_xml or force
      puts "\n\n#{header}:\n#{report.to_xml}"
    end
  end

  describe 'wordpress instance reporting' do
    before :each do
      Net::HTTP.stub!(:new).and_return(FakeHttp.new)
    end

    after :all do
      delete '/deployment/2/wordpress_deployment'
    end

    it "should create the mysql and wordpress configs" do
      post '/configs/2/mysql-uuid', {:data => INSTANCE_MYSQL}
      post '/configs/2/wordpress-uuid', {:data => INSTANCE_WORDPRESS}
      mysql = find_instance(MYSQL_UUID)
      wordpress = find_instance(WORDPRESS_UUID)
      mysql.should_not be nil
      wordpress.should_not be nil
    end

    it "should show initial state report correctly" do
      mysql = find_instance(MYSQL_UUID)
      get '/reports/2/instance/mysql-uuid'
      mysql_report = to_xml(last_response.body)
      (mysql_report % '//registered').should_not be nil
      mysql_report['status'].should eq "incomplete"
      (mysql_report % '//first-contacted').should be nil
      (mysql_report % '//services//configuration-started').should be nil

      wordpress = find_instance(WORDPRESS_UUID)
      get '/reports/2/instance/wordpress-uuid'
      wordpress_report = to_xml(last_response.body)
      (wordpress_report % '//registered').should_not be nil
      wordpress_report['status'].should eq "incomplete"
      (wordpress_report % '//first-contacted').should be nil
      (wordpress_report % '//services//configuration-started').should be nil

      print_xml "MySQL Report (initial)", mysql_report
      print_xml "Wordpress Report (initial)", wordpress_report
    end

    it "should show first contacted state correct" do
      get '/files/2/mysql-uuid'
      mysql = find_instance(MYSQL_UUID)
      get '/reports/2/instance/mysql-uuid'
      mysql_report = to_xml(last_response.body)
      (mysql_report % '//first-contacted').should_not be nil
      (mysql_report % '//last-contacted').should_not be nil

      get '/files/2/wordpress-uuid'
      wordpress = find_instance(WORDPRESS_UUID)
      get '/reports/2/instance/wordpress-uuid'
      wordpress_report = to_xml(last_response.body)
      (wordpress_report % '//first-contacted').should_not be nil
      (wordpress_report % '//last-contacted').should_not be nil

      print_xml "MySQL Report (first contact)", mysql_report
      print_xml "Wordpress Report (first contact)", wordpress_report
    end

    it "should show that the configuration is pending for wordpress" do
      put '/params/2/mysql-uuid', {:audrey_data=>"|hostname&#{"localhost".to_b64}|ipaddress&#{"0.0.0.0".to_b64}|"}
      last_response.should.be.ok

      put '/params/2/wordpress-uuid', {:audrey_data=>"|hostname&#{"localhost".to_b64}|ipaddress&#{"0.0.0.0".to_b64}|"}
      last_response.should.be.ok

      wordpress = find_instance(WORDPRESS_UUID)
      get '/reports/2/instance/wordpress-uuid'
      wordpress_report = to_xml(last_response.body)

      unresolved = wordpress_report %
          "//unresolved-service-parameters/service-parameter[@name='mysql_service']"
      unresolved.should_not be nil

      print_xml "Wordpress Report (configuration pending)", wordpress_report
    end

    it "should show that the configuration has started for mysql" do
      get '/configs/2/mysql-uuid/mysql'
      last_response.status.should eq 200

      mysql = find_instance(MYSQL_UUID)
      get '/reports/2/instance/mysql-uuid'
      mysql_report = to_xml(last_response.body)

      (mysql_report % "//service[@name='mysql']//configuration-started").should_not be nil
      (mysql_report % "//service[@name='mysql']//configuration-ended").should be nil

      print_xml "MySQL Report (configuration started)", mysql_report
    end

    it "should show that the configuration has ended for mysql" do
      put '/params/2/mysql-uuid', {:audrey_data=>"||mysql&#{"0".to_b64}|"}
      last_response.should.be.ok

      mysql = find_instance(MYSQL_UUID)
      get '/reports/2/instance/mysql-uuid'
      mysql_report = to_xml(last_response.body)

      (mysql_report % "//service[@name='mysql']//configuration-started").should_not be nil
      (mysql_report % "//service[@name='mysql']//configuration-ended").should_not be nil
      (mysql_report % "//service[@name='mysql']//completion-status").content.should eq "0"

      print_xml "MySQL Report (configuration ended)", mysql_report
    end

    it "should show that the configuration has started for wordpress" do
      get '/configs/2/wordpress-uuid/wordpress'
      last_response.should.be.ok
      wordpress = find_instance(WORDPRESS_UUID)
      get '/reports/2/instance/wordpress-uuid'
      wordpress_report = to_xml(last_response.body)

      (wordpress_report % "//service[@name='wordpress']//configuration-started").should_not be nil
      (wordpress_report % "//service[@name='wordpress']//configuration-ended").should be nil

      print_xml "Wordpress Report (configuration started)", wordpress_report
    end

    it "should show that configuration has ended for wordpress" do
      put '/params/2/wordpress-uuid', {:audrey_data=>"||wordpress&#{"1".to_b64}|"}
      last_response.should.be.ok

      get '/configs/2/wordpress-uuid/wordpress'
      last_response.should.be.ok
      wordpress = find_instance(WORDPRESS_UUID)
      get '/reports/2/instance/wordpress-uuid'
      wordpress_report = to_xml(last_response.body)

      (wordpress_report % "//service[@name='wordpress']//configuration-started").should_not be nil
      (wordpress_report % "//service[@name='wordpress']//configuration-ended").should_not be nil
      (wordpress_report % "//service[@name='wordpress']//completion-status").content.should eq "1"

      print_xml "Wordpress Report (configuration ended)", wordpress_report
    end

    it "should show the that mysql and wordpress are complete" do
      mysql = find_instance(MYSQL_UUID)
      get '/reports/2/instance/mysql-uuid'
      mysql_report = to_xml(last_response.body)

      mysql_report['status'].should eq "success"
      (mysql_report / '//unresolved-parameters').should be_empty
      (mysql_report / '//pending-return-parameters').should be_empty
      (mysql_report / '//completed').should_not be nil


      wordpress = find_instance(WORDPRESS_UUID)
      get '/reports/2/instance/wordpress-uuid'
      wordpress_report = to_xml(last_response.body)

      wordpress_report['status'].should eq "error"
      (wordpress_report / '//unresolved-parameters').should be_empty
      (wordpress_report / '//pending-return-parameters').should be_empty
      (wordpress_report / '//completed').should_not be nil

      print_xml "MySQL Report (complete success)", mysql_report
      print_xml "Wordpress Report (complete error)", wordpress_report
    end

    it "should show that the deployment has a status of error" do
      deployment = ConfigServer::Model::Deployable.find(DEPLOYMENT_UUID)
      get '/reports/2/deployment/wordpress_deployment'
      deployment_report = to_xml(last_response.body)

      deployment_report['status'].should eq "error"
      (deployment_report % 'completed').should_not be nil

      print_xml "Deployment Report (complete error)", deployment_report
    end
  end
end
