#!/bin/bash
sed -i -e '/^[;\s]*open_basedir\s*=/d' -e '$ a open_basedir = "/usr/share/roundcubemail/:/var/lib/roundcube/:/tmp/"' /etc/php.ini
