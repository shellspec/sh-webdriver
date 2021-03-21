# Selenium/WebDriver bindings for shell script

NOTE: This project is released as part of the [ShellSpec](https://github.com/shellspec/shellspec) project,
but for now it is not related and can be used independently.

----

**Project Status**: Preview Release v0.1.0

This project is in the early stages of development. There are unimplemented features and
it has not been fully tested. Incompatible changes may be made.
**Bug reports and pull requests are welcome!**

Documentation for library is not yet available,
see [webdriver.sh](https://github.com/shellspec/sh-webdriver/blob/main/lib/webdriver.sh).

[WebDriver API Support Status](docs/status.md)

----

## Quick start

```sh
#!/bin/sh
set -eu

. ./lib/webdriver.sh

chrome_options() {
  echo '{ "args": [] }'
  # echo '{ "args": ["--headless"] }'
}

# You need to run the `chromedriver` beforehand
WebDriver driver="$(ChromeDriver chrome_options "http://localhost:9515")"
driver get "https://www.google.com"

WebElement element="$(driver find_element "css selector:[name=q]")"
element send_keys "WebDriver" :enter

# **Shorthand**
# driver find_element "css selector:[name=q]" send_keys "WebDriver" :enter

for element_id in $(driver find_elements "css selector:a"); do
  WebElement element="$element_id"
  element attribute "text"
done

driver quit
unset -f element driver
```

## Requirements

- POSIX shell (`dash`, `bash`, `ksh`, `zsh`, etc.)
- `curl`, `jq`, `base64`
- WebDriver

| WebDriver                                                                                | Version                |
| ---------------------------------------------------------------------------------------- | ---------------------- |
| [Google Chrome Driver](https://chromedriver.chromium.org/downloads)                      | Tested on 89.0.4389.23 |
| [Mozilla GeckoDriver](https://github.com/mozilla/geckodriver)                            | Not yet tested         |
| [Microsoft Edge Driver](https://developer.microsoft.com/microsoft-edge/tools/webdriver/) | Not yet tested         |
| [Opera](https://github.com/operasoftware/operachromiumdriver)                            | Not yet tested         |
| [IEDriver](https://github.com/SeleniumHQ/selenium/wiki/InternetExplorerDriver)           | Not yet tested         |
| SafariDriver (Builtin)                                                                   | Not yet tested         |

## Environment variables

- `WEBDRIVER_SH_DEBUG` - If set, outputs HTTP logs.

## TODO

- WebDriver API
  - Actions
  - Print
  - HTTP Proxy
  - Shadow root
  - Bidi API, DevTools (Support for WebSocket is required. Feasible?)
- Additional Functions
  - Select
  - Conditional Waits
  - Events
  - Some useful functions
  - High level API (?)
- Documentation
  - References
  - Page object models for shell script

## License

MIT License