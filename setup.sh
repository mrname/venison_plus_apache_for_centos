#!/bin/bash

#CONSTANTS

#Define Variables For Apache Tuning
if [ $(free -m | awk 'NR==4 { print $2 }') == 0 ]
   then
       version='40'
       ramCount=`awk 'match($0,/vmguar/) {print $4}' /proc/user_beancounters`
   else
       version='45'
       ramCount=`awk 'match($0,/oomguar/) {print $4}' /proc/user_beancounters`
fi
ramBase=-16 && for ((;ramCount>1;ramBase++)); do ramCount=$((ramCount/2)); done

#FUNCTIONS

tune_apache()
{

#Adjust Prefork Settings
perl -0 -p -i -e 's/(\<IfModule\sprefork\.c\>(\n|[^\n])*?StartServers\s*?)\s\d+/\1\ '"$ramBase"'/;' \
-e 's/(\<IfModule\sprefork\.c\>(\n|[^\n])*?MinSpareServers\s*?)\s\d+/\1\ '"$ramBase"'/;' \
-e 's/(\<IfModule\sprefork\.c\>(\n|[^\n])*?MaxSpareServers\s*?)\s\d+/\1\ '"$(($ramBase*2 + 1))"'/;' \
-e 's/(\<IfModule\sprefork\.c\>(\n|[^\n])*?ServerLimit\s*?)\s\d+/\1\ '"$(( 50 + (($ramBase**2)*10) + (($ramBase-2)*10) ))"'/;' \
-e 's/(\<IfModule\sprefork\.c\>(\n|[^\n])*?MaxClients\s*?)\s\d+/\1\ '"$(( 50 + (($ramBase**2)*10) + (($ramBase-2)*10) ))"'/;' \
-e 's/(\<IfModule\sprefork\.c\>(\n|[^\n])*?MaxRequestsPerChild\s*?)\s\d+/\1\ '"$(( 2048 + ($ramBase*256) ))"'/;' /etc/httpd/conf/httpd.conf 

#Disable Additional Modules
perl -0 -p -i \
-e 's/\#?(LoadModule\ authn_alias_module\ modules\/mod_authn_alias\.so)/#\1/;' \
-e 's/\#?(LoadModule\ authn_anon_module\ modules\/mod_authn_anon\.so)/#\1/;' \
-e 's/\#?(LoadModule\ authn_dbm_module\ modules\/mod_authn_dbm\.so)/#\1/;' \
-e 's/\#?(LoadModule\ authnz_ldap_module\ modules\/mod_authnz_ldap\.so)/#\1/;' \
-e 's/\#?(LoadModule\ authz_dbm_module\ modules\/mod_authz_dbm\.so)/#\1/;' \
-e 's/\#?(LoadModule\ authz_owner_module\ modules\/mod_authz_owner\.so)/#\1/;' \
-e 's/\#?(LoadModule\ cache_module\ modules\/mod_cache\.so)/#\1/;' \
-e 's/\#?(LoadModule\ dav_module\ modules\/mod_dav\.so)/#\1/;' \
-e 's/\#?(LoadModule\ dav_fs_module\ modules\/mod_dav_fs\.so)/#\1/;' \
-e 's/\#?(LoadModule\ disk_cache_module\ modules\/mod_disk_cache\.so)/#\1/;' \
-e 's/\#?(LoadModule\ ext_filter_module\ modules\/mod_ext_filter\.so)/#\1/;' \
-e 's/\#?(LoadModule\ file_cache_module\ modules\/mod_file_cache\.so)/#\1/;' \
-e 's/\#?(LoadModule\ info_module\ modules\/mod_info\.so)/#\1/;' \
-e 's/\#?(LoadModule\ ldap_module\ modules\/mod_ldap\.so)/#\1/;' \
-e 's/\#?(LoadModule\ mem_cache_module\ modules\/mod_mem_cache\.so)/#\1/;' \
-e 's/\#?(LoadModule\ status_module\ modules\/mod_status\.so)/#\1/;' \
-e 's/\#?(LoadModule\ speling_module\ modules\/mod_speling\.so)/#\1/;' \
-e 's/\#?(LoadModule\ usertrack_module\ modules\/mod_usertrack\.so)/#\1/;' \
-e 's/\#?(LoadModule\ version_module\ modules\/mod_version\.so)/#\1/;' /etc/httpd/conf/httpd.conf


}

