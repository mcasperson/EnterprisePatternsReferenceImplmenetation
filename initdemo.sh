#!/bin/bash

if ! which docker
then
  echo "You must install Docker: https://docs.docker.com/get-docker/"
  exit 1
fi

if ! docker compose > /dev/null 2>&1
then
  echo "You must install Docker Compose: https://docs.docker.com/get-docker/"
  echo "Linux users can find instructions here: https://www.digitalocean.com/community/tutorials/how-to-install-and-use-docker-compose-on-ubuntu-22-04"
  exit 1
fi

if ! which curl
then
  echo "You must install curl"
  exit 1
fi

if ! which terraform
then
  echo "You must install terraform: https://developer.hashicorp.com/terraform/downloads"
  exit 1
fi

if ! which minikube
then
  echo "You must install minikube in order to automatically create the Kubernetes targets. The script will not attempt to create these targets."
fi

if ! which kubectl
then
  echo "You must install kubectl."
fi

if ! which openssl
then
  echo "You must install openssl"
  exit 1
fi

if ! which jq
then
  echo "You must install jq"
  exit 1
fi

if [[ -z "${OCTOPUS_SERVER_BASE64_LICENSE}" ]]
then
  echo "You must set the OCTOPUS_SERVER_BASE64_LICENSE environment variable to the base 64 encoded representation of an Octopus license."
  echo "See https://help.ubuntu.com/community/EnvironmentVariables for setting environment variables in Linux (this also applied to WSL)."
  echo "See https://apple.stackexchange.com/a/421171 for setting environment variables in macOS."
  exit 1
fi

if [[ -z "${TF_VAR_docker_username}" ]]
then
  echo "You must set the TF_VAR_docker_username environment variable to the DockerHub username."
  echo "See https://help.ubuntu.com/community/EnvironmentVariables for setting environment variables in Linux (this also applied to WSL)."
  echo "See https://apple.stackexchange.com/a/421171 for setting environment variables in macOS."
  exit 1
fi

if [[ -z "${TF_VAR_docker_password}" ]]
then
  echo "You must set the TF_VAR_docker_password environment variable to the DockerHub password."
  echo "See https://help.ubuntu.com/community/EnvironmentVariables for setting environment variables in Linux (this also applied to WSL)."
  echo "See https://apple.stackexchange.com/a/421171 for setting environment variables in macOS."
  exit 1
fi

if [[ "${INSTALL_ARGO}" == "TRUE" ]]
then
  if ! which argocd
  then
    echo "You must install the Aro CD CLI: https://argo-cd.readthedocs.io/en/stable/cli_installation/#download-with-curl"
    exit 1
  fi

  if ! which zip
  then
    echo "You must install zip"
    exit 1
  fi

  if ! (which octo || which dotnet-octo)
  then
    echo "You must install the Octopus CLI"
    exit 1
  fi
fi

OCTOCLI=octo
if which dotnet-octo
then
  OCTOCLI=dotnet-octo
fi

# We know these test credentials, so hard code them
export TF_VAR_git_username="octopus"
export TF_VAR_git_password="Password01!"
export TF_VAR_git_host="gitea:3000"
export TF_VAR_git_protocol="http"
export TF_VAR_git_organization="octopuscac"

# Create a new cluster with a custom configuration that binds to all network addresses
if which minikube
then
  # If the kube config file does not exist, we need to recreate the minikube cluster.
  if [[ ! -f /$HOME/octoconfig.yml ]]
  then
    minikube delete
  fi

  # KUBECONFIG is the environment variable that defines the path for a k8s config file for all k8s tooling
  export KUBECONFIG=/$HOME/octoconfig.yml

  # It is not uncommon for minikube to fail to start, especially if the docker stack and its network is started.
  # This retry loop will attempt to start minikube, and on failure to a hard cleanup and try again.
  max_retry=3
  counter=0
  until minikube start --container-runtime=containerd --driver=docker
  do
     ./cleanup.sh
     minikube delete

     sleep 10
     [[ counter -eq $max_retry ]] && echo "Failed! Try running the ./cleanup.sh script." && exit 1
     echo "Trying again. Try #$counter"
     ((counter++))
  done

  # We need ingress networking for the sample applications.
  minikube addons enable ingress

  # Start the Docker Compose stack
  pushd docker
  docker compose pull
  docker compose up -d
  popd

  # Link the octopus and gitea networks with miniukbe. This allows tools like Argo CD to access git, and allows
  # pods in Minikube to access Octopus (and visa versa).
  docker network connect minikube octopus
  docker network connect minikube gitea

  # This returns the IP address of the minikube network
  DOCKER_HOST_IP=$(minikube ip)

  # This is the internal port exposed by minikube
  CLUSTER_PORT="8443"

  # Extract the client certificate data
  CLIENT_CERTIFICATE=$(docker run --rm -v $HOME/octoconfig.yml:/workdir/octoconfig.yml:Z mikefarah/yq '.users[0].user.client-certificate' octoconfig.yml)
  CLIENT_KEY=$(docker run --rm -v $HOME/octoconfig.yml:/workdir/octoconfig.yml:Z mikefarah/yq '.users[0].user.client-key' octoconfig.yml)

  # Create a self contained PFX certificate
  openssl pkcs12 -export -name 'test.com' -password 'pass:Password01!' -out /tmp/kind.pfx -inkey "${CLIENT_KEY}" -in "${CLIENT_CERTIFICATE}"

  # Base64 encode the PFX file
  COMBINED_CERT=$(cat /tmp/kind.pfx | base64 -w0)
  if [[ $? -ne 0 ]]; then
    # Assume we are on a mac, which doesn't have -w
    COMBINED_CERT=$(cat /tmp/kind.pfx | base64)
  fi
