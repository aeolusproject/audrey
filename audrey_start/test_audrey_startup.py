#!/usr/bin/python2.6

'''
 test_audrey_startup.py

 Test program for audrey_startup
'''

import base64
import logging
import os
import os.path
import tempfile
import unittest

from audrey_startup import *
from audrey_startup import parse_provides_params
from audrey_startup import parse_require_config
from audrey_startup import _run_cmd
from audrey_startup import setup_logging

class TestAudreyStartupRequiredConfig(unittest.TestCase):
    '''
    Class for exercising the parsing of the Required Configs from the CS.
    '''

    def setUp(self):
        '''
        Perform required setup including setting up logging.
        '''
        setup_logging(logging.DEBUG, './test_audrey_startup.log')

    def test_success_service_n_params(self):
        '''
        Success case:
        - Exercise parse_require_config() with valid input
        '''
        # Establish valid test data:

        src = '|service|jon1' + \
            '|parameters|jon_server_ip&' + base64.b64encode('192.168.1.1') + \
            '|jon_server_ip_2&' + base64.b64encode('192.168.1.2') + \
            '|jon_server_ip_3&' + base64.b64encode('192.168.1.3') + \
            '|service|jon2|'

        validation_dict = {'AUDREY_VAR_jon1_jon_server_ip' : '192.168.1.1',
            'AUDREY_VAR_jon1_jon_server_ip_2' : '192.168.1.2',
            'AUDREY_VAR_jon1_jon_server_ip_3' : '192.168.1.3' }

        print '\nTest Name: test_success_service_n_params()'
        print 'Test input:\n' + src
        print 'Expect: parse_require_config() success'

        # Exersise code segment
        services = parse_require_config(src)

        # Validate results
        self.assertEqual(services[0].name, 'jon1')
        self.assertEqual(services[1].name, 'jon2')

        for service in services:
            for param in service.params:
                name_val = param.split('&')
                if service.name == '':
                    env_var  = 'AUDREY_VAR_' + name_val[0]
                else:
                    env_var  = 'AUDREY_VAR_' + service.name + '_' + name_val[0]
                print 'name_val[0]:   ' + str(name_val[0])
                print 'param:         ' + str(param)
                print 'services.name: ' + str(service.name)

                cmd = ['/usr/bin/printenv', env_var]
                ret = _run_cmd(cmd)
                self.assertEqual(ret['out'][:-1], \
                    validation_dict[env_var])

    def test_success_empty_source(self):
        '''
        Success case:
        - Exercise parse_require_config() with valid empty input
        '''

        # Establish valid test data:
        src = '||'
        print '\nTest Name: test_success_empty_source()'
        print 'Test input:\n' + src
        print 'Expect: parse_require_config() success'

        # Exersise code segment
        services = parse_require_config(src)
        print 'services: ' + str(services)

        # Validate results
        self.assertEqual(services, [])

    def test_success_empty_service(self):
        '''
        Failure case:
        - Exercise parse_require_config() with valid input
        '''

        # Establish valid test data:
        src = '|service|' + \
            '|parameters|jon_server_ip&' + base64.b64encode('192.168.1.1') + \
            '|jon_server_ip_2&' + base64.b64encode('192.168.1.2') + \
            '|jon_server_ip_3&' + base64.b64encode('192.168.1.3') + \
            '|service|jon2|'

        validation_dict = {'AUDREY_VAR_jon_server_ip' : '192.168.1.1',
            'AUDREY_VAR_jon_server_ip_2' : '192.168.1.2',
            'AUDREY_VAR_jon_server_ip_3' : '192.168.1.3' }

        print '\nTest Name: test_success_empty_service()'
        print 'Test input:\n' + src
        print 'Expect: parse_require_config() success'

        # Exersise code segment
        services = parse_require_config(src)

        # Validate results
        self.assertEqual(services[0].name, '')
        self.assertEqual(services[1].name, 'jon2')

        for service in services:
            for param in service.params:
                name_val = param.split('&')
                if service.name == '':
                    env_var  = 'AUDREY_VAR_' + name_val[0]
                else:
                    env_var  = 'AUDREY_VAR_' + service.name + '_' + name_val[0]

                print 'name_val[0]:   ' + str(name_val[0])
                print 'param:         ' + str(param)
                print 'services.name: ' + str(service.name)

                cmd = ['/usr/bin/printenv', env_var]
                ret = _run_cmd(cmd)
                self.assertEqual(ret['out'][:-1], \
                    validation_dict[env_var])

    def test_failure_no_services_name(self):
        '''
        Failure case:
        - Exercise parse_require_config() with valid input

        The slight difference between this test and test_success_empty_services
        is the success case has an empty service name indicated by "||":
        |service||paramseters

        and the failure case has no service name:
        |service|paramseters

        '''

        # Establish valid test data:
        src = '|service' \
            '|parameters|jon_server_ip&' + base64.b64encode('192.168.1.1') + \
            '|jon_server_ip_2&' + base64.b64encode('192.168.1.2') + \
            '|jon_server_ip_3&' + base64.b64encode('192.168.1.3') + \
            '|service|jon2|'

        validation_dict = {'AUDREY_VAR_jon_server_ip' : '192.168.1.1',
            'AUDREY_VAR_jon_server_ip_2' : '192.168.1.2',
            'AUDREY_VAR_jon_server_ip_3' : '192.168.1.3' }

        print '\nTest Name: test_failure_no_service_names()'
        print 'Test input:\n' + src
        print 'Expect: parse_require_config() success'

        # Exersise code segment
        with self.assertRaises(ASError):
            print 'parse_require_config returned: ' + \
                str(parse_require_config(src))

    def test_failure_bad_service_name(self):
        '''
        Failure case:
        - Exercise parse_require_config() with valid input
        '''

        # Establish valid test data:
        src = '|service|parameters|'
        print '\nTest Name: test_failure_bad_service_name()'
        print 'Test input:\n' + src
        print 'Expect: parse_require_config() ASError'

        # Exersise code segment
        with self.assertRaises(ASError):
            print 'parse_require_config returned: ' + \
                str(parse_require_config(src))

