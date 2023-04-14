
# This file provides utilities that are used by the `shellHook` among other things.
# They are meant to be loaded into interactive shells, so use an underscore prefix
# to avoid polluting the command tab completion.

_pre_commit_hooks_nix_install_main() {
  if _pre_commit_hooks_nix_local_config_file="$(_pre_commit_hooks_nix_find_git_toplevel)/.pre-commit-config.yaml"; then
    _pre_commit_hooks_nix_ensure_config_file_up_to_date && _pre_commit_hooks_nix_install_stages
  fi
}

_pre_commit_hooks_nix_find_git_toplevel() {
  if ! type -t git >/dev/null; then
    # This happens in pure shells, including lorri
    echo 1>&2 "WARNING: pre-commit-hooks.nix: git command not found; skipping installation."
    return 1
  elif ! $_pre_commit_hooks_nix_git rev-parse --git-dir &> /dev/null; then
    echo 1>&2 "WARNING: pre-commit-hooks.nix: .git not found; skipping installation."
    return 1
  else
    $_pre_commit_hooks_nix_git rev-parse --show-toplevel
  fi
}

_pre_commit_hooks_nix_is_config_up_to_date() {
  readlink "${GIT_WC}/.pre-commit-config.yaml" >/dev/null \
      && [[ $(readlink "${GIT_WC}/.pre-commit-config.yaml") == "$_pre_commit_hooks_nix_config" ]]
}

_pre_commit_hooks_nix_ensure_config_file_up_to_date() {
  # These update procedures compare before they write, to avoid
  # filesystem churn. This improves performance with watch tools like lorri
  # and prevents installation loops by via lorri.
  if _pre_commit_hooks_nix_is_config_up_to_date; then
    echo 1>&2 "pre-commit-hooks.nix: hooks up to date"
    return 0;
  fi

  echo 1>&2 "pre-commit-hooks.nix: updating $PWD repo"

  [ -L .pre-commit-config.yaml ] && unlink .pre-commit-config.yaml

  if [ -e "${GIT_WC}/.pre-commit-config.yaml" ]; then
    echo 1>&2 "pre-commit-hooks.nix: WARNING: Refusing to install because of pre-existing .pre-commit-config.yaml"
    echo 1>&2 "    1. Translate .pre-commit-config.yaml contents to the new syntax in your Nix file"
    echo 1>&2 "        see https://github.com/cachix/pre-commit-hooks.nix#getting-started"
    echo 1>&2 "    2. remove .pre-commit-config.yaml"
    echo 1>&2 "    3. add .pre-commit-config.yaml to .gitignore"
    return 1;
  fi

  ln -fs "$_pre_commit_hooks_nix_config" "${GIT_WC}/.pre-commit-config.yaml"
}

_pre_commit_hooks_nix_install_stages() {
  # Remove any previously installed hooks (since pre-commit itself has no convergent design)
  hooks="pre-commit pre-merge-commit pre-push prepare-commit-msg commit-msg post-checkout post-commit"
  for hook in $hooks; do
    pre-commit uninstall -t $hook
  done
  # Add hooks for configured stages (only) ...
  if [ ! -z "$_pre_commit_hooks_nix_install_stages" ]; then
    for stage in $_pre_commit_hooks_nix_install_stages; do
      if [[ "$stage" == "manual" ]]; then
        continue
      fi
      case $stage in
        # if you amend these switches please also review $hooks above
        commit | merge-commit | push)
          stage="pre-"$stage
          pre-commit install -t $stage
          ;;
        prepare-commit-msg | commit-msg | post-checkout | post-commit)
          pre-commit install -t $stage
          ;;
        *)
          echo 1>&2 "ERROR: pre-commit-hooks.nix: either $stage is not a valid stage or pre-commit-hooks.nix doesn't yet support it."
          exit 1
          ;;
      esac
    done
  # ... or default 'pre-commit' hook
  else
    pre-commit install
  fi
}