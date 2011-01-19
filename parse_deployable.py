#!/usr/bin/python

import sys
import os
import libxml2

def usage():
    print "Usage: %s [xmlfiles]" % (sys.argv[0])
    print
    print " [xmlfiles] must contain at one (and only one) deployable XML"
    print " file, one or more assembly XML files, and one or more template"
    print " XML files."
    sys.exit(1)

if len(sys.argv) < 2:
    usage()

class Instance:
    def __init__(self, assyname, hwp, templatename, services):
        self.assemblyname = assyname
        self.hwp = hwp
        self.templatename = templatename
        self.realm = None
        self.services = services

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
    elif len(doc.xpathEval('/image')) == 1:
        templates.append(doc)
    else:
        raise Exception, "Unknown XML file"

if deployable == None:
    raise Exception, "No deployable file specified"

# OK, we classified all of the documents.  Let's make sure all of the assemblies
# referenced in the deployable are present
instances = []
for neededassy in deployable.xpathEval('/deployable/assemblies/assembly'):
    assyname = neededassy.prop('name')
    if assyname == None:
        raise Exception, "No name specified for assembly"

    neededassytype = neededassy.prop('type')
    if neededassytype == None:
        raise Exception, "No type specified for assembly"

    hwpnode = neededassy.xpathEval('hardware_profile')
    if len(hwpnode) == 1:
        hwp = hwpnode[0].getContent()
    elif len(hwpnode) == 0:
        # FIXME: we want to eventually allow hardware_profiles in the assembly
        # files and the template files as well
        raise Exception, "No hardware_profile specified for assembly %s" % (assyname)
    else:
        raise Exception, "Invalid number of hardware_profiles specified"

    found_assy = False
    for assy in assemblies:
        namenode = assy.xpathEval('/assembly/name')
        if len(namenode) != 1:
            raise Exception, "No name specified in assembly"
        assemblyname = namenode[0].getContent()
        if assemblyname == neededassytype:
            found_assy = True
            # OK, found the assembly.  Let's find the template
            assemblyimage = assy.xpathEval('/assembly/image')
            if len(assemblyimage) != 1:
                raise Exception, "No image specified in assembly %s" % (assemblyname)
            assemblyimagename = assemblyimage[0].prop('type')
            if assemblyimagename == None:
                raise Exception, "No image type specified in assembly %s" % (assemblyname)

            servicesNode = assy.xpathEval('/assembly/image/config/services/service')
            startservices = []
            for service in servicesNode:
                if service.prop('action') == 'start':
                    startservices.append(service.prop('name'))

            found_templ = False
            for template in templates:
                templatenode = template.xpathEval('/image/name')
                if len(templatenode) != 1:
                    raise Exception, "Invalid template document passed"
                templatename = templatenode[0].getContent()
                if templatename == assemblyimagename:
                    found_templ = True
                    instances.append(Instance(assyname, hwp, templatename))
                    break
            if not found_templ:
                raise Exception, "Could not find template to match %s" % (assemblyimagename)
            break
    if not found_assy:
        raise Exception, "Could not find assembly to match %s" % (assyname)

def escape(inputstr):
    out = inputstr.replace('\\', '\\\\')
    out = out.replace(' ', '\\ ')
    return out

jobnum = 1
for instance in instances:
    job_name = "job_" + str(jobnum)
    userdata = "#!/bin/bash\n"
    for service in instance.services:
        userdata += "service " + service + " start\n"

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
    resource += " $$(hardwareprofile_key) $$(keypair) " + b64 + "\n"
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
