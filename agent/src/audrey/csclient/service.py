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

class ServiceParams(object):
    '''
    Description:
        Used for storing a service and all of it's associated parameters
        as provided by the Config Server in the "required" parameters
        API message.

        services = [
                ServiceParams('serviceA', ['n&v', 'n&v', 'n&v',...]),
                ServiceParams('serviceB', ['n&v', 'n&v', 'n&v',...]),
                ServiceParams('serviceB', ['n&v', 'n&v', 'n&v',...]),
        ]

        This structure aids in tracking the parsed required config
        parameters which is useful when doing UNITTESTing.

    '''
    def __init__(self, name=None):
        if name == None:
            name = ''
        self.name = name # string
        self.params = [] # start with an empty list
    def add_param(self, param):
        '''
        Description:
            Add a parameter provided by   the Config Server to the list.
        '''
        self.params.append(param)
    def __repr__(self):
        return repr((self.name, self.params))
