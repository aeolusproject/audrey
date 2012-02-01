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
import sys
import unittest
import logging

import audrey.user_data_ec2

from audrey import ASError
from audrey import setup_logging
from audrey.shell import run_cmd
from audrey.agent import main
from audrey.csclient import gen_env

from tests.mocks import CLOUD_INFO_FILE
from tests.user_data import _write_file

class TestAudreyAgent(unittest.TestCase):
    '''
    Class for exercising the full audrey script functionality
    '''

    def setUp(self):
        audrey.user_data_ec2.EC2_USER_DATA_URL='http://169.254.169.254/latest/user-data'
        audrey.csclient.client.TOOLING_URL = 'files'
        audrey.csclient.client.PARAMS_URL = 'params'
        audrey.csclient.client.CONFIGS_URL = 'configs'
        # make a copy of argv
        self.argv = list(sys.argv)
        # clean out args before you run me
        sys.argv = sys.argv[:1]
        sys.argv.extend(['-p', '-L', 'DEBUG'])

    def tearDown(self):
        # replace argv
        sys.argv = list(self.argv)
        if os.path.exists(CLOUD_INFO_FILE):
            os.remove(CLOUD_INFO_FILE)

    def test_main(self):
        _write_file(CLOUD_INFO_FILE, 'EC2')
        main()

    def test_fail_main(self):
        self.assertRaises(ASError, main)

    def test_fail_main_404(self):
        audrey.user_data_ec2.EC2_USER_DATA_URL='http://169.254.169.254/gimmie-404'
        self.assertRaises(ASError, main)

    def test_fail_main_invalid_cloudinfo(self):
        _write_file(CLOUD_INFO_FILE, 'INVALID')
        self.assertRaises(ASError, main)

    def test_fail_main_no_cloudinfo_no_userdata_module(self):
        self.assertRaises(ASError, main)

    def test_empty_gen_env(self):
        self.assertRaises(ASError, gen_env, '', '')

    def test_version_and_stream_logger(self):
        # remember std out & err
        self.old_stdout, self.old_stderr = sys.stdout, sys.stderr
        self.old_stdout.flush(); self.old_stderr.flush()

        # redirects std out & err to log
        setup_logging(logging.INFO) 

        # test
        sys.stdout.write('test redirect stdout to log')
        sys.argv.append('-v')
        self.assertRaises(SystemExit, main)

        # reset std out & err
        # no need to flush, the logger doesn't need to
        sys.stdout = self.old_stdout
        sys.stderr = self.old_stderr

        # reset logging
        setup_logging(logging.DEBUG)

    # not sure how to do this
    # without creating a function to mock
    # then we still don't have something covered
    #def test_version_and_stream_logger(self):
    #    sys.argv.extend(['-k', 'test_key'])
    #    main()

    def test_no_connectivity(self):
        _write_file(CLOUD_INFO_FILE, 'EC2')
        audrey.agent.VERSION_URL = 'raiseException'
        self.assertRaises(SystemExit, main)

    def test_404_from_tooling(self):
        _write_file(CLOUD_INFO_FILE, 'EC2')
        audrey.csclient.client.TOOLING_URL = 'gimmie-404'
        main()

    def test_404_from_params(self):
        _write_file(CLOUD_INFO_FILE, 'EC2')
        audrey.csclient.client.PARAMS_URL = 'gimmie-404'
        main()

    def test_404_from_configs(self):
        _write_file(CLOUD_INFO_FILE, 'EC2')
        audrey.csclient.client.CONFIGS_URL = 'gimmie-404'
        self.assertRaises(ASError, main)
