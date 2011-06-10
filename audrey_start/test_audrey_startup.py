#!/usr/bin/python2.6

'''
 test_audrey_startup.py

 Test program for audrey_startup
'''

import base64
import os
import os.path
import tempfile
import unittest

from audrey_startup import *
from audrey_startup import _parse_provides_params
from audrey_startup import _parse_require_config 

class TestAudreyStartupRequiredConfig(unittest.TestCase):
    '''
    Class for exercising the parsing of the Required Configs from the CS.
    '''

    def test_success_class_n_params(self):
        '''
        Success case:
        - Exercise _parse_require_config() with valid input
        '''
 
        print 'JJV 01 hi'
 
        # Establish valid test data:
        src = '|classes&ssh::server&apache2::common' \
            '|parameters|ssh_port&' + base64.b64encode('<b64/22>') + \
            '|apache_port&' + base64.b64encode('<b64/8081>') + '|'
        print '\nTest Name: test_success_class_n_params()'
        print 'Test input:\n' + src
        print 'Expect: _parse_require_config() success'
        print 'Expect: generate_yaml() True'
        
        expected_params_list = ['ssh_port&' + base64.b64encode('<b64/22>'),
            'apache_port&' + base64.b64encode('<b64/8081>')]
        expected_classes_list = ['ssh::server', 'apache2::common']

        # Exersise code segment
        params_list, classes_list = _parse_require_config(src)

        # Validate results
        self.assertEqual(params_list, expected_params_list)
        self.assertEqual(classes_list, expected_classes_list)

        with tempfile.NamedTemporaryFile() as tmpf:
            print 'generate_yaml returned: ' + str(generate_yaml(src,
                yaml_file=tmpf.name))

    def test_success_empty_class_n_params(self):
        '''
        Success case:
        - Exercise _parse_require_config() with valid empty input
        '''
 
        # Establish valid test data:
        src = '||'
        print '\nTest Name: test_success_empty_class_n_params()'
        print 'Test input:\n' + src
        print 'Expect: _parse_require_config() success'
        print 'Expect: generate_yaml() False'
        
        expected_params_list = ['']
        expected_classes_list = ['']

        # Exersise code segment
        params_list, classes_list = _parse_require_config(src)

        # Validate results
        self.assertEqual(params_list, expected_params_list)
        self.assertEqual(classes_list, expected_classes_list)

        # this is only safe on unix filesystems
        with tempfile.NamedTemporaryFile() as tmpf:
            print 'generate_yaml returned: ' + str(generate_yaml(src,
                yaml_file=tmpf.name))

    def test_success_no_class_n_params(self):
        '''
        Success case:
        - Exercise _parse_require_config() with valid input
        '''
 
        # Establish valid test data:
        src = '|classes|parameters|'
        print '\nTest Name: test_success_no_class_n_params()'
        print 'Test input:\n' + src
        print 'Expect: _parse_require_config() success'
        print 'Expect: generate_yaml() False'

        expected_params_list = ['']
        expected_classes_list = ['']

        # Exersise code segment
        params_list, classes_list = _parse_require_config(src)

        # Validate results
        self.assertEqual(params_list, expected_params_list)
        self.assertEqual(classes_list, expected_classes_list)

        with tempfile.NamedTemporaryFile() as tmpf:
            print 'generate_yaml returned: ' + \
                str(generate_yaml(src, yaml_file=tmpf.name))

    def test_failure_empty_classes(self):
        '''
        Failure case:
        - Exercise _parse_require_config() with valid input
        '''
 
        # Establish valid test data:
        src = '|classes' \
            '|parameters|ssh_port&' + base64.b64encode('<b64/22>') + \
            '|apache_port&' + base64.b64encode('<b64/8081>') + '|'
        print '\nTest Name: test_failure_empty_classes()'
        print 'Test input:\n' + src
        print 'Expect: _parse_require_config() success'
        print 'Expect: generate_yaml() ASError'
        
        expected_params_list = ['ssh_port&' + base64.b64encode('<b64/22>'),
            'apache_port&' + base64.b64encode('<b64/8081>')]
        expected_classes_list = ['']

        # Exersise code segment
        params_list, classes_list = _parse_require_config(src)

        # Validate results
        self.assertEqual(params_list, expected_params_list)
        self.assertEqual(classes_list, expected_classes_list)

        # Exersise code segment
        with self.assertRaises(ASError):
            print 'generate_yaml returned: ' + str(generate_yaml(src))

    def test_failure_empty_parameters(self):
        '''
        Failure case:
        - Exercise _parse_require_config() with valid input
        '''
 
        # Establish valid test data:
        src = '|classes&ssh::server&apache2::common|parameters|'
        print '\nTest Name: test_failure_empty_parameters()'
        print 'Test input:\n' + src
        print 'Expect: _parse_require_config() success'
        print 'Expect: generate_yaml() ASError'
        
        expected_params_list = ['']
        expected_classes_list = ['ssh::server', 'apache2::common']

        # Exersise code segment
        params_list, classes_list = _parse_require_config(src)

        # Validate results
        self.assertEqual(params_list, expected_params_list)
        self.assertEqual(classes_list, expected_classes_list)

        # Exersise code segment
        with self.assertRaises(ASError):
            print 'generate_yaml returned: ' + str(generate_yaml(src))

    def test_failure_missing_delimeters(self):
        '''
        Failure case:
        - missing either or both leading and trailing '|'
        '''
 
        # Establish invalid test data:
        # missing leading '|'
        src = 'classes&ssh::server&apache2::common' \
            '|parameters|ssh_port&' + base64.b64encode('<b64/22>') + \
            '|apache_port&' + base64.b64encode('<b64/8081>') + '|'
        print '\nTest Name: test_failure_missing_delimeters() -0A0-'
        print 'Test input:\n' + src
        print 'Expect: _parse_require_config() ASError'
        print 'Expect: generate_yaml() ASError'

        with self.assertRaises(ASError):
            params_list, classes_list = _parse_require_config(src)

        with self.assertRaises(ASError):
            print 'generate_yaml returned: ' + str(generate_yaml(src))

        # Establish invalid test data:
        # missing trailing '|'
        src = '|classes&ssh::server&apache2::common' \
            '|parameters|ssh_port&' + base64.b64encode('<b64/22>') + \
            '|apache_port&' + base64.b64encode('<b64/8081>')
        print '\nTest Name: test_failure_missing_delimeters() -0B0-'
        print 'Test input:\n' + src
        print 'Expect: _parse_require_config() ASError'
        print 'Expect: generate_yaml() ASError'

        with self.assertRaises(ASError):
            params_list, classes_list = _parse_require_config(src)

        with self.assertRaises(ASError):
            print 'generate_yaml returned: ' + str(generate_yaml(src))

        # Establish invalid test data:
        # missing both leading and trailing '|'
        src = 'classes&ssh::server&apache2::common' \
            '|parameters|ssh_port&' + base64.b64encode('<b64/22>') + \
            '|apache_port&' + base64.b64encode('<b64/8081>')
        print '\nTest Name: test_failure_missing_delimeters() -0C0-'
        print 'Test input:\n' + src
        print 'Expect: _parse_require_config() ASError'
        print 'Expect: generate_yaml() ASError'

        with self.assertRaises(ASError):
            params_list, classes_list = _parse_require_config(src)

        with self.assertRaises(ASError):
            print 'generate_yaml returned: ' + str(generate_yaml(src))

    def test_failure_bad_tag_placement(self):
        '''
        Failure case:
        - Incorrect placement |classes and |parameters tags.
          |classes must be at src[0]
        '''
 
        # Establish invalid test data:
        # Incorrect classes tag placement
        src = '|parameters|ssh_port&' + base64.b64encode('<b64/22>') + \
            '|apache_port&' + base64.b64encode('<b64/8081>') + \
            '|classes&ssh::server&apache2::common|'
        print '\nTest Name: test_failure_bad_tag_placement()'
        print 'Test input:\n' + src
        print 'Expect: _parse_require_config() ASError'
        print 'Expect: generate_yaml() ASError'

        with self.assertRaises(ASError):
            params_list, classes_list = _parse_require_config(src)

        with self.assertRaises(ASError):
            print 'generate_yaml returned: ' + str(generate_yaml(src))