else
  # Use dummy values. This allows us to gracefully fall back to a system that can't do k8s deployments but is otherwise functional.
  DOCKER_HOST_IP="kubernetes"
  CLUSTER_PORT="443"
  COMBINED_CERT="MIIQoAIBAzCCEFYGCSqGSIb3DQEHAaCCEEcEghBDMIIQPzCCBhIGCSqGSIb3DQEHBqCCBgMwggX/AgEAMIIF+AYJKoZIhvcNAQcBMFcGCSqGSIb3DQEFDTBKMCkGCSqGSIb3DQEFDDAcBAjBMRI6S6M9JgICCAAwDAYIKoZIhvcNAgkFADAdBglghkgBZQMEASoEEFTttp7/9moU4zB8mykyT2eAggWQBGjcI6T8UT81dkN3emaXFXoBY4xfqIXQ0nGwUUAN1TQKOY2YBEGoQqsfB4yZrUgrpP4oaYBXevvJ6/wNTbS+16UOBMHu/Bmi7KsvYR4i7m2/j/SgHoWWKLmqOXgZP7sHm2EYY74J+L60mXtUmaFO4sHoULCwCJ9V3/l2U3jZHhMVaVEB0KSporDF6oO5Ae3M+g7QxmiXsWoY1wBFOB+mrmGunFa75NEGy+EyqfTDF8JqZRArBLn1cphi90K4Fce51VWlK7PiJOdkkpMVvj+mNKEC0BvyfcuvatzKuTJsnxF9jxsiZNc28rYtxODvD3DhrMkK5yDH0h9l5jfoUxg+qHmcY7TqHqWiCdExrQqUlSGFzFNInUF7YmjBRHfn+XqROvYo+LbSwEO+Q/QViaQC1nAMwZt8PJ0wkDDPZ5RB4eJ3EZtZd2LvIvA8tZIPzqthGyPgzTO3VKl8l5/pw27b+77/fj8y/HcZhWn5f3N5Ui1rTtZeeorcaNg/JVjJu3LMzPGUhiuXSO6pxCKsxFRSTpf/f0Q49NCvR7QosW+ZAcjQlTi6XTjOGNrGD+C6wwZs1jjyw8xxDNLRmOuydho4uCpCJZVIBhwGzWkrukxdNnW722Wli9uEBpniCJ6QfY8Ov2aur91poIJDsdowNlAbVTJquW3RJzGMJRAe4mtFMzbgHqtTOQ/2HVnhVZwedgUJbCh8+DGg0B95XPWhZ90jbHqE0PIR5Par1JDsY23GWOoCxw8m4UGZEL3gOG3+yE2omB/K0APUFZW7Y5Nt65ylQVW5AHDKblPy1NJzSSo+61J+6jhxrBUSW21LBmAlnzgfC5xDs3Iobf28Z9kWzhEMXdMI9/dqfnedUsHpOzGVK+3katmNFlQhvQgh2HQ+/a3KNtBt6BgvzRTLACKxiHYyXOT8espINSl2UWL06QXsFNKKF5dTEyvEmzbofcgjR22tjcWKVCrPSKYG0YHG3AjbIcnn+U3efcQkeyuCbVJjjWP2zWj9pK4T2PuMUKrWlMF/6ItaPDDKLGGoJOOigtCC70mlDkXaF0km19RL5tIgTMXzNTZJAQ3F+xsMab8QHcTooqmJ5EPztwLiv/uC7j9RUU8pbukn1osGx8Bf5XBXAIP3OXTRaSg/Q56PEU2GBeXetegGcWceG7KBYSrS9UE6r+g3ZPl6dEdVwdNLXmRtITLHZBCumQjt2IW1o3zDLzQt2CKdh5U0eJsoz9KvG0BWGuWsPeFcuUHxFZBR23lLo8PZpV5/t+99ML002w7a80ZPFMZgnPsicy1nIYHBautLQsCSdUm7AAtCYf0zL9L72Kl+JK2aVryO77BJ9CPgsJUhmRQppjulvqDVt9rl6+M/6aqNWTFN43qW0XdP9cRoz6QxxbJOPRFDwgJPYrETlgGakB47CbVW5+Yst3x+hvGQI1gd84T7ZNaJzyzn9Srv9adyPFgVW6GNsnlcs0RRTY6WN5njNcxtL1AtaJgHgb54GtVFAKRQDZB7MUIoPGUpTHihw4tRphYGBGyLSa4HxZ7S76BLBReDj2D77sdO0QhyQIsCS8Zngizotf7rUXUEEzIQU9KrjEuStRuFbWpW6bED7vbODnR9uJR/FkqNHdaBxvALkMKRCQ/oq/UTx5FMDd2GCBT2oS2cehBAoaC9qkAfX2xsZATzXoAf4C+CW1yoyFmcr742oE4xFk3BcqmIcehy8i2ev8IEIWQ9ehixzqdbHKfUGLgCgr3PTiNfc+RECyJU2idnyAnog/3Yqd2zLCliPWYcXrzex2TVct/ZN86shQWP/8KUPa0OCkWhK+Q9vh3s2OTZIG/7LNQYrrg56C6dD+kcTci1g/qffVOo403+f6QoFdYCMNWVLB/O5e5tnUSNEDfP4sPKUgWQhxB53HcwggolBgkqhkiG9w0BBwGgggoWBIIKEjCCCg4wggoKBgsqhkiG9w0BDAoBAqCCCbEwggmtMFcGCSqGSIb3DQEFDTBKMCkGCSqGSIb3DQEFDDAcBAgBS68zHNqTgQICCAAwDAYIKoZIhvcNAgkFADAdBglghkgBZQMEASoEEIzB1wJPWoUGAgMgm6n2/YwEgglQGaOJRIkIg2BXvJJ0n+689/+9iDt8J3S48R8cA7E1hKMSlsXBzFK6VinIcjESDNf+nkiRpBIN1rmuP7WY81S7GWegXC9dp/ya4e8Y8HVqpdf+yhPhkaCn3CpYGcH3c+To3ylmZ5cLpD4kq1ehMjHr/D5SVxaq9y3ev016bZaVICzZ0+9PG8+hh2Fv/HK4dqsgjX1bPAc2kqnYgoCaF/ETtcSoiCLavMDFTFCdVeVQ/7TSSuFlT/HJRXscfdmjkYDXdKAlwejCeb4F4T2SfsiO5VVf15J/tgGsaZl77UiGWYUAXJJ/8TFTxVXYOTIOnBOhFBSH+uFXgGuh+S5eq2zq/JZVEs2gWgTz2Yn0nMpuHzLfiOKLRRk4pIgpZ3Lz44VBzSXjE2KaAopgURfoRQz25npPW7Ej/xjetFniAkxx2Ul/KTNu9Nu8SDR7zdbdJPK5hKh9Ix66opKg7yee2aAXDivedcKRaMpNApHMbyUYOmZgxc+qvcf+Oe8AbV6X8vdwzvBLSLAovuP+OubZ4G7Dt08dVAERzFOtxsjWndxYgiSbgE0onX37pJXtNasBSeOfGm5RIbqsxS8yj/nZFw/iyaS7CkTbQa8zAutGF7Q++0u0yRZntI9eBgfHoNLSv9Be9uD5PlPetBC7n3PB7/3zEiRQsuMH8TlcKIcvOBB56Alpp8kn4sAOObmdSupIjKzeW3/uj8OpSoEyJ+MVjbwCmAeq5sUQJwxxa6PoI9WHzeObI9PGXYNsZd1O7tAmnL00yJEQP5ZGMexGiQviL6qk7RW6tUAgZQP6L9cPetJUUOISwZNmLuoitPmlomHPNmjADDh+rFVxeNTviZY0usOxhSpXuxXCSlgRY/197FSms0RmDAjw/AEnwSCzDRJp/25n6maEJ8rWxQPZwcCfObsMfEtxyLkN4Qd62TDlTgekyxnRepeZyk8rXnwDDzK6GZRmXefBNq7dHFqp7eHG25EZJVotE43x3AKf/cHrf0QmmzkNROWadUitWPAxHjEZax9oVST5+pPJeJbROW6ItoBVWTSKLndxzn8Kyg/J6itaRUU4ZQ3QHPanO9uqqvjJ78km6PedoMyrk+HNkWVOeYD0iUV3caeoY+0/S+wbvMidQC0x6Q7BBaHYXCoH7zghbB4hZYyd7zRJ9MCW916QID0Bh+DX7sVBua7rLAMJZVyWfIvWrkcZezuPaRLxZHK54+uGc7m4R95Yg9V/Juk0zkHBUY66eMAGFjXfBl7jwg2ZQWX+/kuALXcrdcSWbQ6NY7en60ujm49A8h9CdO6gFpdopPafvocGgCe5D29yCYGAPp9kT+ComEXeHeLZ0wWlP77aByBdO9hJjXg7MSqWN8FuICxPsKThXHzH68Zi+xqqAzyt5NaVnvLvtMAaS4BTifSUPuhC1dBmTkv0lO36a1LzKlPi4kQnYI6WqOKg5bqqFMnkc+/y5UMlGO7yYockQYtZivVUy6njy+Gum30T81mVwDY21l7KR2wCS7ItiUjaM9X+pFvEa/MznEnKe0O7di8eTnxTCUJWKFAZO5n/k7PbhQm9ZGSNXUxeSwyuVMRj4AwW3OJvHXon8dlt4TX66esCjEzZKtbAvWQY68f2xhWZaOYbxDmpUGvG7vOPb/XZ8XtE57nkcCVNxtLKk47mWEeMIKF+0AzfMZB+XNLZFOqr/svEboPH98ytQ5j1sMs54rI9MHKWwSPrh/Wld18flZPtnZZHjLg5AAM0PX7YZyp3tDqxfLn/Uw+xOV/4RPxY3qGzvQb1CdNXUBSO9J8imIfSCySYsnpzdi3MXnAaA59YFi5WVLSTnodtyEdTeutO9UEw6q+ddjjkBzCPUOArc/60jfNsOThjeQvJWvzmm6BmrLjQmrQC3p8eD6kT56bDV6l2xkwuPScMfXjuwPLUZIK8THhQdXowj2CAi7qAjvHJfSP5pA4UU/88bI9SW07YCDmqTzRhsoct4c+NluqSHrgwRDcOsXGhldMDxF4mUGfObMl+gva2Sg+aXtnQnu90Z9HRKUNIGSJB7UBOKX/0ziQdB3F1KPmer4GQZrAq/YsVClKnyw3dkslmNRGsIcQET3RB0UEI5g4p0bcgL9kCUzwZFZ6QW2cMnl7oNlMmtoC+QfMo+DDjsbjqpeaohoLpactsDvuqXYDef62the/uIEEu6ezuutcwk5ABvzevAaJGSYCY090jeB865RDQUf7j/BJANYOoMtUwn/wyPK2vcMl1AG0fwYrL1M4brnVeMBcEpsbWfhzWgMObZjojP52hQBjl0F+F3YRfk0k1Us4hGYkjQvdMR3YJBnSll5A9dN5EhL53f3eubBFdtwJuFdkfNOsRNKpL0TcA//6HsJByn5K+KlOqkWkhooIp4RB6UBHOmSroXoeiMdopMm8B7AtiX7aljLD0ap480GAEZdvcR55UGpHuy8WxYmWZ3+WNgHNa4UE4l3W1Kt7wrHMVd0W6byxhKHLiGO/8xI1kv2gCogT+E7bFD20E/oyI9iaWQpZXOdGTVl2CqkCFGig+aIFcDADqG/JSiUDg/S5WucyPTqnFcmZGE+jhmfI78CcsB4PGT1rY7CxnzViP38Rl/NCcT9dNfqhQx5Ng5JlBsV3Ets0Zy6ZxIAUG5BbMeRp3s8SmbHoFvZMBINgoETdaw6AhcgQddqh/+BpsU7vObu6aehSyk9xGSeFgWxqOV8crFQpbl8McY7ONmuLfLjPpAHjv8s5TsEZOO+mu1LeSgYXuEGN0fxklazKGPRQe7i4Nez1epkgR6+/c7Ccl9QOGHKRpnZ4Mdn4nBCUzXn9jH80vnohHxwRLPMfMcArWKxY3TfRbazwQpgxVV9qZdTDXqRbnthtdrfwDBj2/UcPPjt87x8/qSaEWT/u9Yb65Gsigf0x7W7beYo0sWpyJJMJQL/U0cGM+kaFU6+fiPHz8jO1tkdVFWb+zv6AlzUuK6Q6EZ7F+DwqLTNUK1zDvpPMYKwt1b4bMbIG7liVyS4CQGpSNwY58QQ0TThnS1ykEoOlC74gB7Rcxp/pO8Ov2jHz1fY7CF7DmZeWqeRNATUWZSayCYzArTUZeNK4EPzo2RAfMy/5kP9RA11FoOiFhj5Ntis8kn2YRx90vIOH9jhJiv6TcqceNR+nji0Flzdnule6myaEXIoXKqp5RVVgJTqwQzWc13+0xRjAfBgkqhkiG9w0BCRQxEh4QAHQAZQBzAHQALgBjAG8AbTAjBgkqhkiG9w0BCRUxFgQUwpGMjmJDPDoZdapGelDCIEATkm0wQTAxMA0GCWCGSAFlAwQCAQUABCDRnldCcEWY+iPEzeXOqYhJyLUH7Geh6nw2S5eZA1qoTgQI4ezCrgN0h8cCAggA"
