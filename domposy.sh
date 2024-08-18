#!/bin/bash

ENABLE_ADVANCED_LOGGING=false
ENABLE_DEBUG_LOGGING=false

LOG_FILE_PATH="/tmp"

# # # # # # # # # # # #|# # # # # # # # # # # #
#              SCRIPT INFORMATION             #
# # # # # # # # # # # #|# # # # # # # # # # # #

SCRIPT_DIR=$(dirname "$(realpath "$0")")
SCRIPT_NAME="$0"
SIMPLE_SCRIPT_NAME=$(basename "$SCRIPT_NAME")
SIMPLE_SCRIPT_NAME_WITHOUT_FILE_EXTENSION="${SIMPLE_SCRIPT_NAME%.*}"


# # # # # # # # # # # #|# # # # # # # # # # # #
#              LOGGING DIRECTORIES            #
# # # # # # # # # # # #|# # # # # # # # # # # #

LOG_DIR="${LOG_FILE_PATH}/${SIMPLE_SCRIPT_NAME_WITHOUT_FILE_EXTENSION}_logs/"
LOG_FILE="$(date +"%Y-%m-%d_%H-%M-%S")_log_${SIMPLE_SCRIPT_NAME_WITHOUT_FILE_EXTENSION}.txt"
LOG_FILE_WITH_LOG_DIR="${LOG_DIR}${LOG_FILE}"


# # # # # # # # # # # #|# # # # # # # # # # # #
#             LOGGING FUNCTIONALITY           #
# # # # # # # # # # # #|# # # # # # # # # # # #

log() {
    local level="$1"
    local message="$2"

    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR"
    fi

    local script_info=""
    if [ "$ENABLE_ADVANCED_LOGGING" = true ]; then
        script_info=" ($SIMPLE_SCRIPT_NAME)"
    fi

    if [[ -n "$message" ]]; then
        while IFS= read -r line; do
            echo "$(date +"%d.%m.%Y %H:%M:%S") - $level - $line" >> "$LOG_FILE_WITH_LOG_DIR"
            echo "  $level$script_info - $line"
        done <<< "$message"
    fi
}

log_debug() {
    if [ "$ENABLE_DEBUG_LOGGING" = true ]; then
        log "DEBUG  " "$1"
    fi
}

log_cmd() {
    log "CMD    " "$1"
}

log_info() {
    log "INFO   " "$1"
}

log_warning() {
    log "WARNING" "$1"
}

show_log_file() {
    if [[ -f "$LOG_FILE_WITH_LOG_DIR" ]]; then
        log_info "Log file: '${LOG_FILE_WITH_LOG_DIR}'"
    else
        echo "E R R O R - Log file creation failed: '${LOG_FILE_WITH_LOG_DIR}' - E R R O R"
    fi
}

log_error() {
    log "ERROR  " "$1"

    show_log_file
    exit 1
}


# # # # # # # # # # # #|# # # # # # # # # # # #
#                 PREPARATIONS                #
# # # # # # # # # # # #|# # # # # # # # # # # #

check_permissions() {
    log_info "Current user: '$(whoami)'"
    if [[ $(id -u) -ne 0 ]]; then
        if groups $(whoami) | grep -q '\bdocker\b'; then
            log_warning "You do not have root rights. If you want to create backups, they may not work properly."
        else
            log_error "You need to be either a member of the 'docker' group or have root privileges to run this script."
        fi
    fi
}

get_docker_compose_command() {
    if command -v docker-compose &> /dev/null; then
        echo "docker-compose"
    elif docker compose version &> /dev/null; then
        echo "docker compose"
    else
        log_error "Neither 'docker-compose' nor 'docker compose' command found. Is it installed?"
    fi
}

validate_docker_compose_command() {
    local version_output="$($DOCKER_COMPOSE_CMD version 2>&1)"

    if [[ $? -ne 0 ]]; then
        log_error "Failed to execute '$DOCKER_COMPOSE_CMD version'. Error: $version_output"
    fi
    log_cmd "$version_output"
}

check_permissions

DOCKER_COMPOSE_NAME="docker-compose"

DOCKER_COMPOSE_CMD=$(get_docker_compose_command)
log_debug "'${DOCKER_COMPOSE_CMD}' is used"
validate_docker_compose_command