get_vars()
{
#Prompt For User Variables
echo "Welcome To Venison For CentOS!!!!"
echo ""
echo -n "Enter The Hostname Of Your Website: "
read hostname
echo -n "Enter The Name Of Your Sudo User: "
read sudo_user
while true; do
    echo -n "Enter The Password For Your Sudo User: "
    read -s sudo_user_passwd
    echo ""
    echo -n "Confirm Sudo User Password: "
    read -s sudo_user_passwd_confirm
    echo ""
    passwd_check $sudo_user_passwd $sudo_user_passwd_confirm
    done
while true; do
    echo -n "Enter Your New ROOT Password: "
    read -s root_passwd
    echo ""
    echo -n "Confirm Your New ROOT Password: "
    read -s root_passwd_confirm
    echo ""
    passwd_check $root_passwd $root_passwd_confirm
    done
echo -n "Enter Your Desired SSH Port: "
read ssh_port
echo -n "Choose Your Database Server (mysql,percona,mariadb): "
read db_choice
echo -n "Enter The Title Of Your Website: "
read wptitle
echo -n "Enter Your WordPress Admin Username: "
read wpuser
while true; do
    echo -n "Enter Your WordPress Admin Password: "
    read -s wppass
    echo ""
    echo -n "Confirm Your WordPress Admin Password: "
    read -s wppass_confirm
    echo ""
    passwd_check $wppass $wppass_confirm
    done
echo -n "Enter Your WordPress Admin Email Address: "
read wpemail
}

passwd_check()
{
   if [ "$1" != "$2" ]
      then
        echo "Passwords Do Not Match...."
   else
        break
   fi
}

os_check()
{
  if ! [ "$(cat /etc/redhat-release | egrep '(^CentOS.*6.*)')" ]; then
  echo "You need to be running CentOS 6.x"
    exit
  fi
}

set_locale()
{
  echo -n "Setting up system locale... "
  { locale-gen en_US.UTF-8
    unset LANG
    /usr/sbin/update-locale LANG=en_US.UTF-8
  } > /dev/null 2>&1
  export LANG=en_US.UTF-8
  echo "done."
}  

set_timezone()
{
  mv /etc/localtime /etc/localtime.bak
  ln -s /usr/share/zoneinfo/America/Los_Angeles /etc/localtime 
}

change_root_passwd()
{
  if [ -n "$root_passwd" ]
  then
    echo -n "Changing root password... "
    echo "$root_passwd\n$root_passwd" > tmp/rootpass.$$
    passwd root < tmp/rootpass.$$ > /dev/null 2>&1
    echo "done."
  fi
}

create_sudo_user()
{
  if [ -n "$sudo_user" -a -n "$sudo_user_passwd" ]
  then
    id $sudo_user > /dev/null 2>&1 && echo "Cannot create sudo user! User $sudo_user already exists!" && touch tmp/sudofailed.$$ && return
    echo -n "Creating sudo user... "
    useradd -d /home/$sudo_user -s /bin/bash -m $sudo_user
    echo "$sudo_user:$sudo_user_passwd" | chpasswd
    echo "$sudo_user ALL=(ALL) ALL" >> /etc/sudoers
    { echo 'export PS1="\[\e[32;1m\]\u\[\e[0m\]\[\e[32m\]@\h\[\e[36m\]\w \[\e[33m\]\$ \[\e[0m\]"'
    } >> /home/$sudo_user/.bashrc
    echo "done."
  fi
}

config_ssh()
{
  conf='/etc/ssh/sshd_config'
  echo -n "Configuring SSH... "
  mkdir ~/.ssh && chmod 700 ~/.ssh/
  cp /etc/ssh/sshd_config /etc/ssh/sshd_config.`date "+%Y-%m-%d"`
  sed -i -r 's/\s*X11Forwarding\s+yes/X11Forwarding no/g' $conf
  sed -i -r 's/\s*UsePAM\s+yes/UsePAM no/g' $conf
  sed -i -r 's/\s*UseDNS\s+yes/UseDNS no/g' $conf
  perl -p -i -e 's|LogLevel INFO|LogLevel VERBOSE|g;' $conf
  grep -q "UsePAM no" $conf || echo "UsePAM no" >> $conf
  grep -q "UseDNS no" $conf || echo "UseDNS no" >> $conf
  if [ -n "$ssh_port" ]
  then
    sed -i "s/#Port 22/Port $ssh_port/g" $conf
    cp files/iptables.up.rules tmp/fw.$$
    sed -i -r "s/\s+22\s+/ $ssh_port /" tmp/fw.$$
  fi
  if id $sudo_user > /dev/null 2>&1 && [ ! -e tmp/sudofailed.$$ ]
  then
    sed -i -r 's/\s*PermitRootLogin\s+yes/PermitRootLogin no/g' $conf
    echo "AllowUsers $sudo_user" >> $conf
  fi
  echo "done."
}

