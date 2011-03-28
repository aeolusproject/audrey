#!/usr/bin/ruby

require 'nokogiri'
require 'base64'
require 'rubygems'
require 'uuid'
require 'optparse'

class Instance
  attr_reader :deplname, :deplid, :name, :assytype, :hwp, :realm, :uuid
  attr_accessor :tmplname

  def initialize(deplname, deplid, assyname, assytype, assyhwp, realm)
    @deplname = deplname
    @deplid = deplid
    @name = assyname
    @assytype = assytype
    @hwp = assyhwp
    @realm = realm
    @uuid = UUID.generate

    @services = []
    @provided_params = []
  end

  def add_service(name, config_type, opts={})
    s = {}
    s[:name] = name
    #FIXME: Puppet specific
    if 'puppet' == config_type
      if opts[:classes] != nil
        s[:classes] = opts[:classes].clone.uniq
      end
      if opts[:parameters] != nil
        s[:parameters] = opts[:parameters].clone
      end
    end
    @services << s
  end

  def add_provided_param(param_name)
    (@provided_params << param_name).uniq!
  end

  def to_condor_job(job_name)
    data = generate_user_data(true)
    job  = "universe = grid\n"
    job += "executable = #{job_name}\n"
    job += "grid_resource = deltacloud $$(provider_url)\n"
    job += "DeltacloudUsername = $$(username)\n"
    job += "DeltacloudPassword = $$(password)\n"
    job += "DeltacloudImageID = $$(image_key)\n"
    job += "DeltacloudHardwareProfile = $$(hardware_profile_key)\n"
    job += "DeltacloudKeyname = $$(keypair)\n"
    if not @realm.nil?
      job += "DeltacloudRealmId = $$(realm_key)\n"
    end
    if data.length > 0
        job += "DeltacloudUserData = #{data}\n"
    end

    requirements = "requirements = hardwareprofile == \"#{@hwp}\" && image == \"#{@tmplname}\""
    if not @realm.nil?
      requirements += " && realm == \"#{@realm}\""
    end
    # FIXME: skipping the quota check for now
    requirements += "\n"
    job += requirements
    job += "notification = never\n"
    job += "queue\n"
    return job
  end

  def generate_user_data(b64_encode=false)
    host = $options[:config_server_host]
    port = $options[:config_server_port]
    data = "#{host}:#{port}:#{@uuid}"
    if b64_encode
      data = [data].pack("m0").delete("\n")
    end
    return data
  end

  def to_instance_config
    xml  = "<instance-config id='#{@uuid}' name='#{@name}'" +
                                          " type='#{@assytype}'>\n"
    xml += "  <deployable name='#{@deplname}' id='#{@deplid}'/>\n"
    xml += "  <template name='#{@tmplname}'/>\n"
    xml += "  <provided-parameters>\n"
    @provided_params.each do |p|
      xml += "    <provided-parameter name='#{p}'/>\n"
    end
    xml += "  </provided-parameters>\n"
    xml += "  <services>\n"
    #FIXME: Puppet specific
    xml += "    <puppet>\n"
    @services.each do |s|
      # puppet services have the form of:
      # :classes => [class, class,...]
      #   class == "fully qualified puppet classname"
      # :parameters => [parameter, parameter,...]
      #   parameter ==
      #     1) :name => "name", :value => "value": for simple name-value pairs
      #     2) :name => "name", :ref_assembly => "assy", \
      #         :ref_parameter = "param": for externally referenced parameters
      xml += "      <service name='#{s[:name]}'>\n"
      s[:classes].each do |c|
        xml += "        <class name='#{c}'/>\n"
      end
      s[:parameters].each do |p|
        if p.key?(:value) # handle simple name-value pair
          xml += "        <parameter name='#{p[:name]}'>\n"
          xml += "          <value><![CDATA[#{p[:value]}]]></value>\n"
          xml += "        </parameter>\n"
        elsif p.key?(:ref_assembly) # handle externally referenced parameter
          xml += "        <parameter name='#{p[:name]}'>\n"
          xml += "          <reference assembly='#{p[:ref_assembly]}'" +
                            " provided-parameter='#{p[:ref_parameter]}'/>\n"
          xml += "        </parameter>\n"
        end
      end
      xml += "      </service>\n"
    end
    xml += "    </puppet>\n"
    xml += "  </services>\n"
    xml += "</instance-config>\n"
    return xml
  end
end

def usage
  puts "Usage: %s [TAD]" % [$0]
  puts
  puts " [TAD] must contain one (and only one) deployable XML"
  puts " file, one or more assembly files, and one or more"
  puts " template XML files."
end

