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

import httplib2
import base64

from audrey.errors import AAError
from audrey.user_data import UserDataBase

EC2_USER_DATA_URL = 'http://169.254.169.254/latest/user-data'


class UserData(UserDataBase):
    '''
    EC2 specific userdata read
    '''

    def read(self):
        try:
            max_attempts = 5
            headers = {'Accept': 'text/plain'}
            while max_attempts:
                response, body = httplib2.Http().request(EC2_USER_DATA_URL,
                                              headers=headers)
                if response.status == 200:
                    break
                max_attempts -= 1

            if response.status != 200:
                raise AAError('Max attempts to get EC2 user data \
                        exceeded.')

            if '|' not in body:
                body = base64.b64decode(body)
            return self._parse_user_data(body)

        except Exception, err:
            raise AAError('Failed accessing EC2 user data: %s' % err)