setup_firewall()
{
  echo -n "Setting up firewall... "
  cp tmp/fw.$$ /etc/iptables.up.rules
  iptables -F
  iptables-restore < /etc/iptables.up.rules > /dev/null 2>&1 &&
  /sbin/service iptables save > /dev/null 2>&1
  /etc/init.d/ssh reload > /dev/null 2>&1
  echo "done."
}

setup_tmpdir()
{
  echo -n "Setting up temporary directory... "
  mkdir ~/tmp && chmod 777 ~/tmp
  mount --bind ~/tmp /tmp
  echo "done."
}

function init_repos {
#Add EPEL And Remi Repo
cd ./tmp
wget http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm > /dev/null 2>&1
wget http://rpms.famillecollet.com/enterprise/remi-release-6.rpm > /dev/null 2>&1
rpm -Uvh remi-release-6*.rpm epel-release-6*.rpm > /dev/null 2>&1
cd ..

#Enable Remi Repo
sed -i '/\[remi\]/,/^ *\[/ s/enabled=0/enabled=1/' /etc/yum.repos.d/remi.repo

#Enable Debug Packages
sed -i 's/enabled=0/enabled=1/g' /etc/yum.repos.d/CentOS-Debuginfo.repo
sed -i '/\[epel-debuginfo\]/,/^ *\[/ s/enabled=0/enabled=1/' /etc/yum.repos.d/epel.repo
sed -i '/\[remi-debuginfo\]/,/^ *\[/ s/enabled=0/enabled=1/' /etc/yum.repos.d/remi.repo

}

install_base()
{
  init_repos
  echo -n "Setting up base packages... "
  yum -y upgrade > /dev/null 2>&1
  yum -y groupinstall "Development Tools" > /dev/null 2>&1
  yum -y install zlib-devel pcre-devel openssl-devel geoip geoip-devel expect git-core htop yum-utils > /dev/null 2>&1
  
  #Install Debug Packages For Apache Backtrace
  debuginfo-install httpd php php-fpm Percona-Server-55-debuginfo curl-debuginfo cyrus-sasl-debuginfo freetype-debuginfo gcc-debuginfo keyutils-debuginfo libX11-debuginfo libXau-debuginfo libXpm-debuginfo libgcrypt-debuginfo libgpg-error-debuginfo libjpeg-turbo-debuginfo libmcrypt-debuginfo libpng-debuginfo libssh2-debuginfo libxcb-debuginfo libxslt-debuginfo nspr-debuginfo nss-debuginfo nss-softokn-debuginfo nss-util-debuginfo php-pecl-apc-debuginfo readline-debuginfo t1lib-debuginfo util-linux-ng-debuginfo 
  echo "done."
}

install_apache() {
echo -n "Installing Apache... "
chmod o+x /home/$sudo_user
yum -y install httpd httpd-devel
mkdir /etc/httpd/sites-available
mkdir /etc/httpd/sites-enabled
cp /etc/httpd/conf/httpd.conf /etc/httpd/conf/httpd.conf.`date "+%Y-%m-%d"`
echo 'Include sites-enabled/*.conf' >> /etc/httpd/conf/httpd.conf
sed -i 's/Listen 80/Listen 7080/g' /etc/httpd/conf/httpd.conf
sed -i 's/#NameVirtualHost \*:80/NameVirtualHost \*:7080/g' /etc/httpd/conf/httpd.conf
sed -i 's/DirectoryIndex index.html index.html.var/DirectoryIndex index.html index.html.var index.shtml index.cfm index.php index.htm/g' /etc/httpd/conf/httpd.conf
cp files/mydomain.com_httpd /etc/httpd/sites-available/$hostname.conf
sed -i -r "s/mydomain.com/$hostname/g" /etc/httpd/sites-available/$hostname.conf
sed -i -r "s/sudoer/$sudo_user/g" /etc/httpd/sites-available/$hostname.conf
ln -s -v /etc/httpd/sites-available/$hostname.conf /etc/httpd/sites-enabled/001-$hostname.conf > /dev/null 2>&1

#Allow Core Dumps
sed -i '/# Source function library/i \ulimit -c unlimited' /etc/init.d/httpd
echo 'CoreDumpDirectory /tmp' >> /etc/httpd/conf/httpd.conf
}

