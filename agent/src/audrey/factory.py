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
import audrey.agent
import audrey.provides
import audrey.service

from audrey.tooling import Tooling


class AudreyFactory(object):
    '''
    handles object instanciation for all objects
    we have to ask the factory for the objects
    to ensure that we're operating on the appropriate
    logic associated with the api_version
    negotiatied with the configserver
    '''
    def __init__(self, api_version):
        '''
        establish the objects based on the the
        api_version negotiated
        '''
        self.api_version = api_version
        self.tooling = Tooling

        if api_version == 1:
            self.agent = audrey.agent.AgentV1
            self.provides = audrey.provides.ProvidesV1
            self.service = audrey.service.ServiceV1
        else:
            # Version 2 is the default
            self.agent = audrey.agent.AgentV2
            self.provides = audrey.provides.ProvidesV2
            self.service = audrey.service.ServiceV2

        audrey.agent.Tooling = self.tooling
        audrey.agent.Service = self.service
        audrey.agent.Provides = self.provides
        audrey.tooling.Provides = self.provides
        audrey.tooling.Service = self.service
        audrey.provides.Service = self.service
        audrey.service.Service = self.service
