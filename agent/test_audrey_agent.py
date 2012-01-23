#!/usr/bin/python2.6
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

from audrey.agent import setup_logging

####
# import the tests
####
from tests.agent import *
from tests.shell import *
from tests.cs_client import *
from tests.user_data import *

####
# turn down the sleep time in the loop
# to speed up the test process
####
import audrey.agent
audrey.agent.SLEEP_SECS = 0

####
# Cloud info test file
####
from tests.mocks import CLOUD_INFO_FILE
audrey.user_data.CLOUD_INFO_FILE = CLOUD_INFO_FILE

####
# monkey patch run_cmd function so we can
# mock certain shell commands
####
import audrey.user_data_rhev
import audrey.user_data_vsphere
import tests.mocks
audrey.user_data_rhev.run_cmd = tests.mocks.mock_run_cmd
audrey.user_data_vsphere.run_cmd = tests.mocks.mock_run_cmd

####
# Monkey Patch the http calls
####
from tests.mocks import HttpUnitTest
oauth2.Client = HttpUnitTest
httplib2.Http = HttpUnitTest

if __name__ == '__main__':

    setup_logging(logging.DEBUG, logfile_name='./test_audrey_agent.log')
    unittest.main()