# # # # # # # # # # # #|# # # # # # # # # # # #
#                   GETOPTS                   #
# # # # # # # # # # # #|# # # # # # # # # # # #

DEFAULT_ACTION="all"
DEFAULT_SEARCH_DIR="/home/"
DEFAULT_BACKUP_DIR="/tmp/${SIMPLE_SCRIPT_NAME_WITHOUT_FILE_EXTENSION}_backups/"
DEFAULT_EXCLUDE_DIR="tmp"

ACTION="${DEFAULT_ACTION}"
SEARCH_DIR="${DEFAULT_SEARCH_DIR}"
BACKUP_DIR="${DEFAULT_BACKUP_DIR}"
EXCLUDE_DIR="${DEFAULT_EXCLUDE_DIR}"

CLEAN_FLAG=false

while getopts ":hda:s:b:e:c" opt; do
    case ${opt} in
        h )
            echo "It is recommended to run the script with root rights to ensure that the backups work properly."
            echo
            echo "Usage: (sudo) $SCRIPT_NAME [-h] [-d] [-a ACTION] [-s SEARCH_DIR] [-b BACKUP_DIR] [-e EXCLUDE_DIR] [-c]"
            echo "  -h                 Show help"
            echo "  -d                 Enables debug logging"
            echo "  -a ACTION          ACTION to be performed: 'update', 'backup' or 'all' (Default: '${DEFAULT_ACTION}')"
            echo "  -s SEARCH_DIR      Directory to search for ${DOCKER_COMPOSE_NAME} files (Default: '${DEFAULT_SEARCH_DIR}')"
            echo "  -b BACKUP_DIR      Destination directory for backups (Default: '${DEFAULT_BACKUP_DIR}')"
            echo "  -e EXCLUDE_DIR     Directory to exclude from search (Default: '${DEFAULT_EXCLUDE_DIR}')"
            echo "  -c                 Additional docker cleanup"
            exit 0
            ;;
        d )
            log_debug "'-d' selected"
            ENABLE_DEBUG_LOGGING=true
            ;;
        a )
            log_debug "'-a' selected: '$OPTARG'"
            ACTION="${OPTARG}"
            ;;
        s )
            log_debug "'-s' selected: '$OPTARG'"
            SEARCH_DIR="${OPTARG}"
            ;;
        b )
            log_debug "'-b' selected: '$OPTARG'"
            BACKUP_DIR="${OPTARG}"
            ;;
        e )
            log_debug "'-e' selected: '$OPTARG'"
            EXCLUDE_DIR="${OPTARG}"
            ;;
        c )
            log_debug "'-c' selected"
            CLEAN_FLAG=true
            ;;
        \? )
            log_error "Invalid option: -$OPTARG"
            ;;
        : )
            log_error "Option -$OPTARG requires an argument!"
            ;;
    esac
done
shift $((OPTIND -1))


# # # # # # # # # # # #|# # # # # # # # # # # #
#                  FUNCTIONS                  #
# # # # # # # # # # # #|# # # # # # # # # # # #

validate_search_dir() {
    if [[ "${SEARCH_DIR: -1}" != "/" ]]; then
        tmp_search_dir="${SEARCH_DIR}"
        SEARCH_DIR="${SEARCH_DIR}/"
        log_warning "SEARCH_DIR: '${tmp_search_dir}' changed to '${SEARCH_DIR}'"
    fi

    if [[ ! -d "$SEARCH_DIR" ]]; then
        log_error "The specified search directory '$SEARCH_DIR' could not be found"
    fi

    local absolute_search_dir=$(realpath "$SEARCH_DIR")

    if [[ "$SEARCH_DIR" != "$absolute_search_dir/" ]]; then
        log_warning "SEARCH_DIR: '${SEARCH_DIR}' replaced with the absolute path '${absolute_search_dir}/'"
        SEARCH_DIR="${absolute_search_dir}/"
    fi
}

get_vars() {
    log_info ">>>>>>>>>>>>>>> VARIABLES >>>>>>>>>>>>>>>"
    log_info "Script name: '${SCRIPT_NAME}'"
    log_info "Log file with log dir: '${LOG_FILE_WITH_LOG_DIR}'"
    log_info "Action: '${ACTION}'"
    log_info "Search dir: '${SEARCH_DIR}'"
    log_info "Backup dir: '${BACKUP_DIR}'"
    log_info "Exclude dir: '${EXCLUDE_DIR}'"
    log_info "<<<<<<<<<<<<<<< VARIABLES <<<<<<<<<<<<<<<"
}

