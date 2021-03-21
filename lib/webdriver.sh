# shellcheck shell=sh

# WebDriver bindings for shell script
# https://www.w3.org/TR/webdriver/

# ========================================
# Constants
# ========================================

# The web element identifier
WEBDRIVER_SH_WEB_ELEMENT_KEY="element-6066-11e4-a52e-4f735466cecf"

WebDriver__keys_() {
  # https://www.w3.org/TR/webdriver/#keyboard-actions
  set -- \
  E000:unidentified   E001:cancel           E002:help         E003:backspace   \
  E004:tab            E005:clear            E006:return       E007:enter       \
  E008:shift          E009:control          E00A:alt          E00B:pause       \
  E008:left_shift     E009:left_control     E00A:left_alt                      \
  E00C:escape         E00D:space            E00E:page_up      E00F:page_down   \
  E010:end            E011:home                                                \
  E012:left           E013:up               E014:right        E015:down        \
  E012:arrow_left     E013:arrow_up         E014:arrow_right  E015:arrow_down  \
                                            E016:insert       E017:delete      \
  E018:semicolon      E019:equals           E01A:numpad0      E01B:numpad1     \
  E01C:numpad2        E01D:numpad3          E01E:numpad4      E01F:numpad5     \
  E020:numpad6        E021:numpad7          E022:numpad8      E023:numpad9     \
  E024:multiply       E025:add              E026:separator    E027:subtract    \
  E028:decimal        E029:divide                                              \
                      E031:f1               E032:f2           E033:f3          \
  E034:f4             E035:f5               E036:f6           E037:f7          \
  E038:f8             E039:f9               E03A:f10          E03B:f11         \
  E03C:f12            E03D:meta             E03D:command      E03D:left_meta   \
  E050:right_shift    E051:right_control    E052:right_alt    E053:right_meta  \
  E054:numpad_page_up E055:numpad_page_down E056:numpad_end   E057:numpad_home \
  E058:numpad_left    E059:numpad_up        E05A:numpad_right E05B:numpad_down \
  E05C:numpad_insert  E05D:numpad_delete
  while [ $# -gt 0 ]; do
    echo "\"WEBDRIVER_SH_KEY_${1#*:}=\" + \"'\\u${1%:*}'\""
    [ $# -gt 1 ] && echo ','
    shift
  done
}
eval "$(jq -nr "$(WebDriver__keys_)")"

# ========================================
# WebDriver
# ========================================

WebDriver() {
  case $1 in
    ::*) eval "shift; WebDriver__${1#::}_ \"\$@\"" ;;
    *=) echo "Unable to connect to WebDriver" >&2; return 1 ;;
    *=*) WebDriver ::new "$@"
  esac
}

# ----------------------------------------
# WebDriver: private class methods
# ----------------------------------------

WebDriver__new_() {
  set -- "${1%%\=*}" "${1#*\=}"
  eval "WEBDRIVER_SH_$1=\$2"
  [ "$2" ] || return 1
  # shellcheck disable=SC2046
  set -- "$@" $(printf '%s' "$2" | jq -r '.name, .session.sessionId')
  eval "$1() { eval 'shift; \"$3_'\"\$1\"'\" \"${1}:session/$4\" \"\$@\"'; }"
}

WebDriver__del_() {
  unset "WEBDRIVER_SH_${1%%:*}"
}

WebDriver__curl_() {
  # JSON formmat check
  if [ "$2" = "POST" ]; then
    if ! printf '%s\n' "$4" | jq . >/dev/null; then
      printf '%s\n' "$4" >&2
      return 1
    fi
  fi

  if [ "${WEBDRIVER_SH_DEBUG:-}" ]; then
    echo '=== curl ===' >&2
    curl --verbose "$@" | {
      WebDriver ::http_response_header
      if [ "$2" = "POST" ]; then
        echo '---- request ----' >&2
        printf '%s\n' "$4" | jq . >&2
      fi
      echo '---- response ----' >&2
      set -- "$(cat)"
      printf '%s\n' "$1" | jq . >&2
      printf '%s\n' "$1"
    }
    echo '=== end ===' >&2
  else
    curl "$@"
  fi
}