install_php()
{
  echo -n "Installing PHP... "
  mkdir -p /var/www
  yum -y install php php-common php-cli php-pear php-pdo php-mysql php-gd php-mbstring php-mcrypt php-xml php-apc php-fpm > /dev/null 2>&1 
  cp /etc/php.ini /etc/php.ini.`date "+%Y-%m-%d"`
  perl -p -i -e 's|;date.timezone =|date.timezone = America/Los_Angeles|g;' /etc/php.ini
  perl -p -i -e 's|expose_php = On|expose_php = Off|g;' /etc/php.ini
  perl -p -i -e 's|allow_url_fopen = On|allow_url_fopen = Off|g;' /etc/php.ini
  perl -p -i -e 's|;cgi.fix_pathinfo=1|cgi.fix_pathinfo=0|g;' /etc/php.ini
  perl -p -i -e 's|;realpath_cache_size = 16k|realpath_cache_size = 128k|g;' /etc/php.ini
  perl -p -i -e 's|;realpath_cache_ttl = 120|realpath_cache_ttl = 600|g;' /etc/php.ini
  perl -p -i -e 's|upload_max_filesize = 2M|upload_max_filesize = 10M|g;' /etc/php.ini
  perl -p -i -e 's|disable_functions =|disable_functions = "system,exec,shell_exec,passthru,escapeshellcmd,popen,pcntl_exec"|g;' /etc/php.ini

  cp /etc/php-fpm.d/www.conf /etc/php-fpm.d/www.conf.default
  mv /etc/php-fpm.d/www.conf /etc/php-fpm.d/$sudo_user.conf
  sed -i "s/\[www\]/\[$sudo_user\]/g" /etc/php-fpm.d/$sudo_user.conf
  sed -i "s%listen = 127.0.0.1:9000%listen = /var/run/php5-fpm.$sudo_user.sock%g" /etc/php-fpm.d/$sudo_user.conf
  sed -i "s%user = apache%user = $sudo_user%g" /etc/php-fpm.d/$sudo_user.conf
  perl -p -i -e 's|;pm.status_path = /status|pm.status_path = /status|g;' /etc/php-fpm.d/$sudo_user.conf
  perl -p -i -e 's|;request_slowlog_timeout = 0|request_slowlog_timeout = 5s|g;' /etc/php-fpm.d/$sudo_user.conf
  sed -i 's/pm.max_children = 50/pm.max_children = 70/g' /etc/php-fpm.d/$sudo_user.conf
  sed -i 's/pm.start_servers = 5/pm.start_servers = 8/g' /etc/php-fpm.d/$sudo_user.conf
  sed -i 's/pm.max_spare_servers = 35/pm.max_spare_servers = 10/g' /etc/php-fpm.d/$sudo_user.conf
    
  echo "done."
}

install_fastcgi()
{
cd ./tmp
wget http://www.fastcgi.com/dist/mod_fastcgi-current.tar.gz
tar xvfz mod_fastcgi-current.tar.gz
cd mod_fastcgi-2*
cp Makefile.AP2 Makefile
sed -i 's%/usr/local/apache2%/etc/httpd%g' Makefile
sed -i 's%top_srcdir   = ${top_dir}%top_srcdir   = /usr/sbin%g' Makefile
sed -i 's%top_builddir = ${top_dir}%top_builddir = /usr/lib64/httpd%g' Makefile
make && make install
sed -i '/LoadModule version_module modules\/mod_version.so/ a\LoadModule fastcgi_module modules/mod_fastcgi.so' /etc/httpd/conf/httpd.conf
mv /etc/httpd/conf.d/php.conf /etc/httpd/conf.d/php.conf.disabled
cd ../../
}

install_maria()
{
  #Add MariaDB Repo
cat <<EOF > /etc/yum.repos.d/mariadb.repo
# MariaDB 5.5 CentOS repository list - created 2013-05-15 02:49 UTC
# http://mariadb.org/mariadb/repositories/
[mariadb]
name = MariaDB
baseurl = http://yum.mariadb.org/5.5/centos6-amd64
gpgkey=https://yum.mariadb.org/RPM-GPG-KEY-MariaDB
gpgcheck=1
EOF


  echo -n "Installing MariaDBL... "
  MYSQL_PASS=`echo $(</dev/urandom tr -dc A-Za-z0-9 | head -c 15)`
  yum -y install MariaDB-server MariaDB-client MariaDB-shared > /dev/null 2>&1
  mv /etc/my.cnf.d/server.cnf /etc/my.cnf.d/server.cnf.`date "+%Y-%m-%d"`
  cp files/server.cnf /etc/my.cnf.d/server.cnf
  touch /var/lib/mysql/mysql-slow.log
  chown mysql:mysql /var/lib/mysql/mysql-slow.log
  /etc/init.d/mysql start > /dev/null 2>&1
  echo "done."
}

