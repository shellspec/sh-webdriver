#!/bin/sh

set -eu

. ./lib/webdriver.sh

chrome_options() {
  echo '{ "args": [] }'
  # echo '{ "args": ["--headless"] }'
}

WebDriver driver="$(ChromeDriver chrome_options "http://localhost:9515")"
driver get "https://www.google.com"

WebElement element="$(driver find_element "css selector:[name=q]")"
element send_keys "WebDriver" :enter

# **Shorthand**
# driver find_element 'css selector:[name=q]' send_keys "WebDriver" :enter

for element_id in $(driver find_elements "css selector:a"); do
  WebElement element="$element_id"
  element attribute "text"
done

sleep 3

driver quit
unset -f element driver
