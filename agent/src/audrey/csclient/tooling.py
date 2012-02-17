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

from audrey import ASError, ASErrorInvalidTar
from audrey.shell import run_cmd

TOOLING_DIR = '/var/audrey/tooling/'
logger = logging.getLogger('Audrey')


class ConfigTooling(object):
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

    def __init__(self, tool_dir=TOOLING_DIR):
        '''
        Description:
            Set initial state so it can be tracked.
        '''
        self.tool_dir = tool_dir
        self.user_dir = os.path.join(tool_dir, 'user')
        self.audrey_dir = os.path.join(tool_dir, 'AUDREY_TOOLING')
        self.redhat_dir = os.path.join(tool_dir, 'REDHAT')
        self.tarball = ''

        # Create the extraction destination
        try:
            os.makedirs(self.user_dir)
        except OSError, (errno, strerror):
            if errno is 17:  # File exists
                pass
            else:
                raise ASError(('Failed to create directory %s. ' + \
                    'Error: %s') % (self.user_dir, strerror))

    def __str__(self):
        '''
        Description:
            Called by the str() function and by the print statement to
            produce the informal string representation of an object.
        '''
        return('\n<Instance of: %s\n' \
               '\tTooling Dir: %s\n' \
               '\tUnpack User Tooling Tarball Dir: %s\n' \
               '\ttarball Name: %s\n' \
               'eot>' %
            (self.__class__.__name__,
            str(self.tool_dir),
            str(self.user_dir),
            str(self.tarball),
            ))

    def invoke_tooling(self, services):
        '''
        Description:
            Invoke the configuration tooling for the specified services.

        Input:
            services - A list of ServiceParams objects.

        '''

        # For now invoke them all. Later versions will invoke the service
        # based on the required params from the Config Server.
        logger.debug('Invoked ConfigTooling.invoke_tooling()')
        logger.debug(str(services))
        for service in services:

            try:
                top_level, tooling_path = self.find_tooling(service.name)
            except ASError:
                # No tooling found. Try the next service.
                continue

            cmd = [tooling_path]
            cmd_dir = os.path.dirname(tooling_path)
            ret = run_cmd(cmd, cmd_dir)
            logger.info('Execute Tooling command: ' + ' '.join(cmd))

            retcode = ret['subproc'].returncode
            if retcode == 0:
                # Command successed, log the output.
                logger.info('return code: ' + str(retcode))
                logger.info('\n\tStart Output of: ' + ' '.join(cmd) + \
                    ' >>>\n' +  \
                    str(ret['out']) + \
                    '\n\t<<< End Output')
            else:
                # Command failed, log the errors.
                logger.info('\n\tStart Output of: ' + ' '.join(cmd) + \
                    ' >>>\n' +  \
                    str(ret['out']) + \
                    '\n\t<<< End Output')
                logger.error('error code: ' + str(retcode))
                logger.error('error msg:  ' + str(ret['err']))

            # If tooling was provided at the top level only run it once
            # for all services listed in the required config params.
            if top_level:
                break

    def unpack_tooling(self, tarball):
        '''
        Description:
            Methods used to untar the user provided tarball

            Perform validation of the text message sent from the
            Config Server. Validate, open and write out the contents
            of the user provided tarball.
        '''
        logger.info('Invoked unpack_tooling()')
        logger.debug('tarball: ' + str(tarball) + \
            'Target Direcory: ' + str(self.user_dir))

        self.tarball = tarball

        # Validate the specified tarfile.
        if not os.path.exists(self.tarball):
            raise ASError('File does not exist: %s ' % self.tarball)
        if not tarfile.is_tarfile(self.tarball):
            raise ASErrorInvalidTar('Not a valid tar file: %s' % self.tarball)

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
            raise ASError(('Failed to access tar file %s. Error: %s') %  \
                (self.tarball, strerror))

    def is_user_supplied(self):
        '''
        Description:
            Is the the configuration tooling for the specified service
            supplied by the user?

            TBD: Take in a service_name and evaluate.
            def is_user_supplied(self, service_name):
        '''
        return True

    def is_rh_supplied(self):
        '''
        Description:
            Is the the configuration tooling for the specified service
            supplied by Red Hat?

            TBD: Take in a service_name and evaluate.
            def is_rh_supplied(self, service_name):
        '''
        return False

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

        for p in tooling_paths:
            if os.access(p[1], os.X_OK):
                return p

        # No tooling found. Raise an error.
        raise ASError(('No configuration tooling found for service: %s') % \
            (service_name))
