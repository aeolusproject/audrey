'''
*
*   Copyright [2011] [Red Hat, Inc.]
*
*   Licensed under the Apache License, Version 2.0 (the "License");
*   you may not use this file except in compliance with the License.
*   You may obtain a copy of the License at
*
*   http://www.apache.org/licenses/LICENSE-2.0
*
*   Unless required by applicable law or agreed to in writing, software
*   distributed under the License is distributed on an "AS IS" BASIS,
*   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*   See the License for the specific language governing permissions and
*  limitations under the License.
*
'''

import unittest
import base64

from audrey import ASError
from audrey.shell import run_cmd
from audrey.csclient.client import CSClient
from audrey.csclient.tooling import ConfigTooling
from audrey.csclient import parse_require_config
from audrey.csclient import parse_provides_params
from audrey.csclient import generate_provides

from tests.mocks import HttpUnitTest

DUMMY_CS_CONFIG = {'endpoint': 'http://example.com/',
                   'oauth_key': 'oauthConsumer',
                   'oauth_secret': 'oauthSecret',}

class TestAudreyCSClient(unittest.TestCase):
    '''
    Class for exercising the gets and put to and from the CS
    '''

    def setUp(self):
        '''
        If the cloud info file is not present assume running in a
        UNITTEST environment. This will allow for exercising some
        of the code without having to be running in a cloud VM.
        '''
        # Create the client Object
        self.cs_client = CSClient(**DUMMY_CS_CONFIG)
        self.cs_client.http = HttpUnitTest()

    def test_success_get_cs_configs(self):
        '''
        Success case:
        - Exercise get_cs_configs()
        '''
        self.cs_client.get_cs_configs()

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
        self.cs_client.get_cs_params()

    def test_success_get_cs_confs_n_params(self):
        '''
        Success case:
        - Exercise get_cs_configs() and get_cs_params()
        '''
        self.cs_client.get_cs_configs()
        self.cs_client.get_cs_params()


    def test_success_put_cs_params_values(self):
        '''
        Success case:
        - Exercise put_cs_params_values()
        '''
        self.cs_client.put_cs_params_values('')

    def test_error_http_status(self):
        '''
        Success case:
        - Get a 401
        '''
        self.assertRaises(ASError, self.cs_client._validate_http_status, 401)

    def test_catch_get_exception(self):
        '''
        Success case:
        - get fails but audrey recovers
        '''
        self.cs_client._get('http://hostname/raiseException')

    def test_catch_put_exception(self):
        '''
        Success case:
        - put fails but audrey recovers
        '''
        self.cs_client._put('http://hostname/raiseException')

class TestAudreyStartupConfigTooling(unittest.TestCase):
    '''
    Make sure all the Config tooling is tested
    '''
    def test_is_user_supplied(self):
        ConfigTooling('test_tooling').is_user_supplied()

    def test_is_rh_supplied(self):
        ConfigTooling('test_tooling').is_rh_supplied()

    def test_empty_find_tooling(self):
        self.assertRaises(ASError, ConfigTooling('test_tooling').find_tooling, '')

    def test_fail_to_create_tooling_dir(self):
        self.assertRaises(ASError, ConfigTooling, tool_dir='/not/real/dir')