class TestAudreyStartupProvidesParameters(unittest.TestCase):
    '''
    Class for exercising the parsing of the Provides ParametersConfigs
    from the CS.
    '''

    def test_success_parameters(self):
        '''
        Success case:
        - Exercise _parse_provides_params() and generate_provides()
          with valid input
        '''
 
        # Establish valid test data:
        src = '|operatingsystem&is_virtual|'

        print '\nTest Name: test_success_parameters()'
        print 'Test input:\n' + src
        print 'Expect: _parse_provides_params() success'
        
        expected_params_list = ['operatingsystem', 'is_virtual']

        # Exersise code segment
        params_list = _parse_provides_params(src)
        provides = generate_provides(src)
        print 'JJV -010- src: ' + str(src)
        print 'JJV -011- params_list: ' + str(params_list)
        print 'JJV -012- provides: ' + str(provides)
        print 'JJV -013- len(provides): ' + str(len(provides))

        # Validate results
        self.assertEqual(params_list, expected_params_list)

        # The values are not validatable because they are unpredictable
        # but all the expected parameters should be returned.
        # Note: %7C is the encoded |, %26 is the encoded &
        self.assertTrue('audrey_data=%7Coperatingsystem' in provides)
        for param in expected_params_list:
            self.assertTrue('%7C' + str(param) in provides)

    def test_success_no_params(self):
        '''
        Success case:
        - Exercise _parse_provides_params() and generate_provides()
          with valid input
        - Containging an unavailable parameter
        '''
 
        # Establish valid test data:
        src = '|uptime_days&unavailable_dogs&ipaddress|'

        print '\nTest Name: test_success_no_params()'
        print 'Test input:\n' + src
        print 'Expect: _parse_provides_params() success'
        
        expected_params_list = ['uptime_days', 'unavailable_dogs', 'ipaddress']

        # Exersise code segment
        params_list = _parse_provides_params(src)
        provides = generate_provides(src)
        print 'JJV -010- src: ' + str(src)
        print 'JJV -011- params_list: ' + str(params_list)
        print 'JJV -012- provides: ' + str(provides)

        # Validate results
        self.assertEqual(params_list, expected_params_list)

        # The values are not validatable because they are unpredictable
        # but all the expected parameters should be returned.
        # Note: %7C is the encoded |, %26 is the encoded &
        for param in expected_params_list:
            self.assertTrue('%7C' + str(param) in provides)

        # Confirm unavailable parameters return an empty string.
        self.assertTrue('%7C' + 'unavailable_dogs' + '%26%7C' in provides)

    def test_success_one_parameters(self):
        '''
        Success case:
        - Exercise _parse_provides_params() and generate_provides()
          with valid input
        - with only one parameter
        '''
 
        # Establish valid test data:
        src = '|uptime_days|'

        print '\nTest Name: test_success_parameters()'
        print 'Test input:\n' + src
        print 'Expect: _parse_provides_params() success'
        
        expected_params_list = ['uptime_days']

        # Exersise code segment
        params_list = _parse_provides_params(src)
        provides = generate_provides(src)
        print 'JJV -010- src: ' + str(src)
        print 'JJV -011- params_list: ' + str(params_list)
        print 'JJV -012- provides: ' + str(provides)

        # Validate results
        self.assertEqual(params_list, expected_params_list)

        # The values are not validatable because they are unpredictable
        # but all the expected parameters should be returned.
        # Note: %7C is the encoded |, %26 is the encoded &
        for param in expected_params_list:
            self.assertTrue('%7C' + str(param) in provides)

    def test_success_one_parameter(self):
        '''
        Success case:
        - Exercise _parse_provides_params() and generate_provides()
          with valid input
        - With only one parameter which is unavailable
        '''
 
        # Establish valid test data:
        src = '|unavailable_dogs|'

        print '\nTest Name: test_success_one_parameter()'
        print 'Test input:\n' + src
        print 'Expect: _parse_provides_params() success'
        
        expected_params_list = ['unavailable_dogs']

        # Exersise code segment
        params_list = _parse_provides_params(src)
        provides = generate_provides(src)
        print 'JJV -010- src: ' + str(src)
        print 'JJV -011- params_list: ' + str(params_list)
        print 'JJV -012- provides: ' + str(provides)

        # Validate results
        self.assertEqual(params_list, expected_params_list)

        # The values are not validatable because they are unpredictable
        # but all the expected parameters should be returned.
        # Note: %7C is the encoded |, %26 is the encoded &
        for param in expected_params_list:
            self.assertTrue('%7C' + str(param) in provides)

        # Confirm unavailable parameters return an empty string.
        self.assertTrue('%7C' + 'unavailable_dogs' + '%26%7C' in provides)

    def test_failure_missing_delimiter(self):
        '''
        Failure case:
        - Exercise _parse_provides_params() and generate_provides()
          with invalid input
        - missing leading delimiter
        '''
 
        # Establish valid test data:
        src = 'unavailable_dogs|'

        print '\nTest Name: test_failure_missing_delimiter()'
        print 'Test input:\n' + src
        print 'Expect: _parse_require_config() ASError'
        print 'Expect: generate_yaml() ASError'
        
        expected_params_list = ['unavailable_dogs']

        # Exersise code segment and validate results
        with self.assertRaises(ASError):
            params_list = _parse_provides_params(src)

        with self.assertRaises(ASError):
            provides = generate_provides(src)