WebDriver__proxy_() {
  eval "$1_$2() { WebDriver_$2 \"\$@\"; }"
}

WebDriver__create_() {
  set -- "$1" WebDriver quit
  set -- "$@" session_id self hostname version capabilities status
  set -- "$@" timeouts
  set -- "$@" get current_url back forward refresh title # Navigation
  set -- "$@" find_element find_elements # Elements
  set -- "$@" get_all_cookies get_cookie add_cookie delete_cookie delete_all_cookies
  set -- "$@" window_handle close_window window_handles new_window switch_to
  set -- "$@" window
  set -- "$@" page_source
  set -- "$@" execute_script execute_async_script
  set -- "$@" alert
  set -- "$@" save_screenshot screenshot_as

  eval "shift 2; while [ \$# -gt 0 ]; do $2 ::proxy $1 \"\$1\"; shift; done"
}

WebDriver__http_get_() {
  WebDriver ::curl -X GET -si "$1" | WebDriver ::http_result
}

WebDriver__http_post_() {
  set -- "$1" "${2:-}" "Content-Type: application/json"
  [ "$2" ] || set -- "$1" "{}" "$3"
  WebDriver ::curl -X POST -d "$2" -si -H "$3" "$1" | WebDriver ::http_result
}

WebDriver__http_delete_() {
  WebDriver ::curl -X DELETE -si "$1" | WebDriver ::http_result
}

WebDriver__http_response_header_() (
  while IFS= read -r line; do
    printf '%s\n' "$line"
    case $line in (*[[:print:]]*)
      continue
    esac
    break
  done
)

WebDriver__http_result_() (
  IFS= read -r http_code
  http_code=${http_code#* } http_code=${http_code% *}
  WebDriver ::http_response_header >/dev/null
  case $http_code in (2??)
    jq -r 'select(.value != null) | .value'
    return 0
  esac
  jq -r .value.message >&2
  return 1
)

WebDriver__escape_() (
  i=0 option='' filter=''
  while [ "$i" -lt $# ] && i=$((i+1)); do
    option="$option --arg v$i \"\$$i\""
    filter="$filter${filter:+,}\$v$i"
  done
  eval "jq -n $option '$filter'" | while IFS= read -r line; do
    line=${line#?} line=${line%?}
    printf '%s\n' "$line"
  done
)

WebDriver__build_cookie_() {
  WebDriver ::escape "$@" | (
    _name='' _value=''
    unset _domain _expiry _http_only _path _same_site _secure

    # Taken from https://github.com/SeleniumHQ/selenium/blob/selenium-4.0.0-beta-2/rb/lib/selenium/webdriver/common/manager.rb#L49
    # NOTE: This is required because of https://bugs.chromium.org/p/chromedriver/issues/detail?id=3732
    _secure=false

    while IFS= read -r kv; do
      case ${kv%%:*} in
        name | value | domain | expiry | http_only | path | same_site | secure)
          eval "_${kv%%:*}=\${kv#*:}"
      esac
    done

    f='"name": "%s", "value": "%s"'
    set -- "$_name" "$_value"
    [ "${_domain+x}" ] && f="$f"', "domain":"%s"' && set -- "$@" "$_domain"
    [ "${_expiry+x}" ] && f="$f"', "expiry":%s' && set -- "$@" "$_expiry"
    [ "${_http_only+x}" ] && f="$f"', "httpOnly":%s' && set -- "$@" "$_http_only"
    [ "${_path+x}" ] && f="$f"', "path":"%s"' && set -- "$@" "$_path"
    [ "${_same_site+x}" ] && f="$f"', "sameSite":"%s"' && set -- "$@" "$_same_site"
    [ "${_secure+x}" ] && f="$f"', "secure":%s' && set -- "$@" "$_secure"
    printf "{ $f }" "$@"
  )
}

WebDriver__build_text_() (
 text=''
  while [ $# -gt 0 ]; do
    case $1 in (:[!:]*)
      case ${1#:} in
        *[!a-z_]*) ;;
        *) eval "text=\"\${text}\${WEBDRIVER_SH_KEY_${1#:}}\""
      esac
      shift
      continue
    esac
    case $1 in
      ::*) text="${text}${1#:}" ;;
      *) text="${text}${1}" ;;
    esac
    shift
  done
  printf '%s' "$text"
)

