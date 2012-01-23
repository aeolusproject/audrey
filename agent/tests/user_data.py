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

import os
import unittest

import audrey.user_data

from audrey import ASError

from tests.mocks import mock_run_cmd
from tests.mocks import DUMMY_USER_DATA
from tests.mocks import CLOUD_INFO_FILE

def _write_file(filepath, cloud):
    f = open(filepath, 'w')
    f.write(cloud)
    f.close()

class TestAudreyUserData(unittest.TestCase):
    def setUp(self):
        audrey.user_data_ec2.EC2_USER_DATA_URL = 'http://169.254.169.254/latest/user-data'
        self.user_data_file = 'test_user_data.txt'

    def tearDown(self):
        if os.path.exists(self.user_data_file):
            os.remove(self.user_data_file)

    def test_base_error_on_read(self):
        self.assertRaises(Exception, audrey.user_data.UserDataBase().read)

    def test_ec2(self):
        audrey.user_data_ec2.UserData().read()

    def test_ec2_404(self):
        audrey.user_data_ec2.EC2_USER_DATA_URL='http://169.254.169.254/gimmie-404'
        self.assertRaises(ASError, audrey.user_data_ec2.UserData().read)

    def test_rhev(self):
        _write_file(CLOUD_INFO_FILE, 'RHEV')
        _write_file(self.user_data_file, DUMMY_USER_DATA)
        audrey.user_data_rhev.DELTA_CLOUD_USER_DATA = self.user_data_file
        audrey.user_data.discover().read()

    def test_vsphere(self):
        _write_file(CLOUD_INFO_FILE, 'VSPHERE')
        _write_file(self.user_data_file, DUMMY_USER_DATA)
        audrey.user_data_vsphere.DELTA_CLOUD_USER_DATA = self.user_data_file
        audrey.user_data.discover().read()

    def test_invalid_user_data_version(self):
        audrey.user_data_ec2.EC2_USER_DATA_URL='http://169.254.169.254/no-version-user-data'
        self.assertRaises(ASError, audrey.user_data_ec2.UserData().read)

    def test_invalid_user_data_no_delim(self):
        audrey.user_data_ec2.EC2_USER_DATA_URL='http://169.254.169.254/empty-user-data'
        self.assertRaises(ASError, audrey.user_data_ec2.UserData().read)
