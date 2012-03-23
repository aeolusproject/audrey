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

import os
import shutil
import unittest
import base64

from audrey.errors import AAError, AAErrorInvalidTar
from audrey.shell import run_cmd
from audrey.csclient import CSClient
from audrey.tooling import Tooling
from audrey.service import Service
from audrey.provides import Provides

from tests.mocks import HttpUnitTest
from tests.mocks import EXIT_ZERO
from tests.mocks import EXIT_ONE
from tests.mocks import DUMMY_SERVICE_CONFIG_DATA
from tests.mocks import DUMMY_NO_SERVICE_CONFIG_DATA
from tests import _write_file


class TestAudreyAgentTooling(unittest.TestCase):
    '''
    Make sure all the Config tooling is tested
    '''
    def setUp(self):
        self.tool_dir = os.path.join(os.path.abspath('.'), 'test_tooling')
        self.tooling = Tooling(None, self.tool_dir)

    def tearDown(self):
        if os.path.exists(self.tool_dir):
            shutil.rmtree(self.tool_dir)

    def test_fail_to_create_tooling_dir(self):
        self.assertRaises(AAError, Tooling, None, tool_dir='/not/real/dir')

    ###### Note
    # the first two are essentially no op
    # can we remove the code from the agent?
    def test_is_user_supplied(self):
        self.tooling.is_user_supplied()

    def test_is_rh_supplied(self):
        self.tooling.is_rh_supplied()
    ###### end note

    def test_empty_find_tooling(self):
        self.assertRaises(AAError, self.tooling.find_tooling, '')

    def test_find_user_tooling(self):
        start_path = os.path.join(self.tooling.user_dir, 'start')
        _write_file(start_path, EXIT_ZERO, 0744)
        self.tooling.find_tooling('')

    def test_find_user_service_tooling(self):
        service_dir = os.path.join(self.tooling.user_dir, 'test_service')
        os.mkdir(service_dir)
        _write_file(os.path.join(service_dir, 'start'), EXIT_ZERO, 0744)
        self.tooling.find_tooling('test_service')

    def test_find_audrey_service_tooling(self):
        service_dir = os.path.join(self.tooling.audrey_dir, 'test_service')
        os.mkdir(self.tooling.audrey_dir)
        os.mkdir(service_dir)
        _write_file(os.path.join(service_dir, 'start'), EXIT_ZERO, 0744)
        self.tooling.find_tooling('test_service')

    def test_find_redhat_service_tooling(self):
        service_dir = os.path.join(self.tooling.redhat_dir, 'test_service')
        os.mkdir(self.tooling.redhat_dir)
        os.mkdir(service_dir)
        _write_file(os.path.join(service_dir, 'start'), EXIT_ZERO, 0744)
        self.tooling.find_tooling('test_service')

    def test_invalid_tar_unpack_tooling(self):
        tar_file = os.path.join(self.tooling.user_dir, 'invalid_tar')
        _write_file(tar_file, 'NotRealTarFileContents')
        self.assertRaises(AAErrorInvalidTar, Tooling, tar_file, self.tool_dir)

    def test_fail_execution_invoke_tooling(self):
        start_path = os.path.join(self.tooling.user_dir, 'start')
        _write_file(start_path, EXIT_ONE, 0744)
        services = Service('').parse_require_config(DUMMY_NO_SERVICE_CONFIG_DATA)
        self.tooling.invoke_tooling(services)

    def test_user_invoke_tooling(self):
        start_path = os.path.join(self.tooling.user_dir, 'start')
        _write_file(start_path, EXIT_ZERO, 0744)
        services = Service('').parse_require_config(DUMMY_NO_SERVICE_CONFIG_DATA)
        self.tooling.invoke_tooling(services)

    def test_user_service_invoke_tooling(self):
        service_dir = os.path.join(self.tooling.user_dir, 'jon1')
        os.mkdir(service_dir)
        _write_file(os.path.join(service_dir, 'start'), EXIT_ZERO, 0744)
        services = Service('jon1').parse_require_config(DUMMY_SERVICE_CONFIG_DATA)
        self.tooling.invoke_tooling(services)
