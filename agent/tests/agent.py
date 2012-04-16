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

from audrey import setup_logging
from audrey.main import main
from audrey.errors import AAError
from audrey.shell import run_cmd

import tests.mocks
from tests.mocks import CLOUD_INFO_FILE
from tests import _write_file


class TestAudreyInit(unittest.TestCase):

    def setUp(self):
        audrey.user_data_ec2.EC2_USER_DATA_URL = \
            'http://169.254.169.254/latest/user-data'
        audrey.csclient.VERSION_URL = 'version'
        audrey.csclient.TOOLING_URL = 'files'
        audrey.csclient.PROVIDES_URL = 'params'
        audrey.csclient.CONFIGS_URL = 'configs'
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
        self.assertRaises(AAError, main)

    def test_version_and_stream_logger(self):
        # remember std out & err
        self.old_stdout, self.old_stderr = sys.stdout, sys.stderr
        self.old_stdout.flush()
        self.old_stderr.flush()

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


class TestAudreyAgentV1(unittest.TestCase):
    '''
    Class for exercising the full audrey script functionality
    '''

    def setUp(self):
        audrey.user_data_ec2.EC2_USER_DATA_URL = \
            'http://169.254.169.254/latest/user-data'
        audrey.csclient.TOOLING_URL = 'files'
        audrey.csclient.PROVIDES_URL = 'params'
        audrey.csclient.CONFIGS_URL = 'configs'
        tests.mocks.API_VERSION = '1'
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

    def test_fail_userdata_404(self):
        audrey.user_data_ec2.EC2_USER_DATA_URL = \
            'http://169.254.169.254/gimmie-404'
        self.assertRaises(AAError, main)

    def test_fail_invalid_cloudinfo(self):
        _write_file(CLOUD_INFO_FILE, 'INVALID')
        self.assertRaises(AAError, main)

    def test_fail_main_no_cloudinfo_no_userdata_module(self):
        self.assertRaises(AAError, main)

    # not sure how to do this
    # without creating a function to mock
    # then we still don't have something covered
    #def test_version_and_stream_logger(self):
    #    sys.argv.extend(['-k', 'test_key'])
    #    main()

    def test_no_connectivity(self):
        _write_file(CLOUD_INFO_FILE, 'EC2')
        audrey.csclient.VERSION_URL = 'raiseException'
        self.assertRaises(AAError, main)
        audrey.csclient.VERSION_URL = 'version'

    def test_404_from_tooling(self):
        _write_file(CLOUD_INFO_FILE, 'EC2')
        audrey.csclient.TOOLING_URL = 'gimmie-404'
        main()

    def test_404_from_provides(self):
        _write_file(CLOUD_INFO_FILE, 'EC2')
        audrey.csclient.PROVIDES_URL = 'gimmie-404'
        main()

    def test_404_from_configs(self):
        _write_file(CLOUD_INFO_FILE, 'EC2')
        audrey.csclient.CONFIGS_URL = 'gimmie-404'
        self.assertRaises(AAError, main)


class TestAudreyAgentV2(TestAudreyAgentV1):
    def setUp(self):
        super(TestAudreyAgentV2, self).setUp()
        tests.mocks.API_VERSION = '2'
        audrey.csclient.PROVIDES_URL = 'paramsV2'

    def test_404_from_provides(self):
        _write_file(CLOUD_INFO_FILE, 'EC2')
        audrey.csclient.PROVIDES_URL = 'gimmie-404'
        self.assertRaises(AAError, main)

    def test_404_from_configs(self):
        _write_file(CLOUD_INFO_FILE, 'EC2')
        audrey.csclient.CONFIGS_URL = 'gimmie-404'
        # should succeed, we don't bail on 404
        # in api version 2
        main()

    def test_invalid_provides_name(self):
        _write_file(CLOUD_INFO_FILE, 'EC2')
        audrey.csclient.PROVIDES_URL = '/invalidparams'
        self.assertRaises(SystemExit, main)
