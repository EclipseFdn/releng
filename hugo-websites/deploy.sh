#!/usr/bin/env bash

#*******************************************************************************
# Copyright (c) 2021 Eclipse Foundation and others.
# This program and the accompanying materials are made available
# under the terms of the Eclipse Public License 2.0
# which is available at http://www.eclipse.org/legal/epl-v20.html,
# SPDX-License-Identifier: EPL-2.0
#*******************************************************************************

# Bash strict-mode
set -o errexit
set -o nounset
set -o pipefail

IFS=$'\n\t'

# e.g. ./hugo-websites/deploy.sh ../openmobility.eclipse.org/k8s/deployment.jsonnet ../jenkins-pipeline-shared/resources/org/eclipsefdn/hugoWebsite/Dockerfile

DEPLOYMENT="${1}"
DOCKERFILE="${2}"
CONTEXT="${3:-"$(pwd)"}"

buildEnv() {
  local deployment="${1}"
  local environment image
  environment="$(echo "${deployment}" | jq -r '.metadata.labels.environment')"
  image="$(echo "${deployment}" | jq -r '.spec.template.spec.containers[] | select(.name == "nginx") | .image')"

  if [[ "${environment}" == "production" ]]; then
    BASE_NGINX_IMAGE_TAG="stable-alpine"
  else
    BASE_NGINX_IMAGE_TAG="stable-alpine-for-staging"
  fi

  docker build --pull --build-arg NGINX_IMAGE_TAG="${BASE_NGINX_IMAGE_TAG}" -t "${image}" -f "${DOCKERFILE}" "${CONTEXT}" --no-cache
  docker push "${image}"
}

for deploymentName in $(jsonnet "${DEPLOYMENT}" | jq -r '.[] | select(.kind == "Deployment").metadata.name'); do
  buildEnv "$(jsonnet "${DEPLOYMENT}" | jq -r '.[] | select(.kind == "Deployment" and .metadata.name == "'"${deploymentName}"'")')"
done
jsonnet "${DEPLOYMENT}" | jq '.[]' | kubectl apply -f -