install_percona()
{
echo -n "Installing Percona....."
rpm -Uhv http://www.percona.com/downloads/percona-release/percona-release-0.0-1.x86_64.rpm > /dev/null 2>&1
yum -y install Percona-Server-client-55 Percona-Server-server-55 > /dev/null 2>&1
mv /etc/my.cnf /etc/my.cnf.`date "+%Y-%m-%d"`
  cp files/my.cnf /etc/my.cnf
  touch /var/lib/mysql/mysql-slow.log
  chown mysql:mysql /var/lib/mysql/mysql-slow.log
  /etc/init.d/mysql start 
  echo "done."

}

install_mysql()
{
echo -n "Installing MySQL......"
yum -y install mysql-server mysql-client > /dev/null 2>&1
mv /etc/my.cnf /etc/my.cnf.`date "+%Y-%m-%d"`
  cp files/my.cnf /etc/my.cnf
  touch /var/lib/mysql/mysql-slow.log
  chown mysql:mysql /var/lib/mysql/mysql-slow.log
  /etc/init.d/mysqld start > /dev/null 2>&1 
  echo "done."
}

install_db_server()
{
if [ "$db_choice" == "percona" ]
   then
   install_percona
elif [ "$db_choice" == "mariadb" ]
   then
   install_maria
else
   install_mysql
fi
}

secure_mysql()
{
MYSQL_PASS=`echo $(</dev/urandom tr -dc A-Za-z0-9 | head -c 15)`
/usr/bin/mysql_secure_installation << EOF >/dev/null 2>&1

y
$MYSQL_PASS
$MYSQL_PASS
y
y
y
y
EOF
}

config_db()
{
  echo -n "Setting up WordPress database... "
  WP_DB=`echo $(</dev/urandom tr -dc A-Za-z0-9 | head -c 15)`
  WP_USER=`echo $(</dev/urandom tr -dc A-Za-z0-9 | head -c 15)`
  WP_USER_PASS=`echo $(</dev/urandom tr -dc A-Za-z0-9 | head -c 15)`
  mysql -e "CREATE DATABASE $WP_DB"
  mysql -e "GRANT ALL PRIVILEGES ON $WP_DB.* to $WP_USER@localhost IDENTIFIED BY '$WP_USER_PASS'"
  mysql -e "FLUSH PRIVILEGES"
  echo "done."
}

