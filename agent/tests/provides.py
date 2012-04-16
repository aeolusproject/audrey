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
import shutil
import unittest
import base64

from audrey.errors import AAError
from audrey.shell import run_cmd
from audrey.factory import AudreyFactory

from tests.mocks import HttpUnitTest
from tests import _write_file


class TestAudreyAgentProvidesV1(unittest.TestCase):
    '''
    Class for exercising the parsing of the Provides ParametersConfigs
    from the CS.
    '''

    def setUp(self):
        self.factory = AudreyFactory(1)

    def test_success_parameters(self):
        '''
        Success case:
        - Exercise parse_provides() and generate_provides()
          with valid input
        '''

        src = '|operatingsystem&is_virtual|'
        expected = ['operatingsystem', 'is_virtual']

        provides = self.factory.provides()
        provides.parse_cs_str(src)
        provides_str = provides.generate_cs_str()
        self.assertEqual(expected, provides.keys())

        # The values are not validatable because they are unpredictable
        # but all the expected parameters should be returned.
        # Note: %7C is the encoded |, %26 is the encoded &
        self.assertTrue('audrey_data=%7Coperatingsystem' in provides_str)
        for param in expected:
            self.assertIn(param, provides)

    def test_success_empty_provides(self):
        '''
        Success case:
        - Exercise parse_provides() and generate_provides()
          with valid demlims but empty input
        '''
        src = '||'
        provides = self.factory.provides()
        provides.parse_cs_str(src)
        provides_str = provides.generate_cs_str()
        self.assertEqual(provides.keys(), [])
        #self.assertEqual(provides.generate_cs_str(), 'audrey_data=%7C%26%7C')
        self.assertEqual(provides.generate_cs_str(), 'audrey_data=%7C%7C')

    def test_success_no_provides(self):
        '''
        Success case:
        - Exercise parse_provides() and generate_provides()
          with valid input
        - Containging an unavailable parameter
        '''

        src = '|uptime_days&unavailable_dogs&ipaddress|'
        #expected = ['uptime_days', 'unavailable_dogs', 'ipaddress']
        expected = ['ipaddress', 'uptime_days', 'unavailable_dogs']

        provides = self.factory.provides()
        provides.parse_cs_str(src)
        provides_str = provides.generate_cs_str()

        # Validate results
        self.assertEqual(provides.keys(), expected)

        # The values are not validatable because they are unpredictable
        # but all the expected parameters should be returned.
        # Note: %7C is the encoded |, %26 is the encoded &
        for param in expected:
            self.assertIn(param, provides)

        # Confirm unavailable parameters return None
        self.assertEqual(provides['unavailable_dogs'], None)

    def test_success_one_parameters(self):
        '''
        Success case:
        - Exercise parse_provides() and generate_provides()
          with valid input
        - with only one parameter
        '''

        # Establish valid test data:
        src = '|uptime_days|'
        expected = ['uptime_days']

        # Exersise code segment
        provides = self.factory.provides()
        provides.parse_cs_str(src)
        provides_str = provides.generate_cs_str()

        # Validate results
        self.assertEqual(provides.keys(), expected)

        # The values are not validatable because they are unpredictable
        # but all the expected parameters should be returned.
        # Note: %7C is the encoded |, %26 is the encoded &
        for param in expected:
            self.assertIn(param, provides)

    def test_success_one_parameter(self):
        '''
        Success case:
        - Exercise parse_provides() and generate_provides()
          with valid input
        - With only one parameter which is unavailable
        '''

        src = '|unavailable_dogs|'
        expected = ['unavailable_dogs']

        provides = self.factory.provides()
        provides.parse_cs_str(src)
        provides_str = provides.generate_cs_str()
        self.assertEqual(provides.keys(), expected)

        # The values are not validatable because they are unpredictable
        # but all the expected parameters should be returned.
        # Note: %7C is the encoded |, %26 is the encoded &
        for param in expected:
            self.assertIn(param, provides)

        # Confirm unavailable parameters return an empty string.
        self.assertIn('unavailable_dogs', provides)

    def test_failure_missing_delimiter(self):
        '''
        Failure case:
        - Exercise parse_provides() and generate_provides()
          with invalid input
        - missing leading delimiter
        '''

        src = 'unavailable_dogs|'
        expected = ['unavailable_dogs']

        provides = self.factory.provides()
        self.assertRaises(AAError, self.factory.provides().parse_cs_str, src)


