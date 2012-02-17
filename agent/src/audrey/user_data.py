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
import logging
logger = logging.getLogger('Audrey')

from audrey import ASError

CLOUD_INFO_FILE = '/etc/sysconfig/cloud-info'


def discover():
    if os.path.exists(CLOUD_INFO_FILE):
        f = open(CLOUD_INFO_FILE)
        cloud_type = f.read().strip().upper()
        f.close()

        if 'EC2' in cloud_type:
            import audrey.user_data_ec2
            return audrey.user_data_ec2.UserData()
        elif 'RHEV' in cloud_type:
            import audrey.user_data_rhev
            return audrey.user_data_rhev.UserData()
        elif 'VSPHERE' in cloud_type:
            import audrey.user_data_vsphere
            return audrey.user_data_vsphere.UserData()
        else:
            raise ASError('Cloud type "%s" is invalid.' % cloud_type)
    else:
        #try imports
        raise ASError('%s is missing.' % CLOUD_INFO_FILE)


class UserDataBase(object):
    '''
    Description:
        Discover the Config Server access info.
        If not discover it using the cloud provider specific method.
    '''

    ud_version = 0
    endpoint = ''
    oauth_key = ''
    oauth_secret = ''

    def _parse_user_data(self, data):
        '''
        Take a string in form version|[value|][value|][value|]...
        parses according to version and populate the respective self var.
        Conductor puts the UUID into the oauth_key field.
        At minimum this function expects to find a | in the string
        this is in effort not to log oauth secrets.
        '''
        logger.debug('Parsing User Data')
        user_data = data.split('|')
        if len(user_data) > 1:
            if user_data[0] == '1':
                # version 1
                # format version|endpoint|oauth_key|oauth_secret
                ud_version, endpoint, \
                    oauth_key, oauth_secret = user_data
                self.ud_version = ud_version
                self.endpoint = endpoint
                self.oauth_key = oauth_key
                self.oauth_secret = oauth_secret
                return {'endpoint': self.endpoint,
                        'oauth_key': self.oauth_key,
                        'oauth_secret': self.oauth_secret, }
            else:
                raise ASError('Invalid User Data Version: %s' % user_data[0])
        else:
            raise ASError('Could not get user data version, parse failed')

    def read(self):
        '''
        Dummy function, indended to be overridden
        should return (endpoint, oauth_jey, oauth_secret)
        '''
        raise "UserDataBase.read() was not overridden. Execution Aborted"
