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

from audrey.agent import Agent
from audrey.service import Service
from audrey.provides import Provides
from audrey.tooling import Tooling

class AudreyFactory(object):

    def __init__(self, api_version):
        self.api_version = api_version
        self.agent = Agent
        self.provides = Provides
        self.service = Service
        self.tooling = Tooling

        audrey.agent.Tooling = self.tooling
        audrey.agent.Service = self.service
        audrey.agent.Provides = self.provides
