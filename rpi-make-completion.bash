# Bash completion for the rpi Yocto/kas Makefile
#
# Source this file or drop it in /etc/bash_completion.d/ :
#   source /path/to/rpi/rpi-make-completion.bash
#
# Or add to ~/.bashrc:
#   source ~/work/rpi/rpi-make-completion.bash

_rpi_make_boards() {
    # Derive board names dynamically from kas/*.yaml (excluding base.yaml)
    local kas_dir
    kas_dir="$(git -C "$(pwd)" rev-parse --show-toplevel 2>/dev/null)/kas"
    [[ -d "$kas_dir" ]] || kas_dir="$(pwd)/kas"
    find "$kas_dir/boards" -maxdepth 1 -name '*.yaml' \
        -exec basename {} .yaml \; 2>/dev/null | sort
}

_rpi_make() {
    local cur prev words cword
    _init_completion || return

    local targets="build rebuild-image image shell sdk esdk swu flash clean clean-all help"
    local vars="BOARD= DEVICE= BUILD_DIR= DL_DIR= SSTATE_DIR= KAS_IMAGE= SWU_VERSION="

    case "$prev" in
        BOARD)
            # Complete board names after BOARD=
            COMPREPLY=( $(compgen -W "$(_rpi_make_boards)" -- "$cur") )
            return ;;
        DEVICE)
            # Complete block devices for flashing
            COMPREPLY=( $(compgen -W "$(ls /dev/sd? /dev/mmcblk? 2>/dev/null)" -- "$cur") )
            return ;;
        BUILD_DIR|DL_DIR|SSTATE_DIR)
            _filedir -d
            return ;;
        KAS_IMAGE)
            # Complete from available local Docker images
            local images
            images=$(docker images --format '{{.Repository}}:{{.Tag}}' 2>/dev/null)
            COMPREPLY=( $(compgen -W "$images" -- "$cur") )
            return ;;
    esac

    # Handle VAR=value completions mid-word (e.g. "BOARD=rpi<TAB>")
    if [[ "$cur" == BOARD=* ]]; then
        local boards val_prefix="BOARD="
        boards=$(_rpi_make_boards)
        COMPREPLY=( $(compgen -W "$boards" -- "${cur#BOARD=}") )
        COMPREPLY=( "${COMPREPLY[@]/#/$val_prefix}" )
        return
    fi

    if [[ "$cur" == DEVICE=* ]]; then
        local devs val_prefix="DEVICE="
        devs=$(ls /dev/sd? /dev/mmcblk? 2>/dev/null)
        COMPREPLY=( $(compgen -W "$devs" -- "${cur#DEVICE=}") )
        COMPREPLY=( "${COMPREPLY[@]/#/$val_prefix}" )
        return
    fi

    # Default: complete targets and variable names
    COMPREPLY=( $(compgen -W "$targets $vars" -- "$cur") )
} && complete -F _rpi_make make