fi

if [[ "${INSTALL_ARGO}" == "TRUE" ]]
then
  kubectl create namespace argocd
  # Install Argo CD
  kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
  # Patch the server to expose Argo CD as a LoadBalancer (i.e. with an IP address we can open from the local desktop)
  kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
  # Define some user accounts
  kubectl apply -f argocd/argocd-config/argocd-cm.yaml
  # Set the permissions for the user accounts
  kubectl apply -f argocd/argocd-config/argocd-rbac-cm.yaml
  # Setup some triggers
  kubectl apply -f argocd/argocd-config/argocd-notifications-cm.yaml
  # Restart the argocd server to pick up the new settings
  kubectl -n argocd rollout restart deploy argocd-repo-server
fi

# Set the initial admin Gitea user
EXISTING=$(docker exec -i gitea su git bash -c "gitea admin user list")
USER='octopus'
if [[ "$EXISTING" == *"$USER"* ]]; then
  echo "User exists"
else
  echo "We expect to see errors here and so will retry until Gitea is started."
  max_retry=6
  counter=0
  until docker exec -i gitea su git bash -c "gitea admin user create --admin --username octopus --password Password01! --email me@example.com"
  do
     sleep 10
     [[ counter -eq $max_retry ]] && echo "Failed!" && exit 1
     echo "Trying again. Try #$counter"
     ((counter++))
  done
fi

# Create a regular Gitea users
docker exec -i gitea su git bash -c "gitea admin user create --username editor --password Password01! --email editor@example.com --must-change-password=false"

# Create the orgs.
if ! curl -u "octopus:Password01!" http://localhost:3000/api/v1/orgs/octopuscac/teams --fail --silent
then
  max_retry=6
  counter=0
  until curl \
    --output /dev/null \
    --silent \
    -u "octopus:Password01!" \
    -X POST \
    "http://localhost:3000/api/v1/admin/users/octopus/orgs" \
    -H "Content-Type: application/json" \
    -H "accept: application/json" \
    --data '{"username": "octopuscac"}' \
    --fail
  do
     sleep 10
     [[ counter -eq $max_retry ]] && echo "Failed to create gitea org!" && exit 1
     echo "Trying again. Try #$counter"
     ((counter++))
  done
fi

# Create a users team in the new org
if ! curl -u "octopus:Password01!" http://localhost:3000/api/v1/teams/2 --fail --silent
then
  max_retry=6
  counter=0
  until curl \
    --output /dev/null \
    --silent \
    -u "octopus:Password01!" \
    -X POST \
    "http://localhost:3000/api/v1/orgs/octopuscac/teams" \
    -H "Content-Type: application/json" \
    -H "accept: application/json" \
    --data '{
        "name": "Users",
        "description": "",
        "organization": null,
        "includes_all_repositories": true,
        "permission": "write",
        "units": [
            "repo.releases",
            "repo.packages",
            "repo.ext_issues",
            "actions.actions",
            "repo.projects",
            "repo.ext_wiki",
            "repo.issues",
            "repo.wiki",
            "repo.pulls",
            "repo.code"
        ],
        "units_map": {
            "actions.actions": "write",
            "repo.code": "write",
            "repo.ext_issues": "read",
            "repo.ext_wiki": "read",
            "repo.issues": "write",
            "repo.packages": "write",
            "repo.projects": "write",
            "repo.pulls": "write",
            "repo.releases": "write",
            "repo.wiki": "write"
        },
        "can_create_org_repo": false
    }' \
    --fail
  do
     sleep 10
     [[ counter -eq $max_retry ]] && echo "Failed to add users to Gitea org!" && exit 1
     echo "Trying again. Try #$counter"
     ((counter++))
  done
fi

# Add the editor user to the users team
curl \
  --output /dev/null \
  --silent \
  -u "octopus:Password01!" \
  -X PUT \
  "http://localhost:3000/api/v1/teams/2/members/editor" \
  -H "accept: application/json" \
  --fail

# Create the repos and populate with an initial commit.
for repo in hello_world_cac azure_web_app_cac k8s_microservice_template
do
  # Create the repo
  curl \
    --output /dev/null \
    --silent \
    -u "octopus:Password01!" \
    -X POST \
    "http://localhost:3000/api/v1/org/octopuscac/repos" \
    -H "content-type: application/json" \
    -H "accept: application/json" \
    --data "{\"name\":\"${repo}\"}"

  # Add the first commit to initialize the repo.
  curl \
    --output /dev/null \
    --silent \
    -u "octopus:Password01!" \
    -X POST "http://localhost:3000/api/v1/repos/octopuscac/${repo}/contents/README.md" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -d "{ \"author\": { \"email\": \"user@example.com\", \"name\": \"Octopus\" }, \"branch\": \"main\", \"committer\": { \"email\": \"user@example.com\", \"name\": \"string\" }, \"content\": \"UkVBRE1FCg==\", \"dates\": { \"author\": \"2020-04-06T01:37:35.137Z\", \"committer\": \"2020-04-06T01:37:35.137Z\" }, \"message\": \"Initializing repo\"}"

  WEBHOOKS=$(curl -u "octopus:Password01!" --location --silent "http://localhost:3000/api/v1/repos/octopuscac/${repo}/hooks")
  EXISTS=$(echo "${WEBHOOKS}" | jq -r '[ .[] | select(.config.url == "http://giteaproxy:4000") ] | length')

  if [[ "${EXISTS}" == 0 ]]
  then
    # Add a webhook
    curl \
        -u "octopus:Password01!" \
        --output /dev/null \
        --location \
        --silent \
        --request POST \
        "http://localhost:3000/api/v1/repos/octopuscac/${repo}/hooks" \
        --header 'Content-Type: application/json' \
        --header 'Content-Type: application/json' \
        --data-raw '{
          "active": true,
          "branch_filter": "*",
          "config": {
            "content_type": "json",
            "url": "http://giteaproxy:4000",
            "http_method": "post"
          },
          "events": [
            "pull_request",
            "pull_request_sync"
          ],
          "type": "gitea"
        }'
    fi
