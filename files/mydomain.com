server {
    server_name mydomain.com www.mydomain.com;
    root /home/sudoer/mydomain.com/public;
    index index.php index.html;
    charset UTF-8;
    default_type text/html;

    access_log /var/log/nginx/mydomain.com-access.log;
    error_log /var/log/nginx/mydomain.com-error.log;

    include /etc/nginx/conf/proxy_cache_rules;

     location / {
       include proxy_params;
       include proxy_cache_rules;
       include proxy_cache;
       proxy_pass http://localhost:7080;
    }


    location = /favicon.ico {
        log_not_found off;
        access_log off;
    }

    location = /robots.txt {
        allow all;
        access_log off;
		log_not_found off;
    }

	location ~ /\. {
		deny all;
		access_log off;
		log_not_found off;
	}

    location /nginx_status {
        stub_status on;
        access_log off;
    }

    location ~ /purge(/.*) {
	    proxy_cache_purge php_cache "$scheme$request_method$host$1";
	}

    include /home/sudoer/mydomain.com/pagespeed.conf;
}
