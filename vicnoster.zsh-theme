# vim:ft=zsh ts=2 sw=2 sts=2
#
# agnoster's Theme - https://gist.github.com/3712874
# A Powerline-inspired theme for ZSH
#
# # README
#
# In order for this theme to render correctly, you will need a
# [Powerline-patched font](https://github.com/Lokaltog/powerline-fonts).
# Make sure you have a recent version: the code points that Powerline
# uses changed in 2012, and older versions will display incorrectly,
# in confusing ways.
#
# In addition, I recommend the
# [Solarized theme](https://github.com/altercation/solarized/) and, if you're
# using it on Mac OS X, [iTerm 2](http://www.iterm2.com/) over Terminal.app -
# it has significantly better color fidelity.
#
# # Goals
#
# The aim of this theme is to only show you *relevant* information. Like most
# prompts, it will only show git information when in a git working directory.
# However, it goes a step further: everything from the current user and
# hostname to whether the last call exited with an error to whether background
# jobs are running in this shell will all be displayed automatically when
# appropriate.

### Segment drawing
# A few utility functions to make it easy and re-usable to draw segmented prompts

CURRENT_BG='NONE'

# Special Powerline characters

() {
  local LC_ALL="" LC_CTYPE="en_US.UTF-8"
  # NOTE: This segment separator character is correct.  In 2012, Powerline changed
  # the code points they use for their special characters. This is the new code point.
  # If this is not working for you, you probably have an old version of the
  # Powerline-patched fonts installed. Download and install the new version.
  # Do not submit PRs to change this unless you have reviewed the Powerline code point
  # history and have new information.
  # This is defined using a Unicode escape sequence so it is unambiguously readable, regardless of
  # what font the user is viewing this source code in. Do not replace the
  # escape sequence with a single literal character.
  # Do not change this! Do not make it '\u2b80'; that is the old, wrong code point.
  SEGMENT_SEPARATOR=$'\ue0b0'
}

# Begin a segment
# Takes two arguments, background and foreground. Both can be omitted,
# rendering default background/foreground.
prompt_segment() {
  local bg fg
  [[ -n $1 ]] && bg="%K{$1}" || bg="%k"
  [[ -n $2 ]] && fg="%F{$2}" || fg="%f"
  if [[ $CURRENT_BG != 'NONE' && $1 != $CURRENT_BG ]]; then
    echo -n " %{$bg%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR%{$fg%} "
  else
    echo -n "%{$bg%}%{$fg%} "
  fi
  CURRENT_BG=$1
  [[ -n $3 ]] && echo -n $3
}

# End the prompt, closing any open segments
prompt_end() {
  if [[ -n $CURRENT_BG ]]; then
    echo -n " %{%k%F{$CURRENT_BG}%}$SEGMENT_SEPARATOR"
  else
    echo -n "%{%k%}"
  fi
  echo -n "%{%f%}"
  CURRENT_BG=''
}

### Prompt components
# Each component will draw itself, and hide itself if no information needs to be shown

