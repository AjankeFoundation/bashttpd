#!/usr/bin/env bash
#---------------------------#
# Ajanke BasHTTPd Webserver |
#----------------------------------------------------------------------
#  
#  tcpserver -c 10 127.0.0.1 2274 ./bashttpd.sh
#  socat TCP4-LISTEN:2274,fork EXEC:./bashttpd.sh
#  netcat -l -p 2274 -e ./bashttpd.sh & #Set LOG=0 in script for netcat
#
#  A janky HTTP server written in Bash.
#  
#  v2.0.0
#
#  See LICENSE at http://github.com/ajankefoundation/bashttpd
#
#  Original author: Avleen Vig, 2012
#  Reworked by:     Josh Cartwright, 2012
#  Reworked again by: Cody Lee Cochran for the Ajanke Foundation, 2016
#----------------------------------------------------------------------

#---------------------------------#
# SANITY CHECKS AND CONFIGURATION |
#----------------------------------------------------------------------
#
#  You are not advised to run this script as root.
#  If you decide to do it anyway, only attach it to loopback.
#  If you make it externally-facing, bind it to your private IP.
#  If you make it public-facing, prepare to be assimilated by botnets.
#
#----------------------------------------------------------------------

# If root, warn and exit.
  if [[ "$UID" = "0" ]]; then
    log_error_text "root? Just what do you think you are doing, Dave?"
    exit 1
  fi

# If you decide to tweak the script, feel free to turn on debugging.
# Just set DEBUG to "1" to turn it on; debug writes to stderr.
  #DEBUG=0
  DEBUG=1

# log_debug_text() is used when debug mode is on
  log_debug_text() { 
    if [[ "${DEBUG}" == "1" ]]; then
      echo " <I> $@" >&2
    fi
  }

# You can turn off logging by setting LOG to "0".
  #LOG=0
  LOG=1

# The script's major version number is used throughout the script.
  MAJ_VER=3


#-------------------#
# DAEMON CONTROLLER |
#----------------------------------------------------------------------
#
#  This section sets up command line options for initial execution.
#  These functions are skipped if the daemon forks to run children.
#  'exec -a' changes the value of $0; allowing the skip upon fork.
#
#----------------------------------------------------------------------

# Defines the Usage funciton for initial daemon init.
  Usage() {
    log_debug_text "Usage() invoked."
    echo "Usage: bashttpd starts (or stops) a basHTTPd server in the current working directory"
    echo ""
    echo "    start  [-c conn_max] [-i ip_address] [-p tcp_port]"
    echo "      -c   connection limit; sets max connections. Default is \"16\" if unspecified."
    echo "      -i   ip; bind basHTTPd to an ip_address. Default is \"127.0.0.1\" if unspecified."
    echo "      -p   port; bind basHTTPd to a tcp_port. Default is TCP port \"2274\" if unspecified."
    echo ""
    echo "    stop   [process_id]"
    echo "           process_id is optional; default behavior is to stop all basHTTP daemons."       
    echo ""
  }


