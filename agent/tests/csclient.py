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
from audrey.csclient import CSClient

from tests.mocks import HttpUnitTest
from tests.mocks import DUMMY_CS_CONFIG


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

    def test_success_get_configs(self):
        '''
        Success case:
        - Exercise get_configs()
        '''
        self.cs_client.get_configs()

    def test_success_get_tooling(self):
        '''
        Success case:
        - Exercise get_tooling()
        '''
        self.cs_client.get_tooling()

    def test_success_get_provides(self):
        '''
        Success case:
        - Exercise get_provides()
        '''
        self.cs_client.get_provides()

    def test_success_get_confs_n_provides(self):
        '''
        Success case:
        - Exercise get_configs() and get_provides()
        '''
        self.cs_client.get_configs()
        self.cs_client.get_provides()

    def test_success_put_provides(self):
        '''
        Success case:
        - Exercise put_provides_values()
        '''
        self.cs_client.put_provides('')

    def test_error_http_status(self):
        '''
        Success case:
        - Get a 401
        '''
        self.assertRaises(AAError, self.cs_client._validate_http_status,
                          HttpUnitTest.HttpUnitTestResponse(401))

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
