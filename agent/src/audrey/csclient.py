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

import shutil
import logging
import tempfile
import oauth2 as oauth

from xml.etree import ElementTree
from time import sleep

from audrey.errors import AAError
from audrey.errors import AAErrorApiNegotiation
SLEEP_SECS = 10

LOGGER = logging.getLogger('Audrey')

VERSION_URL = 'version'
TOOLING_URL = 'files'
CONFIGS_URL = 'configs'
PROVIDES_URL = 'params'
API_COMPAT = '1-2'


class CSClient(object):
    '''
    Description:
        Client interface to Config Server (CS)
    '''

    def __init__(self, endpoint, oauth_key, oauth_secret, **kwargs):
        '''
        Description:
            Set initial state so it can be tracked. Valuable for
            testing and debugging.
        '''

        self.api_version = 2
        self.cs_endpoint = endpoint
        self.cs_oauth_key = oauth_key
        self.cs_oauth_secret = oauth_secret
        self.cs_params = ''
        self.cs_configs = ''
        self.tmpdir = ''
        self.tarball = ''

        # create an oauth client for communication with the cs
        consumer = oauth.Consumer(self.cs_oauth_key, self.cs_oauth_secret)
        # 2 legged auth, token unnessesary
        token = None  # oauth.Token('access-key-here','access-key-secret-here')
        client = oauth.Client(consumer, token)
        self.http = client

        # BZ812915 compatibility for httplib2 0.7.x
        # assuming we're going to be connecting to a self signed cert
        if 'disable_ssl_certificate_validation' in dir(self.http):
            self.http.disable_ssl_certificate_validation = True

    def __del__(self):
        '''
        Description:
            Class destructor
        '''
        try:
            shutil.rmtree(self.tmpdir)
        except OSError:
            pass  # ignore any errors when attempting to remove the temp dir.

    def _cs_url(self, url_type):
        '''
        Description:
            Generate the Config Server (CS) URL.
        '''
        endpoint = '%s/%s' % (self.cs_endpoint.lower(), url_type)
        if url_type == 'version':
            endpoint += '?api_compat=%s' % API_COMPAT
        else:
            endpoint = '%s/%s/%s' % (endpoint,
                                     self.api_version,
                                     self.cs_oauth_key)
        return endpoint

    def _get(self, url, headers=None):
        '''
        Description:
            Issue the http get to the the Config Server.
        '''
        try:
            response = self.http.request(url, method='GET', headers=headers)
            return response
        except Exception, err:
            return (err, None)

    def _put(self, url, body=None, headers=None):
        '''
        Description:
            Issue the http put to the the Config Server.
        '''
        try:
            return self.http.request(url, method='PUT',
                                body=body, headers=headers)
        except Exception, err:
            return (err, None)

    @staticmethod
    def _validate_http_status(response):
        '''
        Description:
            Confirm the http status is one of:
            200 HTTP OK - Success and no more data of this type
            202 HTTP Accepted - Success and more data of this type
            404 HTTP Not Found - This may be temporary so try again
        '''
        if isinstance(response, Exception):
            raise response
        if response.status not in [200, 202, 404]:
            raise AAError('Invalid HTTP status code: %s' % response.status)

    # Public interfaces
    def test_connection(self, max_retry=5):
        '''
        call configserver's version endpoint and pass my compat api versions
        then parse the response to retireve the api version
        we should operate on
        '''
        # try and wait for connectivity if it's not there
        url = self._cs_url(VERSION_URL)
        response, body = self._get(url, {'Accept': 'text/xml'})
        while isinstance(response, Exception):
            if max_retry:
                max_retry -= 1
                LOGGER.info('Failed attempt to contact config server')
                sleep(SLEEP_SECS)
            else:
                raise AAError("Cannot establish connection to %s" % url)
            response, body = self._get(url)
        try:
            api_v = ElementTree.fromstring(body)
            api_v = api_v.find('api-version')
            self.api_version = int(api_v.text)
            LOGGER.info('Negotiated API V%s' % self.api_version)
        except Exception, err:
            raise AAErrorApiNegotiation(err)

    def get_configs(self, service=None):
        '''
        Description:
            get the required configuration from the Config Server.
        '''
        LOGGER.info('Invoked CSClient.get_configs()')
        url = self._cs_url(CONFIGS_URL)
        if service:
            url = '%s/%s' % (url, service)
        headers = {'Accept': 'text/plain'}

        response, body = self._get(url, headers=headers)
        self.cs_configs = body
        self._validate_http_status(response)

        return response.status, body

    def get_provides(self):
        '''
        Description:
            get the provides parameters from the Config Server.
        '''
        LOGGER.info('Invoked CSClient.get_params()')
        url = self._cs_url(PROVIDES_URL)
        headers = {'Accept': 'text/plain'}

        response, body = self._get(url, headers=headers)
        self.cs_params = body
        self._validate_http_status(response)

        return response.status, body

    def put_provides(self, params_values):
        '''
        Description:
            put the provides parameters to the Config Server.
        '''
        LOGGER.info('Invoked CSClient.put_params_values()')
        url = self._cs_url(PROVIDES_URL)
        headers = {'Content-Type': 'application/x-www-form-urlencoded'}

        response, body = self._put(url, body=params_values, headers=headers)
        return response.status, body

    def get_tooling(self):
        '''
        Description:
            get any optional user supplied tooling which is
            provided as a tarball
        '''
        LOGGER.info('Invoked CSClient.get_tooling()')
        url = self._cs_url(TOOLING_URL)
        headers = {'Accept': 'content-disposition'}

        tarball = ''
        response, body = self._get(url, headers=headers)
        self._validate_http_status(response)

        # Parse the file name burried in the response header
        # at: response['content-disposition']
        # as: 'attachment; tarball="tarball.tgz"'
        if (response.status == 200) or (response.status == 202):
            tarball = response['content-disposition']. \
                lstrip('attachment; filename=').replace('"', '')

            # Create the temporary tarfile
            try:
                self.tmpdir = tempfile.mkdtemp()
                self.tarball = self.tmpdir + '/' + tarball
                temptar = open(self.tarball, 'w')
                temptar.write(body)
                temptar.close()
            except IOError, err:
                raise AAError(('File not found or not a tar file: %s ' + \
                        'Error: %s') % (self.tarball, err))

        return response.status, self.tarball

    @staticmethod
    def validate_message(src):
        '''
        Perform validation of the text message sent from the Config Server.
        '''
        if not src.startswith('|') or not src.endswith('|'):
            raise AAError(('Invalid start and end characters: %s') % (src))
