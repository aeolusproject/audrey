#!/usr/bin/ruby

require 'nokogiri'
require 'libarchive_rs'
require 'base64'

class Instance
  attr_reader :name, :hwp, :tmplname, :realm

  def initialize(assyname, assyhwp, tmplname, realm)
    @name = assyname
    @hwp = assyhwp
    @tmplname = tmplname
    @realm = realm
  end
end

def usage
  puts "Usage: %s [TAD]" % [$0]
  puts
  puts " [TAD] must contain one (and only one) deployable XML"
  puts " file, one or more assembly files, and one or more"
  puts " template XML files."
end

def find_template(neededtmplname, assyname, assyhwp, assyrealm)
  found_tmpl = false

  $templates.each do |template|
    tmplnode = template.xpath('/template/name')
    if tmplnode.length != 1
      raise "Invalid template document"
    end

    tmplname = tmplnode[0].content
    if tmplname == neededtmplname
      found_tmpl = true
      $instances << Instance.new(assyname, assyhwp, tmplname, assyrealm)
      break
    end
  end

  if not found_tmpl
    raise "Could not find template to match %s" % [neededtmplname]
  end
end

def find_assembly(neededassytype, assyname, assyhwp, assyrealm)
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

      find_template(assytmplname, assyname, assyhwp, assyrealm)

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

  assyrealm = neededassy['realm']
  # assyrealm is allowed to be nil

  find_assembly(neededassytype, assyname, assyhwp, assyrealm)
end

jobnum = 1
$instances.each do |instance|
  job_name = "job_" + jobnum.to_s

  userdata = ""

=begin
  if instance.script.length > 0
    tarfile = "deleteme.tar.bz2"
    Archive.write_open_filename(tarfile, Archive::COMPRESSION_BZIP2, Archive::FORMAT_TAR) do |ar|
      instance.script.each do |fn, data|
        ar.new_entry do |entry|
          entry.filetype = Archive::ENTRY_FILE
          entry.pathname = fn
          entry.size = data.length
          entry.mtime = Time.now().to_i
          entry.mode = 100640
          ar.write_header(entry)
          ar.write_data(data)
        end
      end
    end

    userdata = File.open(tarfile, "rb") {|f| f.read}

    File.unlink(tarfile)
  end
=end

  # do base64 encoding
  b64 = [userdata].pack("m0").delete("\n")

  if b64.length > (16 * 1024)
    raise "Userdata is too big for EC2; it must be <= 16K"
  end

  f = File::open(job_name + ".cnd", "w")
  f.write("universe = grid\n")
  f.write("executable = " + job_name + "\n")

  f.write("grid_resource = deltacloud $$(provider_url)\n")
  f.write("DeltacloudUsername = $$(username)\n")
  f.write("DeltacloudPassword = $$(password)\n")
  f.write("DeltacloudImageID = $$(image_key)\n")
  f.write("DeltacloudHardwareProfile = $$(hardwareprofile_key)\n")
  f.write("DeltacloudKeyname = $$(keypair)\n")
  if not instance.realm.nil?
    f.write("DeltacloudRealmId = $$(realm_key)\n")
  end
  if b64.length > 0
      f.write("DeltacloudUserData = " + b64 + "\n")
  end

  requirements = 'requirements = hardwareprofile == "' + instance.hwp + '" && image == "' + instance.tmplname + '"'
  if not instance.realm.nil?
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
