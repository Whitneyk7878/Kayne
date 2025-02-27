#!/usr/bin/env bash
#
# disable_php_functions.sh
#
# This script disables a set of dangerous PHP functions in /etc/php.ini.
# It also backs up the original php.ini file.
#
# Usage: sudo ./disable_php_functions.sh

# Must run as root (or via sudo)
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root (or via sudo). Exiting."
  exit 1
fi

PHP_INI="/etc/php.ini"
PHP_INI_BAK="/etc/php.ini.bak-$(date +%F-%T)"

# The list of functions to disable. Adjust as needed.
DISABLED_FUNCTIONS="exec,shell_exec,system,passthru,popen,proc_open,phpinfo,eval"

# 1) Check that /etc/php.ini exists
if [[ ! -f "$PHP_INI" ]]; then
  echo "ERROR: $PHP_INI not found. Please confirm your php.ini location."
  exit 1
fi

