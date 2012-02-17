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

import base64

from audrey import ASError
from audrey.user_data import UserDataBase
from audrey.shell import run_cmd

DELTA_CLOUD_USER_DATA = '/media/deltacloud-user-data.txt'


class UserData(UserDataBase):
    '''
    RHEVM specific userdata read
    '''

    def read(self):
        #
        # If on RHEV-M the user data will be contained on the
        # floppy device in file deltacloud-user-data.txt.
        # To access it:
        #    modprobe floppy
        #    mount /dev/fd0 /media
        #    read /media/deltacloud-user-data.txt
        #
        # Note:
        # On RHEVm the deltacloud drive had been delivering the user
        # data base64 decoded at one point that changed such that the
        # deltacloud drive leaves the date base64 encoded. This
        # Code segment will handle both base64 encoded and decoded
        # user data.
        #
        # Since ':' is used as a field delimiter in the user data
        # and is not a valid base64 char, if ':' is found assume
        # the data is already base64 decoded.
        #
        #    modprobe floppy
        cmd = ['/sbin/modprobe', 'floppy']
        ret = run_cmd(cmd)
        if ret['subproc'].returncode != 0:
            raise ASError(('Failed command: \n%s \nError: \n%s') % \
                (' '.join(cmd), str(ret['err'])))

        cmd = ['/bin/mkdir', '/media']
        ret = run_cmd(cmd)
        # If /media is already there (1) or any other error (0)
        if (ret['subproc'].returncode != 1) and  \
           (ret['subproc'].returncode != 0):
            raise ASError(('Failed command: \n%s \nError: \n%s') % \
                (' '.join(cmd), str(ret['err'])))

        cmd = ['/bin/mount', '/dev/fd0', '/media']
        ret = run_cmd(cmd)
        # If /media is already mounted (32) or any other error (0)
        if (ret['subproc'].returncode != 32) and  \
           (ret['subproc'].returncode != 0):
            raise ASError(('Failed command: \n%s \nError: \n%s') % \
                (' '.join(cmd), str(ret['err'])))

        # Condfig Server (CS) address:port.
        # This could be done using "with open()" but that's not available
        # in Python 2.4 as used on RHEL5
        try:
            fp = open(DELTA_CLOUD_USER_DATA, 'r')
            ud = fp.read().strip()
            fp.close()
        except:
            raise ASError('Failed accessing RHEVm user data file.')

        if '|' not in ud:
            ud = base64.b64decode(ud)
        return self._parse_user_data(ud)