def find_template(instance)
  found_tmpl = false

  $templates.each do |template|
    tmplnode = template.xpath('/template/name')
    if tmplnode.length != 1
      raise "Invalid template document"
    end

    tmplname = tmplnode[0].content
    if tmplname == instance.tmplname
      found_tmpl = true
      template.xpath('//parameter[@provided="true"]').each do |p|
        instance.add_provided_param(p['name'])
      end

      $instances << instance
      break
    end
  end

  if not found_tmpl
    raise "Could not find template to match %s" % [instance.tmplname]
  end
end

def find_assembly(instance)
  found_assy = false

  $assemblies.each do |assy|
    assyname = assy.xpath('/assembly')[0]['name']

    if assyname == instance.assytype
      found_assy = true

      assytmpl = assy.xpath('/assembly/template')
      if assytmpl.length != 1
        raise "No template specified in assembly %s" % [assemblyname]
      end
      assytmplname = assytmpl[0]['type']
      if assytmplname == nil
        raise "No template type specified in assembly %s" % [assemblyname]
      end
      instance.tmplname = assytmplname

      #FIXME: Puppet specific
      assy.xpath('/assembly/services/puppet/service').each do |s|
        service_name = s['name']
        service = {:classes => [], :parameters => []}
        s.xpath('./class').each do |c|
          service[:classes] << c.content.strip
        end
        # as this evolves, we may need to handle more complex types of
        # parameters such as lists
        s.xpath('./parameter').each do |p|
          param = {:name => p['name']}
          child = p.xpath('reference', 'value')[0]
          if 'reference' == child.node_name
            param[:ref_assembly] = child['assembly']
            param[:ref_parameter] = child['parameter']
          else
            # grab the param value unaltered (no stripping here)
            param[:value] = child.content
          end
          service[:parameters] << param
        end
        instance.add_service(service_name, "puppet", service)
      end

      find_template(instance)

      break
    end

  end

  if not found_assy
    raise "Could not find assembly to match %s" % [assyname]
  end
end

$options={}
optparse = OptionParser.new do |opts|
  #opts.banner = usage
  $options[:config_server_host] = ENV['CONFIG_SERVER_HOST']
  opts.on('-h' '--host HOST', 'The config server hostname or IP address') do |h|
    $options[:config_server_host] = h
  end
  $options[:config_server_port] = ENV['CONFIG_SERVER_PORT'] || "80"
  opts.on('-p' '--port PORT', 'The config server port') do |p|
    $options[:config_server_port] = p
  end
end
optparse.parse!

def escape(input)
  input.sub!('\\', '\\\\')
  input.sub!(' ', '\\ ')
  return input
end

if ARGV.length < 1
    usage
end

deployable = nil
$assemblies = []
$templates = []
for filename in ARGV
  doc = Nokogiri::XML(File::open(filename))

  if doc.xpath('/deployable').length == 1
    if deployable == nil
      deployable = doc
    else
      raise "Multiple deployable files specified"
    end
  elsif doc.xpath('/assembly').length == 1
    $assemblies << doc
  elsif doc.xpath('/template').length == 1
    $templates << doc
  else
    raise "%s: Unknown XML file type" % [filename]
  end
end

if deployable == nil
  raise "No deployable file specified"
end

deplname = deployable.xpath('/deployable/name')[0].content
deplid = UUID.generate

$instances = []
deployable.xpath('/deployable/assemblies/assembly').each do |neededassy|
  assyname = neededassy['name']
  if assyname == nil
    raise "No name specified for assembly"
  end

  neededassytype = neededassy['type']
  if neededassytype == nil
    raise "No type specified for assembly %s" % [assyname]
  end

  assyhwp = neededassy['hwp']
  if assyhwp == nil
    raise "No hardware profile specified for assembly %s" % [assyname]
  end

  assyrealm = neededassy['realm']
  # assyrealm is allowed to be nil

  instance = Instance.new(deplname, deplid, assyname, neededassytype, assyhwp,
                          assyrealm)
  find_assembly(instance)
end

jobnum = 1
$instances.each do |instance|
  job_name = "job_" + jobnum.to_s
  File::open(job_name + ".cnd", "w") do |f|
    f.write(instance.to_condor_job(job_name))
  end

  # for now, just dump the instance config into a file named the instance's UUID
  # this data will eventually have to be submitted to the config server
  File::open(instance.uuid, "w") do |f|
    f.write(instance.to_instance_config)
  end
  puts "Wrote instance config for #{instance.uuid} to #{instance.uuid}"
  host = $options[:config_server_host]
  port = $options[:config_server_port]
  puts "  - Submit with:  curl -X POST " +
          "--data-urlencode \"data@#{instance.uuid}\" " +
          "-w \"HTTP_CODE: %{http_code}\\n\" " +
          "http://#{host}:#{port}/configs/0/#{instance.uuid}"

  jobnum += 1
end