# Context: user@hostname (who am I and where am I)
prompt_context() {
  local PL_USER_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_USER_CHAR=$'\ue11f'
  }
  if [[ "$USER" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
    prompt_segment 042 black "%(!.%{%F{black}%}.)$USER"
  fi
}

# Git: branch/detached head, dirty status
prompt_git() {
  local PL_BRANCH_CHAR PL_ADD_CHAR PL_MOD_CHAR PL_CLEAN_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_BRANCH_CHAR=$'\ue822'
    PL_ADD_CHAR=$'\ue179'
    PL_MOD_CHAR=$'\ue20c'
    PL_CLEAN_CHAR=$'\u2714'
  }
  local ref dirty mode repo_path
  repo_path=$(git rev-parse --git-dir 2>/dev/null)

  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    dirty=$(parse_git_dirty)
    ref=$(git symbolic-ref HEAD 2> /dev/null) || ref="➦ $(git rev-parse --short HEAD 2> /dev/null)"
    if [[ -n $dirty ]]; then
      prompt_segment 178 black
    else
      prompt_segment 082 black
    fi

    if [[ -e "${repo_path}/BISECT_LOG" ]]; then
      mode=" <B>"
    elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
      PL_BRANCH_CHAR=$'\ue824'
      STAGE=" $PL_ADD_CHAR"
    elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
      mode=" >R>"
    fi

    setopt promptsubst
    autoload -Uz vcs_info

    STAGE="$PL_ADD_CHAR"
    UNSTAGE="$PL_MOD_CHAR"

    UNCOMMIT_CHANGES=$(git status | grep 'modified:' | wc -l | sed -e 's/ //g' 2>/dev/null)
    UNTRACKED_FILES=$(git diff | grep 'diff' | wc -l | sed -e 's/ //g' 2>/dev/null)
    DELETED_FILES=$(git diff | grep 'deleted' | wc -l | sed -e 's/ //g' 2>/dev/null)

    if [[ $UNCOMMIT_CHANGES -gt 0 && $UNTRACKED_FILES -gt 0 || $DELETED_FILES -gt 0 ]]; then
      STAGE=" $PL_ADD_CHAR"
    fi


    zstyle ':vcs_info:*' enable git
    zstyle ':vcs_info:*' get-revision true
    zstyle ':vcs_info:*' check-for-changes true
    zstyle ':vcs_info:*' stagedstr $STAGE
    zstyle ':vcs_info:*' unstagedstr $UNSTAGE
    zstyle ':vcs_info:*' formats ' %u%c'
    zstyle ':vcs_info:*' actionformats ' %u%c'
    vcs_info

    DIRECTORY_IS_CLEAN=$(git status | grep 'directory clean' | wc -l | sed -e 's/ //g' 2>/dev/null)
    UNPUSHED_COMMITS=$(git log --branches --not --remotes | grep 'commit' | wc -l | sed -e 's/ //g' 2>/dev/null)
    if [[ $DIRECTORY_IS_CLEAN == 1 && $UNPUSHED_COMMITS == 0 ]]; then
      echo -n "${ref/refs\/heads\//$PL_BRANCH_CHAR }${vcs_info_msg_0_%% }${mode} $PL_CLEAN_CHAR"
    else
      echo -n "${ref/refs\/heads\//$PL_BRANCH_CHAR }${vcs_info_msg_0_%% }${mode}"
    fi
  fi
}

# Count uncommit changes
prompt_changes() {
  local PL_FILES_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_FILES_CHAR=$'\ue812'
  }
  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    UNCOMMIT_CHANGES=$(git status | grep 'modified:' | wc -l | sed -e 's/ //g' 2>/dev/null)

    if [[ $UNCOMMIT_CHANGES -gt 0 ]]; then
      prompt_segment 240 white "$PL_FILES_CHAR $UNCOMMIT_CHANGES"
    fi
  fi
}

# Count unpushed changes
prompt_commits() {
  local PL_COMMITS_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_COMMITS_CHAR=$'\ue821'
  }
  if $(git rev-parse --is-inside-work-tree >/dev/null 2>&1); then
    UNPUSHED_COMMITS=$(git log --branches --not --remotes | grep 'commit' | wc -l | sed -e 's/ //g' 2>/dev/null)

    if [[ $UNPUSHED_COMMITS -gt 0 ]]; then
      prompt_segment white black "$PL_COMMITS_CHAR $UNPUSHED_COMMITS"
    fi
  fi
}

# Dir: current working directory
prompt_dir() {
  local PL_HOME_CHAR PL_FOLDER_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_HOME_CHAR=$'\ue12c'
    PL_FOLDER_CHAR=$'\ue18d'
  }
  if [[ $PWD == $HOME ]]; then
    prompt_segment 056 white "$PL_HOME_CHAR"
  else
    prompt_segment 056 white "$PL_FOLDER_CHAR %s %~"
  fi
}

