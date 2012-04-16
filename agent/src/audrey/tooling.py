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
import tarfile

from audrey.errors import AAError, AAErrorInvalidTar
from audrey.shell import run_cmd

TOOLING_DIR = '/var/audrey/tooling/'
LOGGER = logging.getLogger('Audrey')


class Tooling(object):
    '''
    TBD - Consider making this class derived from dictionary or a mutable
    mapping.

    Description:
        Interface to configuration tooling:
        - Getting optional user supplied tooling from CS
        - Verify and Unpack optional user supplied tooling retrieved
          from CS
        - Is tooling for a given service user supplied
        - Is tooling for a given service Red Hat supplied
        - Find tooling for a given service Red Hat supplied
        - List tooling for services and indicate if it is user or Red
          Hat supplied.
    '''

    def __init__(self, tarball, tool_dir=TOOLING_DIR):
        '''
        Description:
            Set initial state so it can be tracked.
        '''
        self.tool_dir = tool_dir
        self.user_dir = os.path.join(tool_dir, 'user')
        self.audrey_dir = os.path.join(tool_dir, 'AUDREY_TOOLING')
        self.redhat_dir = os.path.join(tool_dir, 'REDHAT')
        self.tarball = tarball

        # Create the extraction destination
        if not os.path.exists(self.user_dir):
            try:
                os.makedirs(self.user_dir)
            except OSError, err:
                raise AAError(('Failed to create directory %s. ' + \
                               'Error: %s') % (self.user_dir, err))

        if self.tarball:
            self.unpack_tooling()

    def invoke_tooling(self, services):
        '''
        invoke the tooling on all services passed in the list
        '''
        # For now invoke them all. Later versions will invoke the service
        # based on the required params from the Config Server.
        LOGGER.debug('Invoked ConfigTooling.invoke_tooling()')
        LOGGER.debug(str(services))
        for service in services:
            self.invoke(service)

    def invoke(self, service):
        '''
        Description:
            Invoke the configuration tooling for the specified services.

        Input:
            services - A list of ServiceParams objects.

        '''
        service.gen_env()
        try:
            top_level, tooling_path = self.find_tooling(service.name)
        except AAError:
            # No tooling found. Try the next service.
            return -1

        if top_level:
            pass
            # this case has been eliminated from the design spec
            # and probably will never be used.

        cmd = [tooling_path]
        cmd_dir = os.path.dirname(tooling_path)
        ret = run_cmd(cmd, cmd_dir)
        LOGGER.info('Execute Tooling command: ' + ' '.join(cmd))

        retcode = ret['subproc'].returncode
        LOGGER.info('\n\tStart Output of: %s >>>\n%s\n\t<<< End Output' % \
                (' '.join(cmd), ret['out']))
        if retcode == 0:
            # Command successed, log the output.
            LOGGER.info('return code: %s' % retcode)
        else:
            # Command failed, log the errors.
            LOGGER.error('error code: %s' % retcode)
            LOGGER.error('error msg: %s' % ret['err'])

        return retcode

        # If tooling was provided at the top level only run it once
        # for all services listed in the required config params.
        #if top_level:
        #    break

    def unpack_tooling(self):
        '''
        Description:
            Methods used to untar the user provided tarball

            Perform validation of the text message sent from the
            Config Server. Validate, open and write out the contents
            of the user provided tarball.
        '''
        LOGGER.info('Invoked unpack_tooling()')

        # Validate the specified tarfile.
        if not os.path.exists(self.tarball):
            raise AAError('File does not exist: %s ' % self.tarball)
        if not tarfile.is_tarfile(self.tarball):
            raise AAErrorInvalidTar('Not a valid tar file: %s' % self.tarball)

        # Attempt to extract the contents from the specified tarfile.
        # If tarfile access or content is bad report to the user to aid
        # problem resolution.
        try:
            tarf = tarfile.open(self.tarball)
            tarf.extractall(path=self.user_dir)
            tarf.close()
        # Capture and report errors with the tarfile
        except (tarfile.TarError, tarfile.ReadError, \
                tarfile.CompressionError, tarfile.StreamError, \
                tarfile.ExtractError, IOError), (strerror):
            raise AAError(('Failed to access tar file %s. Error: %s') %  \
                (self.tarball, strerror))

    def find_tooling(self, service_name):
        '''
        Description:
            Given a service name return the path to the configuration
            tooling.

            Search for the service start executable in the user
            tooling directory.
                self.tool_dir + '/user/<service name>/start'

            If not found there search for the it in the documented directory
            here built in tooling should be placed.
                self.tool_dir + '/AUDREY_TOOLING/<service name>/start'

            If not found there search for the it in the Red Hat tooling
            directory.
                self.tool_dir + '/REDHAT/<service name>/start'

           If not found there raise an error.

        Returns:
            return 1 - True if top level tooling found, False otherwise.
            return 2 - path to tooling
        '''
        # common join
        service_start = os.path.join(service_name, 'start')
        # returns, check the paths and return the tuple
        tooling_paths = [(True, os.path.join(self.user_dir, 'start')),
                         (False, os.path.join(self.user_dir, service_start)),
                         (False, os.path.join(self.audrey_dir, service_start)),
                         (False, os.path.join(self.redhat_dir, service_start)),
                        ]

        for path in tooling_paths:
            if os.access(path[1], os.X_OK):
                return path

        # No tooling found. Raise an error.
        raise AAError(('No configuration tooling found for service: %s') % \
            (service_name))
