import sys
import subprocess

# Install our own dependencies
subprocess.check_call([sys.executable, '-m', 'pip', 'install', 'jwt'])

import argparse
import json
import os
import time
import urllib.request
from argparse import Namespace

import jwt

# If this script is not being run as part of an Octopus step, setting variables is a noop
if 'set_octopusvariable' not in globals():
    def set_octopusvariable(variable, value):
        pass

# If this script is not being run as part of an Octopus step, return variables from environment variables.
if 'get_octopusvariable' not in globals():
    def get_octopusvariable(variable):
        if variable == 'GitHub.App.Id':
            return os.environ['GITHUB_APP_ID']
        if variable == 'GitHub.App.PrivateKey':
            return os.environ['GITHUB_APP_PRIVATEKEY']
        if variable == 'GitHub.App.InstallationId':
            return os.environ['GITHUB_APP_INSTALLATIONID']

        return ''


def get_octopusvariable_quiet(variable):
    """
    Gets an octopus variable, or an empty string if it does not exist.
    :param variable: The variable name
    :return: The variable value, or an empty string if the variable does not exist
    """
    try:
        return get_octopusvariable(variable)
    except:
        return ''


def init_argparse() -> tuple[Namespace, list[str]]:
    parser = argparse.ArgumentParser(
        usage='%(prog)s [OPTION] [FILE]...',
        description='Fork a GitHub repo'
    )
    parser.add_argument('--github-app-id', action='store', default=get_octopusvariable_quiet('GitHub.App.Id'))
    parser.add_argument('--github-app-installation-id', action='store',
                        default=get_octopusvariable_quiet('GitHub.App.InstallationId'))
    parser.add_argument('--github-app-private-key', action='store',
                        default=get_octopusvariable_quiet('GitHub.App.PrivateKey'))

    return parser.parse_known_args()


parser, _ = init_argparse()

# Generate the tokens used by git and the GitHub API
app_id = parser.github_app_id
signing_key = jwt.jwk_from_pem(parser.github_app_private_key.encode('utf-8'))

payload = {
    # Issued at time
    'iat': int(time.time()),
    # JWT expiration time (10 minutes maximum)
    'exp': int(time.time()) + 600,
    # GitHub App's identifier
    'iss': app_id
}

# Create JWT
jwt_instance = jwt.JWT()
encoded_jwt = jwt_instance.encode(payload, signing_key, alg='RS256')

# Create access token
url = 'https://api.github.com/app/installations/' + parser.github_app_installation_id + '/access_tokens'
headers = {
    'Authorization': 'Bearer ' + encoded_jwt,
    'Accept': 'application/vnd.github+json',
    'X-GitHub-Api-Version': '2022-11-28'
}
request = urllib.request.Request(url, headers=headers, method='POST')
response = urllib.request.urlopen(request)
response_json = json.loads(response.read().decode())
token = response_json['token']

set_octopusvariable('GitHubToken', token)