class TestAudreyAgentProvidesV2(unittest.TestCase):
    '''
    Class for exercising the parsing of the Provides ParametersConfigs
    from the CS.
    '''

    def setUp(self):
        self.factory = AudreyFactory(2)

    def test_success_parameters(self):
        '''
        Success case:
        - Exercise parse_provides() and generate_provides()
          with valid input
        '''

        src = '|operatingsystem&is_virtual|test_service&test_service2|'
        expected = ['operatingsystem', 'is_virtual']

        provides = self.factory.provides()
        provides.parse_cs_str(src)
        provides_str = provides.generate_cs_str()
        self.assertEqual(expected, provides.keys())

        # The values are not validatable because they are unpredictable
        # but all the expected parameters should be returned.
        # Note: %7C is the encoded |, %26 is the encoded &
        self.assertTrue('audrey_data=%7Coperatingsystem' in provides_str)
        for param in expected:
            self.assertIn(param, provides)

    def test_success_empty_provides(self):
        '''
        Success case:
        - Exercise parse_provides() and generate_provides()
          with valid demlims but empty input
        '''
        src = '|||'
        provides = self.factory.provides()
        provides.parse_cs_str(src)
        provides_str = provides.generate_cs_str()
        self.assertEqual(provides.keys(), [])
        #self.assertEqual(provides.generate_cs_str(), 'audrey_data=%7C%26%7C')
        self.assertEqual(provides.generate_cs_str(), 'audrey_data=%7C%7C')

    def test_success_no_provides(self):
        '''
        Success case:
        - Exercise parse_provides() and generate_provides()
          with valid input
        - Containging an unavailable parameter
        '''

        src = '|uptime_days&unavailable_dogs&ipaddress|test_service|'
        #expected = ['uptime_days', 'unavailable_dogs', 'ipaddress']
        expected = ['ipaddress', 'uptime_days', 'unavailable_dogs']

        provides = self.factory.provides()
        provides.parse_cs_str(src)
        provides_str = provides.generate_cs_str()

        # Validate results
        self.assertEqual(provides.keys(), expected)

        # The values are not validatable because they are unpredictable
        # but all the expected parameters should be returned.
        # Note: %7C is the encoded |, %26 is the encoded &
        for param in expected:
            self.assertIn(param, provides)

        # Confirm unavailable parameters return None
        self.assertEqual(provides['unavailable_dogs'], None)

    def test_success_one_parameters(self):
        '''
        Success case:
        - Exercise parse_provides() and generate_provides()
          with valid input
        - with only one parameter
        '''

        # Establish valid test data:
        src = '|uptime_days|test_service|'
        expected = ['uptime_days']

        # Exersise code segment
        provides = self.factory.provides()
        provides.parse_cs_str(src)
        provides_str = provides.generate_cs_str()

        # Validate results
        self.assertEqual(provides.keys(), expected)

        # The values are not validatable because they are unpredictable
        # but all the expected parameters should be returned.
        # Note: %7C is the encoded |, %26 is the encoded &
        for param in expected:
            self.assertIn(param, provides)

    def test_success_one_parameter(self):
        '''
        Success case:
        - Exercise parse_provides() and generate_provides()
          with valid input
        - With only one parameter which is unavailable
        '''

        src = '|unavailable_dogs|not_real_service|'
        expected = ['unavailable_dogs']

        provides = self.factory.provides()
        provides.parse_cs_str(src)
        provides_str = provides.generate_cs_str()
        self.assertEqual(provides.keys(), expected)

        # The values are not validatable because they are unpredictable
        # but all the expected parameters should be returned.
        # Note: %7C is the encoded |, %26 is the encoded &
        for param in expected:
            self.assertIn(param, provides)

        # Confirm unavailable parameters return an empty string.
        self.assertIn('unavailable_dogs', provides)

    def test_failure_missing_delimiter(self):
        '''
        Failure case:
        - Exercise parse_provides() and generate_provides()
          with invalid input
        - missing leading delimiter
        '''

        src = 'unavailable_dogs|service_name'
        expected = ['unavailable_dogs']

        provides = self.factory.provides()
        self.assertRaises(AAError, provides.parse_cs_str, src)