class TestConfigServerClient(unittest.TestCase):
    '''
    Class for exercising the gets and put to and from the CS
    '''

    def setUp(self):
        '''
        If the cloud info file is not present assume running in a
        UNITTEST environment. This will allow for exercising some
        of the code without having to be running in a cloud VM.
        '''
        if os.path.exists('/etc/sysconfig/cloud-info'):
            self.cs_client_unittest = False
        else:
            self.cs_client_unittest = True

        # Create the client Object
        self.cs_client = CSClient(self.cs_client_unittest)

    def tearDown(self):
        pass

    def test_success_csclient_init(self):
        '''
        Success case:
        - Exercise cs_client __init__ method
        '''
        print '\n\n--- Test Name: test_success_csclient_init ---'

        print 'self.cs_client : START \n' + str(self.cs_client) + \
            '\nself.cs_client : END'

        #print 'errstr: ' + str(self.cs_client.curlp.errstr())
        #print 'HTTP_CODE: ' + \
            #str(self.cs_client.curlp.getinfo(pycurl.HTTP_CODE))
        #print 'EFFECTIVE_URL: ' + \
            #str(self.cs_client.curlp.getinfo(pycurl.EFFECTIVE_URL))

        if self.cs_client_unittest:
            self.assertEqual(self.cs_client.ec2_user_data_url, \
                'http://169.254.169.254/2009-04-04/user-data')
            self.assertEqual(self.cs_client.cloud_type,  'UNITTEST')
            self.assertEqual(self.cs_client.cs_addr, 'csAddr')
            self.assertEqual(self.cs_client.cs_port, 'csPort')
            self.assertEqual(self.cs_client.cs_UUID, 'csUUID')
            self.assertEqual(self.cs_client.cs_pw, 'csPW')
            self.assertEqual(self.cs_client.config_serv, \
                'csAddr:csPort:csUUID:csPW')
        else:
            self.assertEqual(self.cs_client.ec2_user_data_url, \
                'http://169.254.169.254/2009-04-04/user-data')
            self.assertEqual(self.cs_client.cloud_type,  'EC2')

            # For live nondeterministic data check for not blank.
            self.assertNotEqual(self.cs_client.cs_addr, '')
            self.assertNotEqual(self.cs_client.cs_port, '')
            self.assertNotEqual(self.cs_client.cs_UUID, '')
            self.assertNotEqual(self.cs_client.cs_pw, '')
            self.assertNotEqual(self.cs_client.config_serv, '')

    def test_success_get_cs_configs(self):
        '''
        Success case:
        - Exercise get_cs_configs()
        '''
        print '\n\n--- Test Name: test_success_get_cs_configs ---'

        self.cs_client.get_cs_configs()

        # JJV Add asserts
        print 'self.cs_client : START \n' + str(self.cs_client) + \
            '\nself.cs_client : END'

    def test_success_get_cs_params(self):
        '''
        Success case:
        - Exercise get_cs_params()
        '''
        print '\n\n--- Test Name: test_success_get_cs_params ---'

        self.cs_client.get_cs_params()

        # JJV Add asserts
        print 'self.cs_client : START \n' + str(self.cs_client) + \
            '\nself.cs_client : END'

    def test_success_get_cs_confs_n_params(self):
        '''
        Success case:
        - Exercise get_cs_configs() and get_cs_params()
        '''
        print '\n\n--- Test Name: test_success_get_cs_confs_and_params ---'

        self.cs_client.get_cs_configs()
        self.cs_client.get_cs_params()

        # JJV Add asserts
        print 'self.cs_client : START \n' + str(self.cs_client) + \
            '\nself.cs_client : END'

