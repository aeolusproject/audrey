#!/usr/bin/ruby

require 'nokogiri'

class Instance
  attr_reader :name, :hwp, :tmplname, :script, :realm

  def initialize(assyname, assyhwp, tmplname, script)
    @name = assyname
    @hwp = assyhwp
    @tmplname = tmplname
    @script = script
    @realm = nil
  end
end

def usage
  puts "Usage: %s [TAD]" % [$0]
  puts
  puts " [TAD] must contain one (and only one) deployable XML"
  puts " file, one or more assembly files, and one or more"
  puts " template XML files."
end

def find_template(neededtmplname, assyname, assyhwp, script)
  found_tmpl = false

  $templates.each do |template|
    tmplnode = template.xpath('/template/name')
    if tmplnode.length != 1
      raise "Invalid template document"
    end

    tmplname = tmplnode[0].content
    if tmplname == neededtmplname
      found_tmpl = true
      $instances << Instance.new(assyname, assyhwp, tmplname, script)
      break
    end
  end

  if not found_tmpl
    raise "Could not find template to match %s" % [neededtmplname]
  end
end

def find_assembly(neededassytype, assyname, assyhwp, script)
  found_assy = false

  $assemblies.each do |assy|
    assyname = assy.xpath('/assembly')[0]['name']

    if assyname == neededassytype
      found_assy = true

      assytmpl = assy.xpath('/assembly/template')
      if assytmpl.length != 1
        raise "No template specified in assembly %s" % [assemblyname]
      end
      assytmplname = assytmpl[0]['type']
      if assytmplname == nil
        raise "No template type specified in assembly %s" % [assemblyname]
      end

      assy.xpath('/assembly/services/service/config/file').each do |config|
        script[config['name']] = config.content.strip
      end

      find_template(assytmplname, assyname, assyhwp, script)

      break
    end

  end

  if not found_assy
    raise "Could not find assembly to match %s" % [assyname]
  end
end

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

  script = {}
  neededassy.xpath('services/service/config/file').each do |config|
    script[config['name']] = config.content.strip
  end

  find_assembly(neededassytype, assyname, assyhwp, script)
end

jobnum = 1
$instances.each do |instance|
  job_name = "job_" + jobnum.to_s

  userdata = ""

  # FIXME: deal with creating the tarfile here

  if userdata.length > (16 * 1024)
    raise "Userdata is too big for EC2; it must be <= 16K"
  end

  f = File::open(job_name + ".cnd", "w")
  f.write("universe = grid\n")
  f.write("executable = " + job_name + "\n")

  resource = "grid_resource = dcloud $$(provider_url) $$(username) $$(password) $$(image_key) " + escape(instance.name)
  if instance.realm == nil
    resource += " NULL"
  else
    resource += " $$(realm_key)"
  end
  resource += " $$(hardwareprofile_key) $$(keypair) "
  # FIXME: this is where userdata goes
  resource += "NULL\n"
  f.write(resource)

  requirements = 'requirements = hardwareprofile == "' + instance.hwp + '" && image == "' + instance.tmplname + '"'
  if instance.realm != nil
    requirements += ' && realm == "' + instance.realm + '"'
  end
  # FIXME: skipping the quota check for now
  requirements += "\n"
  f.write(requirements)
  f.write("notification = never\n")
  f.write("queue\n")
  f.close
  jobnum += 1
end
