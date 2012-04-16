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
import urllib
import base64

from audrey.csclient import CSClient
from audrey.shell import get_system_info

LOGGER = logging.getLogger('Audrey')


class ProvidesV1(dict):
    '''
    a dictionary of provides and their values
    '''
    def __setitem__(self, key, value):
        '''
        casts all data values to strings so we can map a join
        to the key value pars when we generate_cs_str
        '''
        # NoneType is sacred and must be preserved
        if value is not None:
            value = str(value)
        # Now pass the set to the parent object to be completed
        super(ProvidesV1, self).__setitem__(key, value)

    def parse_cs_str(self, src, tooling=None):
        '''
        Description:
            Parse the provides parameters text message sent from the
            Config Server.

        Input:
            The provides parameters string obtained from the Config Server.

            The delimiters will be an | and an &

            To ensure all the data was received the entire string will be
            terminated with an "|".

            This will be a continuous text string (no CR or New Line).

            Format:
            |name1&name2...&nameN|

            e.g.:
            |ipaddress&virtual|

        Returns:
            - Provides populated with param names
                  as the keys and None as the value
        '''

        CSClient.validate_message(src)

        # split and prune the payload
        src = src[1:-1].split('|')
        if len(src) >= 1:
            for provides in src[0].split('&'):
                if provides:
                    self[provides] = None

        return self

    def generate_cs_str(self):
        '''
        Description:
            Generate the provides parameters list.

        Input:
            The provides parameters string obtained from the Config Server.

        Returns:
            A string to send back to the Config Server  with prifix
            'audrey_data='<url encoded return data>'

            The return portion will be delimited with an | and an &

            To ensure all the data is transmitted the entire string will be
            terminated with an "|".

            This will be a continuous text string (no CR or New Line).

            Data portion Format:
            |name1&val1|name2&val...|nameN$valN|

            e.g.:
            |ipaddress&<b64/10.118.46.205>|virtual&<b64/xenu>|

            The return string format:
            "audrey_data=<url encoded data portion>"


        '''
        LOGGER.info('Invoked Provides.generate_cs_str()')

        system_info = get_system_info(self.keys())

        for param in self.keys():
            if param in system_info:
                self[param] = base64.b64encode(system_info[param])

        def is_not_none(abc, xyz):
            '''
            used to reduce a list of key value paired tuples
            to only ones that have None as their value
            '''
            if xyz[1] is not None:
                abc.append(xyz)
            return abc

        non_none = reduce(is_not_none, self.items(), [])
        kv_pairs = ['&'.join(x) for x in non_none]

        return urllib.urlencode({'audrey_data': '|%s|' % '|'.join(kv_pairs)})


class ProvidesV2(ProvidesV1):
    '''
    API version 2 compatible Provides object
    '''
    def clean(self):
        '''
        remove non-None provides
        should be called after sending the values
        '''
        LOGGER.info('Invoked Provides.clean()')

        for provide in self.keys():
            if self[provide] is not None:
                del self[provide]

    def parse_cs_str(self, src, tooling=None):
        '''
        Description:
            Parse the provides parameters text message sent from the
            Config Server.

        Input:
            Format:
            |name1&name2...&nameN|service1&service2|

            e.g.:
            |ipaddress&virtual|myservice&yourservice|

            and an optional Tooling Object

        Returns Tuple:
            - Services objects list
            - Provides (dict) populated with param names
                  as the keys and None as the value
        '''

        # use the V1 code to populate my dict
        super(ProvidesV2, self).parse_cs_str(src)

        services = {}
        # split and prune the payload
        src = src[1:-1].split('|')
        if len(src) >= 2:
            # create the services
            for svc in src[1].split('&'):
                services[svc] = Service(svc, tooling)

        return services, self