class TestAudreyStartupRequiredConfig(unittest.TestCase):
    '''
    Class for exercising the parsing of the Required Configs from the CS.
    '''

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

        # Exersise code segment
        services = parse_require_config(src)

        # Validate results
        self.assertEqual(services[0].name, 'jon1')
        self.assertEqual(services[1].name, 'jon2')

        for service in services:
            for param in service.params:
                name_val = param.split('&')
                env_var  = 'AUDREY_VAR_' + service.name + '_' + name_val[0]
                cmd = ['/usr/bin/printenv', env_var]
                ret = run_cmd(cmd)
                self.assertEqual(ret['out'][:-1], \
                    validation_dict[env_var])

    def test_success_empty_source(self):
        '''
        Success case:
        - Exercise parse_require_config() with valid empty input
        '''

        src = '||'
        services = parse_require_config(src)
        self.assertEqual(services, [])

    def test_success_empty_service(self):
        '''
        Failure case:
        - Exercise parse_require_config() with valid input
        '''

        src = '|service|' + \
            '|parameters|jon_server_ip&' + base64.b64encode('192.168.1.1') + \
            '|jon_server_ip_2&' + base64.b64encode('192.168.1.2') + \
            '|jon_server_ip_3&' + base64.b64encode('192.168.1.3') + \
            '|service|jon2|'

        validation_dict = {'AUDREY_VAR_jon_server_ip' : '192.168.1.1',
            'AUDREY_VAR_jon_server_ip_2' : '192.168.1.2',
            'AUDREY_VAR_jon_server_ip_3' : '192.168.1.3' }

        services = parse_require_config(src)
        self.assertEqual(services[0].name, '')
        self.assertEqual(services[1].name, 'jon2')

        for service in services:
            for param in service.params:
                name_val = param.split('&')
                env_var  = 'AUDREY_VAR_' + name_val[0]
                cmd = ['/usr/bin/printenv', env_var]
                ret = run_cmd(cmd)
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

        self.assertRaises(ASError, parse_require_config, src)

    def test_failure_bad_service_name(self):
        '''
        Failure case:
        - Exercise parse_require_config() with valid input
        '''

        src = '|service|parameters|'
        self.assertRaises(ASError, parse_require_config, src)

    def test_failure_service_tag_not_found(self):
        '''
        Failure Case:
        - |service| not in src to parse_require_config()
        '''
        src = '|notservice|blah|'
        self.assertRaises(ASError, parse_require_config, src)

    def test_failure_no_amp_delim(self):
        '''
        Failure Case:
        - no delim in param token
        '''
        src = '|service|blah|parameters|blah|'
        self.assertRaises(ASError, parse_require_config, src)


class TestAudreyStartupProvidesParameters(unittest.TestCase):
    '''
    Class for exercising the parsing of the Provides ParametersConfigs
    from the CS.
    '''

    def test_success_parameters(self):
        '''
        Success case:
        - Exercise parse_provides_params() and generate_provides()
          with valid input
        '''

        src = '|operatingsystem&is_virtual|'
        expected_params_list = ['operatingsystem', 'is_virtual']

        params_list = parse_provides_params(src)
        provides = generate_provides(src)
        self.assertEqual(params_list, expected_params_list)

        # The values are not validatable because they are unpredictable
        # but all the expected parameters should be returned.
        # Note: %7C is the encoded |, %26 is the encoded &
        self.assertTrue('audrey_data=%7Coperatingsystem' in provides)
        for param in expected_params_list:
            self.assertTrue('%7C' + str(param) in provides)

    def test_success_empty_params(self):
        '''
        Success case:
        - Exercise parse_provides_params() and generate_provides()
          with valid demlims but empty input
        '''
        src = '||'
        params_list = parse_provides_params(src)
        provides = generate_provides(src)
        self.assertEqual(params_list, [''])
        self.assertEqual(provides, 'audrey_data=%7C%26%7C')

    def test_success_no_params(self):
        '''
        Success case:
        - Exercise parse_provides_params() and generate_provides()
          with valid input
        - Containging an unavailable parameter
        '''

        src = '|uptime_days&unavailable_dogs&ipaddress|'
        expected_params_list = ['uptime_days', 'unavailable_dogs', 'ipaddress']

        params_list = parse_provides_params(src)
        provides = generate_provides(src)

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
        expected_params_list = ['uptime_days']

        # Exersise code segment
        params_list = parse_provides_params(src)
        provides = generate_provides(src)

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

        src = '|unavailable_dogs|'
        expected_params_list = ['unavailable_dogs']

        params_list = parse_provides_params(src)
        provides = generate_provides(src)
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

        src = 'unavailable_dogs|'
        expected_params_list = ['unavailable_dogs']

        self.assertRaises(ASError, parse_provides_params, src)
        self.assertRaises(ASError, generate_provides, src)