class TestAudreyScript(unittest.TestCase):
    '''
    Class for exercising the full audrey script functionality
    '''

    def setUp(self):
        '''
        This test currently require to be run in a cloud VM
        with a live Config Server.
        '''

    def tearDown(self):
        pass

    def test_audrey_script_main(self):
        '''
        Perform what the audrey script will do.
        This test has been added as a diagnostic aid.
        '''
        print '\n\n--- Test Name: test_audrey_script_main  ---'

        # Only run this test on a cloud VM were the cloud-info file has
        # been built into this image.
        if not os.path.exists('/etc/sysconfig/cloud-info'):
            return

        # Create the client Object
        self.cs_client = CSClient()

        # Get the Required Configs from the Config Server
        configs = self.cs_client.get_cs_configs()

        # Generate the YAML file using the provided required configs
        generate_yaml(configs)

        # Exercise Puppet using the generated YAML
        #
        # Exercise puppet to configure the system using the user
        # specified puppet input.
        #
        invoke_puppet()

        # Get the requested provides from the Config Server
        params = self.cs_client.get_cs_params()

        # Generate the values for the requested provides parameters.
        params_values = generate_provides(params)

        # JJV Add asserts
        print 'self.cs_client : START \n' + str(self.cs_client) + \
            '\nself.cs_client : END'

        print 'configs: \n' + str(configs)
        print 'params: \n' + str(params)
        print 'params_values: \n' + str(params_values)

        # Put the requested provides with values to the Config Server
        self.cs_client.put_cs_params_values(params_values)

if __name__ == '__main__':

    print 'JJV 01 hi'
    unittest.main()
    print 'JJV 02 bye'

