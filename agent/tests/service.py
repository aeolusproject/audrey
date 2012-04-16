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

from audrey.errors import AAError
from audrey.shell import run_cmd
from audrey.factory import AudreyFactory

from tests.mocks import DUMMY_CS_CONFIG
from tests.mocks import DUMMY_SERVICE_CONFIG_DATA
from tests.mocks import DUMMY_NO_SERVICE_CONFIG_DATA
from tests import _write_file


class TestAudreyAgentServiceV1(unittest.TestCase):
    '''
    Class for exercising the parsing of the Required Configs from the CS.
    '''

    def setUp(self):
        self.factory = AudreyFactory(1)
        self.service = self.factory.service('test_service')

    def test_success_service_n_provides(self):
        '''
        Success case:
        - Exercise service().parse_require_config() with valid input
        '''
        # Exersise code segment
        services = self.factory.service('jon1').parse_require_config(
                                                     DUMMY_SERVICE_CONFIG_DATA)

        # Validate results
        self.assertEqual(services[0].name, 'jon1')
        self.assertEqual(services[1].name, 'jon2')

        ## ## TODO: verify the env variable else where
        #for service in services:
        #    for param in service.params:
        #        name_val = param.split('&')
        #        env_var = 'AUDREY_VAR_' + service.name + '_' + name_val[0]
        #        cmd = ['/usr/bin/printenv', env_var]
        #        ret = run_cmd(cmd)
        #        self.assertEqual(ret['out'][:-1], \
        #            VALIDATE_SERVICE_CONFIG_DATA[env_var])

    def test_success_empty_source(self):
        '''
        Success case:
        - Exercise service().parse_require_config() with valid empty input
        '''

        src = '||'
        services = self.service.parse_require_config(src)
        self.assertEqual(services, [])

    def test_success_empty_service(self):
        '''
        Failure case:
        - Exercise service().parse_require_config() with valid input
        '''

        services = self.factory.service('').parse_require_config(
                                                  DUMMY_NO_SERVICE_CONFIG_DATA)
        self.assertEqual(services[0].name, '')
        self.assertEqual(services[1].name, 'jon2')

        ## ## TODO: verify the env variable else where
        #for service in services:
        #    for param in service.params:
        #        name_val = param.split('&')
        #        env_var = 'AUDREY_VAR_' + name_val[0]
        #        cmd = ['/usr/bin/printenv', env_var]
        #        ret = run_cmd(cmd)
        #        self.assertEqual(ret['out'][:-1], \
        #            VALIDATE_NO_SERVICE_CONFIG_DATA[env_var])

    def test_failure_no_services_name(self):
        '''
        Failure case:
        - Exercise service().parse_require_config() with valid input

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

        validation_dict = {'AUDREY_VAR_jon_server_ip': '192.168.1.1',
            'AUDREY_VAR_jon_server_ip_2': '192.168.1.2',
            'AUDREY_VAR_jon_server_ip_3': '192.168.1.3'}

        self.assertRaises(AAError,
                          self.factory.service('').parse_require_config, src)

    def test_failure_bad_service_name(self):
        '''
        Failure case:
        - Exercise service().parse_require_config() with valid input
        '''

        src = '|service|parameters|'
        self.assertRaises(AAError,
                          self.factory.service('').parse_require_config, src)

    def test_failure_service_tag_not_found(self):
        '''
        Failure Case:
        - |service| not in src to service().parse_require_config()
        '''
        src = '|notservice|blah|'
        self.assertRaises(AAError,
                          self.factory.service('').parse_require_config, src)

    def test_failure_no_amp_delim(self):
        '''
        Failure Case:
        - no delim in param token
        '''
        src = '|service|blah|parameters|blah|'
        self.assertRaises(AAError,
                          self.factory.service('').parse_require_config, src)


class TestAudreyAgentServiceV2(TestAudreyAgentServiceV1):
    '''
    Class for exercising the parsing of the Required Configs from the CS.
    '''

    def setUp(self):
        self.factory = AudreyFactory(2)
        self.service = self.factory.service('test_service')
