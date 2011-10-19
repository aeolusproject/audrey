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
import sys
import tarfile

from audrey_startup import CSClient
from audrey_startup import Config_Tooling
from audrey_startup import ASError
from audrey_startup import parse_args
from audrey_startup import parse_provides_params
from audrey_startup import parse_require_config
from audrey_startup import audrey_script_main
from audrey_startup import gen_env
from audrey_startup import _run_cmd, _run_pipe_cmd
from audrey_startup import generate_provides
from audrey_startup import setup_logging
from audrey_startup import discover_config_server

# Helpers and utils
DUMMY_USER_DATA = '1|http://example.com/|oauthConsumer|oauthSecret'
DUMMY_CS_CONFIG = {'endpoint': 'http://example.com/',
                   'oauth_key': 'oauthConsumer',
                   'oauth_secret': 'oauthSecret',}

try:
    from cStringIO import StringIO as BIO
except ImportError: # python 3
    from io import BytesIO as BIO

class HttpUnitTest(object):
    '''
    Description:
        When testing the http object does not exists. This class provides
        test methods that could be preformed when doing UNITTESTing.
    '''
    class HttpUnitTestResponse(object):
        '''
        Description:
            When testing the http object does not exists. This class
            provides the test method response that could be preformed
            when doing UNITTESTing.
        '''
        def __init__(self, status):
            self.status = status

        def add_content_disposition(self):
            self.__dict__['content-disposition'] = \
                                   'attachment; filename=test.tar.gz'

        def __getitem__(self, key):
            return self.__dict__[key]


    # simple HTTP Response with 200 status code
    ok_response = HttpUnitTestResponse(200)
    not_found_response = HttpUnitTestResponse(404)

    def request(self, url, method='GET', body=None, headers=None):
        '''
        Handle request when not running live but in test environment.
        '''
        body = ''
        response = HttpUnitTest.ok_response
        if method == 'GET':
            if url.find('/configs/') > -1:
                body = '|service|s1|parameters|param1&%s|param2&%s|' % \
                    (base64.b64encode('value1'), base64.b64encode('value2'))
            elif url.find('/params/') > -1:
                body = '|param1&param2|'
            elif url.find('/files/') > -1:
                file_out = BIO()
                tar = tarfile.open(mode = "w:gz", fileobj = file_out)
                tar.add('/etc/passwd')
                tar.close()
                body = file_out.getvalue()
                response.add_content_disposition()
            elif url.endswith('/user-data'):
                body = base64.b64encode(DUMMY_USER_DATA)
            elif url.endswith('/no-version-user-data'):
                body = base64.b64encode('0|endpoint')
            elif url.endswith('/empty-user-data'):
                body = base64.b64encode('')
            elif url.endswith('/gimmie-404'):
                body = base64.b64encode(DUMMY_USER_DATA)
                response = HttpUnitTest.not_found_response
            else:
                print url
                response = HttpUnitTest.not_found_response
        #elif method == 'POST' and url.find('/params/') > -1:
        #    body = ''
        return response, body

def _write_info_file(filepath, cloud):
    f = open(filepath, 'w')
    f.write(cloud)
    f.close()

# The actual tests

class TestAudreyStarupRunCmds(unittest.TestCase):
    '''
    Test the _run*cmd functions
    '''
    def test_success_run_pipe_cmd(self):
        self.assertEqual("'test'\n",
            _run_pipe_cmd(["echo", "'test'"], ["grep", "test"])['out'])

    def test_cmd2_fail_run_pipe_cmd(self):
        self.assertEqual("[Errno 2] No such file or directory",
            _run_pipe_cmd(["echo", "'test'"], ["notreal"])['err'])

    def test_cmd1_fail_run_pipe_cmd(self):
        self.assertEqual("[Errno 2] No such file or directory",
            _run_pipe_cmd(["notreal"], ["echo", "'test'"])['err'])

class TestAudreyStartupConfigTooling(unittest.TestCase):
    '''
    Make sure all the Config tooling is tested
    '''
    def test_is_user_supplied(self):
        Config_Tooling('test_tooling').is_user_supplied('')

    def test_is_rh_supplied(self):
        Config_Tooling('test_tooling').is_rh_supplied('')

    def test_empty_find_tooling(self):
        self.assertRaises(ASError, Config_Tooling('test_tooling').find_tooling, '')

    def test_fail_to_create_tooling_dir(self):
        self.assertRaises(ASError, Config_Tooling, tool_dir='/not/real/dir')

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
                env_var  = 'AUDREY_VAR_' + name_val[0]

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

