#!/usr/bin/env bash
#
# Copyright (c) 2022 SAP SE or an SAP affiliate company. All rights reserved. This file is licensed under the Apache Software License, v. 2 except as noted otherwise in the LICENSE file
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o nounset
set -o pipefail

tmpDir=$(mktemp -d)
function cleanup_output {
  rm -rf "$tmpDir"
}
trap cleanup_output EXIT

retval=0
temp=0

# PULL_BASE_SHA env variable is set by default in prow presubmit jobs
if [ -n "${PULL_BASE_SHA:-}" ]; then
  echo "invoking: go-apidiff ${PULL_BASE_SHA} --print-compatible --repo-path=."
  go-apidiff ${PULL_BASE_SHA} --print-compatible --repo-path=. >${tmpDir}/output.txt
else
  echo "invoking: go-apidiff master --print-compatible --repo-path=."
  go-apidiff master --print-compatible --repo-path=. >${tmpDir}/output.txt
fi

exported_pkg=(
  "gardener/gardener/extensions/"
  "gardener/gardener/pkg/api/"
  "gardener/gardener/pkg/apis/"
  "gardener/gardener/pkg/chartrenderer/"
  "gardener/gardener/pkg/client/"
  "gardener/gardener/pkg/controllerutils/"
  "gardener/gardener/pkg/extensions/"
  "gardener/gardener/pkg/gardenlet/apis/config/"
  "gardener/gardener/pkg/logger/"
  "gardener/gardener/pkg/mock/controller-runtime/client/"
  "gardener/gardener/pkg/operation/botanist/component/extensions/operatingsystemconfig/"
  "gardener/gardener/pkg/resourcemanager/controller/garbagecollector/references/"
  "gardener/gardener/pkg/scheduler/"
  "gardener/gardener/pkg/utils/"
  "gardener/gardener/test/framework/"
)

# check the changes only for the package that is in the exported_pkg list
while IFS= read -r line; do
  if [[ $line =~ ^"github.com/gardener/gardener" ]]; then
    temp=0
    for x in ${exported_pkg[*]}; do
      if [[ $line =~ $x ]]; then
        retval=1
        temp=1
        echo "$line" >>${tmpDir}/result.txt
      fi
    done
  else
    if [[ $temp -eq 1 ]]; then
      echo "$line" >>${tmpDir}/result.txt
    fi
  fi
done <"${tmpDir}/output.txt"

if [[ $retval -eq 1 ]]; then
  echo >&2 "FAIL: contains compatible/incompatible changes:"
  cat ${tmpDir}/result.txt

  cat <<EOF

The apidiff check failed – don't worry!
This check is optional and hence not required to pass before merging a PR.

The apidiff check makes changes to the go packages' API surface visible.
For example, other repositories rely on a stable API of the extensions library located in gardener/gardener/extensions.
When introducing incompatible changes in the extensions library, those dependants need to adapt to these changes when upgrading their go dependencies.
To make this process easier for your fellow developers, try to keep incompatible changes limited.
For all other cases, please check all incompatible changes listed above and add a friendly release note about them to your PR.
Even better: you could explain how to adapt to the breaking changes in your PR's description or add a short doc.

If your PR only contains compatible API changes, no action is required. You're good to go!
EOF
fi

exit $retval
