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

from audrey import parse_args
from audrey import setup_logging
from audrey import user_data

from audrey.csclient import CSClient
from audrey.factory import AudreyFactory


def main():
    '''
    Description:
        This script will be used on EC2 for configuring the running
        instance based on Cloud Engine configuration supplied at
        launch time in the user data.

        Config Server Status:
        200 HTTP OK - Success and no more data of this type
        202 HTTP Accepted - Success and more data of this type
        404 HTTP Not Found - This may be temporary so try again
    '''
    # parse the args and setup logging
    conf = parse_args()
    log_file = {}
    if 'pwd' in conf and conf.pwd:
        log_file = {'logfile_name': 'audrey.log'}

    logger = setup_logging(level=conf.log_level, **log_file)

    if not conf.endpoint:
        # discover the cloud I'm on
        # update the conf with the user data
        #conf = dict(vars(conf).items() + user_data.discover().read().items())
        vars(conf).update(user_data.discover().read().items())

    # ensure the conf is a dictionary, not a namespace
    if hasattr(conf, '__dict__'):
        conf = vars(conf)

    logger.info('Invoked audrey main')

    # Create the Client Object and test connectivity
    # to CS by negotiating the api version
    client = CSClient(**conf)
    client.test_connection()

    # Get the agent object
    agent = AudreyFactory(client.api_version).agent
    # run the agent
    agent(conf).run()