done

for repo in hello_world_cac
do
  CHECK_JS=$(cat "pr_ocl_check/check.js" | base64 -w0)
  if [[ $? -ne 0 ]]; then
    # Assume we are on a mac, which doesn't have -w
    CHECK_JS=$(cat "pr_ocl_check/check.js" | base64)
  fi

  PACKAGE_JSON=$(cat "pr_ocl_check/package.json" | base64 -w0)
  if [[ $? -ne 0 ]]; then
    # Assume we are on a mac, which doesn't have -w
    PACKAGE_JSON=$(cat "pr_ocl_check/package.json" | base64)
  fi

  curl \
    --output /dev/null \
    --silent \
    -u "octopus:Password01!" \
    -X POST "http://localhost:3000/api/v1/repos/octopuscac/${repo}/contents/check.js" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -d "{ \"author\": { \"email\": \"user@example.com\", \"name\": \"Octopus\" }, \"branch\": \"main\", \"committer\": { \"email\": \"user@example.com\", \"name\": \"string\" }, \"content\": \"${CHECK_JS}\", \"dates\": { \"author\": \"2020-04-06T01:37:35.137Z\", \"committer\": \"2020-04-06T01:37:35.137Z\" }, \"message\": \"Upload PR check script\"}"

  curl \
      --output /dev/null \
      --silent \
      -u "octopus:Password01!" \
      -X POST "http://localhost:3000/api/v1/repos/octopuscac/${repo}/contents/package.json" \
      -H "accept: application/json" \
      -H "Content-Type: application/json" \
      -d "{ \"author\": { \"email\": \"user@example.com\", \"name\": \"Octopus\" }, \"branch\": \"main\", \"committer\": { \"email\": \"user@example.com\", \"name\": \"string\" }, \"content\": \"${PACKAGE_JSON}\", \"dates\": { \"author\": \"2020-04-06T01:37:35.137Z\", \"committer\": \"2020-04-06T01:37:35.137Z\" }, \"message\": \"Upload PR check script\"}"
done

# Create and populate a repo for Argo CD
if [[ "${INSTALL_ARGO}" == "TRUE" ]]
then
# Create the ArgoCD repo
  curl \
    --output /dev/null \
    --silent \
    -u "octopus:Password01!" \
    -X POST \
    "http://localhost:3000/api/v1/org/octopuscac/repos" \
    -H "content-type: application/json" \
    -H "accept: application/json" \
    --data "{\"name\":\"argo_cd\"}"

  # Add the first commit to initialize the repo.
  curl \
    --output /dev/null \
    --silent \
    -u "octopus:Password01!" \
    -X POST "http://localhost:3000/api/v1/repos/octopuscac/argo_cd/contents/README.md" \
    -H "accept: application/json" \
    -H "Content-Type: application/json" \
    -d "{ \"author\": { \"email\": \"user@example.com\", \"name\": \"Octopus\" }, \"branch\": \"main\", \"committer\": { \"email\": \"user@example.com\", \"name\": \"string\" }, \"content\": \"UkVBRE1FCg==\", \"dates\": { \"author\": \"2020-04-06T01:37:35.137Z\", \"committer\": \"2020-04-06T01:37:35.137Z\" }, \"message\": \"Initializing repo\"}"

  # Checkout the repo, add the argo files, and commit
  argocddir=$(mktemp -d 2>/dev/null || mktemp -d -t 'argocddir')
  cwd=$(pwd)
  pushd "$argocddir"
    git clone http://octopus:Password01!@localhost:3000/octopuscac/argo_cd.git .
    git config user.email "octopus@local"
    git config user.name "Octopus"
    cp -r "$cwd/argocd" "$argocddir"
    git add .
    git commit -m "Added Argo CD apps"
    git push
  popd

fi

# Install all the tools we'll need to perform deployments. This means we don't need a separate worker to do deployments,
# and can do deployments directly on the Octopus server.
docker compose -f docker/compose.yml exec octopus sh -c 'apt-get update'
docker compose -f docker/compose.yml exec octopus sh -c 'apt-get install -y ca-certificates curl gnupg jq git dnsutils zip gnupg software-properties-common python3 python3-pip'
docker compose -f docker/compose.yml exec octopus sh -c 'mkdir -p /etc/apt/keyrings'
docker compose -f docker/compose.yml exec octopus sh -c 'if [ ! -f /etc/apt/keyrings/nodesource.gpg ]; then curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg; fi';
docker compose -f docker/compose.yml exec octopus sh -c 'echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" | tee /etc/apt/sources.list.d/nodesource.list'
docker compose -f docker/compose.yml exec octopus sh -c 'apt-get update'
docker compose -f docker/compose.yml exec octopus sh -c 'apt-get install nodejs -y'
docker compose -f docker/compose.yml exec octopus sh -c 'pip install slack_sdk'
docker compose -f docker/compose.yml exec octopus sh -c 'pip install pycryptodome'
docker compose -f docker/compose.yml exec octopus sh -c 'apt update --allow-insecure-repositories; apt install -y --no-install-recommends gnupg curl ca-certificates apt-transport-https && curl -sSfL https://apt.octopus.com/public.key | apt-key add - && sh -c "echo deb https://apt.octopus.com/ stable main > /etc/apt/sources.list.d/octopus.com.list" && apt update; apt install -y octopuscli'
docker compose -f docker/compose.yml exec octopus sh -c 'if [ ! -f /usr/share/keyrings/hashicorp-archive-keyring.gpg ]; then wget -O- https://apt.releases.hashicorp.com/gpg | gpg --dearmor > /usr/share/keyrings/hashicorp-archive-keyring.gpg; fi'
docker compose -f docker/compose.yml exec octopus sh -c 'echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" > /etc/apt/sources.list.d/hashicorp.list'
docker compose -f docker/compose.yml exec octopus sh -c 'apt update --allow-insecure-repositories; apt-get install -y terraform'
docker compose -f docker/compose.yml exec octopus sh -c 'curl -sL https://aka.ms/InstallAzureCLIDeb | bash'
docker compose -f docker/compose.yml exec octopus sh -c 'if [ ! -f /usr/local/bin/kubectl ]; then curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl; fi'
# Download all the terraform provider versions. This removes a point of failure during demos, as well as speeding complex deployments up.
docker compose -f docker/compose.yml exec octopus sh -c 'RELEASES=$(curl --silent https://api.github.com/repos/OctopusDeployLabs/terraform-provider-octopusdeploy/releases | jq -r ".[0:5] | .[].name[1:]"); echo $RELEASES; for RELEASE in ${RELEASES}; do echo "Downloading https://github.com/OctopusDeployLabs/terraform-provider-octopusdeploy/releases/download/v${RELEASE}/terraform-provider-octopusdeploy_${RELEASE}_linux_amd64.zip"; mkdir -p "/terraformcache/registry.terraform.io/octopusdeploylabs/octopusdeploy/${RELEASE}/linux_amd64"; cd "/terraformcache/registry.terraform.io/octopusdeploylabs/octopusdeploy/${RELEASE}/linux_amd64"; if [ ! -f "terraform-provider-octopusdeploy_v${RELEASE}" ]; then curl --silent -L -o "terraform-provider-octopusdeploy_${RELEASE}_linux_amd64.zip" "https://github.com/OctopusDeployLabs/terraform-provider-octopusdeploy/releases/download/v${RELEASE}/terraform-provider-octopusdeploy_${RELEASE}_linux_amd64.zip"; unzip -o "terraform-provider-octopusdeploy_${RELEASE}_linux_amd64.zip"; rm "terraform-provider-octopusdeploy_${RELEASE}_linux_amd64.zip"; fi; done'
# Download 0.22.0 specifically, which is referenced by some of the python scripts
docker compose -f docker/compose.yml exec octopus sh -c 'mkdir -p "/terraformcache/registry.terraform.io/octopusdeploylabs/octopusdeploy/0.22.0/linux_amd64"; cd "/terraformcache/registry.terraform.io/octopusdeploylabs/octopusdeploy/0.22.0/linux_amd64"; if [ ! -f "terraform-provider-octopusdeploy_v0.22.0" ]; then curl --silent -L -o "terraform-provider-octopusdeploy_0.22.0_linux_amd64.zip" "https://github.com/OctopusDeployLabs/terraform-provider-octopusdeploy/releases/download/v0.22.0/terraform-provider-octopusdeploy_0.22.0_linux_amd64.zip"; unzip -o "terraform-provider-octopusdeploy_0.22.0_linux_amd64.zip"; rm "terraform-provider-octopusdeploy_0.22.0_linux_amd64.zip"; fi'
# https://developer.hashicorp.com/terraform/cli/config/config-file#explicit-installation-method-configuration
docker compose -f docker/compose.yml exec octopus sh -c 'echo "provider_installation {\nfilesystem_mirror {\npath = \"/terraformcache\"\ninclude = [\"registry.terraform.io/octopusdeploylabs/octopusdeploy\"]\n}\n}" > ~/.terraformrc'
docker compose -f docker/compose.yml exec octopus sh -c 'curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64; install -m 555 argocd-linux-amd64 /usr/local/bin/argocd; rm argocd-linux-amd64'

