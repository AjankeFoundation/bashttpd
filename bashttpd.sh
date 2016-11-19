#!/usr/bin/env bash
  if [[ "$UID" = "0" ]]; then
    log_error_text "root? Just what do you think you are doing, Dave?"
    exit 1
  fi
  log_debug_text() { 
    if [[ "${DEBUG}" == "1" ]]; then
      echo " <I> $@" >&2
    fi
  }
  MAJ_VER=3
  Usage() {
    echo "Usage: bashttpd starts (or stops) a basHTTPd server in the current working directory"
    echo ""
    echo "    start  [-c conn_max] [-i ip_address] [-p tcp_port]"
    echo "      -c   connection limit; sets max connections. Default is \"16\" if unspecified."
    echo "      -i   ip; bind basHTTPd to an ip_address. Default is \"127.0.0.1\" if unspecified."
    echo "      -p   port; bind basHTTPd to a tcp_port. Default is TCP port \"2274\" if unspecified."
    echo ""
    echo "    stop   [process_id]"
    echo "           process_id is optional; default behavior: stop all bashttpd/tcpserver processes."       
    echo ""
  }
  get_opts() {
    if [[ "${1}" == "start" ]]; then
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
      BASHTTPD_START=1
      shift
      while getopts ":i:p:c:" opt; do
        case "${opt}" in
          i)
            IP_ADDRESS="${OPTARG//[^a-zA-Z0-9\:\.]/}"
            ;;
          p)
            PORT="${OPTARG//[^0-9]/}"
            ;;
          c)
            CONN_MAX="${OPTARG//[^0-9]/}"
            ;;
          *)
            echo "Invalid option \"${opt}\" passed to \"${0} start\". See Usage."
            Usage
            ;;
        esac
      done
    fi
    if [[ "${1}" == "stop" ]]; then
      BASHTTPD_STOP=1
      shift
      if [[ "${1}" == "" ]]; then
        STOP_TARGET="${DAEMON_NAME}"
      elif [[ ${1//[^0-9]/} > "1" ]]; then
        STOP_TARGET="${1}"
      elif [[ ${1//[^0-9]/} == "1" ]]; then
        echo "Stop process ID 1? I'm sorry, Dave; I'm afraid I can't do that."
        exit 1
      else
        echo "Invalid process ID: \"${OPTARG//[^0-9]/}\"; exiting."
        exit 1            
      fi
    fi
  }
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
      killall ${STOP_TARGET} tcpserver 2>/dev/null && \
      echo "[SUCCESS] All processes named \"${DAEMON_NAME}\" and tcpserver have been stopped." && \
      exit 0 || \
      type killall >/dev/null && \
      echo "[INFO] Unable to find \"${DAEMON_NAME}\" to terminate; exiting." && \
      exit 1
    else
      kill ${STOP_TARGET} 2>/dev/null && \
      echo "[SUCCESS] SIGTERM sent to process ID \"${STOP_TARGET}\"." && \
      exit 0 || \
      echo "[FAILURE] No process ID \"${STOP_TARGET}\" found; exiting." && \
      exit 1
    fi
  }
parse_ppid() {
  DAEMON_NAME=bashttpd${MAJ_VER}
  PARENT_PROC="$(ps -p $PPID -o command)"
  if [[ "${1}" == "start" ]] || [[ "${1}" == "stop" ]]; then
    daemon_ctl "$@"
  elif [[ "${PARENT_PROC:8:${#DAEMON_NAME}}" != "${DAEMON_NAME}" ]]; then
    Usage
    exit 1
  fi
}
  log_request_text() {
    if [[ "${LOG}" == "1" ]]; then
      echo "<C $@" >&2
    fi
  }
  log_error_text() { 
    if [[ "${LOG}" == "1" ]]; then  
      echo " <!> $@" >&2
    fi
  }
  send_response_text() { 
    if [[ "${LOG}" == "1" ]]; then
      echo "   S> $@" >&2
    fi
    printf '%s\r\n' "$*"
  }
  log_binary_response() { 
    if [[ "${LOG}" == "1" ]]; then
      echo "> <<< Transmitted some terminal-unfriendly binary data >>>" >&2
    fi
  }
  declare -a RESPONSE_HEADERS=(
    "Date: $(date +"%a, %d %b %Y %H:%M:%S %Z" 2>/dev/null)"
    "Connection: close"
    "Server: Ajanke/${MAJ_VER}"
  )
  add_response_header() {
    RESPONSE_HEADERS+=( "$1: $2" )
  }
  declare -a RESPONSE_CODES=(
    [200]="OK"
    [400]="Bad Request"
    [403]="Forbidden"
    [404]="Not Found"
    [405]="Method Not Allowed"
    [500]="Internal Server Error"
  )
  set_response_code_to() { 
    RESPONSE_CODE="${1}"
  }
  send_headers() {
    send_response_text "HTTP/1.0 ${RESPONSE_CODE} ${RESPONSE_CODES[${RESPONSE_CODE}]}"
    for _each_header in "${RESPONSE_HEADERS[@]}"; do
      send_response_text "${_each_header}"
    done
    send_response_text ""
    if [ "${REQUEST_METHOD}" = "HEAD" ]; then
      exit 0
    elif [[ "${RESPONSE_CODE}" != "200" ]]; then
      send_response_text "HTTP ${RESPONSE_CODE} ${RESPONSE_CODES[${RESPONSE_CODE}]}"
      exit 1
    fi
  }
serve_dir_list() {
  if [[ "${FILE_TYPE}" == "directory" ]]; then
    add_response_header "Content-Type" "text/html"
    set_response_code_to 200
    send_headers
    send_response_text "<h1>Contents of ${FILE_PATH}:</h1>"
    while IFS=" " read -r _ls_output; do
      send_response_text "<h3><a href="http://${REQUEST_HOST}${FILE_PATH:1}/${_ls_output}">${_ls_output}</a></h3>"
    done < <(ls "${FILE_PATH}")
  fi
}
serve_file() {
  CONTENT_TYPE=""
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
      while read -r _line; do
        send_response_text $_line
      done < "${FILE_PATH}"
    else
      cat "${FILE_PATH}" && log_binary_response
    fi
}
declare -a REQUEST_HEADERS
parse_request() {
  read -r _request_line
  if [[ ! -n "${_request_line}" ]]; then
    set_response_code_to 400
    send_headers
  fi
  _request_line=${_request_line%%$'\r'}
  log_request_text "${_request_line}"
  read -r REQUEST_METHOD REQUEST_URI REQUEST_HTTP_VERSION <<<"${_request_line}"
  if [[ ! -n "$REQUEST_METHOD" ]] || [[ ! -n "$REQUEST_URI" ]] || [[ ! -n "$REQUEST_HTTP_VERSION" ]]; then
    set_response_code_to 400
    send_headers
  fi  
  if [[ "$REQUEST_METHOD" != "GET" ]]; then 
    set_response_code_to 405
    send_headers
  fi
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
}
check_uri_path() { 
  FILE_PATH=".${REQUEST_URI}"
  FILE_PATH=${FILE_PATH//[^a-zA-Z0-9_~\-\.\/]/}
  FILE_PATH="${FILE_PATH%%/}"
  if [[ $FILE_PATH == *..* ]]; then
    set_response_code_to 400
  fi
  if [[ ! -e "${FILE_PATH}" ]]; then
    set_response_code_to 404
    send_headers
  elif [[ ! -r "${FILE_PATH}" ]]; then
    set_response_code_to 403
    send_headers
  fi
  if [[ ! -d "${FILE_PATH}" ]]; then
    if [[ ! -f "${FILE_PATH}" ]]; then
      FILE_TYPE="other"
      set_response_code_to 400
      send_headers
    else
      FILE_TYPE="file"
    fi
  elif [[ ! -x "${FILE_PATH}" ]]; then
    set_response_code_to 404
    send_headers
  else
    FILE_TYPE="directory"
  fi
}
  parse_ppid "$@"
  parse_request && check_uri_path
  if [[ "${FILE_TYPE}" == "directory" ]]; then
    serve_dir_list
  elif [[ "${FILE_TYPE}" == "file" ]]; then
    serve_file
  else
    exit 1
  fi