WebDriver__to_rect_() {
  case ${1:-} in
    ?*) jq -r "select(.$1 != null) | .$1" ;;
    '') jq -r '[ .["x", "y", "width", "height"] | tostring ] | join(" ")' ;;
  esac
}

WebDriver__to_ms_() {
  case $1 in
    null) echo "$1" ;;
    *) echo "$(($1 * 1000))" ;;
  esac
}

WebDriver__as_() {
  case $1 in
    base64) cat ;;
    png) base64 -d ;;
    *) echo "unsupported format: $1" >&2; exit 1
  esac
}

# ----------------------------------------
# WebDriver: private instance methods
# ----------------------------------------

WebDriver__self() {
  eval "printf '%s\n' \"\$WEBDRIVER_SH_${1%%:*}\" | jq ."
}

WebDriver__get() {
  WebDriver ::http_get "$(WebDriver__build_uri "$1" "$2")"
}

WebDriver__post() {
  if [ $# -lt 3 ]; then
    WebDriver ::http_post "$(WebDriver__build_uri "$1" "$2")"
  else
    ( shift 3; WebDriver ::escape "$@" ) | (
      uri=$(WebDriver__build_uri "$1" "$2")
      set -- "$3"
      while IFS= read -r line; do
        set -- "$@" "$line"
      done
      # shellcheck disable=SC2059
      WebDriver ::http_post "$uri" "$(printf "$@")"
    )
  fi
}

WebDriver__delete() {
  WebDriver ::http_delete "$(WebDriver__build_uri "$1" "$2")"
}

WebDriver__build_uri() {
  set -- "$1" "$(WebDriver__self "$1" | jq -r .hostname)" "$2"
  printf '%s/%s%s\n' "$2" "${1#*:}" "$3"
}

# ----------------------------------------
# WebDriver: instance methods
# ----------------------------------------

WebDriver_session_id() {
  echo "${1#*:}"
}

WebDriver_hostname() {
  WebDriver__self "$1" | jq -r ".hostname"
}

WebDriver_vearsion() {
  echo "unknown"
}

# ----------------------------------------
# WebDriver: Capabilities
# ----------------------------------------

WebDriver_capabilities() {
  WebDriver__self "$1" | jq -r ".session.capabilities${2:+.}${2:-}"
}

# ----------------------------------------
# WebDriver: Sessions
# ----------------------------------------

# https://www.w3.org/TR/webdriver/#new-session
WebDriver_new_session() {
  WebDriver ::http_post "$1/session" '{"capabilities":{"alwaysMatch":'"$2"'}}'
}

# https://www.w3.org/TR/webdriver/#delete-session
WebDriver_delete_session() {
  WebDriver ::http_delete "$(WebDriver__build_uri "$1" "")"
}

WebDriver_quit() {
  WebDriver_delete_session "$1"
  WebDriver ::del "$1"
}

# https://www.w3.org/TR/webdriver/#status
WebDriver_status() {
  WebDriver ::http_get "$(WebDriver_hostname "$1")/status" | jq -r ".${2:-}"
}

# ----------------------------------------
# WebDriver: Timeouts
# ----------------------------------------

WebDriver_timeouts() {
  case $# in
    1)
      WebDriver_get_timeouts "$1" | {
        jq -r '[ .["script", "pageLoad", "implicit"] | tostring ] | join(" ")'
      } ;;
    2) WebDriver_get_timeouts "$1" | jq -r ".$2" ;;
    3) WebDriver_set_timeouts "$@" ;;
  esac
}

# https://www.w3.org/TR/webdriver/#get-timeouts
WebDriver_get_timeouts() {
  WebDriver__get "$1" /timeouts
}

# https://www.w3.org/TR/webdriver/#set-timeouts
WebDriver_set_timeouts() {
  WebDriver__post "$1" /timeouts '{"%s":%s}' "$2" "$(WebDriver ::to_ms "$3")"
}

# ----------------------------------------
# WebDriver: Navigation
# ----------------------------------------

# https://www.w3.org/TR/webdriver/#navigate-to
WebDriver_get() {
  WebDriver__post "$1" /url '{"url":"%s"}' "$2"
}