# Defines get_opts() for option parsing if the value of $0 indicates that script was not forked from daemon.
  get_opts() {
    log_debug_text "get_opts() invoked."
    # Parses 'start' subcommand's options, if applicable.
    if [[ "${1}" == "start" ]]; then
      # If Bash version is less than 4, instruct and exit.
      if [[ ${BASH_VERSION:0:1} != 4 ]]; then
        echo " Looks like you do not have Bash v4+; bashttpd will have to be started manually."
        echo " Consider upgrading Bash via your package manager (e.g. for Mac OS X: 'brew install bash')."
        echo " Alternately, you can invoke bashttpd manually by directly calling its TCP engine; examples:"
        echo ' $ tcpserver -c 16 127.0.0.1 2274 ./bashttpd &'  
        echo " ### Bind bashttpd to local interface, port 2274, and background (bg/&) process; limit 16 conns."
        echo ' $ tcpserver 192.168.0.5 2274 ./bashttpd &'
        echo " ### Bind bashttpd to a private network IP, port 2274, and bg process; no conn limit."
        echo ' $ tcpserver 0.0.0.0 2274 ./bashttpd'
        echo " ### Bind bashttpd to all interfaces, on port 2274, both public & private; NOT recommended!"
        exit 1
      fi
      log_debug_text "start subcommand parsed."
      BASHTTPD_START=1
      log_debug_text "BASHTTPD_START set to \"${BASHTTPD_START}\""
      log_debug_text "Current positional parameters are: \"${@}\"."
      shift
      log_debug_text "shift builtin invoked. New positional parameters are: \"${@}\"."
      while getopts ":i:p:c:" opt; do
        case "${opt}" in
          i)
            IP_ADDRESS="${OPTARG//[^a-zA-Z0-9\:\.]/}"
            log_debug_text "\$IP_ADDRESS set to \"${OPTARG}\"."
            ;;
          p)
            PORT="${OPTARG//[^0-9]/}"
            log_debug_text "\$PORT set to \"${OPTARG}\"."
            ;;
          c)
            CONN_MAX="${OPTARG//[^0-9]/}"
            log_debug_text "\$CONN_MAX set to \"${OPTARG}\"."
            ;;
          *)
            echo "Invalid option \"${opt}\" passed to \"${0} start\". See Usage."
            log_debug_text "No valid options for start subcommand detected."
            Usage
            ;;
        esac
      done
    fi

    # Parses 'stop' subcommand's options, if applicable.
    if [[ "${1}" == "stop" ]]; then
      log_debug_text "stop subcommand parsed."
      BASHTTPD_STOP=1
      log_debug_text "BASHTTPD_STOP set to \"${BASHTTPD_STOP}\""
      log_debug_text "Current positional parameters are: \"${@}\"."
      shift
      log_debug_text "shift builtin invoked. New positional parameters are: \"${@}\"."
      log_debug_text "STOP_TARGET value initialized to \"${DAEMON_NAME}\" as default."
      log_debug_text "-k option parsed by getopts; STOP_SIG set to \"${STOP_SIG}\"."
      if [[ "${1}" == "" ]]; then
        log_debug_text "\${OPTARG} determined to be empty. Value is: \"${OPTARG}\"; no PID provided to stop."
        STOP_TARGET="${DAEMON_NAME}"
        log_debug_text "No args to 'stop' found. STOP_TARGET set to DAEMON_NAME aka \"${DAEMON_NAME}\"."
      elif [[ ${1//[^0-9]/} > "1" ]]; then
        log_debug_text "\${OPTARG} determined to be greater than PID 1. Value is: \"${OPTARG}\"; will stop PID \"${OPTARG}\"."
        STOP_TARGET="${1}"
        log_debug_text "STOP_TARGET set to \"${STOP_TARGET}\"."
      elif [[ ${1//[^0-9]/} == "1" ]]; then
        echo "Stop process ID 1? I'm sorry, Dave; I'm afraid I can't do that."
        exit 1
      else
        echo "Invalid process ID: \"${OPTARG//[^0-9]/}\"; exiting."
        exit 1            
      fi
    fi
  }

# Checks to see if the process is a fork of the daemon; if not, the options are parsed and daemon is started.
# Also checks to see if you're using Bash v3 or lower. If so, manual init instructions provided.
  daemon_ctl() {
    get_opts "$@"
    if [[ "${BASHTTPD_START}" == "1" ]]; then
      if [[ "${DEBUG}" != "1" ]]; then
        exec -a ${DAEMON_NAME} tcpserver -c ${CONN_MAX:=16} ${IP_ADDRESS:=127.0.0.1} ${PORT:=2274} ${0} & 
      else 
        exec -a ${DAEMON_NAME} tcpserver -c ${CONN_MAX:=16} ${IP_ADDRESS:=127.0.0.1} ${PORT:=2274} ${0}
      fi
      echo "[INFO] Attempting to start ${DAEMON_NAME} with the following settings."
      echo "IP Address: ${IP_ADDRESS:=127.0.0.1}"
      echo "Port: ${PORT:=2274}"
      echo "Connection Limit: ${CONN_MAX:=16}"
      echo "Process ID: ${!}"
      echo "Document Root: ${PWD}"
      exit 0
    elif [[ "${BASHTTPD_STOP}" == "1" ]] && [[ "${STOP_TARGET}" == "${DAEMON_NAME}" ]]; then
      log_debug_text "killall invoked."
      killall ${STOP_TARGET} 2>/dev/null && \
      echo "[SUCCESS] All instances of basHTTPd have now been stopped." && \
      exit 0 || \
      type killall >/dev/null && \
      echo "[INFO] Unable to find \"${DAEMON_NAME}\" to terminate; exiting." && \
      exit 1
    else
      log_debug_text "kill invoked."
      log_debug_text "STOP_SIG is set to \"${STOP_SIG}\" and STOP_TARGET is set to \"${STOP_TARGET}\"."
      kill ${STOP_TARGET} 2>/dev/null && \
      echo "[SUCCESS] SIGTERM sent to process ID \"${STOP_TARGET}\"." && \
      exit 0 || \
      echo "[FAILURE] No process ID \"${STOP_TARGET}\" found; exiting." && \
      exit 1
    fi
  }

# determines if this is a child of an already-started bashttp daemon or not.
parse_ppid() {
  DAEMON_NAME=bashttpd${MAJ_VER}
  log_debug_text "DAEMON_NAME set to \"${DAEMON_NAME}\"."
  PARENT_PROC="$(ps -p $PPID -o command)"
  log_debug_text "PARENT_PROC set to \"${PARENT_PROC}\"."
  log_debug_text "PARENT_PROC substring: \"${PARENT_PROC:8:${#DAEMON_NAME}}\"."
  if [[ "${1}" == "start" ]] || [[ "${1}" == "stop" ]]; then
    daemon_ctl "$@"
  elif [[ "${PARENT_PROC:8:${#DAEMON_NAME}}" != "${DAEMON_NAME}" ]]; then
    log_debug_text "PARENT_PROC substring: \"${PARENT_PROC:8:${#DAEMON_NAME}}\"."
    log_debug_text "Substring equal to DAEMON_NAME; printing Usage and exiting."
    Usage
    exit 1
  fi
  log_debug_text "Substring not equal to DAEMON_NAME, continuing."
}

#---------------------------------#
# TIER 1: DATA DELIVERY FUNCTIONS |
#----------------------------------------------------------------------
#
#  All the other functions forward data to these functions. 
#
#  They are responsible for sending data to either stdout, 
#  which is attached to the TCP port, or alternately, 
#  to stderr which is attached to the terminal.
#
#  There are seperate functions for sending binary and text. 
#  This is important, use them accordingly.
#
#----------------------------------------------------------------------

# log_request_text() logs the HTTP request stream from stdin
  log_request_text() {
    if [[ "${LOG}" == "1" ]]; then
      echo "<C $@" >&2
    fi
  }

# log_error_text() is used for logging errors to stderr
  log_error_text() { 
    if [[ "${LOG}" == "1" ]]; then  
      echo " <!> $@" >&2
    fi
  }


# send_response_text() receives a text stream. It passes one copy to stderr.
# The other goes to the client as part of the HTTP response.
# The printf in send_response_text() strips tailing NLs and replaces them.
# The final format is: CR & NL. This is how response headers are formatted.
  send_response_text() { 
    if [[ "${LOG}" == "1" ]]; then
      echo "   S> $@" >&2
    fi
    printf '%s\r\n' "$*"
  }

# log_binary_response() logs when binary is sent as a response body.
# It is a placeholder for the actual binary stream.
# cat is called directly to send the binary data to ensure that
# an exact copy of the binary file is transmitted to the client.
# Bash will 
  log_binary_response() { 
    if [[ "${LOG}" == "1" ]]; then
      echo "> <<< Transmitted some terminal-unfriendly binary data >>>" >&2
    fi
  }

#-------------------------------------#
# TIER 2: HTTP RESPONSE BUILDER SUITE |
#----------------------------------------------------------------------
#
#  Before passing text/binary to the tier 1 functions, data is arranged.
#  The builder suite is a set of arrays and functions.
#
#  They are responsible for building syntaxically correct HTTP. 
#  Each component of the suite adds, sets, or builds pieces.
#
#  Everything is eventually funneled to send_headers(),
#  it transfers header data to tier 1 functions.
#
#  The response bodies on the other hand, bypass tier 2 formatting.
#
#----------------------------------------------------------------------

# These first few headers are static, and placed in an array.
# The date() may fail due to diffs amongst unices; adjust if needed.
# Example of standard format per the HTTP Protocol is below: 
# Mon, 01 Jan 2001 01:01:01 CST
  declare -a RESPONSE_HEADERS=(
    "Date: $(date +"%a, %d %b %Y %H:%M:%S %Z" 2>/dev/null)"
    "Connection: close"
    "Server: Ajanke/${MAJ_VER}"
  )

# Function for appending new headers to header array
  add_response_header() {
    log_debug_text "add_response_header() invoked."
    log_debug_text "Argument 1: \"${1}\"."
    log_debug_text "Argument 2: \"${2}\"."
    RESPONSE_HEADERS+=( "$1: $2" )
  }

# HTTP-compliant response code storage array
  declare -a RESPONSE_CODES=(
    [200]="OK"
    [400]="Bad Request"
    [403]="Forbidden"
    [404]="Not Found"
    [405]="Method Not Allowed"
    [500]="Internal Server Error"
  )

# This will pass a response code to send_headers()
  set_response_code_to() { 
    RESPONSE_CODE="${1}"
  }

# This is the builder function that sends the HTTP headers
  send_headers() {
    log_debug_text "send_headers() invoked."
    send_response_text "HTTP/1.0 ${RESPONSE_CODE} ${RESPONSE_CODES[${RESPONSE_CODE}]}"
    log_debug_text "RESPONSE_CODE set to \"${RESPONSE_CODE}\"."
    for _each_header in "${RESPONSE_HEADERS[@]}"; do
      send_response_text "${_each_header}"
    done
    send_response_text ""
    log_debug_text "Last response header sent; blank line delimiter printed; body below."
    if [ "${REQUEST_METHOD}" = "HEAD" ]; then
      log_debug_text "REQUEST_METHOD was equal to HEAD, no body needed; exiting 0."
      exit 0
    elif [[ "${RESPONSE_CODE}" != "200" ]]; then
      log_debug_text "Respone Code NOT 200, exiting with return value 1."
      send_response_text "HTTP ${RESPONSE_CODE} ${RESPONSE_CODES[${RESPONSE_CODE}]}"
      exit 1
    fi
  }


#---------------------------#
# TIER 3: FILE SYSTEM HOOKS |
#----------------------------------------------------------------------
#
#  Each of these functions handles files and directories.
#  These functions feed response header data to send_headers().
#
#  They also feed HTTP response bodies to the client.
#  They are invoked by the tier 4 functions.
#
#  These functions are feed $FILE_TYPE and $FILE_PATH.
#  They use these to determine how to serve the content.
#  
#----------------------------------------------------------------------

# serve_dir_list() serves a simple directory listing for a given dir.
serve_dir_list() {
  log_debug_text "serve_dir_list() invoked."
  log_debug_text "FILE_PATH set to \"${FILE_PATH}\"."
  if [[ "${FILE_TYPE}" == "directory" ]]; then
    log_debug_text "FILE_TYPE was equal to "directory", test passed."
    add_response_header "Content-Type" "text/html"
    set_response_code_to 200
    send_headers
    send_response_text "<h1>Contents of ${FILE_PATH}:</h1>"
    while IFS=" " read -r _ls_output; do
      send_response_text "<h3><a href="http://${REQUEST_HOST}${FILE_PATH:1}/${_ls_output}">${_ls_output}</a></h3>"
    done < <(ls "${FILE_PATH}")
  fi
}

# serve_file() is invoked to serve up a single file.
serve_file() {
  log_debug_text "server_file() invoked."
  CONTENT_TYPE=""
  log_debug_text "CONTENT_TYPE initialized with value: \"${CONTENT_TYPE}\"."
    case ${FILE_PATH} in
      *\.html)
        CONTENT_TYPE="text/html"
        ;;
      *\.css)
        CONTENT_TYPE="text/css"
        ;;
      *\.js)
        CONTENT_TYPE="text/javascript"
        ;;
      *)
        read -r CONTENT_TYPE < <(file -b --mime-type "${FILE_PATH}") || \
        CONTENT_TYPE="application/octet-stream"
        ;;
    esac
    add_response_header "Content-Type" "${CONTENT_TYPE}"
    set_response_code_to 200
    send_headers
    if [[ "${CONTENT_TYPE:0:4}" == "text" ]]; then
      log_debug_text "Content type for file is \"text\", sending as text."
      while read -r _line; do
        send_response_text $_line
      done < "${FILE_PATH}"
    else
      log_debug_text "Content type for file not text, catting as binary."
      cat "${FILE_PATH}" && log_binary_response
    fi
}


#-------------------------#
# TIER 4: REQUEST PARSERS |
#----------------------------------------------------------------------
#
#  The request parsers receive requests first, and translate it.
#  They also check the syntax to prevent injection or chroot escape.
#  
#  Lastly, they set $FILE_PATH and $FILE_TYPE for the tier 3 functions.
#
#----------------------------------------------------------------------

# Setup a place to store the request headers
declare -a REQUEST_HEADERS

# This function parses the request headers
parse_request() {
  log_debug_text "parse_request() invoked."
  read -r _request_line
  if [[ ! -n "${_request_line}" ]]; then
    set_response_code_to 400
    send_headers
    log_debug_text "First line of request was null; request rejected."
  fi
  log_debug_text "First line of request was NOT null; captured by parse_request()."
  _request_line=${_request_line%%$'\r'}
  log_debug_text " _request_line stripped of CRs and set to \"${_request_line}\"."
  log_request_text "${_request_line}"
  read -r REQUEST_METHOD REQUEST_URI REQUEST_HTTP_VERSION <<<"${_request_line}"
  log_debug_text " REQUEST_METHOD set to \"${REQUEST_METHOD}\"."
  log_debug_text " REQUEST_URI set to \"${REQUEST_URI}\"."
  log_debug_text " REQUEST_HTTP_VERSION set to \"${REQUEST_HTTP_VERSION}\"."
  if [[ ! -n "$REQUEST_METHOD" ]] || [[ ! -n "$REQUEST_URI" ]] || [[ ! -n "$REQUEST_HTTP_VERSION" ]]; then
    set_response_code_to 400
    send_headers
  fi  
  log_debug_text "First line request header values are all non-null, continuing."
  if [[ "$REQUEST_METHOD" != "GET" ]]; then 
    set_response_code_to 405
    send_headers
  fi
  log_debug_text "Method is supported, continuing."
  while read -r _other_headers; do
    _other_headers=${_other_headers%%$'\r'}
    case $_other_headers in
      Host:*)
        REQUEST_HOST="${_other_headers}"
        REQUEST_HOST="${REQUEST_HOST:6}"
        ;;
      *)
        ;;
    esac
    log_request_text "${_other_headers}"
    [ -z "${_other_headers}" ] && break 
    REQUEST_HEADERS+=( "${_other_headers}" )
  done
    log_debug_text "End of request headers found. Blank line read."
    log_debug_text "REQUEST_HOST set to \"${REQUEST_HOST}\"."
}