class TestAudreyStartupDiscovery(unittest.TestCase):
    def setUp(self):
        '''
        Perform required setup including setting up logging.
        '''
        setup_logging(logging.DEBUG, 'test_audrey_startup.log')
        self.cloud_info_file = 'cloud_info'
        self.condor_addr_file = 'condor_addr'
        self.condor_uuid_file = 'condor_uuid'

    def tearDown(self):
        os.remove(self.cloud_info_file)
        if os.path.exists(self.condor_addr_file):
            os.remove(self.condor_addr_file)
        if os.path.exists(self.condor_uuid_file):
            os.remove(self.condor_uuid_file)

    def test_ec2(self):
        _write_info_file(self.cloud_info_file, 'EC2')
        discover_config_server(self.cloud_info_file, http=HttpUnitTest())

    def test_ec2_404(self):
        _write_info_file(self.cloud_info_file, 'EC2')
        self.assertRaises(ASError,
            discover_config_server, self.cloud_info_file, http=HttpUnitTest(),
            ec2_user_data='http://169.254.169.254/gimmie-404')

    def test_condorcloud(self):
        _write_info_file(self.condor_addr_file, '1|endpoint|secret')
        _write_info_file(self.condor_uuid_file, 'key')
        _write_info_file(self.cloud_info_file, 'CONDORCLOUD')
        discover_config_server(self.cloud_info_file,
                               condor_addr_file=self.condor_addr_file,
                               condor_uuid_file=self.condor_uuid_file)

    def test_rhev(self):
        _write_info_file(self.cloud_info_file, 'RHEV')
        self.assertRaises(ASError,
            discover_config_server, self.cloud_info_file)

    def test_vsphere(self):
        _write_info_file(self.cloud_info_file, 'VSPHERE')
        self.assertRaises(ASError,
            discover_config_server, self.cloud_info_file)

    def test_invalid_user_data_version(self):
        _write_info_file(self.cloud_info_file, 'EC2')
        self.assertRaises(ASError,
            discover_config_server, self.cloud_info_file, http=HttpUnitTest(),
            ec2_user_data='http://169.254.169.254/no-version-user-data')

    def test_invalid_user_data_no_delim(self):
        _write_info_file(self.cloud_info_file, 'EC2')
        self.assertRaises(ASError,
            discover_config_server, self.cloud_info_file, http=HttpUnitTest(),
            ec2_user_data='http://169.254.169.254/empty-user-data')


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

        # Create the client Object
        self.cs_client = CSClient(**DUMMY_CS_CONFIG)
        self.cs_client.http = HttpUnitTest()

    def tearDown(self):
        pass

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

    def test_success_get_cs_tooling(self):
        '''
        Success case:
        - Exercise get_cs_tooling()
        '''
        self.cs_client.get_cs_tooling()

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

    def test_success_put_cs_params_values(self):
        '''
        Success case:
        - Exercise put_cs_params_values()
        '''
        self.cs_client.put_cs_params_values('')

    def test_error_http_status(self):
        '''
        Success case:
        - Exercise put_cs_params_values()
        '''
        self.assertRaises(ASError, self.cs_client._validate_http_status, 401)

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
        # make a copy of argv
        self.argv = list(sys.argv)

    def tearDown(self):
        # replace argv
        sys.argv = list(self.argv)

    def test_audrey_script_main(self):
        '''
        Perform what the audrey script will do.
        '''
        cloud_info_file = 'cloud_info'
        sys.argv.extend(['-p'])
        _write_info_file(cloud_info_file, 'EC2')
        audrey_script_main(HttpUnitTest())
        os.remove(cloud_info_file)

    def test_fail_audrey_script_main(self):
        '''
        Perform what the audrey script will do.
        '''
        self.assertRaises(ASError, audrey_script_main)

    def test_audrey_parseargs(self):
        '''
        mainly to provide test coverage.
        '''
        sys.argv.extend(['-e', 'endpoint', '-k', 'oauth_key', '-s', 'oauth_secret'])
        parse_args()
        # Don't need to actually assert, just want to make sure there's no errors

    def test_empty_gen_env(self):
        self.assertRaises(ASError, gen_env, '', '')

    # doesn't actually test what I wanted it to.
    #def test_parse_require_config(self):
    #    self.assertRaises(ASError, parse_require_config, '')

if __name__ == '__main__':

    setup_logging(logging.DEBUG, logfile_name='./test_audrey_startup.log')
    unittest.main()