show_docker_info() {
    log_info ">>>>>>>>>>>>>>> DOCKER INFO >>>>>>>>>>>>>>>"
    log_info "docker system df..."
    log_cmd "$(docker system df)"

    log_info "docker ps..."
    log_cmd "$(docker ps)"

    log_info "docker info (formatted)..."
    log_cmd "$(docker info --format "Containers: {{.Containers}} | Running: {{.ContainersRunning}} | Paused: {{.ContainersPaused}} | Stopped: {{.ContainersStopped}} | Images: {{.Images}} | Docker Root Dir: {{.DockerRootDir}}")"

    log_info "docker images..."
    log_cmd "$(docker images)"
    log_info "<<<<<<<<<<<<<<< DOCKER INFO <<<<<<<<<<<<<<<"
}

find_docker_compose_files() {
    local docker_compose_file_names=("${DOCKER_COMPOSE_NAME}.yml" "${DOCKER_COMPOSE_NAME}.yaml")
    local docker_compose_files=""
    for name in "${docker_compose_file_names[@]}"; do
        files=$(find "$SEARCH_DIR" -path "*/${EXCLUDE_DIR}/*" -prune -o -name "$name" -print 2>/dev/null)
        if [ -n "$files" ]; then
            docker_compose_files+="$files"$'\n'
        fi
    done
    echo "$docker_compose_files"
}

remove_docker_compose_images() {
    local images=$($DOCKER_COMPOSE_CMD config | grep 'image:' | sed -E 's/.*image: *//')
    for image in $images; do
        log_info "Remove image ('${image}')..."
        log_cmd "$(docker rmi "${image}")"
    done
}

backup_docker_compose_folder() {
    local file=$1
    local file_dir=$(dirname "$file")
    local file_simple_dirname=$(basename "$(dirname "$file")")

    local tmp_backup_dir="${BACKUP_DIR}"

    if [[ "${BACKUP_DIR: -1}" != "/" ]]; then
        BACKUP_DIR="${BACKUP_DIR}/"
        log_warning "BACKUP_DIR: '${tmp_backup_dir}' changed to '${BACKUP_DIR}'"
    fi

    BACKUP_DIR="${BACKUP_DIR}$(date +"%Y-%m-%d")/"

    if [[ ! -d "$BACKUP_DIR" ]]; then
        mkdir -p "$BACKUP_DIR"
        log_info "Backup directory '$(realpath "$BACKUP_DIR")' was created"
    fi

    local tar_file="$(date +"%Y-%m-%d_%H-%M-%S")_backup_${file_simple_dirname}.tar"
    local gz_file="${tar_file}.gz"

    local tar_file_with_backup_dir="${BACKUP_DIR}${tar_file}"
    local gz_file_with_backup_dir="${BACKUP_DIR}${gz_file}"

    log_info "TAR..."
    tar -cpf "$tar_file_with_backup_dir" -C "$file_dir" . || { log_warning "Problem while creating the tar file '${tar_file_with_backup_dir}'. Skipping further backup actions and undoing file creations."; rm -f "$tar_file_with_backup_dir"; return; }

    if [[ -f "$tar_file_with_backup_dir" ]]; then
        log_info "File created: '${tar_file_with_backup_dir}'"
    else
        log_error "File creation failed: '${tar_file_with_backup_dir}'"
    fi

    log_info "GZIP..."
    gzip "${tar_file_with_backup_dir}" || { log_warning "Problem while compressing the tar file '${tar_file_with_backup_dir}'. Skipping further backup actions and undoing file creations."; rm -f "$tar_file_with_backup_dir" "$gz_file_with_backup_dir"; return; }

    if [[ -f "$gz_file_with_backup_dir" ]]; then
        log_info "File created: '${gz_file_with_backup_dir}'"
    else
        log_error "File creation failed: '${gz_file_with_backup_dir}'"
    fi

    log_info "'${BACKUP_DIR}'..."
    log_cmd "$(ls -larth "${BACKUP_DIR}")"

    log_info "Backup created. You can download '${gz_file_with_backup_dir}' e.g. with FileZilla."
    log_info "To navigate to the backup folder: 'cd ${BACKUP_DIR}'"
    log_info "To move the file: 'sudo mv ${gz_file} /my/dir/for/${DOCKER_COMPOSE_NAME}-containers/${file_simple_dirname}/'"
    log_info "To undo gzip: 'sudo gunzip ${gz_file}'"
    log_info "To unpack the tar file: 'sudo tar -xpf ${tar_file}'"
}

