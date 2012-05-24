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

from time import sleep

from audrey.errors import AAError
from audrey.errors import AAErrorPutProvides
from audrey.errors import AAErrorGetTooling
from audrey.csclient import CSClient

SLEEP_SECS = 10
PWD_TOOLING = 'tooling'
MAX_RETRY = 5

LOGGER = logging.getLogger('Audrey')

# The VERSION string is filled in during the make process.
AUDREY_VER = '@VERSION@'


class AgentV1(object):
    '''
    contains the main logic for processing
    This object is compatible with API Version 1
    '''
    def __init__(self, conf):
        '''
        conf: argparse dict
        '''
        tool_dir = {}
        if 'pwd' in conf and conf['pwd']:
            tool_dir = {'tool_dir': PWD_TOOLING}

        # Create the Client Object
        self.client = CSClient(**conf)
        self.client.test_connection()

        # Get any optional tooling from the Config Server
        tooling_status, tarball = self.client.get_tooling()
        if tooling_status != 200:
            LOGGER.error('Get Tooling returned: %s' % tooling_status)
            raise AAErrorGetTooling('Get Tooling returned: %s' % tooling_status)
        
        self.tooling = Tooling(tarball, **tool_dir)

    def run(self):
        '''
        Main agent loop, called by main() in /usr/bin/audrey
        '''
        # 0 means don't run again
        # -1 is non zero so initial runs will happen
        config_status = -1
        provides_status = -1

        max_retry = MAX_RETRY
        loop_count = 60
        services = []

        # Process the Requires and Provides parameters until the HTTP status
        # from the get_configs and the get_params both return 200
        while config_status or provides_status:

            LOGGER.debug('Config Parameter status: ' + str(config_status))
            LOGGER.debug('Return Parameter status: ' + str(provides_status))

            # Get the Required Configs from the Config Server
            if config_status:
                config_status, configs = self.client.get_configs()

                # Configure the system with the provided Required Configs
                if config_status == 200:
                    services = Service.parse_require_config(configs, self.tooling)
                    self.tooling.invoke_tooling(services)
                    # don't do any more config status work
                    # now that the tooling has run
                    config_status = 0
                else:
                    LOGGER.info(
                        'No configuration parameters provided. status: ' + \
                        str(config_status))

            # Get the requested provides from the Config Server
            if provides_status:
                get_status = self.client.get_provides()[0]

                # Gather the values from the system for the requested provides
                if get_status == 200:
                    params_values = Provides().generate_cs_str()
                else:
                    params_values = '|&|'

                # Put the requested provides with values to the Config Server
                provides_status = self.client.put_provides(params_values)[0]
                if provides_status == 200:
                    # don't operate on params anymore, all have been provided.
                    provides_status = 0

            # Retry a number of times if 404 HTTP Not Found is returned.
            if config_status == 404 or provides_status == 404:
                LOGGER.error('404 from Config Server.')
                LOGGER.error('Required Config status: %s' % config_status)
                LOGGER.info('Return Parameter status: %s' % provides_status)

                max_retry -= 1
                if max_retry < 0:
                    raise AAError('Too many 404 Config Server responses.')

            if loop_count:
                loop_count-=1
                sleep(SLEEP_SECS)
            else:
                break


class AgentV2(AgentV1):
    '''
    Overrides V1 with updates for API V2
    '''
    def run(self):
        '''
        Main loop called by main() in /usr/bin/audrey
        '''
        provides_len = 0
        services_len = 0
        retry_ct = 0

        status, provides_str = self.client.get_provides()
        if status == 200:
            services, provides = Provides().parse_cs_str(provides_str,
                                                         self.tooling)
        else:
            raise AAError('HTTP %s from provides & services list' % status)

        # process services and provides, removing them from the ques
        # as they have been processed.
        while services or provides:

            # Put the requested provides with values to the Config Server
            provides_str = provides.generate_cs_str()
            LOGGER.debug('Put Provides: %s' % provides_str)
            status = self.client.put_provides(provides_str)[0]
            # report non 200 status
            if status != 200:
                raise AAErrorPutProvides('Put provides returned %s' % status)
            # clean regardless of status, otherwise we'll get in
            # an infinite loop.
            provides.clean()

            # check for required configs per service
            for service in services.keys():
                svc = services[service]
                # Get the Required Configs from Config Server for the service
                status, configs = self.client.get_configs(svc.name)
                svc.parse_configs(configs)

                # Configure the system with the provided Required Configs
                if status == 202:
                    # couldn't be given all the configs yet.
                    continue
                else:
                    if status == 200:
                        # got all the configs, so invoke and report status
                        status = svc.invoke_tooling()
                    LOGGER.info('Service %s returns %s' % (service, status))
                    # report service status
                    status = self.client.put_provides(
                                               svc.generate_cs_str(status))[0]
                    # report non 200 status on service status put
                    if status != 200:
                        raise AAErrorPutProvides('Put service status %s'
                                                                     % status)
                    # the service has been processed
                    del services[service]

            if services_len == len(services) and provides_len == len(provides):
                if retry_ct == MAX_RETRY:
                    LOGGER.error("Max retry count exceeded. Exiting.")
                    exit(1)
                retry_ct += 1
            else:
                services_len = len(services)
                provides_len = len(provides)
                retry_ct = 0

            sleep(SLEEP_SECS)
