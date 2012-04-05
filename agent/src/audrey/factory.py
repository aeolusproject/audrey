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

    def __init__(self, api_version):

        self.api_version = api_version
        self.Tooling = Tooling

        if api_version == 1:
            self.Agent = audrey.agent.AgentV1
            self.Provides = audrey.provides.ProvidesV1
            self.Service = audrey.service.ServiceV1
        else:
            # Version 2 is the default
            self.Agent = audrey.agent.AgentV2
            self.Provides = audrey.provides.ProvidesV2
            self.Service = audrey.service.ServiceV2

        audrey.agent.Tooling = self.Tooling
        audrey.agent.Service = self.Service
        audrey.agent.Provides = self.Provides
        audrey.tooling.Provides = self.Provides
        audrey.tooling.Service = self.Service
        audrey.provides.Service = self.Service
        audrey.service.Service = self.Service
