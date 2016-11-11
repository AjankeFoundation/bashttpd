
  if [[ "$UID" = "0" ]]; then
    log_error_text "WARNING: Do not run BasHTTPd as root; are you high?"
    exit 1
  fi
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
  log_debug_text() { 
    if [[ "${DEBUG}" == "1" ]]; then
      echo " <I> $@" >&2
    fi
  }
  send_response_text() { 
    if [[ "${LOG}" == "1" ]]; then
      echo "   S> $@" >&2
      printf '%s\r\n' "$*"
    fi
  }
  log_binary_response() { 
    echo "> <<< Transmitted some terminal-unfriendly binary data >>>" >&2
  }
  declare -a RESPONSE_HEADERS=(
    "Date: $(date +"%a, %d %b %Y %H:%M:%S %Z" 2>/dev/null)"
    "Connection: close"
    "Server: Ajanke/2.0.0"
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
    send_response_text "<h1>Contents of \"${FILE_PATH}\":</h1>"
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
        read -r CONTENT_TYPE < <(file -b --mime-type "${FILE_PATH}")
        ;;
    esac
    add_response_header "Content-Type" "${CONTENT_TYPE}"
    set_response_code_to 200
    send_headers
    if [[ "${CONTENT_TYPE:0:4}" == "text" ]]; then
      while read -r _line; do
        send_response_text 
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
  if [[ -n "$REQUEST_METHOD" ]] && [[ -n "$REQUEST_URI" ]] && [[ -n "$REQUEST_HTTP_VERSION" ]]; then
  else
    set_response_code_to 400
    send_headers
  fi  
  if [[ "$REQUEST_METHOD" = "GET" ]]; then 
  else
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
  if [[ "${1}" == "" ]]; then
    FILE_PATH=".${REQUEST_URI}"
  else
    FILE_PATH="${1}"
  fi
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
  parse_request && check_uri_path
  if [[ "${FILE_TYPE}" == "directory" ]]; then
    serve_dir_list
  elif [[ "${FILE_TYPE}" == "file" ]]; then
    serve_file
  else
    exit 1
  fi
