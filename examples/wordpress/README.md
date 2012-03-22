# Wordpress Example

This Wordpress example contains all the files necessary for starting from scratch
and ending up with a working Wordpress deployment.

The end system will have a Wordpress server running apache+php, and a separate
mysql server.

## Prerequisites

Before you begin, make sure you have:

*  an Aeolus Conductor server running and configured
    *  Aeolus Conductor should be configured with an EC2 provider account
    *  The EC2 account's default security group should allow external access over port 80
*  an Audrey Config Server setup and configured
    *  Add the Audrey Config Server to the Aeolus Conductor EC2 provider account
    *  see [instructions](http://www.aeolusproject.org/audrey.html#update_conductor)

## Understanding the sample files

### Templates

* apache.xml
* mysql.xml

These files are used to build the Wordpress and MySQL images for the Wordpress
deployment.  The <code>aeolus image build</code> and <code>aeolus image
push</code> commands use Image Factory to build and push the images to a cloud
provider account.

### Scripts and files

* dbup.rb
* wordpress-http.sh
* wordpress-mysql.sh

The scripts and files in the Wordpress example are used during the post-launch
configuration of the instances.  These scripts and files are downloaded by the
instances from the Audrey Config Server and used during configuration.

### Deployable

* wordpress-inline.xml

The Deployable XML file contains references to built images as well as the
scripts and files inline.  All of these references are packaged together in
<code>&lt;assembly&gt;</code> elements, which provide a way to tie the two
instances together.

## Getting started

To build the Wordpress example you're going to do several things:

1. build the images for the Wordpress server and the mysql server
2. import the Wordpress deployable into your Conductor server
3. Update the deployable XML file in Conductor to reference your built images
4. Launch the deployable in a cloud provider

*Note*: These instructions assume you'll be using EC2 as the cloud provider to
build images and launch the deployment.

## Build the images

To build the images, you need to supply a template file to the <code>aeolus
image</code> command line tool.

1. Download the image files
<pre><code>
   $> wget https://raw.github.com/aeolusproject/audrey/master/examples/wordpress/mysql.xml
   $> wget https://raw.github.com/aeolusproject/audrey/master/examples/wordpress/apache.xml
</code></pre>
2. Build the mysql image
<pre><code>
   $> aeolus image build --target ec2 --template mysql.xml
</code></pre>
This command returns quickly and will produce output similar to:
<pre><code>
Target Image                             Target     Status        Image                                    Build
------------------------------------     ------     ---------     ------------------------------------     ------------------------------------
9fc1a21e-711b-4d73-8791-945b10cdb45d     ec2        COMPLETED     4e9b2d75-4599-474c-a7c3-f022ec9aa859     2d25f363-5a73-4531-8897-95e58851ebee
</code></pre>
3. Push the image to EC2
<pre><code>
   $> aeolus image push --account ec2AccountName --targetimages 9fc1a21e-711b-4d73-8791-945b10cdb45d
</code></pre>
This command returns quickly, but the actual process of pushing to EC2 will take
several minutes.  The command produces output similar to:
<pre><code>
ID                                       Provider          Account         Status     Target Image
------------------------------------     -------------     --------------  -------    ------------------------------------
fe030093-596a-4a90-b07a-57ac57a22640     ec2-us-east-1     ec2AccountName  Pushing    9fc1a21e-711b-4d73-8791-945b10cdb45d
</code></pre>
4. Repeat steps 2 and 3 for the apache.xml file

## Import and update the deployable

1. Import the Deployable file into Conductor
   > In order to launch the Wordpress deployment, the Wordpress deployable file needs to be
   > loaded into Conductor.
   >
   > 1. Log into your Conductor web UI
   > 2. Click the "Administer" tab
   > 3. Click the "Content" tab
   > 4. Select a Catalog (or, create a new Catalog)
   > 5. Click the "New Deployable" button
   > 6. Click "From URL"
   > 7. Enter a name
   > 8. Provide
       "https://raw.github.com/aeolusproject/audrey/master/examples/wordpress/wordpress-inline.xml"
       as the url
   > 9. Click the "Edit XML after save" checkbox
   > 0. Click "Save"
2. Replace the image IDs
   > After saving the deployable XML, you will be taken to a page where you can
   > edit the deployable XML.
   > <br/>
   > <br/>
   > The deployable XML contains <code>&lt;image&gt;</code> XML elements.  These
   > elements indicate what is the corresponding image to use for each assembly.
   > <br/>
   > <br/>
   > The images' ID attribute must be replaced with the "Image" values provided by the
   > two <code>aeolus image build</code> commands issued to build to the
   > apache and mysql images.
   > <br/>
   > <br/>
   > Find the <code>&lt;image id="APACHE\_IMAGE\_ID"/&gt;</code> XML element and
   > use the "Image" uuid provided when building the "apache" image.  Then, find
   > the <code>&lt;image id="MYSQL\_IMAGE\_ID"/&gt;</code> XML element and use
   > the "Image" uuid provided when building the "mysql" image.
3. Click "Save" after updating the image IDs

## Launch the deployable

Now you're ready to launch the Wordpress deployment.  Notice the big green "Launch"
button that's available after saving the deployable XML file.

1. Click the "Launch" button.
2. Provide launch time values
   > Notice that all of the launch time parameters have default values
   > provided.  You may keep these all as defaults, or provide your own custom
   > values.
   > <br/>
   > <br/>
   > *NOTE*: If you change the "Db Pw" value, you need to make sure you
   > provide the same value for both the "Http" service and the "Mysql" service.
   > This value corresponds to the Wordpress database password.
3. Click "Finalize"
4. Click "Launch"

## Access your new Wordpress server

After the deployment launches, Conductor should be updated with the IP address
of the Wordpress and MySQL servers.  Once you have the Wordpress server's IP address,
you can access Wordpress via:

    http://<IP-Address>/wordpress
