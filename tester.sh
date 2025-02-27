#!/bin/bash
sudo sed -i '/^\s*disable_functions\s*=/d' /etc/php.ini && sudo sh -c 'echo "disable_functions = exec,shell_exec,system,passthru,popen,proc_open,phpinfo,eval" >> /etc/php.ini'