class TestAudreyStartupProvidesParameters(unittest.TestCase):
    '''
    Class for exercising the parsing of the Provides ParametersConfigs
    from the CS.
    '''

    def setUp(self):
        '''
        Perform required setup including setting up logging.
        '''
        setup_logging(logging.DEBUG, './test_audrey_startup.log')

    def test_success_parameters(self):
        '''
        Success case:
        - Exercise parse_provides_params() and generate_provides()
          with valid input
        '''

        # Establish valid test data:
        src = '|operatingsystem&is_virtual|'

        print '\nTest Name: test_success_parameters()'
        print 'Test input:\n' + src
        print 'Expect: parse_provides_params() success'

        expected_params_list = ['operatingsystem', 'is_virtual']

        # Exersise code segment
        params_list = parse_provides_params(src)
        provides = generate_provides(src)
        print 'src: ' + str(src)
        print 'params_list: ' + str(params_list)
        print 'provides: ' + str(provides)
        print 'len(provides): ' + str(len(provides))

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
        - Exercise parse_provides_params() and generate_provides()
          with valid input
        - Containging an unavailable parameter
        '''

        # Establish valid test data:
        src = '|uptime_days&unavailable_dogs&ipaddress|'

        print '\nTest Name: test_success_no_params()'
        print 'Test input:\n' + src
        print 'Expect: parse_provides_params() success'

        expected_params_list = ['uptime_days', 'unavailable_dogs', 'ipaddress']

        # Exersise code segment
        params_list = parse_provides_params(src)
        provides = generate_provides(src)
        print 'src: ' + str(src)
        print 'params_list: ' + str(params_list)
        print 'provides: ' + str(provides)

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
        - Exercise parse_provides_params() and generate_provides()
          with valid input
        - with only one parameter
        '''

        # Establish valid test data:
        src = '|uptime_days|'

        print '\nTest Name: test_success_parameters()'
        print 'Test input:\n' + src
        print 'Expect: parse_provides_params() success'

        expected_params_list = ['uptime_days']

        # Exersise code segment
        params_list = parse_provides_params(src)
        provides = generate_provides(src)
        print 'src: ' + str(src)
        print 'params_list: ' + str(params_list)
        print 'provides: ' + str(provides)

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
        - Exercise parse_provides_params() and generate_provides()
          with valid input
        - With only one parameter which is unavailable
        '''

        # Establish valid test data:
        src = '|unavailable_dogs|'

        print '\nTest Name: test_success_one_parameter()'
        print 'Test input:\n' + src
        print 'Expect: parse_provides_params() success'

        expected_params_list = ['unavailable_dogs']

        # Exersise code segment
        params_list = parse_provides_params(src)
        provides = generate_provides(src)
        print 'src: ' + str(src)
        print 'params_list: ' + str(params_list)
        print 'provides: ' + str(provides)

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
        - Exercise parse_provides_params() and generate_provides()
          with invalid input
        - missing leading delimiter
        '''

        # Establish valid test data:
        src = 'unavailable_dogs|'

        print '\nTest Name: test_failure_missing_delimiter()'
        print 'Test input:\n' + src
        print 'Expect: parse_require_config() ASError'

        expected_params_list = ['unavailable_dogs']

        # Exersise code segment and validate results
        with self.assertRaises(ASError):
            params_list = parse_provides_params(src)

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

        Set up logging.
        '''

        setup_logging(logging.DEBUG, './test_audrey_startup.log')

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
                'http://169.254.169.254/latest/user-data')
            self.assertEqual(self.cs_client.cloud_type,  'UNITTEST')
            self.assertEqual(self.cs_client.cs_addr, 'csAddr')
            self.assertEqual(self.cs_client.cs_port, 'csPort')
            self.assertEqual(self.cs_client.cs_UUID, 'csUUID')
            self.assertEqual(self.cs_client.cs_pw, 'csPW')
            self.assertEqual(self.cs_client.config_serv, \
                'csAddr:csPort:csUUID:csPW')
        else:
            self.assertEqual(self.cs_client.ec2_user_data_url, \
                'http://169.254.169.254/latest/user-data')
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
        print 'JJV -010- test_success_get_cs_configs() Add asserts'
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
        print 'JJV -010- test_success_get_cs_params() Add asserts'
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
        print 'JJV -010- test_success_get_cs_confs_n_params() Add asserts'
        print 'self.cs_client : START \n' + str(self.cs_client) + \
            '\nself.cs_client : END'
        print 'JJV -011- test_success_get_cs_confs_n_params() Add asserts'

class TestAudreyScript(unittest.TestCase):
    '''
    Class for exercising the full audrey script functionality
    '''

    def setUp(self):
        '''
        Perform required setup including setting up logging.

        This test currently require to be run in a cloud VM
        with a live Config Server.
        '''
        setup_logging(logging.DEBUG, './test_audrey_startup.log')


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

        # Get the requested provides from the Config Server
        params = self.cs_client.get_cs_params()

        # Generate the values for the requested provides parameters.
        params_values = generate_provides(params)

        # JJV Add asserts
        print 'JJV -010- test_audrey_script_main() Add asserts'
        print 'self.cs_client : START \n' + str(self.cs_client) + \
            '\nself.cs_client : END'

        print 'configs: \n' + str(configs)
        print 'params: \n' + str(params)
        print 'params_values: \n' + str(params_values)

        # Put the requested provides with values to the Config Server
        self.cs_client.put_cs_params_values(params_values)

if __name__ == '__main__':

    setup_logging()
    unittest.main()

