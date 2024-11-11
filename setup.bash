#!/usr/bin/env bash

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░                VARIABLES                 ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

declare -r CONST_APP_NAME="domposy"
declare -r CONST_APP_BRANCH_NAME="v2"

declare -r CONST_LOGGER_NAME="simbashlog"
declare -r CONST_LOGGER_BRANCH_NAME="v1.1.3"

declare -r CONST_GLOBAL_DOWNLOAD_PATH="/opt"
declare -r CONST_GLOBAL_BIN_PATH="/usr/bin"

declare -r CONST_USER_DOWNLOAD_PATH="$HOME/.local/share"
declare -r CONST_USER_BIN_PATH="$HOME/.local/bin"

declare -r CONST_DEPENDENCIES=(
    "git"
    "docker"
    "tar"
    "gzip"
)

# NOTE: The repos must contain a directory called 'src' with a bash script that has the same name as the repo and ends with '.bash'!
declare -r CONST_REPO_URLS=(
    "https://github.com/fuchs-fabian/${CONST_LOGGER_NAME}.git"
    "https://github.com/fuchs-fabian/${CONST_APP_NAME}.git"
)

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░                  LOGIC                   ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

function is_root {
    [[ $(id -u) -eq 0 ]]
}

function check_dependencies {
    for dependency in "${CONST_DEPENDENCIES[@]}"; do
        echo "Checking if '$dependency' is available..."
        command -v "$dependency" >/dev/null 2>&1 ||
            {
                echo "'$dependency' is not available. Please install it and try again."
                exit 1
            }
        echo "'$dependency' is available."
    done
}

function create_directory {
    local directory="$1"

    if [ ! -d "$directory" ]; then
        echo "Creating directory '$directory'..."
        mkdir -p "$directory"
    fi
}

function get_app_name_from_repo_url {
    basename "$1" .git
}

function clone_app_from_repo_url {
    local repo_url="$1"
    local app_name="$2"
    local app_path="$3"

    if [[ "$app_name" == "$CONST_LOGGER_NAME" ]]; then
        echo "Cloning '$CONST_LOGGER_NAME' from branch '$CONST_LOGGER_BRANCH_NAME'..."
        git clone --branch "$CONST_LOGGER_BRANCH_NAME" "$repo_url" "$app_path"

    elif [[ "$app_name" == "$CONST_APP_NAME" ]]; then
        echo "Cloning '$CONST_APP_NAME' from branch '$CONST_APP_BRANCH_NAME'..."
        git clone --branch "$CONST_APP_BRANCH_NAME" "$repo_url" "$app_path"

    else
        echo "Cloning $app_name..."
        git clone "$repo_url" "$app_path"
    fi
}

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║                INSTALLATION                ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

function install {
    local download_path=""
    local bin_path=""

    echo
    echo "Installing..."

    check_dependencies

    if is_root; then
        download_path="$CONST_GLOBAL_DOWNLOAD_PATH"
        bin_path="$CONST_GLOBAL_BIN_PATH"
    else
        echo "You are not root."
        echo "The installation will be only available for the current user."
        echo "To install it globally, please run this script as root (sudo)."

        read -r -p "Do you want to continue? [Y/n] " choice
        if [[ "$choice" =~ ^[Yy]$ ]]; then
            download_path="$CONST_USER_DOWNLOAD_PATH"
            bin_path="$CONST_USER_BIN_PATH"

            create_directory "$CONST_USER_DOWNLOAD_PATH"
            create_directory "$CONST_USER_BIN_PATH"
        else
            echo "Installation aborted."
            exit 1
        fi
    fi

    echo "Donwload path: '$download_path'"
    echo "Bin path: '$bin_path'"

    for repo_url in "${CONST_REPO_URLS[@]}"; do
        local app_name
        app_name=$(get_app_name_from_repo_url "$repo_url")

        local app_path="$download_path/$app_name"

        if [ -d "$app_path" ]; then
            echo "'$app_name' is already downloaded."
        else
            echo "Downloading '$app_name'..."

            clone_app_from_repo_url "$repo_url" "$app_name" "$app_path" ||
                {
                    echo "Failed to download '$app_name'."
                    exit 1
                }
        fi

        local original_app_path="$app_path/src/${app_name}.bash"

        if [ -f "$original_app_path" ]; then
            echo "Making '$app_name' executable..."
            chmod +x "$original_app_path" ||
                {
                    echo "Failed to make '$app_name' executable."
                    exit 1
                }

            echo "Creating symlink for '$app_name'..."
            ln -sf "$original_app_path" "$bin_path/$app_name" ||
                {
                    echo "Failed to create symlink for '$app_name' in '$bin_path'."
                    exit 1
                }

            echo "'$app_name' has been installed and is now executable."

            if [ -n "$(command -v "$app_name")" ]; then
                "$app_name" -v
                echo "'$app_name' is working."
            else
                echo "'$app_name' is not working. Aborting..."
                exit 1
            fi
        else
            echo "The file '${app_name}.bash' was not found in '$app_path/src'."
        fi
    done
}

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║               UNINSTALLATION               ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

