import json
import re
import subprocess
import os
import argparse
import sys

# If this script is not being run as part of an Octopus step, return variables from environment variables.
# Periods are replaced with underscores, and the variable name is converted to uppercase
if "get_octopusvariable" not in globals():
    def get_octopusvariable(variable):
        return os.environ[re.sub('\\.', '_', variable.upper())]

# If this script is not being run as part of an Octopus step, print directly to std out.
if "printverbose" not in globals():
    def printverbose(msg):
        print(msg)


def printverbose_noansi(output):
    """
    Strip ANSI color codes and print the output as verbose
    :param output: The output to print
    """
    output_no_ansi = re.sub('\x1b\[[0-9;]*m', '', output)
    printverbose(output_no_ansi)


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


def execute(args, cwd=None, env=None, print_args=None, print_output=printverbose_noansi):
    """
        The execute method provides the ability to execute external processes while capturing and returning the
        output to std err and std out and exit code.
    """
    process = subprocess.Popen(args,
                               stdout=subprocess.PIPE,
                               stderr=subprocess.PIPE,
                               text=True,
                               cwd=cwd,
                               env=env)
    stdout, stderr = process.communicate()
    retcode = process.returncode

    if print_args is not None:
        print_output(' '.join(args))

    if print_output is not None:
        print_output(stdout)
        print_output(stderr)

    return stdout, stderr, retcode


def init_argparse():
    """
    init_argparse does triple duty. It supports running the script as a regular CLI command, supports running the
    script in the context of a plain script step, and supports the script when embedded in a step template. This is
    why the values of all arguments are sourced from Octopus variables, and why we source from two styles of variables:
    regular project variables and prefixed step template variables.
    """
    parser = argparse.ArgumentParser(
        usage='%(prog)s [OPTION] [FILE]...',
        description='Find conflicts between Git repos'
    )
    parser.add_argument('--terraform-backend-type',
                        action='store',
                        default=get_octopusvariable_quiet('Terraform.Backend.Type') or get_octopusvariable_quiet(
                            'ListDownstream.Terraform.Backend.Type'),
                        help='The Terraform backend holding the state of downstream projects')
    parser.add_argument('--terraform-backend-init-1',
                        action='store',
                        default=get_octopusvariable_quiet('Terraform.Backend.Init1') or get_octopusvariable_quiet(
                            'ListDownstream.Terraform.Backend.Init1'),
                        help='The first additional argument to pass to "terraform init", usually the "-backend-config" arguments required to connect to a custom backend')
    parser.add_argument('--terraform-backend-init-2',
                        action='store',
                        default=get_octopusvariable_quiet('Terraform.Backend.Init2') or get_octopusvariable_quiet(
                            'ListDownstream.Terraform.Backend.Init2'),
                        help='The second additional argument to pass to "terraform init", usually the "-backend-config" arguments required to connect to a custom backend')
    parser.add_argument('--terraform-backend-init-3',
                        action='store',
                        default=get_octopusvariable_quiet('Terraform.Backend.Init3') or get_octopusvariable_quiet(
                            'ListDownstream.Terraform.Backend.Init3'),
                        help='The third additional argument to pass to "terraform init", usually the "-backend-config" arguments required to connect to a custom backend')
    parser.add_argument('--terraform-backend-init-4',
                        action='store',
                        default=get_octopusvariable_quiet('Terraform.Backend.Init4') or get_octopusvariable_quiet(
                            'ListDownstream.Terraform.Backend.Init4'),
                        help='The fourth additional argument to pass to "terraform init", usually the "-backend-config" arguments required to connect to a custom backend')
    parser.add_argument('--terraform-backend-init-5',
                        action='store',
                        default=get_octopusvariable_quiet('Terraform.Backend.Init5') or get_octopusvariable_quiet(
                            'ListDownstream.Terraform.Backend.Init5'),
                        help='The fifth additional argument to pass to "terraform init", usually the "-backend-config" arguments required to connect to a custom backend')

    return parser.parse_known_args()


parser, _ = init_argparse()

backend_type = parser.terraform_backend_type or 'pg'

with open('backend.tf', 'w') as f:
    f.write(f"""
    terraform {{
        backend "{backend_type}" {{
      }}
      required_providers {{
        octopusdeploy = {{ source = "OctopusDeployLabs/octopusdeploy", version = "0.22.0" }}
      }}
    }}
    """)

# Allow all the init args to be supplied as variables
custom_args = [x for x in
               [parser.terraform_backend_init_1, parser.terraform_backend_init_2, parser.terraform_backend_init_3,
                parser.terraform_backend_init_4, parser.terraform_backend_init_5] if x != '']
backend = re.sub('[^a-zA-Z0-9]', '_', get_octopusvariable('Octopus.Project.Name').lower())
# Use default values that make sense for the reference implementation if no custom values are provided
init_args = custom_args or [
    '-backend-config=conn_str=postgres://terraform:terraform@terraformdb:5432/' + backend + '?sslmode=disable']
full_init_args = ['terraform', 'init', '-no-color'] + init_args
execute(full_init_args)

workspaces, _, _ = execute(['terraform', 'workspace', 'list'])
workspaces = workspaces.replace('*', '').split('\n')

for workspace in workspaces:
    trimmed_workspace = workspace.strip()

    if trimmed_workspace == 'default' or trimmed_workspace == '':
        continue

    execute(['terraform', 'workspace', 'select', trimmed_workspace])
    workspace_json, _, ret_code, = execute(['terraform', 'show', '-json'])

    if ret_code != 0:
        print(workspace_json)
        sys.exit(1)

    state = json.loads(workspace_json)
    resources = [x for x in state.get('values', {}).get('root_module', {}).get('resources', {}) if
                 x.get('type', '') == 'octopusdeploy_project']

    # The outputs allow us to contact the downstream instance)
    api_key, _, api_key_retcode = execute(['terraform', 'output', '-raw', 'octopus_apikey'], print_output=None)
    server, _, server_retcode = execute(['terraform', 'output', '-raw', 'octopus_server'])
    space_id, _, space_id_retcode = execute(['terraform', 'output', '-raw', 'octopus_space_id'])
    space_name, _, _ = execute(['terraform', 'output', '-raw', 'octopus_space_name'])

    for resource in resources:
        git_settings = resource.get('values', {}).get('git_library_persistence_settings', [{}])
        url = git_settings[0].get('url', None) if len(git_settings) != 0 else None
        space_id = resource.get('values', {}).get('space_id', None)
        name = resource.get('values', {}).get('name', None)

        print(str(space_name or space_id or '') + ' "' + str(name or '') + '" ' + str(url or ''))