config_nginx()
{
  echo -n "Setting up Nginx... "
  cd tmp 

  #Get Nginx
  wget http://nginx.org/download/nginx-1.4.1.tar.gz > /dev/null 2>&1
  tar xvfz nginx-1.4.1.tar.gz > /dev/null 2>&1

  #GET MODULES
  #Get Cache Purge Module
  wget http://labs.frickle.com/files/ngx_cache_purge-2.1.tar.gz > /dev/null 2>&1
  tar xfz ngx_cache_purge-2.1.tar.gz > /dev/null 2>&1
  #Get Headers More Module
  wget -O headers.zip https://github.com/agentzh/headers-more-nginx-module/archive/master.zip > /dev/null 2>&1
  unzip headers.zip > /dev/null 2>&1
  #Get PageSpeed Module
  #wget https://github.com/pagespeed/ngx_pagespeed/archive/release-1.5.27.2-beta.zip > /dev/null 2>&1
  wget -O pagespeed.zip https://github.com/pagespeed/ngx_pagespeed/archive/master.zip > /dev/null 2>&1
  unzip pagespeed.zip > /dev/null 2>&1
  cd ngx_pagespeed-master
  wget https://dl.google.com/dl/page-speed/psol/1.6.29.5.tar.gz > /dev/null 2>&1
  tar -xzvf 1.6.29.5.tar.gz > /dev/null 2>&1
  cd ..

  #Configure Nginx
  cd nginx-1.4.1
  ./configure --prefix=/etc/nginx --sbin-path=/usr/sbin --with-http_stub_status_module --with-http_realip_module --with-http_gzip_static_module --with-http_flv_module --with-http_geoip_module --with-http_mp4_module --with-http_ssl_module --add-module=../headers-more-nginx-module-master --add-module=../ngx_pagespeed-master --add-module=../ngx_cache_purge-2.1 > /dev/null 2>&1 
  make > /dev/null 2>&1
  make install > /dev/null 2>&1
  cd ../../
  mkdir -p /etc/nginx/ngx_pagespeed_cache && chown $sudo_user:$sudo_user /etc/nginx/ngx_pagespeed_cache
  cp files/nginx /etc/init.d/nginx
  chmod 755 /etc/init.d/nginx
  cp /etc/nginx/conf/nginx.conf /etc/nginx/conf/nginx.conf.`date "+%Y-%m-%d"`
  rm -rf /etc/nginx/conf/nginx.conf /etc/nginx/nginx.conf
  cp files/nginx.conf /etc/nginx/conf/nginx.conf
  /bin/mkdir -p ~/.vim/syntax/
  cp files/nginx.vim ~/.vim/syntax/nginx.vim
  touch ~/.vim/filetype.vim
  echo "au BufRead,BufNewFile /etc/nginx/* set ft=nginx" >> ~/.vim/filetype.vim
  mkdir -p /etc/nginx/sites-available/
  mkdir -p /etc/nginx/sites-enabled/
  mkdir /var/log/nginx
  chown $sudo_user:$sudo_user /var/log/nginx
  cp files/mydomain.com /etc/nginx/sites-available/$hostname.conf
  #rm -rf /etc/nginx/fastcgi_params /etc/nginx/conf/fastcgi_params
  cp files/proxy_params /etc/nginx/conf/proxy_params
  cp files/proxy_cache /etc/nginx/conf/proxy_cache
  cp files/proxy_cache_rules /etc/nginx/conf/proxy_cache_rules
  sed -i -r "s/sudoer/$sudo_user/g" /etc/nginx/conf/nginx.conf
  sed -i -r "s/mydomain.com/$hostname/g" /etc/nginx/sites-available/$hostname.conf
  sed -i -r "s/sudoer/$sudo_user/g" /etc/nginx/sites-available/$hostname.conf
  ln -s -v /etc/nginx/sites-available/$hostname.conf /etc/nginx/sites-enabled/001-$hostname.conf > /dev/null 2>&1
  rm -rf /var/www/nginx-default
  /etc/init.d/nginx restart > /dev/null 2>&1
  echo "done."
}

install_postfix()
{
  echo -n "Setting up Postfix... "
  #echo "postfix postfix/mailname string $hostname" | debconf-set-selections
  #echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
  yum -y install postfix > /dev/null 2>&1
  /usr/sbin/postconf -e "inet_interfaces = loopback-only"
  service postfix restart > /dev/null 2>&1
  echo "done."
}