# check_uri_path() further formats the parsed request it checks the file system.
# It determines if the file path requried exists, and are accessible.
check_uri_path() { 
  log_debug_text "check_uri_path() invoked."
  FILE_PATH=".${REQUEST_URI}"
  log_debug_text "FILE_PATH set to \"${FILE_PATH}\"."
  FILE_PATH=${FILE_PATH//[^a-zA-Z0-9_~\-\.\/]/}
  log_debug_text "Front of FILE_PATH sanitized of wildcard characters."
  log_debug_text "FILE_PATH set to \"${FILE_PATH}\"."
  FILE_PATH="${FILE_PATH%%/}"
  log_debug_text "Trailing slash stripped from FILE_PATH"
  log_debug_text "FILE_PATH set to \"${FILE_PATH}\"."
  if [[ $FILE_PATH == *..* ]]; then
    log_debug_text "FILE_PATH FAILED chroot escape attempt check; nope.jpg!" 
    set_response_code_to 400
  fi
  log_debug_text "FILE_PATH passed chroot escape attempt check."
  if [[ ! -e "${FILE_PATH}" ]]; then
    log_debug_text "File path \"${FILE_PATH}\" does NOT exist."
    set_response_code_to 404
    send_headers
  elif [[ ! -r "${FILE_PATH}" ]]; then
    log_debug_text "File path \"${FILE_PATH}\" does exist."
    log_debug_text "File path \"${FILE_PATH}\" is NOT readable." 
    set_response_code_to 403
    send_headers
  fi
  log_debug_text "File path \"${FILE_PATH}\" is readable."
  if [[ ! -d "${FILE_PATH}" ]]; then
    log_debug_text "File path \"${FILE_PATH}\" is NOT a directory."
    if [[ ! -f "${FILE_PATH}" ]]; then
      log_debug_text "File path \"${FILE_PATH}\" is NOT a regular file."
      FILE_TYPE="other"
      log_debug_text "FILE_TYPE set to \"${FILE_TYPE}\"."
      set_response_code_to 400
      send_headers
    else
      FILE_TYPE="file"
    fi
  log_debug_text "FILE_TYPE set to \"${FILE_TYPE}\"."
  log_debug_text "File path \"${FILE_PATH}\" is a regular file."
  log_debug_text "File path \"${FILE_PATH}\" is a directory."
  elif [[ ! -x "${FILE_PATH}" ]]; then
    log_debug_text "Directory \"${FILE_PATH}\" is not executable."
    set_response_code_to 404
    send_headers
  else
    FILE_TYPE="directory"
  fi
  log_debug_text "Directory \"${FILE_PATH}\" is executable."
  log_debug_text "FILE_TYPE set to \"${FILE_TYPE}\"."
  log_debug_text "FILE_PATH and FILE_TYPE are ready for use by functions."
}


#-------------------#
# PROGRAM EXECUTION |
#----------------------------------------------------------------------
#
#  Once everything is setup, this snippet gets the ball rolling.
#
#----------------------------------------------------------------------
  
  parse_ppid "$@"
  parse_request && check_uri_path

  if [[ "${FILE_TYPE}" == "directory" ]]; then
    serve_dir_list
  elif [[ "${FILE_TYPE}" == "file" ]]; then
    serve_file
  else
    exit 1
  fi
