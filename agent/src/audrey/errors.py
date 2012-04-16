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


class AAError(Exception):
    '''
    Some sort of error occurred. The exact cause of the error should
    have been logged. So, this just indicates that something is wrong.
    when invoked without args we redirect stderr to the log so
    logging here is not really nessesary
    '''
    pass


class AAErrorInvalidTar(AAError):
    '''
    Tar file could not be processed, it is invalid
    '''
    pass


class AAErrorApiNegotiation(AAError):
    '''
    not able to negotiate a valid api version with CS
    '''
    pass


class AAErrorPutProvides(AAError):
    '''
    Put on provides failed
    '''
    pass
