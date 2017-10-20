#!/usr/bin/env zsh

# fzftools - a collection of fzf scripts
# Copyright © 2017 midchildan
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the "Software"),
# to deal in the Software without restriction, including without limitation
# the rights to use, copy, modify, merge, publish, distribute, sublicense,
# and/or sell copies of the Software, and to permit persons to whom the
# Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included
# in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
# OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
# OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

fzf-sel() {
  (( $# < 1 )) && fzf::_abort "Insufficient number of arguments."

  local IFS=' '

  local selector
  read -rA selector <<< "$*"
  if ! fzf::_is_function "fzf::sel::$selector[1]" ; then
    fzf::_abort "Unsupported selector $selector[1]"
  fi

  "fzf::sel::$selector[1]" "${(@)selector[2,-1]}"
}

fzf-run() {
  (( $# < 1 )) && fzf::_abort "Insufficient number of arguments."
  local cmd="$1"
  shift

  if fzf::_is_function "fzf::run::$cmd" ; then
    "fzf::run::$cmd" "$@"
  else
    fzf::run::_common "$cmd" "$@"
  fi
}

fzf-loop() {
  while true; do fzf-run "$@"; done
}

#######################
#  utility functions  #
#######################

# Print an error message and return to top-level shell
# Arguments:
#   error_message [default: abort]
# Returns:
#   None
fzf::_abort() {
  local message="abort"
  [[ -n "$1" ]] && message="$1"
  printf "%s %s\n" "$functrace[1]" "$message" >&2
  kill -INT "$$"
}

# Checks whether a function exisits with the given name
# Arguments:
#   name
# Returns:
#   0 if name is a function, 1 otherwise
fzf::_is_function() {
  declare -fF "$1" > /dev/null 2>&1
}

# Checks whether a command exisits with the given name
# Arguments:
#   name
# Returns:
#   0 if name is a command, 1 otherwise
fzf::_is_command() {
  command -v "$1" > /dev/null 2>&1
}

# Checks whether the current directory is a git repository
# Arguments:
#   None
# Returns:
#   0 if the current directory is git repository, non-zero otherwise
fzf::_is_git_repo() {
  git rev-parse > /dev/null 2>&1
}

# Runs FZF and aborts if selection was canceled
# Arguments:
#   args... : Arguemnts to pass to FZF
# Returns:
#   None
fzf::_fzf_or_abort() {
  fzf-tmux "$@" || fzf::_abort "FZF selection canceled."
}

############################
#  common select commands  #
############################

fzf::sel::dir() {
  find -L "${1:-.}" -path '*/\.*' -prune -o -type d -print 2> /dev/null \
    | fzf::_fzf_or_abort -m --preview "ls -l {}"
}

fzf::sel::dirstack() {
  dirs -l -p | fzf::_fzf_or_abort -m --preview "ls -l {}"
}

fzf::sel::file() {
  find -L "$1" \
    -name .git -prune -o -name .svn -prune -o \( -type d -o -type f -o -type l \) \
    -a -not -path "$1" -print 2> /dev/null \
    | sed 's#^\./##' \
    | fzf::_fzf_or_abort -m --preview "head -$LINES {}"
}

fzf::sel::fc() {
  fc -l 1 \
    | fzf::_fzf_or_abort +s --tac -n2..,.. --tiebreak=index \
        --bind=ctrl-s:toggle-sort --header 'Press CTRL-S to toggle sort' \
    | cut -f1
}

fzf::sel::process() {
  ps -ef \
    | sed 1d \
    | fzf::_fzf_or_abort -m --preview 'echo {}' --preview-window down:3:wrap \
    | awk '{print $2}'
}

#########################
#  common run commands  #
#########################

function fzf::run::fc() {
  local IFS=$'\n'

  local selected
  selected=($(fzf::sel::fc))

  if [[ -n "$@" ]]; then
    fc "$@" "${selected[@]}"
  else
    fc "${selected[@]}"
  fi
}

# Runs a command on an item selected using FZF
# Arguments:
#   cmd : command to execute
#   item_type : type of item [file/dir/dirstack/fc/process/...]
# Returns:
#   None
fzf::run::_common() {
  (( $# < 2 )) && fzf::_abort "Insufficient number of arguments."

  local IFS=$'\n'

  local cmd="$1"
  local item_type="$2"
  shift 2

  local selected
  selected=($(fzf-sel "$item_type"))
  [[ -z "$selected" ]] && fzf::_abort

  if [[ -n "$@" ]]; then
    "$cmd" "$@" "$selected[@]"
  else
    "$cmd" "$selected[@]"
  fi
}

##########################
#  brew select commands  #
##########################

fzf::sel::brew() {
  (( $# < 1 )) && fzf::_abort "Insufficient number of arguments."
  fzf::_is_command "brew" || fzf::_abort "Homebrew not installed."

  local cmd="$1"
  shift

  if ! fzf::_is_function "fzf::sel::brew::$cmd" ; then
    fzf::_abort "Invalid selector $cmd"
  fi

  "fzf::sel::brew::$cmd" "$@"
}

fzf::sel::brew::formula() {
  brew search \
    | fzf::_fzf_or_abort -m --preview-window right:70% --preview 'brew info {}'
}

fzf::sel::brew::installed() {
  brew ls \
    | fzf::_fzf_or_abort -m --preview-window right:70% --preview 'brew info {}'
}

fzf::sel::brew::leaves() {
  brew leaves \
    | fzf::_fzf_or_abort -m --preview-window right:70% --preview 'brew info {}'
}

fzf::sel::brew::cask() {
  (( $# < 1 )) && fzf::_abort "Insufficient number of arguments."

  if ! fzf::_is_function "fzf::sel::brew::cask::$1" ; then
    fzf::_abort "Invalid selector $1"
  fi

  "fzf::sel::brew::cask::$1"
}

fzf::sel::brew::cask::cask() {
  brew cask search \
    | fzf::_fzf_or_abort -m --preview-window right:70% --preview 'brew cask info {}'
}

fzf::sel::brew::cask::installed() {
  brew cask ls \
    | fzf::_fzf_or_abort -m --preview-window right:70% --preview 'brew cask info {}'
}

#######################
#  brew run commands  #
#######################

fzf::run::brew() {
  (( $# < 1 )) && fzf::_abort "Insufficient number of arguments."
  local cmd="$1"
  shift

  if fzf::_is_function "fzf::run::brew::$cmd" ; then
    "fzf::run::brew::$cmd" "$@"
  else
    fzf::run::brew::_common "$cmd" "$@"
  fi
}

fzf::run::brew::cask() {
  (( $# < 1 )) && fzf::_abort "Insufficient number of arguments."
  local cmd="$1"
  shift

  if fzf::_is_function "fzf::run::brew::cask::$cmd" ; then
    "fzf::run::brew::cask::$cmd" "$@"
  else
    fzf::run::brew::cask::_common "$cmd" "$@"
  fi
}

# Runs a brew command on an item selected using FZF
# Arguments:
#   cmd : brew command to execute
#   item_type : type of item [formula/installed/leaves]
#   flags : additional flags to pass to brew [optional]
# Returns:
#   None
fzf::run::brew::_common() {
  (( $# < 2 )) && fzf::_abort "Insufficient number of arguments."

  local IFS=$'\n'

  local cmd="$1"
  local item_type="$2"
  shift 2

  local selected
  selected=($(fzf::sel::brew "$item_type"))
  brew "$cmd" "$@" "$selected[@]"
}

# Runs a cask command on an item selected using FZF
# Arguments:
#   cmd : cask command to execute
#   item_type : type of item [cask/installed]
#   flags : additional flags to pass to cask [optional]
# Returns:
#   None
fzf::run::brew::cask::_common() {
  (( $# < 2 )) && fzf::_abort "Insufficient number of arguments."

  local IFS=$'\n'

  local cmd="$1"
  local item_type="$2"
  shift 2

  local selected
  selected=($(fzf::sel::brew::cask "$item_type"))
  brew cask "$cmd" "$@" "$selected[@]"
}

#########################
#  git select commands  #
#########################

fzf::sel::git() {
  (( $# < 1 )) && fzf::_abort "Insufficient number of arguments."

  if ! fzf::_is_function "fzf::sel::git::$1" ; then
    fzf::_abort "Invalid selector $1"
  fi

  "fzf::sel::git::$1"
}

# https://gist.github.com/junegunn/8b572b8d4b5eddd8b85e5f4d40f17236
fzf::sel::git::branch() {
  fzf::_is_git_repo || fzf::_abort "Not a git repository."

  local preview
  preview='git log --oneline --graph --date=short'
  preview+=' --pretty="format:%C(auto)%cd %h%d %s"'
  preview+=' $(sed s/^..// <<< {} | cut -d" " -f1) | head -'$LINES

  git branch -a --color=always \
    | grep -v '/HEAD\s' \
    | sort \
    | fzf::_fzf_or_abort -m --ansi --tac \
        --preview-window right:70% --preview "$preview" \
    | sed 's/^..//' \
    | cut -d' ' -f1 \
    | sed 's#^remotes/##'
}

# https://gist.github.com/junegunn/8b572b8d4b5eddd8b85e5f4d40f17236
fzf::sel::git::commit() {
  fzf::_is_git_repo || fzf::_abort "Not a git repository."

  local preview
  preview='grep -o "[a-f0-9]\{7,\}" <<< {}'
  preview+=' | xargs git show --color=always | head -'$LINES

  git log --graph --color=always --date=short \
          --format="%C(green)%C(bold)%cd %C(auto)%h%d %s (%an)" \
    | fzf::_fzf_or_abort -m +s --ansi --reverse --preview "$preview" \
        --bind 'ctrl-s:toggle-sort' --header 'Press CTRL-S to toggle sort' \
    | grep -o "[a-f0-9]\{7,\}"
}

fzf::sel::git::file() {
  fzf::_is_git_repo || fzf::_abort "Not a git repository."

  # https://github.com/junegunn/fzf#git-ls-tree-for-fast-traversal
  (git ls-tree -r --name-only HEAD \
    || find . -path '*/\.*' -prune -o -type f -print -o -type l -print \
    | sed 's/\..//' \
  ) | fzf::_fzf_or_abort -m \
        --preview "if [[ -d {} ]]; then ls -l {}; else head -$LINES {}; fi"
}

# https://gist.github.com/junegunn/8b572b8d4b5eddd8b85e5f4d40f17236
fzf::sel::git::remote() {
  fzf::_is_git_repo || fzf::_abort "Not a git repository."

  local preview
  preview='git log --oneline --graph --date=short'
  preview+=' --pretty="format:%C(auto)%cd %h%d %s" {1} | head -200'

  git remote -v \
    | awk '{print $1 "\t" $2}' \
    | uniq \
    | fzf::_fzf_or_abort --tac --preview="$preview" \
    | cut -d$'\t' -f1
}

fzf::sel::git::stash() {
  fzf::_is_git_repo || fzf::_abort "Not a git repository."

  local preview
  preview='grep -o "[a-f0-9]\{7,\}" <<< {}'
  preview+=' | xargs git show --color=always | head -'$LINES

  git stash list --pretty="%C(green)%C(bold)%cd %C(auto)%h%d %s (%an)" \
    | fzf::_fzf_or_abort -m +s --ansi --reverse --preview="$preview" \
        --bind 'ctrl-s:toggle-sort' --header 'Press CTRL-S to toggle sort' \
    | grep -o "[a-f0-9]\{7,\}"
}

# https://gist.github.com/junegunn/8b572b8d4b5eddd8b85e5f4d40f17236
fzf::sel::git::status() {
  fzf::_is_git_repo || fzf::_abort "Not a git repository."

  local preview
  preview='(git diff --color=always -- {-1} | sed 1,4d; cat {-1}) | head -500'

  git -c color.status=always status --short \
    | fzf::_fzf_or_abort -m --ansi --nth 2..,.. --preview="$preview" \
    | cut -c4- \
    | sed 's/.* -> //'
}

# https://gist.github.com/junegunn/8b572b8d4b5eddd8b85e5f4d40f17236
fzf::sel::git::tag() {
  fzf::_is_git_repo || fzf::_abort "Not a git repository."

  git tag --sort --version:refname \
    | fzf::_fzf_or_abort -m --preview-window right:70% \
        --preview 'git show --color=always {} | head -'$LINES
}

######################
#  git run commands  #
######################

fzf::run::git() {
  (( $# < 1 )) && fzf::_abort "Insufficient number of arguments."
  local cmd="$1"
  shift

  if fzf::_is_function "fzf::run::git::$cmd" ; then
    "fzf::run::git::$cmd" "$@"
  else
    fzf::run::git::_common "$cmd" "$@"
  fi
}

# Runs a git command on an item selected using FZF
# Arguments:
#   cmd : git command to execute
#   item_type : type of item [branch/commit/file/remote/stash/status/tag]
#   flags : additional flags to pass to git [optional]
# Returns:
#   None
fzf::run::git::_common() {
  (( $# < 2 )) && fzf::_abort "Insufficient number of arguments."

  local IFS=$'\n'

  local cmd="$1"
  local item_type="$2"
  shift 2

  local selected
  selected=($(fzf::sel::git "$item_type"))
  git "$cmd" "$@" "$selected[@]"
}