# https://www.w3.org/TR/webdriver/#get-current-url
WebDriver_current_url() {
  WebDriver__get "$1" /url
}

# https://www.w3.org/TR/webdriver/#back
WebDriver_back() {
  WebDriver__post "$1" /back
}

# https://www.w3.org/TR/webdriver/#forward
WebDriver_forward() {
  WebDriver__post "$1" /forward
}

# https://www.w3.org/TR/webdriver/#refresh
WebDriver_refresh() {
  WebDriver__post "$1" /refresh
}

# https://www.w3.org/TR/webdriver/#get-title
WebDriver_title() {
  WebDriver__get "$1" /title
}

# ----------------------------------------
# WebDriver: Contexts
# ----------------------------------------

# Usage:
#   driver window_handle
#
# https://www.w3.org/TR/webdriver/#get-window-handle
WebDriver_window_handle() {
  WebDriver__get "$1" /window
}

# https://www.w3.org/TR/webdriver/#close-window
WebDriver_close_window() {
  WebDriver__delete "$1" /window
}

# https://www.w3.org/TR/webdriver/#switch-to-window
WebDriver_switch_to_window() {
  WebDriver__post "$1" /window '{"handle":"%s"}' "$2"
}

# https://www.w3.org/TR/webdriver/#get-window-handles
WebDriver_window_handles() {
  WebDriver__get "$1" /window/handles | jq -r '.[]'
}

