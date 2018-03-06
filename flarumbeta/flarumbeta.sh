#!/bin/bash
generated_mysql_pass=$3
domain_named=$( echo "$2" | tr -d . )
flarum_install="/var/www/$2" webuser_group='www-data'
gpasswd -a pi www-data
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/bin --filename=composer
COMPOSER_HOME="/usr/bin" composer create-project flarum/flarum "$flarum_install" --stability=beta
chmod 775 "$flarum_install"
chmod -R 775 "$flarum_install/assets" "$flarum_install/storage"
chgrp "$webuser_group" "$flarum_install"
chgrp -R "$webuser_group" "$flarum_install/assets" "$flarum_install/storage"
mysqladmin -u root password "$1"
mysql -uroot -p"$1" -e "CREATE DATABASE IF NOT EXISTS flarum_$2 ;"
mysql -uroot -p"$1" -e "CREATE USER flarum_$2@localhost IDENTIFIED BY '$generated_mysql_pass';"
mysql -uroot -p"$1" -e "GRANT USAGE ON flarum_$2.* TO flarum_$2@localhost IDENTIFIED BY '$generated_mysql_pass' WITH MAX_QUERIES_PER_HOUR 0 MAX_CONNECTIONS_PER_HOUR 0 MAX_UPDATES_PER_HOUR 0 MAX_USER_CONNECTIONS 0 ;"
mysql -uroot -p"$1" -e "GRANT ALL PRIVILEGES ON flarum_$2.* TO flarum_$2@localhost;"

echo ""
echo "Flarum username -> flarum_$domain_named"
echo "Flarum database -> flarum_$domain_named"
echo 'Flarum database password ->' "$generated_mysql_pass"
unset mysql_pass generated_mysql_pass
sleep 2
echo "
[$2]
listen = /var/run/php7-fpm.$2.sock
listen.allowed_clients = 127.0.0.1
user = www-data
group = www-data
listen.owner = www-data
listen.group = www-data
pm = ondemand
pm.max_children = 10
pm.max_requests = 5000
pm.process_idle_timeout = 60s
chdir = /
" > /etc/php/7.0/fpm/pool.d/$2.conf
echo "
server {
  listen 80;
  root $flarum_install;
  index index.php index.html index.htm;
  error_log /var/log/nginx/error.log error;
  server_name $2;
" > /etc/nginx/sites-available/$2
tee --append << 'EOF' /etc/nginx/sites-available/$2 &> /dev/null


    location / { try_files $uri $uri/ /index.php?$query_string; }
    location /api { try_files $uri $uri/ /api.php?$query_string; }
    location /admin { try_files $uri $uri/ /admin.php?$query_string; }
    location ~ /.well-known {
                allow all;
        }
EOF

echo "
    location /flarum {
        deny all;
        return 404;
    }
    location ~ .php$ {
        fastcgi_split_path_info ^(.+.php)(/.+)$;
        fastcgi_pass unix:/var/run/php7-fpm.$2.sock;
		fastcgi_read_timeout 600;  
        fastcgi_index index.php;
        include fastcgi_params;
        # time out settings
  		proxy_connect_timeout 300s;
  		proxy_send_timeout   600;
  		proxy_read_timeout   600;
  		proxy_buffer_size    64k;
  		proxy_buffers     16 32k;
  		proxy_busy_buffers_size 64k;
  		proxy_temp_file_write_size 64k;
  		proxy_pass_header Set-Cookie;
  		proxy_redirect     off;
  		proxy_hide_header  Vary;
  
  		proxy_ignore_headers Cache-Control Expires;
  	
" >> /etc/nginx/sites-available/$2

tee --append << 'EOF' /etc/nginx/sites-available/$2 &> /dev/null

        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
    }

    location ~* \.html$ {
        expires -1;
    }

    location ~* \.(css|js|gif|jpe?g|png)$ {
        expires 1M;
        add_header Pragma public;
        add_header Cache-Control "public, must-revalidate, proxy-revalidate";
    }

    gzip on;
    gzip_http_version 1.1;
    gzip_vary on;
    gzip_comp_level 6;
    gzip_proxied any;
    gzip_types application/atom+xml
               application/javascript
               application/json
               application/vnd.ms-fontobject
               application/x-font-ttf
               application/x-web-app-manifest+json
               application/xhtml+xml
               application/xml
               font/opentype
               image/svg+xml
               image/x-icon
               text/css
               text/plain
               text/xml;
    gzip_buffers 16 8k;
    gzip_disable "MSIE [1-6]\.(?!.*SV1)";


}
EOF
ln -s /etc/nginx/sites-available/$2 /etc/nginx/sites-enabled/$2
rm /etc/nginx/sites-available/default
rm /etc/nginx/sites-enabled/default