perform_action_for_single_docker_compose_container() {
    local file=$1
    log_info ">>>>>>>>>> '${file}' >>>>>>>>>>"

    local file_dir=$(dirname "$file")
    log_debug "file_dir: '${file_dir}'"

    local file_simple_dirname=$(basename "$(dirname "$file")")
    log_debug "file_simple_dirname: '${file_simple_dirname}'"

    cd "${file_dir}"
    log_info "Changed directory to '$(pwd)'"

    log_info ">>>>> '${ACTION}' >>>>>"
    log_info "DOWN ('${file_simple_dirname}')..."
    log_cmd "$($DOCKER_COMPOSE_CMD down)"

    case $ACTION in
        update)
            remove_docker_compose_images
            ;;
        backup)
            backup_docker_compose_folder "$file"
            ;;
        all)
            backup_docker_compose_folder "$file"
            remove_docker_compose_images
            ;;
    esac

    log_info "UP ('${file_simple_dirname}')..."
    log_cmd "$($DOCKER_COMPOSE_CMD up -d)"
    log_info "<<<<< '${ACTION}' <<<<<"
    log_info "<<<<<<<<<< '${file}' <<<<<<<<<<"
}

perform_action_for_all_docker_compose_containers() {
    log_info ">>>>>>>>>>>>>>> DOCKER COMPOSE >>>>>>>>>>>>>>>"
    case $ACTION in
        update|backup|all)
            log_debug "Action selected: '${ACTION}'"

            docker_compose_files=$(find_docker_compose_files)

            if [ -z "$docker_compose_files" ]; then
                log_error "No ${DOCKER_COMPOSE_NAME} files found in '${SEARCH_DIR}'. Cannot perform action."
            else
                log_info "${DOCKER_COMPOSE_NAME} files: "$'\n'"${docker_compose_files}"
            fi

            while IFS= read -r file; do
                perform_action_for_single_docker_compose_container "$file"
            done <<< "$docker_compose_files"
            ;;
        *)
            log_error "Invalid action: '${ACTION}'"
            ;;
    esac
    log_info "<<<<<<<<<<<<<<< DOCKER COMPOSE <<<<<<<<<<<<<<<"
}

cleanup() {
    log_info ">>>>>>>>>>>>>>> CLEANUP >>>>>>>>>>>>>>>"

    log_info ">>>>>>>>>> PREVIEW >>>>>>>>>>"
    log_info "Listing non-running containers..."
    log_cmd "$(docker ps -a --filter status=created --filter status=restarting --filter status=paused --filter status=exited --filter status=dead)"

    log_info "Listing unused docker images..."
    log_cmd "$(docker image ls -a --filter dangling=true)"

    log_info "Listing unused volumes..."
    log_cmd "$(docker volume ls --filter dangling=true)"
    log_info "<<<<<<<<<< PREVIEW <<<<<<<<<<"

    log_info ">>>>>>>>>> CLEAN >>>>>>>>>>"
    log_info "Removing non-running containers..."
    log_cmd "$(docker container prune -f)"

    log_info "Removing unused docker images..."
    log_cmd "$(docker image prune -f)"

    log_info "Removing unused volumes..."
    log_cmd "$(docker volume prune -f)"
    log_info "<<<<<<<<<< CLEAN <<<<<<<<<<"

    log_info "<<<<<<<<<<<<<<< CLEANUP <<<<<<<<<<<<<<<"
}


# # # # # # # # # # # #|# # # # # # # # # # # #
#                    LOGIC                    #
# # # # # # # # # # # #|# # # # # # # # # # # #

log_info "'$SIMPLE_SCRIPT_NAME_WITHOUT_FILE_EXTENSION' has started."

validate_search_dir

log_info "Current directory: '$(pwd)'"

get_vars

show_docker_info

perform_action_for_all_docker_compose_containers

if $CLEAN_FLAG; then
    cleanup
fi

show_docker_info

show_log_file
exit 0