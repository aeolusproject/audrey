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
import sys
import logging

# Log file
LOG = '/var/log/audrey.log'


class StreamToLogger(object):
    """
    Fake file-like stream object that redirects writes to a logger instance.
    """
    def __init__(self, logger, log_level=logging.INFO):
        self.logger = logger
        self.log_level = log_level
        self.linebuf = ''

    def write(self, buf):
        for line in buf.rstrip().splitlines():
            self.logger.log(self.log_level, line.rstrip())


def setup_logging(level=logging.INFO, logfile_name=LOG):
    '''
    Description:
        Establish the output logging.
    '''

    # If not run as root create the log file in the current directory.
    # This allows minimal functionality, e.g.: --help
    if not os.geteuid() == 0:
        logfile_name = './audrey.log'

    # set up logging
    LOG_FORMAT = ('%(asctime)s - %(levelname)-8s: '
        '%(filename)s:%(lineno)d %(message)s')
    LOG_LEVEL_INPUT = 5
    LOG_NAME_INPUT = 'INPUT'

    logging.basicConfig(filename=logfile_name,
        level=level, filemode='a', format=LOG_FORMAT)

    logging.addLevelName(LOG_LEVEL_INPUT, LOG_NAME_INPUT)

    logger = logging.getLogger('Audrey')

    if level != logging.DEBUG:
        # redirect the stderr and out to the logger
        sys.stdout = StreamToLogger(logger, logging.INFO)
        sys.stderr = StreamToLogger(logger, logging.ERROR)