# https://www.w3.org/TR/webdriver/#new-window
WebDriver_new_window() {
  if [ $# -le 1 ]; then
    set -- "$1" /window/new
  else
    set -- "$1" /window/new '{"type":"%s"}' "$2"
  fi
  WebDriver__post "$@" | jq -r '.handle'
}

WebDriver_switch_to() {
  eval "shift 2; \"WebDriver_switch_to_$2\" \"$1\" \"\$@\""
}

# Usage:
#   driver switch_to frame iframe # (WebElement)
#   driver switch_to frame 1
#   driver switch_to frame 'css selector:#iframe'
#
# https://www.w3.org/TR/webdriver/#switch-to-frame
WebDriver_switch_to_frame() {
  case $2 in
    *:*) set -- "$1" "$(WebDriver_find_element "${1%/*/*}" "$2" as_json)" ;;
    *[!0-9]*) set -- "$1" "$("$2" as_json)" ;;
  esac
  WebDriver__post "$1" /frame "{\"id\":$2}"
}

# Usage:
#   driver switch_to default_content
WebDriver_switch_to_default_content() {
  WebDriver__post "$1" /frame '{"id":null}'
}

# Usage:
#   driver switch_to parent_frame
# https://www.w3.org/TR/webdriver/#switch-to-parent-frame
WebDriver_switch_to_parent_frame() {
  WebDriver__post "$1" /frame/parent
}

WebDriver_window() {
  eval "shift 2; \"WebDriver_window_$2\" \"$1\" \"\$@\""
}

# https://www.w3.org/TR/webdriver/#get-window-rect
WebDriver_window_rect() {
  WebDriver__get "$1" /window/rect | WebDriver ::to_rect "${2:-}"
}

WebDriver_window_position() {
  case ${2:-} in ('' | x | y)
    set -- "$(WebDriver_window_rect "$@")"
    echo "${1% * *}"
  esac
}

WebDriver_window_size() {
  case ${2:-} in ('' | width | height)
    set -- "$(WebDriver_window_rect "$@")"
    echo "${1#* * }"
  esac
}

# https://www.w3.org/TR/webdriver/#set-window-rect
WebDriver_window_set_rect() {
  WebDriver__post "$1" /window/rect '{"x":%s,"y":%s,"width":%s,"height":%s}' \
    "${2:-null}" "${3:-null}" "${4:-null}" "${5:-null}" | WebDriver ::to_rect
}

WebDriver_window_move_to() {
  WebDriver_window_set_rect "$1" "${2:-}" "${3:-}"
}

WebDriver_window_resize_to() {
  WebDriver_window_set_rect "$1" "" "" "${2:-}" "${3:-}"
}

# https://www.w3.org/TR/webdriver/#maximize-window
WebDriver_window_maximize() {
  WebDriver__post "$1" /window/maximize | WebDriver ::to_rect
}

# https://www.w3.org/TR/webdriver/#minimize-window
WebDriver_window_minimize() {
  WebDriver__post "$1" /window/minimize | WebDriver ::to_rect
}

# https://www.w3.org/TR/webdriver/#fullscreen-window
WebDriver_window_fullscreen() {
  WebDriver__post "$1" /window/fullscreen | WebDriver ::to_rect
}

# ----------------------------------------
# WebDriver: Elements Retrieval
# ----------------------------------------

# Locator: <keyword>:<value>
# https://www.w3.org/TR/webdriver/#locator-strategies

# Usage:
#   driver find_element <Locator>
#   driver find_element <Locator> [<WebElement method> [args...]]
#
# https://www.w3.org/TR/webdriver/#find-element
WebDriver_find_element() {
  set -- "$1" "${2%%:*}" "${2#*:}" "$WEBDRIVER_SH_WEB_ELEMENT_KEY" "$@"
  WebDriver__post "$1" /element '{"using":"%s", "value":"%s"}' "$2" "$3" | (
    id=$(jq --arg base "$1/element/" --arg key "$4" -r '$base + .[$key]')
    [ "$id" ] || return $?
    [ $# -le 6 ] && echo "$id" && return 0
    method=$7 && shift 7 && "WebElement_$method" "$id" "$@"
  )
}

# https://www.w3.org/TR/webdriver/#find-elements
WebDriver_find_elements() {
  set -- "$1" "${2%%:*}" "${2#*:}" "$WEBDRIVER_SH_WEB_ELEMENT_KEY"
  WebDriver__post "$1" /elements '{"using":"%s", "value":"%s"}' "$2" "$3" | {
    jq --arg base "$1/element/" --arg key "$4" -r '$base + .[][$key]'
  }
}

# https://www.w3.org/TR/webdriver/#get-active-element
WebDriver_switch_to_active_element() {
  set -- "$1" "$WEBDRIVER_SH_WEB_ELEMENT_KEY"
  WebDriver__get "$1" /element/active | {
    jq --arg base "$1/element/" --arg key "$2" -r '$base + .[$key]'
  }
}

# [Draft] https://w3c.github.io/webdriver/#get-element-shadow-root

# ----------------------------------------
# WebDriver: Document
# ----------------------------------------

# https://www.w3.org/TR/webdriver/#get-page-source
WebDriver_page_source() {
  WebDriver__get "$1" /source
}

# Usage:
#   driver execute_script <script> [args...]
#
# script: JavaScript string
# args: JSON string
#
# https://www.w3.org/TR/webdriver/#execute-script
WebDriver_execute_script() {
  set -- "$1" "$2" "$(shift 2; IFS=","; printf '%s' "[$*]")"
  WebDriver__post "$1" /execute/sync '{"script": "%s", "args":'"$3"'}' "$2"
}

# https://www.w3.org/TR/webdriver/#execute-async-script
WebDriver_execute_async_script() {
  set -- "$1" "$2" "$(shift 2; IFS=","; printf '%s' "[$*]")"
  WebDriver__post "$1" /execute/async '{"script": "%s", "args":'"$3"'}' "$2"
}

# ----------------------------------------
# WebDriver: Cookies
# ----------------------------------------

# https://www.w3.org/TR/webdriver/#get-all-cookies
WebDriver_get_all_cookies() {
  WebDriver__get "$1" /cookie
}

# https://www.w3.org/TR/webdriver/#get-named-cookie
WebDriver_get_cookie() {
  WebDriver__get "$1" /cookie/"$2"
}

# https://www.w3.org/TR/webdriver/#add-cookie
WebDriver_add_cookie() {
  set -- "$@" "name:$2" "value:$3"
  set -- "$1" "$(shift 3; WebDriver ::build_cookie "$@")"
  WebDriver__post "$1" /cookie "{\"cookie\": $2}"
}

# https://www.w3.org/TR/webdriver/#delete-cookie
WebDriver_delete_cookie() {
  WebDriver__delete "$1" /cookie/"$2"
}

# https://www.w3.org/TR/webdriver/#delete-all-cookies
WebDriver_delete_all_cookie() {
  WebDriver__delete "$1" /cookie
}

# ----------------------------------------
# WebDriver: Actions
# ----------------------------------------

# https://www.w3.org/TR/webdriver/#perform-actions
WebDriver_actions() { TODO; }

# https://www.w3.org/TR/webdriver/#release-actions
WebDriver_release_actions() { TODO; }

# ----------------------------------------
# WebDriver: User prompts
# ----------------------------------------

WebDriver_alert() {
  eval "shift 2; \"WebDriver_alert_$2\" \"$1\" \"\$@\""
}

# https://www.w3.org/TR/webdriver/#dismiss-alert
WebDriver_alert_dismiss() {
  WebDriver__post "$1" /alert/dismiss
}

# https://www.w3.org/TR/webdriver/#accept-alert
WebDriver_alert_accept() {
  WebDriver__post "$1" /alert/accept
}

# https://www.w3.org/TR/webdriver/#get-alert-text
WebDriver_alert_text() {
  WebDriver__get "$1" /alert/text
}

# https://www.w3.org/TR/webdriver/#send-alert-text
WebDriver_alert_send_keys() {
  set -- "$1" "$(shift; WebDriver ::build_text "$@")"
  WebDriver__post "$1" /alert/text '{"text":"%s"}' "$2"
}

# ----------------------------------------
# WebDriver: Screen capture
# ----------------------------------------

# https://www.w3.org/TR/webdriver/#take-screenshot
WebDriver_take_screenshot() {
  WebDriver__get "$1" /screenshot
}

WebDriver_save_screenshot() {
  WebDriver_take_screenshot "$1" | WebDriver ::as "png" > "$2"
}

WebDriver_screenshot_as() {
  WebDriver_take_screenshot "$1" | WebDriver ::as "$2"
}

# ----------------------------------------
# WebDriver: Print
# ----------------------------------------

# https://www.w3.org/TR/webdriver/#print
WebDriver_print() { TODO; }

# ========================================
# ChromeDriver
# ========================================

WebDriver ::create ChromeDriver # extends WebDriver
ChromeDriver() {
  set -- "$2" "$(WebDriver_new_session "$2" "{\"goog:chromeOptions\":$($1)}")"
  [ "$2" ] || return 1
  printf '{"name":"ChromeDriver", "hostname":"%s", "session":%s}' "$@"
}

ChromeDriver_version() {
  WebDriver_capabilities "$1" "chrome.chromedriverVersion"
}

# ========================================
# EdgeDriver
# ========================================

WebDriver ::create EdgeDriver # extends WebDriver

# ========================================
# FirefoxDriver
# ========================================

WebDriver ::create FirefoxDriver # extends WebDriver

# ========================================
# InternetExplorerDriver
# ========================================

WebDriver ::create InternetExplorerDriver # extends WebDriver

# ========================================
# RemoteDriver
# ========================================

WebDriver ::create RemoteDriver # extends WebDriver

# ========================================
# OperaDriver
# ========================================

WebDriver ::create OperaDriver # extends WebDriver

# ========================================
# SafariDriver
# ========================================

WebDriver ::create SafariDriver # extends WebDriver

# ========================================
# WebElement
# ========================================

WebElement() {
  set -- "${1%%\=*}" "${1#*\=}"
  eval "$1() { eval 'shift; \"WebElement_'\"\$1\"'\" \"$2\" \"\$@\"'; }"
}

# ----------------------------------------
# WebElement: Elements State
# ----------------------------------------

WebElement_id() {
  echo "${1#*:}"
}

WebElement_as_json() {
  printf '{"%s":"%s"}' "$WEBDRIVER_SH_WEB_ELEMENT_KEY" "${1##*/}"
}

