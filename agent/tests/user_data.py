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
import base64

import audrey.user_data

from audrey.errors import AAError

from tests import _write_file
from tests.mocks import mock_run_cmd
from tests.mocks import mock_run_cmd_modprobe_floppy_fail
from tests.mocks import mock_run_cmd_mkdir_media_fail
from tests.mocks import mock_run_cmd_mount_floppy_fail
from tests.mocks import mock_run_cmd_mount_cdrom_fail
from tests.mocks import DUMMY_USER_DATA
from tests.mocks import CLOUD_INFO_FILE


class TestAudreyUserData(unittest.TestCase):
    def setUp(self):
        audrey.user_data_ec2.EC2_USER_DATA_URL = \
            'http://169.254.169.254/latest/user-data'
        self.user_data_file = 'test_user_data.txt'

    def tearDown(self):
        if os.path.exists(self.user_data_file):
            os.remove(self.user_data_file)
        if os.path.exists(CLOUD_INFO_FILE):
            os.remove(CLOUD_INFO_FILE)

    def test_base_error_on_read(self):
        self.assertRaises(Exception, audrey.user_data.UserDataBase().read)

    def test_ec2(self):
        audrey.user_data_ec2.UserData().read()

    def test_ec2_404(self):
        audrey.user_data_ec2.EC2_USER_DATA_URL = \
            'http://169.254.169.254/gimmie-404'
        self.assertRaises(AAError, audrey.user_data_ec2.UserData().read)

    def test_rhev(self):
        _write_file(CLOUD_INFO_FILE, 'RHEV')
        _write_file(self.user_data_file, DUMMY_USER_DATA)
        audrey.user_data_rhev.DELTA_CLOUD_USER_DATA = self.user_data_file
        audrey.user_data.discover().read()

    def test_rhev_base64encoded(self):
        _write_file(CLOUD_INFO_FILE, 'RHEV')
        _write_file(self.user_data_file, base64.b64encode(DUMMY_USER_DATA))
        audrey.user_data_rhev.DELTA_CLOUD_USER_DATA = self.user_data_file
        audrey.user_data.discover().read()

    def test_rhev_invalid_user_data_file(self):
        _write_file(CLOUD_INFO_FILE, 'RHEV')
        audrey.user_data_rhev.DELTA_CLOUD_USER_DATA = '/invalid_file_path'
        self.assertRaises(AAError, audrey.user_data.discover().read)

    def test_vsphere(self):
        _write_file(CLOUD_INFO_FILE, 'VSPHERE')
        _write_file(self.user_data_file, DUMMY_USER_DATA)
        audrey.user_data_vsphere.DELTA_CLOUD_USER_DATA = self.user_data_file
        audrey.user_data.discover().read()

    def test_vsphere_base64encoded(self):
        _write_file(CLOUD_INFO_FILE, 'VSPHERE')
        _write_file(self.user_data_file, base64.b64encode(DUMMY_USER_DATA))
        audrey.user_data_vsphere.DELTA_CLOUD_USER_DATA = self.user_data_file
        audrey.user_data.discover().read()

    def test_vsphere_invalid_user_data_file(self):
        _write_file(CLOUD_INFO_FILE, 'VSPHERE')
        audrey.user_data_vsphere.DELTA_CLOUD_USER_DATA = '/invalid_file_path'
        self.assertRaises(AAError, audrey.user_data.discover().read)

    def test_invalid_user_data_version(self):
        audrey.user_data_ec2.EC2_USER_DATA_URL = \
            'http://169.254.169.254/no-version-user-data'
        self.assertRaises(AAError, audrey.user_data_ec2.UserData().read)

    def test_invalid_user_data_no_delim(self):
        audrey.user_data_ec2.EC2_USER_DATA_URL = \
            'http://169.254.169.254/empty-user-data'
        self.assertRaises(AAError, audrey.user_data_ec2.UserData().read)

    def test_rhev_modprobe_floppy_fail(self):
        audrey.user_data_rhev.run_cmd = mock_run_cmd_modprobe_floppy_fail
        _write_file(CLOUD_INFO_FILE, 'RHEV')
        _write_file(self.user_data_file, DUMMY_USER_DATA)
        audrey.user_data_rhev.DELTA_CLOUD_USER_DATA = self.user_data_file
        self.assertRaises(AAError, audrey.user_data.discover().read)

    def test_rhev_mkdir_media_fail(self):
        audrey.user_data_rhev.run_cmd = mock_run_cmd_mkdir_media_fail
        _write_file(CLOUD_INFO_FILE, 'RHEV')
        _write_file(self.user_data_file, DUMMY_USER_DATA)
        audrey.user_data_rhev.DELTA_CLOUD_USER_DATA = self.user_data_file
        self.assertRaises(AAError, audrey.user_data.discover().read)

    def test_rhev_mount_floppy_fail(self):
        audrey.user_data_rhev.run_cmd = mock_run_cmd_mount_floppy_fail
        _write_file(CLOUD_INFO_FILE, 'RHEV')
        _write_file(self.user_data_file, DUMMY_USER_DATA)
        audrey.user_data_rhev.DELTA_CLOUD_USER_DATA = self.user_data_file
        self.assertRaises(AAError, audrey.user_data.discover().read)

    def test_vsphere_mkdir_media_fail(self):
        audrey.user_data_vsphere.run_cmd = mock_run_cmd_mkdir_media_fail
        _write_file(CLOUD_INFO_FILE, 'vsphere')
        _write_file(self.user_data_file, DUMMY_USER_DATA)
        audrey.user_data_rhev.delta_cloud_user_data = self.user_data_file
        self.assertRaises(AAError, audrey.user_data.discover().read)

    def test_vsphere_mount_cdrom_fail(self):
        audrey.user_data_vsphere.run_cmd = mock_run_cmd_mount_cdrom_fail
        _write_file(CLOUD_INFO_FILE, 'vsphere')
        _write_file(self.user_data_file, DUMMY_USER_DATA)
        audrey.user_data_rhev.delta_cloud_user_data = self.user_data_file
        self.assertRaises(AAError, audrey.user_data.discover().read)