configure_wp()
{
  echo -n "Setting up WordPress... "
  DB_PREFIX=`echo $(</dev/urandom tr -dc A-Za-z0-9 | head -c 7)`
  mkdir -p /home/$sudo_user/$hostname/public/
  touch /home/$sudo_user/$hostname/pagespeed.conf
  wget -q -o ~/install.log -O /home/$sudo_user/$hostname/public/latest.zip http://wordpress.org/latest.zip
  unzip /home/$sudo_user/$hostname/public/latest.zip -d /home/$sudo_user/$hostname/public/ >> ~/install.log
  mv /home/$sudo_user/$hostname/public/wordpress/* /home/$sudo_user/$hostname/public/
  rm -rf /home/$sudo_user/$hostname/public/wordpress
  rm -rf /home/$sudo_user/$hostname/public/latest.zip
  perl -p -i -e "s|database_name_here|$WP_DB|;" /home/$sudo_user/$hostname/public/wp-config-sample.php
  perl -p -i -e "s|username_here|$WP_USER|;" /home/$sudo_user/$hostname/public/wp-config-sample.php
  perl -p -i -e "s|password_here|$WP_USER_PASS|;" /home/$sudo_user/$hostname/public/wp-config-sample.php
  perl -p -i -e "s|\$table_prefix  = 'wp_';|\$table_prefix  = '$DB_PREFIX';|;" /home/$sudo_user/$hostname/public/wp-config-sample.php
  mv /home/$sudo_user/$hostname/public/wp-config-sample.php /home/$sudo_user/$hostname/public/wp-config.php
  wget -O /tmp/wp.keys https://api.wordpress.org/secret-key/1.1/salt/ > /dev/null 2>&1
  sed -i '/#@-/r /tmp/wp.keys' /home/$sudo_user/$hostname/public/wp-config.php
  sed -i "/#@+/,/#@-/d" /home/$sudo_user/$hostname/public/wp-config.php
  rm -rf /home/$sudo_user/$hostname/public/license.txt && rm -rf /home/$sudo_user/$hostname/public/readme.html
  rm -rf /tmp/wp.keys
  #curl -d "weblog_title=$wptitle&user_name=$wpuser&admin_password=$wppass&admin_password2=$wppass&admin_email=$wpemail" http://$hostname/wp-admin/install.php?step=2 >/dev/null 2>&1
  mv /home/$sudo_user/$hostname/public/wp-config.php /home/$sudo_user/$hostname/wp-config.php
  sed -i 's/'"$(printf '\015')"'$//g' /home/$sudo_user/$hostname/wp-config.php
  chmod 400 /home/$sudo_user/$hostname/wp-config.php
    rm -rf /home/$sudo_user/$hostname/public/wp-admin/install.php
  cp files/install.php /home/$sudo_user/$hostname/public/wp-admin/
  sed -i "s/v_title/$wptitle/g" /home/$sudo_user/$hostname/public/wp-admin/install.php
  sed -i "s/v_user/$wpuser/g" /home/$sudo_user/$hostname/public/wp-admin/install.php
  sed -i "s/v_pass/$wppass/g" /home/$sudo_user/$hostname/public/wp-admin/install.php
  sed -i "s/v_email/$wpemail/g" /home/$sudo_user/$hostname/public/wp-admin/install.php
  chown -R apache:apache /home/$sudo_user/$hostname
  #Run The Install
  php /home/$sudo_user/$hostname/public/wp-admin/install.php > /dev/null 2>&1
  rm -f /home/$sudo_user/$hostname/public/wp-admin/install.php
  #Adjust The Database. Switch Permalinks, and install/enable Nginx Helper plugin
  cd tmp
  wget http://downloads.wordpress.org/plugin/nginx-helper.1.7.2.zip > /dev/null 2>&1
  unzip nginx-helper.1.7.2.zip -d /home/$sudo_user/$hostname/public/wp-content/plugins/ > /dev/null 2>&1
  cd ..
  chown -R $sudo_user:apache /home/$sudo_user/$hostname
  table="$DB_PREFIX"
  table+="options"
  mysql $WP_DB -e "UPDATE $table SET option_value='http://$hostname' WHERE option_name='siteurl'"
  mysql $WP_DB -e "UPDATE $table SET option_value='http://$hostname' WHERE option_name='home'"
  mysql $WP_DB -e "UPDATE $table SET option_value='/%postname%/' WHERE option_name='permalink_structure'"
  mysql $WP_DB -e "UPDATE $table SET option_value='a:1:{i:0;s:29:\"nginx-helper/nginx-helper.php\";}' WHERE option_name='active_plugins'"
  mysql $WP_DB -e "UPDATE $table SET option_value='a:17:{s:9:\"log_level\";s:4:\"INFO\";s:12:\"log_filesize\";i:5;s:12:\"enable_purge\";i:1;s:10:\"enable_map\";i:0;s:10:\"enable_log\";i:0;s:12:\"enable_stamp\";i:1;s:21:\"purge_homepage_on_new\";i:1;s:22:\"purge_homepage_on_edit\";i:1;s:21:\"purge_homepage_on_del\";i:1;s:20:\"purge_archive_on_new\";i:1;s:21:\"purge_archive_on_edit\";i:1;s:20:\"purge_archive_on_del\";i:1;s:28:\"purge_archive_on_new_comment\";i:0;s:32:\"purge_archive_on_deleted_comment\";i:0;s:17:\"purge_page_on_mod\";i:1;s:25:\"purge_page_on_new_comment\";i:1;s:29:\"purge_page_on_deleted_comment\";i:1;}' WHERE option_name='rt_wp_nginx_helper_global_options'"
  mysql $WP_DB -e "UPDATE $table SET option_value='a:13:{s:12:\"enable_purge\";i:1;s:10:\"enable_map\";i:0;s:10:\"enable_log\";i:0;s:12:\"enable_stamp\";i:1;s:22:\"purge_homepage_on_edit\";i:1;s:21:\"purge_homepage_on_del\";i:1;s:21:\"purge_archive_on_edit\";i:1;s:20:\"purge_archive_on_del\";i:1;s:28:\"purge_archive_on_new_comment\";i:0;s:32:\"purge_archive_on_deleted_comment\";i:0;s:17:\"purge_page_on_mod\";i:1;s:25:\"purge_page_on_new_comment\";i:1;s:29:\"purge_page_on_deleted_comment\";i:1;}' WHERE option_name='rt_wp_nginx_helper_options'"
  echo "done."
}

install_monit()
{
  echo -n "Setting up Monit... "
  yum -y install monit > /dev/null 2>&1
  #perl -p -i -e 's|startup=0|startup=1|g;' /etc/default/monit
  mv /etc/monit.conf /etc/monit.conf.bak
  cp files/monitrc /etc/monit.conf
  chmod 700 /etc/monit.conf
  sed -i -r "s/mydomain.com/$hostname/g" /etc/monit.conf
  sed -i -r "s/monitemail/$wpemail/g" /etc/monit.conf
  sed -i -r "s/sshport/$ssh_port/g" /etc/monit.conf
  /etc/init.d/monit restart > /dev/null 2>&1
  echo "done."
}

install_fail2ban()
{
echo ""
echo -n "Installing Fail2ban......."
yum -y install fail2ban > /dev/null 2>&1
mv /etc/fail2ban/jail.conf /etc/fail2ban/jail.conf.bak
cp files/jail.conf /etc/fail2ban/jail.conf
cp files/http-get-dos.conf /etc/fail2ban/filter.d/
sed -i "s/port=ssh/port=$ssh_port/g" /etc/fail2ban/jail.conf
sed -i "s/you@example.com/$wpemail/g" /etc/fail2ban/jail.conf
sed -i "s/fail2ban@example.com/fail2ban@$hostname/g" /etc/fail2ban/jail.conf
/etc/init.d/fail2ban start > /dev/null 2>&1
echo "done!"
}

init_chkconfig()
{
  chkconfig php-fpm on
  chkconfig nginx on
  chkconfig mysql on
  chkconfig postfix on
  chkconfig monit on
  chkconfig fail2ban on
  chkconfig httpd on
  /etc/init.d/httpd start > /dev/null 2>&1
  /etc/init.d/php-fpm start
}
print_report()
{
  echo ""
  echo "Venison is delicious... enjoy!"
  echo ""
  echo "DATABASE INFO:"
  echo ""
  echo "Database to be used: $WP_DB"
  echo "Database user: $WP_USER"
  echo "Database user password: $WP_USER_PASS"
  echo "Root Database Password is: $MYSQL_PASS"
  echo ""
  echo "WORDPRESS INFO:"
  echo ""
  echo "Site Title: $hostname"
  echo "Admin Login User: $wpuser"
  echo "Admin Password: $wppass"
  echo "Admin Email Address: $wpemail"
}

check_vars()
{
  if [ -n "$hostname" -a -n "$sudo_user" -a -n "$sudo_user_passwd" -a -n "$root_passwd" -a -n "$ssh_port" -a -n "$wptitle" -a -n "$wpuser" -a -n "$wppass" -a -n "$wpemail" ]
  then
    return
  else
    echo "Value of variables cannot be empty."
    exit
  fi
}

cleanup()
{
  rm -rf tmp/*
}

#-- Function calls and flow of execution --#

#Get User-Defined Variables
get_vars

# make sure we are running Ubuntu 11.04
os_check

# clean up tmp
cleanup

# check value of all UDVs
check_vars

# set system locale.... not required in CentOS 6
set_locale

# set timezone of server
set_timezone

# change root user password
change_root_passwd

# create and configure sudo user
create_sudo_user

# configure ssh
config_ssh

# set up and activate firewall
setup_firewall

# set up temp directory
#setup_tmpdir

# set up base packages
install_base

# install php
install_php

#Install Database
install_db_server

# configure database
config_db

# configure nginx web server
config_nginx

# Install Apache
install_apache

# Install mod_fastcgi
install_fastcgi

# Tune Apache
tune_apache

# install postfix
install_postfix

# configure wordpress
configure_wp

# install monit
install_monit

#install Fail2Ban
install_fail2ban

#Make Sure Everything Starts On Boot
#init_chkconfig

# Set root Password for MySQL
secure_mysql

#Add all services to chkconfig and boot apache
init_chkconfig

# clean up tmp
cleanup

# print report of db info
print_report
