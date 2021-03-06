venison_plus_apache_for_centos
==============================

A modification of Venison that adds Apache (for all you .htaccess fiends). It is an adaption of the Venison deploy script written by TJ Stein:

https://github.com/tjstein/venison

His script has been modified to operate on CentOS, and adds some extra features as well. 

Overview
============================
This script requires CentOS 6. It installs and configures the required OS packages and the MySQL/Nginx/Apache/PHP-FPM/Postfix deployment stack for WordPress. You can choose between MySQL, Percona, and MariaDB. All packages are installed through yum for future upgrade ease, except for Nginx. The build of Nginx utilized requires third-party modules (discussed below). As a result, it needs to be compiled. 

NOTE: The script disables SSH root login, sets up a sudo user, and optionally changes the SSH port for server security. When you run the setup script, you will be prompted for these values. It is HIGHLY RECOMMENDED that you change your SSH port to something unique, although fail2ban is active upon deployment. 

IMPORTANT: You MUST be root when installing or running venisonctl.
Installation
============================

Installing with git:

1. git clone https://github.com/mrname/venison_plus_apache_for_centos.git
2. Enter setup directory:
        - cd venison_plus_apache_for_centos
3. sh setup.sh
4. Let it run
5. Enjoy the goodness, and tune as necessary!

Install Manually:

1. Login to the server via ssh, download the script files from the GitHub repo as a zip file, and unzip:
   wget https://github.com/mrname/venison_plus_apache_for_centos/archive/master.zip && unzip master.zip
2. Enter setup directory:
	- cd venison_for_centos
3. sh setup.sh
4. Let it run
5. Enjoy the goodness, and tune as necessary!


Managing Domains And Services
============================

Venison comes with a built-in control script. You can run the command 'venisonctl' from any directory to initiate the control script. Your user will need to have /usr/local/sbin in their path for this to work.


Notes
============================
DO NOT LOG OUT of your root session. Once the script has completed, the root user can no longer SSH into the server. You need to use the login for the `sudo_user` you setup in the script variables. So, start a new SSH session and try to login using the account of the `sudo_user`. Once you have confirmed you can login successfully, you can close the root session.

This adaptation of Venison includes the following new features:

- Google Pagespeed Module For Nginx
      https://developers.google.com/speed/pagespeed/ngx
- Cache Purge Module For Nginx
      https://github.com/perusio/nginx-cache-purge
- Headers More Module For Nginx
      http://wiki.nginx.org/HttpHeadersMoreModule
- Fail2Ban - AutoBanning Software To Prevent Brute Force Attacks
      http://www.fail2ban.org/wiki/index.php/Main_Page

All Nginx modules are active on the inital WordPress deployment, and fail2Ban is immediately active, blocking the SSH port only. Fail2Ban has a preset jail for DDOS protection which can be activated in the 'jail.conf' file. The WordPress install comes with the Nginx Helper plugin, which automatically purges the Nginx cache when content is updated. Although the plugin is active, it needs to have cache purging turned on, and settings configured. PageSpeed is using default settings. Depending on your website, you might need to change these. This can be changed in the 'pagespeed.conf' file in the document root of your website, at the same level as the 'public' directory. Consult the PageSpeed documentation for more info.

This build also adds Apache to the stack, which is running mod_fastcgi to connect to php-fpm. When you add domains, individual php-fpm pools will be created if you are running the site under a new user. This adds a higher level of customization and security, but it also means that your php-fpm pools will need to be properly tuned depending on the number of sites running under that user.

License
============================
Copyright (c) 2013 by TJ Stein / Justin Crown

This program is free software: you can redistribute it and/or modify it under the terms of the MIT License.

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
