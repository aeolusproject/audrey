#!/usr/bin/python

import sys
import os
import libxml2
import base64
import time
import tarfile
import StringIO

def usage():
    print "Usage: %s [xmlfiles]" % (sys.argv[0])
    print
    print " [xmlfiles] must contain at one (and only one) deployable XML"
    print " file, one or more assembly XML files, and one or more template"
    print " XML files."
    sys.exit(1)

class Instance:
    def __init__(self, assyname, hwp, templatename, script):
        self.assemblyname = assyname
        self.hwp = hwp
        self.templatename = templatename
        self.realm = None
        self.script = script

def find_template(assemblytmplname, assyname, hwp, script):
    found_templ = False
    for template in templates:
        templatenode = template.xpathEval('/template/name')
        if len(templatenode) != 1:
            raise Exception, "Invalid template document passed"
        templatename = templatenode[0].getContent()
        if templatename == assemblytmplname:
            found_templ = True
            instances.append(Instance(assyname, hwp, templatename, script))
            break

    if not found_templ:
        raise Exception, "Could not find template to match %s" % (assemblytmplname)

def find_assembly(neededassytype, assyname, hwp, script):
    found_assy = False
    for assy in assemblies:
        assemblyname = assy.xpathEval('/assembly')[0].prop('name')
        if assemblyname == neededassytype:
            found_assy = True
            # OK, found the assembly.  Let's find the template
            assemblytmpl = assy.xpathEval('/assembly/template')
            if len(assemblytmpl) != 1:
                raise Exception, "No template specified in assembly %s" % (assemblyname)
            assemblytmplname = assemblytmpl[0].prop('type')
            if assemblytmplname == None:
                raise Exception, "No template type specified in assembly %s" % (assemblyname)

            scriptnodes = assy.xpathEval('/assembly/services/service/config/file')
            for config in scriptnodes:
                script[config.prop('name')] = config.getContent()

            find_template(assemblytmplname, assyname, hwp, script)

            break
    if not found_assy:
        raise Exception, "Could not find assembly to match %s" % (assyname)

def escape(inputstr):
    out = inputstr.replace('\\', '\\\\')
    out = out.replace(' ', '\\ ')
    return out

# main
if len(sys.argv) < 2:
    usage()

deployable = None
assemblies = []
templates = []
for filename in sys.argv[1:]:
    doc = libxml2.parseFile(filename)

    if len(doc.xpathEval('/deployable')) == 1:
        if deployable == None:
            deployable = doc
        else:
            raise Exception, "Multiple deployable files specified"
    elif len(doc.xpathEval('/assembly')) == 1:
        assemblies.append(doc)
    elif len(doc.xpathEval('/template')) == 1:
        templates.append(doc)
    else:
        raise Exception, "Unknown XML file"

if deployable == None:
    raise Exception, "No deployable file specified"

# OK, we classified all of the documents.  Let's make sure all of the
# assemblies referenced in the deployable are present
instances = []
for neededassy in deployable.xpathEval('/deployable/assemblies/assembly'):
    assyname = neededassy.prop('name')
    if assyname == None:
        raise Exception, "No name specified for assembly"

    neededassytype = neededassy.prop('type')
    if neededassytype == None:
        raise Exception, "No type specified for assembly %s" % (assyname)

    hwp = neededassy.prop('hwp')
    if hwp == None:
        raise Exception, "No hardware profile specified for assembly %s" % (assyname)

    script = {}
    scriptnodes = neededassy.xpathEval('services/service/config/file')
    for config in scriptnodes:
        script[config.prop('name')] = config.getContent()    

    find_assembly(neededassytype, assyname, hwp, script)

jobnum = 1
for instance in instances:
    job_name = "job_" + str(jobnum)

    userdata = ""

    tar = tarfile.open("out.tar.bz2", "w:bz2")
    saw_go = False
    for fname,contents in instance.script.items():
        if fname == '/root/go.sh':
            saw_go = True
        cstring = StringIO.StringIO(contents)
        info = tarfile.TarInfo(name=fname)
        info.size = len(cstring.buf)
        info.mtime = int(time.time())
        tar.addfile(tarinfo=info, fileobj=cstring)
    tar.close()

    userdata = open('out.tar.bz2', 'r').read()
    os.unlink('out.tar.bz2')

    if not saw_go:
        raise Exception, "A /root/go.sh file must be specified"

    if len(userdata) > 16 * 1024:
        raise Exception, "Userdata is too big for EC2; it must be <= 16K"

    b64 = base64.b64encode(userdata)

    f = open(job_name + ".cnd", "w")
    f.write("universe = grid\n")
    f.write("executable = " + job_name + "\n")
    resource = "grid_resource = dcloud $$(provider_url) $$(username) $$(password) $$(image_key) " + escape(instance.assemblyname)
    if instance.realm == None:
        resource += " NULL"
    else:
        resource += " " + instance.realm
    resource += " $$(hardwareprofile_key) $$(keypair) "
    if len(b64) == 0:
        resource += "NULL\n"
    else:
        resource += b64 + "\n"
    f.write(resource)
    requirements = "requirements = hardwareprofile == \"" + instance.hwp + "\" && image == \"" + instance.templatename + "\""
    if instance.realm != None:
        requirements += " && realm == \"" + instance.realm + "\""
    # FIXME: skipping the quota check for now
    #requirements += " && deltacloud_quota_check(\"" + job_name + "\", other.cloud_account_id)"
    requirements += "\n"
    f.write(requirements)
    f.write("notification = never\n")
    f.write("queue\n")
    f.close()
    jobnum += 1