# Wait for the Octopus server.
echo "Waiting for the Octopus server"
max_retry=24
counter=0
exit_code=1
until [[ "${exit_code}" == "0" ]]
do
  [[ counter -eq $max_retry ]] && echo "Failed!" && echo "Check the Octopus logs with:" && echo "docker logs octopus" && exit 1
  [[ counter -ne 0 ]] && sleep 5
  ((counter++))
  curl --output /dev/null --silent --fail http://localhost:18080/api
  exit_code=$?
done

echo ""

delete_project () {
  SPACE_ID="${1}"
  PROJECT_NAME="${2}"

  PROJECT_ID=$(curl --silent --header 'X-Octopus-ApiKey: API-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' "http://localhost:18080/api/${SPACE_ID}/Projects/all" | jq -r ".[] | select(.Name == \"${PROJECT_NAME}\") | .Id")
  curl --silent -X DELETE --header 'X-Octopus-ApiKey: API-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' "http://localhost:18080/api/${SPACE_ID}/Projects/${PROJECT_ID}"
}

execute_terraform () {
  PG_DATABASE="${1}"
  TF_MODULE_PATH="${2}"
  SPACE_ID="${3}"

  docker compose -f docker/compose.yml exec terraformdb sh -c "/usr/bin/psql -v ON_ERROR_STOP=1 --username \"\$POSTGRES_USER\" -c \"CREATE DATABASE $PG_DATABASE\""
  pushd "${TF_MODULE_PATH}" || exit 1

  terraform init -reconfigure -upgrade
  terraform workspace new "${SPACE_ID}" || echo "Workspace already exists"
  terraform workspace select "${SPACE_ID}"

  # Sometimes the TF provider fails, especially with scoped variables. A retry usually fixes it.
  max_retry=2
  counter=0
  exit_code=1
  until [[ "${exit_code}" == "0" ]]
  do
    [[ counter -eq $max_retry ]] && echo "Failed!" && exit 1
    [[ counter -ne 0 ]] && sleep 5
    ((counter++))
    terraform apply -auto-approve "-var=octopus_space_id=${SPACE_ID}"
    exit_code=$?
  done

  popd || exit 1
}

execute_terraform_destroy () {
  PG_DATABASE="${1}"
  TF_MODULE_PATH="${2}"
  SPACE_ID="${3}"

  docker compose -f docker/compose.yml exec terraformdb sh -c "/usr/bin/psql -v ON_ERROR_STOP=1 --username \"\$POSTGRES_USER\" -c \"CREATE DATABASE $PG_DATABASE\""
  pushd "${TF_MODULE_PATH}" || exit 1

  terraform init -reconfigure -upgrade
  terraform workspace new "${SPACE_ID}" || echo "Workspace already exists"
  terraform workspace select "${SPACE_ID}"
  terraform destroy -auto-approve "-var=octopus_space_id=${SPACE_ID}"

  popd || exit 1
}

execute_terraform_with_workspace () {
  ALL_ARGS=("$@")
  PG_DATABASE="${1}"
  WORKSPACE="${2}"
  TF_MODULE_PATH="${3}"
  SPACE_ID="${4}"
  OTHER_ARGS=("${ALL_ARGS[@]:4}")

  docker compose -f docker/compose.yml exec terraformdb sh -c "/usr/bin/psql -v ON_ERROR_STOP=1 --username \"\$POSTGRES_USER\" -c \"CREATE DATABASE $PG_DATABASE\""
  pushd "${TF_MODULE_PATH}" || exit 1

  terraform init -reconfigure -upgrade
  terraform workspace new "${SPACE_ID}-${WORKSPACE}" || echo "Workspace already exists"
  terraform workspace select "${SPACE_ID}-${WORKSPACE}"

  # Sometimes the TF provider fails, especially with scoped variables. A retry usually fixes it.
  max_retry=2
  counter=0
  exit_code=1
  until [[ "${exit_code}" == "0" ]]
  do
    [[ counter -eq $max_retry ]] && echo "Failed!" && exit 1
    [[ counter -ne 0 ]] && sleep 5
    ((counter++))
    # This function is assumed to be used by modules that create resources outside of Octopus,
    # in which case the octopus_server is http://localhost:18080, or inside Octopus, in which case
    # the step deploying this module will set octopus_server to http://octopus:8080.
    # Exposing the octopus_server variable is unique to modules applied with execute_terraform_with_workspace.
    terraform apply -auto-approve "-var=octopus_space_id=${SPACE_ID}" "-var=octopus_server=http://localhost:18080" "${OTHER_ARGS[@]}"
    exit_code=$?
  done

  popd || exit 1
}

execute_terraform_with_project () {
    PG_DATABASE="${1}"
    TF_MODULE_PATH="${2}"
    WORKSPACE="${3}"
    PROJECT="${4}"
    SPACE_ID="${5}"
    CREATE_SPACE_PROJECT="${6}"
    CREATE_SPACE_RUNBOOK="${7}"
    COMPOSE_PROJECT="${8}"
    COMPOSE_RUNBOOK="${9}"

    docker compose -f docker/compose.yml exec terraformdb sh -c "/usr/bin/psql -v ON_ERROR_STOP=1 --username \"\$POSTGRES_USER\" -c \"CREATE DATABASE $PG_DATABASE\""
    pushd "${TF_MODULE_PATH}" || exit 1

    terraform init -reconfigure -upgrade
    terraform workspace new "${SPACE_ID}_${WORKSPACE}" || echo "Workspace already exists"
    terraform workspace select "${SPACE_ID}_${WORKSPACE}"

    # Sometimes the TF provider fails, especially with scoped variables. A retry usually fixes it.
    max_retry=3
    counter=0
    exit_code=1
    until [[ "${exit_code}" == "0" ]]
    do
       [[ counter -eq $max_retry ]] && echo "Failed!" && exit 1
       [[ counter -ne 0 ]] && sleep 5
       ((counter++))

       if [[ -z "${COMPOSE_PROJECT}" && -z "${CREATE_SPACE_PROJECT}"  ]]
       then
         terraform apply -auto-approve "-var=octopus_space_id=${SPACE_ID}" "-var=project_name=${PROJECT}"
       elif [[ -z "${COMPOSE_PROJECT}" ]]
       then
         terraform apply -auto-approve "-var=octopus_space_id=${SPACE_ID}" "-var=project_name=${PROJECT}" "-var=create_space_project=${CREATE_SPACE_PROJECT}" "-var=create_space_runbook=${CREATE_SPACE_RUNBOOK}"
       else
         terraform apply -auto-approve "-var=octopus_space_id=${SPACE_ID}" "-var=project_name=${PROJECT}" "-var=create_space_project=${CREATE_SPACE_PROJECT}" "-var=create_space_runbook=${CREATE_SPACE_RUNBOOK}" "-var=compose_project=${COMPOSE_PROJECT}" "-var=compose_runbook=${COMPOSE_RUNBOOK}"
       fi

       exit_code=$?
    done


    popd || exit 1
}