# Virtualenv: current working virtualenv
prompt_virtualenv() {
  local virtualenv_path="$VIRTUAL_ENV"
  if [[ -n $virtualenv_path && -n $VIRTUAL_ENV_DISABLE_PROMPT ]]; then
    prompt_segment blue black "(`basename $virtualenv_path`)"
  fi
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
  local symbols PL_ERROR_CHAR PL_ROOT_CHAR PL_PID_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_ERROR_CHAR=$'\u2718'
    PL_ROOT_CHAR=$'\ue801'
    PL_PID_CHAR=$'\u2699'
  }
  symbols=()
  [[ $RETVAL -ne 0 ]] && symbols+="%{%F{196}%}$PL_ERROR_CHAR"
  [[ $UID -eq 0 ]] && symbols+="%{%F{178}%}$PL_ROOT_CHAR"
  [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}$PL_PID_CHAR"

  [[ -n "$symbols" ]] && prompt_segment black default "$symbols"
}

# Battery Level
prompt_battery() {
  local symbols PL_HEART_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_HEART_CHAR=$'\ue11c '
  }

  if [[ $(uname) == "Linux"  ]] ; then

    function battery_is_charging() {
      ! [[ $(acpi 2&>/dev/null | grep -c '^Battery.*Discharging') -gt 0 ]]
    }

    function battery_pct() {
      if (( $+commands[acpi] )) ; then
        echo "$(acpi | cut -f2 -d ',' | tr -cd '[:digit:]')"
      fi
    }

    function battery_pct_remaining() {
      if [ ! $(battery_is_charging) ] ; then
        battery_pct
      else
        echo "External Power"
      fi
    }

    function battery_time_remaining() {
      if [[ $(acpi 2&>/dev/null | grep -c '^Battery.*Discharging') -gt 0 ]] ; then
        echo $(acpi | cut -f3 -d ',')
      fi
    }

    b=$(battery_pct_remaining)
    if [[ $(acpi 2&>/dev/null | grep -c '^Battery.*Discharging') -gt 0 ]] ; then
      if [ $b -gt 40 ] ; then
        prompt_segment 082 black
      elif [ $b -gt 20 ] ; then
        prompt_segment 178 black
      else
        PL_HEART_CHAR='\ue19a '
        prompt_segment 196 black
      fi
      echo -n "$PL_HEART_CHAR$(battery_pct_remaining)%%"
    fi
  fi

  if [[ $(uname) == "Darwin" ]] ; then
    function battery_pct_remaining() {
      echo $(pmset -g ps  |  sed -n 's/.*[[:blank:]]+*\(.*%\).*/\1/p' | tr -d '%')
    }

    b=$(battery_pct_remaining)

    if [[ $(pmset -g ps  |  sed -n 's/.*[[:blank:]]+*\(.*%\).*/\1/p' | tr -d '%' 2&>/dev/null) -gt 0 ]] ; then
      if [ $b -gt 40 ] ; then
        prompt_segment 082 black
      elif [ $b -gt 20 ]; then
        prompt_segment 178 black
      else
        PL_HEART_CHAR='\ue19a '
        prompt_segment 196 black
      fi
      echo -n "$PL_HEART_CHAR$(battery_pct_remaining)%%"
    fi
  fi
}

prompt_time() {
  local symbols PL_TIME_CHAR
  () {
    local LC_ALL="" LC_CTYPE="en_US.UTF-8"
    PL_TIME_CHAR=$'\ue12e'
  }
  prompt_segment white black "\ue12e %D{%H:%M}"
}

## Main prompt
build_prompt() {
  RETVAL=$?
  prompt_status
  prompt_time
  prompt_battery
  prompt_virtualenv
  prompt_context
  prompt_dir
  prompt_git
  prompt_changes
  prompt_commits
  prompt_end
  echo -n "\n"
  CURRENT_BG='NONE'
  echo "❯"
}

PROMPT='%{%f%b%k%}$(build_prompt) '
