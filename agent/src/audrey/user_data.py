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
import os
import time
LOGGER = logging.getLogger('Audrey')

from audrey.errors import AAError
from audrey.shell import get_system_info

CLOUD_INFO_FILE = '/etc/sysconfig/cloud-info'

def retry(ExceptionToCheck, tries=4, delay=3, backoff=2, logger=None):
    """Retry calling the decorated function using an exponential backoff.

    http://www.saltycrane.com/blog/2009/11/trying-out-retry-decorator-python/
    original from: http://wiki.python.org/moin/PythonDecoratorLibrary#Retry

    :param ExceptionToCheck: the exception to check. may be a tuple of
        excpetions to check
    :type ExceptionToCheck: Exception or tuple
    :param tries: number of times to try (not retry) before giving up
    :type tries: int
    :param delay: initial delay between retries in seconds
    :type delay: int
    :param backoff: backoff multiplier e.g. value of 2 will double the delay
        each retry
    :type backoff: int
    :param logger: logger to use. If None, print
    :type logger: logging.Logger instance
    """
    def deco_retry(f):
        def f_retry(*args, **kwargs):
            mtries, mdelay = tries, delay
            try_one_last_time = True

            while mtries > 1:
                try:
                    return f(*args, **kwargs)
                    try_one_last_time = False
                    break
                except ExceptionToCheck, e:
                    msg = "%s, Retrying in %d seconds..." % (str(e), mdelay)
                    if logger:
                        logger.warning(msg)
                    else:
                        print msg
                    time.sleep(mdelay)
                    mtries -= 1
                    mdelay *= backoff
            if try_one_last_time:
                return f(*args, **kwargs)
            return
        return f_retry  # true decorator
    return deco_retry


def _get_cloud_type():
    '''
    Description:
        Get the type of the cloud back end this instance is running on.

        Currently utilizes Puppet's facter via a Python subprocess call.
        Currently supported cloud back end types are:
            EC2, RHEV, VSPHERE

    Input:
        None

    Returns:
        One of the following strings:
        'EC2', 'RHEV', 'VSPHERE' or 'UNKNOWN'

    '''
    system_facts = get_system_info(['productname', 'ec2_ami_id'])

    # Check for productname key as found on RHEVm and VMware/vSphere
    if 'productname' in system_facts:
        if 'RHEV' in system_facts['productname'].upper():
            return 'RHEV'
        if 'VMWARE' in system_facts['productname'].upper():
            return 'VSPHERE'

    # Check for ec2_ami_id key as found on EC2
    if 'ec2_ami_id' in  system_facts:
        return 'EC2'

    return 'UNKNOWN'

@retry(Exception, tries=4)
def discover():
    '''
    Description:
        User Data is passed to the launching instance which
        provides the Config Server contact information.

        Cloud providers expose the user data differently.
        It is necessary to determine which cloud provider
        the current instance is running on to determine
        how to access the user data. Images built with
        image factory will contain a CLOUD_INFO_FILE which
        contains a string identifying the cloud provider.

        Images not built with Imagefactory will try to
        determine what the cloud provider is based on system
        information.
    '''

    LOGGER.debug('Invoked discover')

    if os.path.exists(CLOUD_INFO_FILE):
        cloud_info = open(CLOUD_INFO_FILE)
        cloud_type = cloud_info.read().strip().upper()
        cloud_info.close()

    else:
        cloud_type = _get_cloud_type()

    LOGGER.debug('cloud_type: ' + str(cloud_type))

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
        raise AAError('Cloud type "%s" is invalid.' % cloud_type)

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
        LOGGER.debug('Parsing User Data')
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
                raise AAError('Invalid User Data Version: %s' % user_data[0])
        else:
            raise AAError('Could not get user data version, parse failed')

    def read(self):
        '''
        Dummy function, indended to be overridden
        should return (endpoint, oauth_jey, oauth_secret)
        '''
        raise AAError("%s read() not overridden. Execution Aborted" % self)