# https://www.w3.org/TR/webdriver/#is-element-selected
WebElement_selected() {
  WebDriver__get "$1" /selected
}

# https://www.w3.org/TR/webdriver/#get-element-attribute
WebElement_attribute() {
  WebDriver__get "$1" /attribute/"$2"
}

# https://www.w3.org/TR/webdriver/#get-element-property
WebElement_property() {
  WebDriver__get "$1" /property/"$2"
}

# https://www.w3.org/TR/webdriver/#get-element-css-value
WebElement_css_value() {
  WebDriver__get "$1" /css/"$2"
}

# https://www.w3.org/TR/webdriver/#get-element-text
WebElement_text() {
  WebDriver__get "$1" /text
}

# https://www.w3.org/TR/webdriver/#get-element-tag-name
WebElement_tag_name() {
  WebDriver__get "$1" /name
}

# https://www.w3.org/TR/webdriver/#get-element-rect
WebElement_rect() {
  WebDriver__get "$1" /rect | WebDriver ::to_rect "${2:-}"
}

WebElement_location() {
  case ${2:-} in ('' | x | y)
    set -- "$(WebElement_rect "$@")"
    echo "${1% * *}"
  esac
}

WebElement_size() {
  case ${2:-} in ('' | width | height)
    set -- "$(WebElement_rect "$@")"
    echo "${1#* * }"
  esac
}

