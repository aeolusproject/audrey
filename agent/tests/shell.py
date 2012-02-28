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

import audrey.shell

from tests.mocks import mock_run_cmd
from tests.mocks import mock_run_cmd_facter_fail

from audrey.errors import ASError
from audrey.shell import run_cmd
from audrey.shell import run_pipe_cmd
from audrey.shell import get_system_info


class TestAudreyShell(unittest.TestCase):
    '''
    Test the _run*cmd functions
    '''
    def test_success_run_pipe_cmd(self):
        self.assertEqual("'test'\n",
            run_pipe_cmd(["echo", "'test'"], ["grep", "test"])['out'])

    def test_fail_run_cmd(self):
        self.assertEqual("[Errno 2] No such file or directory",
            run_cmd(["notreal"])['err'])

    def test_cmd2_fail_run_pipe_cmd(self):
        self.assertEqual("[Errno 2] No such file or directory",
            run_pipe_cmd(["echo", "'test'"], ["notreal"])['err'])

    def test_cmd1_fail_run_pipe_cmd(self):
        self.assertEqual("[Errno 2] No such file or directory",
            run_pipe_cmd(["notreal"], ["echo", "'test'"])['err'])

    def test_get_system_info_fail(self):
        audrey.shell.run_cmd = mock_run_cmd_facter_fail
        self.assertRaises(ASError, get_system_info)
        audrey.shell.run_cmd = mock_run_cmd