function uninstall {
    local download_path=""
    local bin_path=""

    echo
    echo "Uninstalling..."

    local uninstall_success=false

    if is_root; then
        download_path="$CONST_GLOBAL_DOWNLOAD_PATH"
        bin_path="$CONST_GLOBAL_BIN_PATH"
    else
        download_path="$CONST_USER_DOWNLOAD_PATH"
        bin_path="$CONST_USER_BIN_PATH"
    fi

    echo "Donwload path: '$download_path'"
    echo "Bin path: '$bin_path'"

    for repo_url in "${CONST_REPO_URLS[@]}"; do
        app_name=$(get_app_name_from_repo_url "$repo_url")

        if [ -d "$download_path/$app_name" ] && [ -L "$bin_path/$app_name" ]; then
            read -r -p "Do you want to uninstall '$app_name'? [Y/n] " choice
            if [[ "$choice" =~ ^[Yy]$ ]]; then
                echo "Uninstalling '$app_name'..."

                echo "Removing symlink for '$app_name' in '$bin_path'..."
                rm "$bin_path/$app_name" ||
                    {
                        echo "Failed to remove symlink for '$app_name' in '$bin_path'."
                        exit 1
                    }

                app_path="$download_path/$app_name"
                echo "Removing directory '$app_path'..."
                rm -rf "$app_path" ||
                    {
                        echo "Failed to remove directory '$app_path'."
                        exit 1
                    }

                echo "'$app_name' has been uninstalled."
                uninstall_success=true
            else
                echo "Uninstallation for '$app_name' aborted."
            fi
        else
            echo "'$app_name' is not installed?"

            if is_root; then
                echo "You run this script as root. Please run it as the user who installed it to uninstall it."
            else
                echo "You run this script as a user. Please run it as root to uninstall it globally or with the user who installed it."
            fi
        fi
    done

    if [ "$uninstall_success" = true ]; then
        return 0
    else
        return 1
    fi
}

# ╔═════════════════════╦══════════════════════╗
# ║                                            ║
# ║                  UPDATE                    ║
# ║                                            ║
# ╚═════════════════════╩══════════════════════╝

function update {
    echo
    echo "Updating..."
    echo "Note: The update will uninstall and install it again."

    if uninstall; then
        install
    else
        echo "Failed to uninstall. Aborting update..."
        exit 1
    fi
}

# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░
# ░░                                          ░░
# ░░                                          ░░
# ░░                  MAIN                    ░░
# ░░                                          ░░
# ░░                                          ░░
# ░░░░░░░░░░░░░░░░░░░░░▓▓▓░░░░░░░░░░░░░░░░░░░░░░

echo "Current user: '$(whoami)'"

case "$1" in
install)
    install
    ;;
uninstall)
    uninstall
    ;;
update)
    update
    ;;
*)
    echo "Usage: $0 {install|uninstall|update}"
    exit 1
    ;;
esac
