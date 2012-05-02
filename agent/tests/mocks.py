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

'''
 test_audrey_agent.py

 Test program for audrey_agent
'''

import base64
import tarfile

try:
    from cStringIO import StringIO as BIO
except ImportError:  # python 3
    from io import BytesIO as BIO

API_VERSION = '2'
TOOLING_DIR = 'test_tooling'

DUMMY_USER_DATA = '1|http://example.com/|oauthConsumer|oauthSecret'
CLOUD_INFO_FILE = 'test_cloud_info'
EXIT_ZERO = '#!/bin/sh\nexit 0'
EXIT_ONE = '#!/bin/sh\nexit 1'

DUMMY_CS_CONFIG = {'endpoint': 'http://example.com/',
                   'oauth_key': 'oauthConsumer',
                   'oauth_secret': 'oauthSecret', }

DUMMY_NO_SERVICE_CONFIG_DATA = '|service|' + \
    '|parameters|jon_server_ip&' + base64.b64encode('192.168.1.1') + \
    '|jon_server_ip_2&' + base64.b64encode('192.168.1.2') + \
    '|jon_server_ip_3&' + base64.b64encode('192.168.1.3') + \
    '|service|jon2|'

VALIDATE_NO_SERVICE_CONFIG_DATA = {
    'AUDREY_VAR_jon_server_ip': '192.168.1.1',
    'AUDREY_VAR_jon_server_ip_2': '192.168.1.2',
    'AUDREY_VAR_jon_server_ip_3': '192.168.1.3'}

DUMMY_SERVICE_CONFIG_DATA = '|service|jon1' + \
    '|parameters|jon_server_ip&' + base64.b64encode('192.168.1.1') + \
    '|jon_server_ip_2&' + base64.b64encode('192.168.1.2') + \
    '|jon_server_ip_3&' + base64.b64encode('192.168.1.3') + \
    '|service|jon2||'

VALIDATE_SERVICE_CONFIG_DATA = {
    'AUDREY_VAR_jon1_jon_server_ip': '192.168.1.1',
    'AUDREY_VAR_jon1_jon_server_ip_2': '192.168.1.2',
    'AUDREY_VAR_jon1_jon_server_ip_3': '192.168.1.3'}

TARFILE = tarfile.open("test_tooling.tar.gz", mode="w:gz")
TARFILE.add('/etc/passwd')
TARFILE.close()
TARFILE = "test_tooling.tar.gz"


#####
# Redefine oauth.Client(key, secret)
# to inject this class into the agent
# for testing
#####

class HttpUnitTest(object):
    '''
    Description:
        When testing the http object does not exists. This class provides
        test methods that could be preformed when doing UNITTESTing.
    '''
    class HttpUnitTestResponse(object):
        '''
        Description:
            When testing the http object does not exists. This class
            provides the test method response that could be preformed
            when doing UNITTESTing.
        '''
        def __init__(self, status):
            self.status = status
            self.url = None

        def add_attachment(self, filename):
            self.__dict__['content-disposition'] = \
                                   'attachment; filename=%s' % filename

        def __getitem__(self, key):
            return self.__dict__[key]

    # simple HTTP Response with 200 status code
    ok_response = HttpUnitTestResponse(200)
    not_found_response = HttpUnitTestResponse(404)

    def __init__(self, oauth_key='', oauth_secret=''):
        # need this just to accept the oauth.Client init params
        pass

    def request(self, url, method='GET', body=None, headers=None):
        '''
        Handle request when not running live but in test environment.
        '''
        body = ''
        response = HttpUnitTest.ok_response
        if '/raiseException' in url:
            raise Exception
        if method == 'GET':
            if url.find('/configs/') > -1:
                body = '|service|s1|parameters|param1&%s|param2&%s|' % \
                    (base64.b64encode('value1'), base64.b64encode('value2'))
            elif url.find('/params/') > -1:
                body = '|ipaddress&uptime|'
            elif url.find('/paramsV2/') > -1:
                body = '|ipaddress&uptime|service_test|'
            elif url.find('/invalidparams/') > -1:
                body = '|not_real&uptime|'
            elif url.find('/files/') > -1:
                file_out = BIO()
                tar = tarfile.open(mode="w:gz", fileobj=file_out)
                tar.add('/etc/passwd')
                tar.close()
                body = file_out.getvalue()
                response.add_attachment('test.tar.gz')
            elif url.endswith('/user-data'):
                body = base64.b64encode(DUMMY_USER_DATA)
            elif url.endswith('/no-version-user-data'):
                body = base64.b64encode('0|endpoint')
            elif url.endswith('/empty-user-data'):
                body = base64.b64encode('')
            elif '/version' in url:
                body = '''<config-server>
  <application-version>VALUE_IGNORED</application-version>
  <api-version>%s</api-version>
</config-server>''' % API_VERSION
            elif '/badversion' in url:
                body = ''
            elif '/gimmie-404' in url:
                response = HttpUnitTest.not_found_response
            else:
                response = HttpUnitTest.not_found_response
        elif method == 'PUT':
            if url.find('/params/') > -1:
                response = HttpUnitTest.ok_response
        #elif method == 'POST' and url.find('/params/') > -1:
        #    body = ''
        else:
            response = HttpUnitTest.not_found_response
        response.url = url
        return response, body


class MockPopen(object):
    def __init__(self, returncode=0):
        self.returncode = returncode


def mock_run_cmd(cmd, my_cwd=None):
    return {'subproc': MockPopen(),
                'err': '', 'out': ''}


def mock_run_cmd_facter_fail(cmd, my_cwd=None):
    if cmd == ['/usr/bin/facter']:
        return {'subproc': MockPopen(1),
                'err': '', 'out': ''}


def mock_run_cmd_modprobe_floppy_fail(cmd, my_cwd=None):
    if cmd == ['/sbin/modprobe', 'floppy']:
        return {'subproc': MockPopen(1),
                'err': '', 'out': ''}


def mock_run_cmd_mkdir_media_fail(cmd, my_cwd=None):
    if cmd == ['/bin/mkdir', '/media']:
        return {'subproc': MockPopen(2),
                'err': '', 'out': ''}
    else:
        return mock_run_cmd(cmd, my_cwd)


def mock_run_cmd_mount_floppy_fail(cmd, my_cwd=None):
    if cmd == ['/bin/mount', '/dev/fd0', '/media']:
        return {'subproc': MockPopen(2),
                'err': '', 'out': ''}
    else:
        return mock_run_cmd(cmd, my_cwd)


def mock_run_cmd_mount_cdrom_fail(cmd, my_cwd=None):
    if cmd == ['/bin/mount', '/dev/cdrom', '/media']:
        return {'subproc': MockPopen(2),
                'err': '', 'out': ''}
    else:
        return mock_run_cmd(cmd, my_cwd)