execute_terraform_with_spacename () {
  PG_DATABASE="${1}"
  TF_MODULE_PATH="${2}"
  SPACENAME="${3}"

  docker compose -f docker/compose.yml exec terraformdb sh -c "/usr/bin/psql -v ON_ERROR_STOP=1 --username \"\$POSTGRES_USER\" -c \"CREATE DATABASE $PG_DATABASE\""
  pushd "${TF_MODULE_PATH}" || exit 1

  terraform init -reconfigure -upgrade
  terraform workspace new "${SPACENAME//[^[:alnum:]]/_}" || echo "Workspace already exists"
  terraform workspace select "${SPACENAME//[^[:alnum:]]/_}"

  # Sometimes the TF provider fails, especially with scoped variables. A retry usually fixes it.
  max_retry=2
  counter=0
  exit_code=1
  until [[ "${exit_code}" == "0" ]]
  do
   [[ counter -eq $max_retry ]] && echo "Failed!" && exit 1
   [[ counter -ne 0 ]] && sleep 5
   ((counter++))

    terraform apply -auto-approve "-var=space_name=${SPACENAME}"
    exit_code=$?
  done
  popd || exit 1
}

publish_runbook() {
  PROJECT_NAME="${1}"
  RUNBOOK_NAME="${2}"
  DATE=$(date '+%Y-%m-%d %H:%M:%S')

  PROJECT_ID=$(curl --silent --header 'X-Octopus-ApiKey: API-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' http://localhost:18080/api/Spaces-1/Projects/all | jq -r ".[] | select(.Name == \"${PROJECT_NAME}\") | .Id")
  RUNBOOK_ID=$(curl --silent --header 'X-Octopus-ApiKey: API-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' http://localhost:18080/api/Spaces-1/Projects/${PROJECT_ID}/runbooks | jq -r ".Items[] | select(.Name == \"${RUNBOOK_NAME}\") | .Id")
  PUBLISH=$(curl --request POST --silent --header 'X-Octopus-ApiKey: API-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA' --header 'Content-Type: application/json' http://localhost:18080/api/Spaces-1/runbookSnapshots?publish=true --data-raw "{\"ProjectId\":\"${PROJECT_ID}\",\"RunbookId\":\"${RUNBOOK_ID}\",\"Notes\":null,\"Name\":\"${RUNBOOK_NAME} ${DATE}\",\"SelectedPackages\":[]}")
}

# This is the space used to represent a development Octopus instance. This instance is where teams
# edit the deployment process before it is applied to the test and production Octopus instances.
execute_terraform_with_spacename 'spaces' 'shared/spaces/pgbackend' 'Development'

# This is the space used to represent a test and production Octopus instance. The projects on this
# instance are prompted from the development instance.
execute_terraform_with_spacename 'spaces' 'shared/spaces/pgbackend' 'Test\Production'

# The development "instance" has the dev environment in its simple lifecycle, and a sync environment to promote projects
execute_terraform 'sync_environment' 'shared/environments/sync/pgbackend' 'Spaces-2'
execute_terraform 'environments' 'shared/environments/dev_test_prod/pgbackend' 'Spaces-2'
execute_terraform 'lifecycle_simple_dev' 'shared/lifecycles/simple_dev/pgbackend' 'Spaces-2'

# The test/prod "instance" has test and production environments in their simple lifecycle
execute_terraform 'environments' 'shared/environments/dev_test_prod/pgbackend' 'Spaces-3'
execute_terraform 'lifecycle_simple_test_prod' 'shared/lifecycles/simple_test_prod/pgbackend' 'Spaces-3'

# Prepare both spaces with the global resources needed to host the sample project
for space in "Spaces-2" "Spaces-3"
do
  execute_terraform 'project_group_hello_world' 'shared/project_group/hello_world/pgbackend' "${space}"
done

# The dev instance gets library variable sets for exporting projects
execute_terraform 'lib_var_octopus_server' 'shared/variables/octopus_server/pgbackend' "Spaces-2"
execute_terraform 'lib_var_this_instance' 'shared/variables/this_instance/pgbackend' "Spaces-2"

# Deploy the sample project to the dev space
execute_terraform 'project_hello_world' 'management_instance/projects/hello_world/pgbackend' "Spaces-2"

# The dev instance gets a tenant representing test/prod
execute_terraform 'tenants_environment' 'management_instance/tenants/environment_tenants/pgbackend' "Spaces-2"

# Append the common runbooks to the sample project
for project in "Hello World"
do
  execute_terraform_with_project 'serialize_and_deploy' 'management_instance/runbooks/serialize_and_deploy/pgbackend' "${project//[^[:alnum:]]/_}" "${project}" "Spaces-2"
  execute_terraform_with_project 'runbooks_list' 'management_instance/runbooks/list/pgbackend' "${project//[^[:alnum:]]/_}" "${project}" "Spaces-2"
done

execute_terraform 'team_variable_editor' 'shared/team/deployer_variable_editor/pgbackend' 'Spaces-1'

execute_terraform 'team_deployer' 'shared/team/deployer/pgbackend' 'Spaces-1'

execute_terraform 'gitcreds' 'shared/gitcreds/gitea/pgbackend' 'Spaces-1'

execute_terraform 'environments' 'shared/environments/dev_test_prod/pgbackend' 'Spaces-1'

execute_terraform 'lifecycle_simple_dev_test_prod' 'shared/lifecycles/simple_dev_test_prod/pgbackend' 'Spaces-1'

execute_terraform 'sync_environment' 'shared/environments/sync/pgbackend' 'Spaces-1'

execute_terraform 'mavenfeed' 'shared/feeds/maven/pgbackend' 'Spaces-1'

execute_terraform 'dockerhubfeed' 'shared/feeds/dockerhub/pgbackend' 'Spaces-1'

execute_terraform 'project_group_client_space' 'management_instance/project_group/client_space/pgbackend' 'Spaces-1'

execute_terraform 'project_group_hello_world' 'shared/project_group/hello_world/pgbackend' 'Spaces-1'

execute_terraform 'project_group_azure' 'shared/project_group/azure/pgbackend' 'Spaces-1'

execute_terraform 'project_group_k8s' 'shared/project_group/k8s/pgbackend' 'Spaces-1'

execute_terraform 'lib_var_this_instance' 'shared/variables/this_instance/pgbackend' 'Spaces-1'

execute_terraform 'management_tenant_tags' 'management_instance/tenant_tags/regional/pgbackend' 'Spaces-1'

execute_terraform 'account_azure' 'shared/accounts/azure/pgbackend' 'Spaces-1'

execute_terraform 'lib_var_octopus_server' 'shared/variables/octopus_server/pgbackend' 'Spaces-1'

execute_terraform 'lib_var_azure' 'shared/variables/azure/pgbackend' 'Spaces-1'

execute_terraform 'lib_var_docker' 'shared/variables/docker/pgbackend' 'Spaces-1'

execute_terraform 'lib_var_k8s' 'shared/variables/k8s/pgbackend' 'Spaces-1'

execute_terraform 'lib_var_client_slack' 'shared/variables/client_slack/pgbackend' 'Spaces-1'

execute_terraform 'lib_var_slack' 'shared/variables/slack/pgbackend' 'Spaces-1'

execute_terraform 'lib_var_git' 'shared/variables/git/pgbackend' 'Spaces-1'

execute_terraform 'lib_var_export_options' 'shared/variables/export_options/pgbackend' 'Spaces-1'

execute_terraform 'project_create_client_space' 'management_instance/projects/create_client_space/pgbackend' 'Spaces-1'
publish_runbook "__ Create Client Space" "Create Client Space"

execute_terraform 'project_hello_world' 'management_instance/projects/hello_world/pgbackend' 'Spaces-1'

execute_terraform 'project_hello_world_cac' 'management_instance/projects/hello_world_cac/pgbackend' 'Spaces-1'

execute_terraform 'project_azure_web_app_cac' 'management_instance/projects/azure_web_app_cac/pgbackend' 'Spaces-1'

# Remove the project first to fix the error "Error: Octopus API error: Sequence contains no matching element []"
delete_project 'Spaces-1' 'K8S Microservice Template'
execute_terraform 'project_k8s_microservice' 'management_instance/projects/k8s_microservice/pgbackend' 'Spaces-1'

execute_terraform 'project_azure_space_initialization' 'management_instance/projects/azure_space_initialization/pgbackend' 'Spaces-1'
publish_runbook "__ Compose Azure Resources" "Initialize Space"

execute_terraform 'project_k8s_space_initialization' 'management_instance/projects/k8s_space_initialization/pgbackend' 'Spaces-1'
publish_runbook "__ Compose K8S Resources" "Initialize Space"

execute_terraform 'project_pr_checks' 'management_instance/projects/pr_checks/pgbackend' 'Spaces-1'

# Setup targets
docker compose -f docker/compose.yml exec terraformdb sh -c '/usr/bin/psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -c "CREATE DATABASE target_k8s"'
pushd shared/targets/k8s/pgbackend || exit 1
terraform init -reconfigure -upgrade
terraform workspace new "Spaces-1" || echo "Workspace already exists"
terraform workspace select "Spaces-1"
terraform apply \
  -auto-approve \
  -var=octopus_space_id=Spaces-1 \
  "-var=k8s_cluster_url=https://${DOCKER_HOST_IP}:${CLUSTER_PORT}" \
  "-var=k8s_client_cert=${COMBINED_CERT}"
popd

# Add the tenants
docker compose -f docker/compose.yml exec terraformdb sh -c '/usr/bin/psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -c "CREATE DATABASE tenants_region"'
pushd management_instance/tenants/regional_tenants/pgbackend || exit 1
terraform init -reconfigure -upgrade
terraform workspace new "Spaces-1" || echo "Workspace already exists"
terraform workspace select "Spaces-1"
terraform apply -auto-approve \
  "-var=octopus_space_id=Spaces-1" \
  "-var=america_k8s_cert=${COMBINED_CERT}" \
  "-var=america_k8s_url=https://${DOCKER_HOST_IP}:${CLUSTER_PORT}" \
  "-var=europe_k8s_cert=${COMBINED_CERT}" \
  "-var=europe_k8s_url=https://${DOCKER_HOST_IP}:${CLUSTER_PORT}" || exit 1
popd

# Add serialize and deploy runbooks to sample projects.
# These runbooks are common across these kinds of projects, but benefit from being able to reference the project they
# are associated with. So they are linked up to each project individually, even though they all come from the same source.
for project in "Hello World:__ Create Client Space:Create Client Space" "K8S Microservice Template:__ Create Client Space:Create Client Space:__ Compose K8S Resources:Initialize Space"
do
  IFS=':'; split=($project); unset IFS;

  echo "Adding runbooks to ${split[0]}"

  execute_terraform_with_project 'serialize_and_deploy' 'management_instance/runbooks/serialize_and_deploy/pgbackend' "${project//[^[:alnum:]]/_}" "${split[0]}" "Spaces-1" "${split[1]}" "${split[2]}" "${split[3]}" "${split[4]}"
  execute_terraform_with_project 'runbooks_list' 'management_instance/runbooks/list/pgbackend' "${project//[^[:alnum:]]/_}" "${split[0]}" "Spaces-1"

  for runbook in "__ 1. Serialize Project" "__ 4. List Downstream Projects"
  do
    publish_runbook "${split[0]}" "${runbook}"
  done
done

# Link up the CaC selection of runbooks. Like above, these runbooks are copied into each CaC project that is to be
# serialized and shared with other spaces.
for project in "Hello World CaC:__ Create Client Space:Create Client Space" "Azure Web App CaC:__ Create Client Space:Create Client Space:__ Compose Azure Resources:Initialize Space"
do
  IFS=':'; split=($project); unset IFS;

  echo "Adding runbooks to ${split[0]}"

  execute_terraform_with_project 'runbooks_fork' 'management_instance/runbooks/fork/pgbackend' "${project//[^[:alnum:]]/_}" "${split[0]}" "Spaces-1" "${split[1]}" "${split[2]}" "${split[3]}" "${split[4]}"
  execute_terraform_with_project 'runbooks_merge' 'management_instance/runbooks/merge/pgbackend' "${project//[^[:alnum:]]/_}" "${split[0]}" "Spaces-1"
  execute_terraform_with_project 'runbooks_list' 'management_instance/runbooks/list/pgbackend' "${project//[^[:alnum:]]/_}" "${split[0]}" "Spaces-1"
  execute_terraform_with_project 'runbooks_updates' 'management_instance/runbooks/conflict/pgbackend' "${project//[^[:alnum:]]/_}" "${split[0]}" "Spaces-1"

  for runbook in "__ 1. Serialize Project" "__ 3. Merge with Downstream Project" "__ 4. List Downstream Projects" "__ 5. Find Updates"
  do
    publish_runbook "${split[0]}" "${runbook}"
  done
done

# Enable branch protections after the projects are initially committed
for repo in hello_world_cac
do
    curl \
        -u "octopus:Password01!" \
        --output /dev/null \
        --location \
        --silent \
        --request POST \
        "http://localhost:3000/api/v1/repos/octopuscac/${repo}/branch_protections" \
        --header 'Content-Type: application/json' \
        --data-raw '{
            "branch_protections": "main",
            "rule_name": "main",
            "enable_status_check": true,
            "status_check_contexts": [
                "octopus"
            ]
        }'
done

# Publish the check PR runbook
publish_runbook "PR Checks" "PR Check"

# Push the sample ArgoCD app
if [[ "${INSTALL_ARGO}" == "TRUE" ]]
then
  # Get the Argo CD password
  PASSWORD=$(KUBECONFIG=$HOME/octoconfig.yml argocd admin initial-password -n argocd)
  # Extract the first line of the output, which is the password
  PASSWORDARRAY=(${PASSWORD[@]})

  # Retry this because sometimes it times out
  max_retry=3
  counter=0
  exit_code=1
  until [[ "${exit_code}" == "0" ]]
  do
    [[ counter -eq $max_retry ]] && echo "Failed!" && exit 1

    ((counter++))

    # Generate a token for the user octopus
    TOKEN=$(KUBECONFIG=$HOME/octoconfig.yml kubectl run --rm -i --image=argoproj/argocd argocdinit${counter} -- /bin/bash -c "argocd login --insecure argocd-server.argocd.svc.cluster.local --username admin --password ${PASSWORDARRAY[0]} >/dev/null; argocd account generate-token --account octopus")

    exit_code=$?

    # sometimes these pods do not clean themselves up, so force the deletion
    KUBECONFIG=$HOME/octoconfig.yml kubectl delete pod argocdinit${counter} -n default --grace-period=0 --force >/dev/null 2>&1

    # Remove the messages captured after the token about the pod being removed
    TOKEN=${TOKEN%%pod \"*}
    # Remove trailing whitespace (https://stackoverflow.com/a/3352015/8246539)
    TOKEN="${TOKEN%"${TOKEN##*[![:space:]]}"}"
  done

  # Save the token in a secret
  KUBECONFIG=$HOME/octoconfig.yml kubectl create secret generic octoargosync-secret --from-literal=argotoken=${TOKEN} -n argocd
  # Deploy the octopus argo cd sync service
  KUBECONFIG=$HOME/octoconfig.yml kubectl apply -f argocd/argocd-config/octoargosync.yaml
  # Deploy the sample apps
  KUBECONFIG=$HOME/octoconfig.yml kubectl apply -f argocd/app-of-apps-gitea.yaml
  # Get the admin login
  ARGO_PASSWORD=$(KUBECONFIG=$HOME/octoconfig.yml argocd admin initial-password -n argocd)
  # Remove the messages captured after the token about the password needing to be changed
  ARGO_PASSWORD=${ARGO_PASSWORD%%This password *}
  # Remove trailing whitespace (https://stackoverflow.com/a/3352015/8246539)
  ARGO_PASSWORD="${ARGO_PASSWORD%"${ARGO_PASSWORD##*[![:space:]]}"}"

  # Create a space to monitor and manage the Octppub deployment in ArgoCD
  execute_terraform_with_spacename 'spaces' 'shared/spaces/pgbackend' 'ArgoCD'

  # Create the ArgoCD template and push it to Octopus
  pushd argocd/template || exit 1
  zip -r argocd_template.1.0.0.zip .
  ${OCTOCLI} push --server=http://localhost:18080 --apiKey=API-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA -space=Spaces-4 --package=argocd_template.1.0.0.zip --replace-existing
  rm argocd_template.1.0.0.zip
  popd || exit 1

  # Create the ArgoCD project Terraform module package and push it to Octopus
  pushd argocd_dashboard/projects || exit 1
  zip -r argocd_octopus_projects.1.0.0.zip . -i '*.tf' '*.sh'
  ${OCTOCLI} push --server=http://localhost:18080 --apiKey=API-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA -space=Spaces-4 --package=argocd_octopus_projects.1.0.0.zip --replace-existing
  rm argocd_octopus_projects.1.0.0.zip
  popd || exit 1

  # Create the library variable set with the argocd token
  docker compose -f docker/compose.yml exec terraformdb sh -c '/usr/bin/psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" -c "CREATE DATABASE lib_var_argo"'
  pushd argocd_dashboard/variables/argo/pgbackend || exit 1
  terraform init -reconfigure -upgrade
  terraform workspace new "Spaces-4" || echo "Workspace already exists"
  terraform workspace select "Spaces-4"
  terraform apply \
    -auto-approve \
    -var=octopus_space_id=Spaces-4 \
    "-var=argocd_token=${TOKEN}"
  popd || exit 1

  execute_terraform 'mavenfeed' 'shared/feeds/maven/pgbackend' 'Spaces-4'
  execute_terraform 'environments' 'shared/environments/dev_test_prod/pgbackend' 'Spaces-4'
  execute_terraform 'admin_environment' 'shared/environments/administration/pgbackend' 'Spaces-4'

  # Setup targets
  terraform init -reconfigure -upgrade
  terraform workspace new "Spaces-4" || echo "Workspace already exists"
  terraform workspace select "Spaces-4"
  pushd argocd_dashboard/targets/k8s/pgbackend || exit 1
  terraform apply \
    -auto-approve \
    -var=octopus_space_id=Spaces-4 \
    "-var=k8s_cluster_url=https://${DOCKER_HOST_IP}:${CLUSTER_PORT}" \
    "-var=k8s_client_cert=${COMBINED_CERT}"
  popd || exit 1

  execute_terraform 'lifecycle_simple_dev_test_prod' 'shared/lifecycles/simple_dev_test_prod/pgbackend' 'Spaces-4'
  execute_terraform 'single_phase_simple_dev_test_prod' 'argocd_dashboard/lifecycles/single_phase_dev_test_prod/pgbackend' 'Spaces-4'
  execute_terraform 'project_group_argo_cd' 'argocd_dashboard/project_group/octopub/pgbackend' 'Spaces-4'
  execute_terraform_with_workspace 'project_argo_cd_dashboard' 'octopub_frontend' 'argocd_dashboard/projects/argo_cd_dashboard/pgbackend' 'Spaces-4' '-var=project_name=Overview: Octopus Frontend' '-var=project_description=This project is used to manage the deployment of the Octopub Frontend via ArgoCD.' '-var=argocd_application_development=argocd/octopub-frontend-development' '-var=argocd_application_test=argocd/octopub-frontend-test' '-var=argocd_application_production=argocd/octopub-frontend-production' '-var=argocd_version_image=octopussamples/octopub-frontend' '-var=argocd_sbom_version_image=octopussamples/octopub-frontend' '-var=argocd_sbom_package_id=com.octopus:octopub-frontend-sbom'
  execute_terraform_with_workspace 'project_argo_cd_dashboard' 'octopub_products' 'argocd_dashboard/projects/argo_cd_dashboard/pgbackend' 'Spaces-4' '-var=project_name=Overview: Octopus Products' '-var=project_description=This project is used to manage the deployment of the Octopub Products service via ArgoCD.' '-var=argocd_application_development=argocd/octopub-products-development' '-var=argocd_application_test=argocd/octopub-products-test' '-var=argocd_application_production=argocd/octopub-products-production' '-var=argocd_version_image=octopussamples/octopub-products-microservice' '-var=argocd_sbom_version_image=octopussamples/octopub-products-microservice' '-var=argocd_sbom_package_id=com.octopus:products-microservice-sbom'
  execute_terraform_with_workspace 'project_argo_cd_dashboard' 'octopub_audits' 'argocd_dashboard/projects/argo_cd_dashboard/pgbackend' 'Spaces-4' '-var=project_name=Overview: Octopus Audits' '-var=project_description=This project is used to manage the deployment of the Octopub Audits service via ArgoCD.' '-var=argocd_application_development=argocd/octopub-audits-development' '-var=argocd_application_test=argocd/octopub-audits-test' '-var=argocd_application_production=argocd/octopub-audits-production' '-var=argocd_version_image=octopussamples/octopub-audit-microservice' '-var=argocd_sbom_version_image=octopussamples/octopub-audit-microservice' '-var=argocd_sbom_package_id=com.octopus:audit-microservice-sbom'
  execute_terraform_with_workspace 'project_argo_cd_progression' 'octopub_frontend' 'argocd_dashboard/projects/argo_cd_progression/pgbackend' 'Spaces-4'
  execute_terraform 'project_argo_cd_template' 'argocd_dashboard/projects/argo_cd_template/pgbackend' 'Spaces-4'
fi

# All done
echo "###############################################################################################################################" > keys.txt
echo "Open Octopus at http://localhost:18080 - username is \"admin\" and password is \"Password01!\"" >> keys.txt
echo "Open Gitea at http://localhost:3000 - username is \"octopus\" and password is \"Password01!\"" >> keys.txt
if [[ "${INSTALL_ARGO}" == "TRUE" ]]
then
  echo "Start a minikube tunnel in Linux/macOS with: KUBECONFIG=$HOME/octoconfig.yml minikube tunnel" >> keys.txt
  echo "Start a minikube tunnel in WSL with: MINIKUBE_HOME=\"\$HOME/.minikube\" KUBECONFIG=$HOME/octoconfig.yml sudo --preserve-env=MINIKUBE_HOME --preserve-env=KUBECONFIG minikube tunnel" >> keys.txt
  echo "Wait for the Argo CD pods to start. You can see their status with: KUBECONFIG=$HOME/octoconfig.yml kubectl get pods -n argocd" >> keys.txt
  echo "Find the Argo CD IP address with: KUBECONFIG=$HOME/octoconfig.yml kubectl get service argocd-server -n argocd" >> keys.txt
  echo "Get the initial Argo CD admin password with: KUBECONFIG=$HOME/octoconfig.yml argocd admin initial-password -n argocd" >> keys.txt
  echo "Get the logs for the OctopusArgoCDProxy with: KUBECONFIG=$HOME/octoconfig.yml kubectl logs -f deployment/octoargosync -n argocd" >> keys.txt
  echo "ArgoCD token for account octopus is: ${TOKEN%%pod \"*}" >> keys.txt
  echo "ArgoCD password is: ${ARGO_PASSWORD}" >> keys.txt
fi
echo "###############################################################################################################################" >> keys.txt

cat keys.txt
