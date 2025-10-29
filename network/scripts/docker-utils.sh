#!/bin/bash

. set-env.sh

up() {
    local COMPOSE_FILE=$1
    docker compose -f ${COMPOSE_FILE} -p ${DOCKER_PROJECT_NAME} up -d
}

down() {
    local COMPOSE_FILE=$1
    docker compose -f ${COMPOSE_FILE} -p ${DOCKER_PROJECT_NAME} down
}

force_down() {
    local COMPOSE_FILE=$1
    docker compose -f ${COMPOSE_FILE} -p ${DOCKER_PROJECT_NAME} down --volumes --remove-orphans
}