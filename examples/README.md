# Examples

This directory contains example templates and deployables which can be used to
build images and launch deployments with Aeolus and Audrey.

### Using the examples

To use the examples, you must already:

*  have Aeolus Conductor [installed](https://www.aeolusproject.org/get_it.html) and [configured](https://www.aeolusproject.org/configuring_aeolus.html)
*  have an Audrey Config Server [setup and configured](https://www.aeolusproject.org/audrey.html#config_server)

# Full Examples

These examples contain everything needed to create a working deployment.  This
includes:

*  image templates for building images through Image Factory
*  deployables for launching deployments in Aeolus Conductor
*  scripts for configuring the services in the launched instances

## Example: [Wordpress](https://github.com/aeolusproject/audrey/tree/master/examples/wordpress)

The Wordpress example shows how to use the entire Aeolus tool chain to build a
Wordpress server.

## Example: [Drupal](https://github.com/aeolusproject/audrey/tree/master/examples/drupal)

Similar to the Wordpress example, the Drupal example shows how to use the entire
Aeolus tool chain to build a Drupal server.

# Other utilities

## [Deployables](https://github.com/aeolusproject/audrey/tree/master/examples/deployables)

This collection of sample deployables shows how to use the DeployableXML file in
different ways to achieve different end results.

## [Templates](https://github.com/aeolusproject/audrey/tree/master/examples/templates)

This collection of templates provides some sample templates for building images
with the Audrey Agent or with the Audrey Config Server.

## [SSH Pubkey](https://github.com/aeolusproject/audrey/tree/master/examples/ssh-pubkey)

This example demonstrates how to use Audrey to inject a public key file into a
launching guest.
