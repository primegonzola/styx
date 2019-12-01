#!/bin/bash
. ../../environment/deploy/globals.sh

WORK_DIR="$(dirname "$(dirname "${PWD}")")"
DOCKER_RUN="docker run -i --rm --name ${CONTAINER} --user $(id -u):$(id -g) -e HOME=/work/.home --volume=${WORK_DIR}:/work -w /work/samples/reporting styx-tools:${TOOLS_VERSION} sh -c"

# execute command
${DOCKER_RUN} "${1} ${2} ${3} ${4} ${5} ${6} ${7} ${8} ${9} ${10} ${11} ${12} ${13} ${14} ${15}"