#!/bin/bash
sed -i -e '/^[;\s]*allow_url_fopen\s*=/d' -e '/^[;\s]*allow_url_include\s*=/d' -e '$ a allow_url_fopen = Off\nallow_url_include = Off' /etc/php.ini