# https://www.w3.org/TR/webdriver/#is-element-enabled
WebElement_enabled() {
  WebDriver__get "$1" /enabled
}

# https://www.w3.org/TR/webdriver/#get-computed-role
WebElement_aria_role() {
  WebDriver__get "$1" /computedrole
}

# https://www.w3.org/TR/webdriver/#get-computed-label
WebElement_accessible_name() {
  WebDriver__get "$1" /computedlabel
}

# ----------------------------------------
# WebElement: Elements Interaction
# ----------------------------------------

# https://www.w3.org/TR/webdriver/#element-click
WebElement_click() {
  WebDriver__post "$1" /click
}

# https://www.w3.org/TR/webdriver/#element-clear
WebElement_clear() {
  WebDriver__post "$1" /clear
}

# https://www.w3.org/TR/webdriver/#element-send-keys
WebElement_send_keys() {
  set -- "$1" "$(shift; WebDriver ::build_text "$@")"
  WebDriver__post "$1" /value '{"text":"%s"}' "$2"
}

WebElement_submit() {
  # See https://github.com/SeleniumHQ/selenium/blob/selenium-4.0.0-beta-2/rb/lib/selenium/webdriver/remote/bridge.rb#L433
  TODO
}

# ----------------------------------------
# WebElement: Elements Retrieval
# ----------------------------------------

# https://www.w3.org/TR/webdriver/#find-element-from-element
WebElement_find_element() {
  set -- "$1" "${2%%:*}" "${2#*:}" "$WEBDRIVER_SH_WEB_ELEMENT_KEY" "$@"
  WebDriver__post "$1" /element '{"using":"%s", "value":"%s"}' "$2" "$3" | (
    id=$(jq --arg base "${1%/*/*}/element/" --arg key "$4" -r '$base + .[$key]')
    [ "$id" ] || return $?
    [ $# -le 6 ] && echo "$id" && return 0
    method=$7 && shift 7 && "WebElement_$method" "$id" "$@"
  )
}

# https://www.w3.org/TR/webdriver/#find-elements-from-element
WebElement_find_elements() {
  set -- "$1" "${2%%:*}" "${2#*:}" "$WEBDRIVER_SH_WEB_ELEMENT_KEY"
  WebDriver__post "$1" /elements '{"using":"%s", "value":"%s"}' "$2" "$3" | {
    jq --arg base "${1%/*/*}/element/" --arg key "$4" -r '$base + .[][$key]'
  }
}

# ----------------------------------------
# WebElement: Elements Screen capture
# ----------------------------------------

# https://www.w3.org/TR/webdriver/#take-element-screenshot
WebElement_take_screenshot() {
  WebDriver__get "$1" /screenshot
}

WebElement_save_screenshot() {
  WebElement_take_screenshot "$1" | WebDriver ::as "png" > "$2"
}

WebElement_screenshot_as() {
  WebElement_take_screenshot "$1" | WebDriver ::as "$2"
}

# ========================================
# WebShadow
# ========================================

# ----------------------------------------
# WebShadow: Elements Retrieval
# ----------------------------------------

# [Draft] https://w3c.github.io/webdriver/#find-element-from-shadow-root
# [Draft] https://w3c.github.io/webdriver/#find-elements-from-shadow-root
