#!/usr/bin/env python
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

import logging
import unittest
import sys
import oauth2
import httplib2

sys.path.append('src')

#### Import Audrey
import audrey.agent
import audrey.csclient.tooling
import audrey.user_data_rhev
import audrey.user_data_vsphere

#### import the tests
import tests.mocks
from tests.mocks import HttpUnitTest
from tests.agent import *
from tests.shell import *
from tests.csclient import *
from tests.user_data import *
from tests.mocks import CLOUD_INFO_FILE

#### Override from config params
audrey.agent.SLEEP_SECS = 0
audrey.agent.PWD_TOOLING = 'test_tooling'

audrey.csclient.tooling.TOOLING_DIR = os.path.join(
                                      os.path.abspath('.'), 'test_tooling')

#### Cloud info test file
audrey.user_data.CLOUD_INFO_FILE = CLOUD_INFO_FILE

#### monkey patch run_cmd function so we can mock certain shell commands
audrey.user_data_rhev.run_cmd = tests.mocks.mock_run_cmd
audrey.user_data_vsphere.run_cmd = tests.mocks.mock_run_cmd

#### Monkey Patch the http calls
oauth2.Client = HttpUnitTest
httplib2.Http = HttpUnitTest

raw_input = lambda: 'raw_input'

if __name__ == '__main__':
    unittest.main()
