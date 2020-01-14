# TT-RSS in a container

App from tt-rss.org

Docker container to be used in conjunction with a proxy container (like nginx)

example docker-compose.yml:

```docker-compose
version: '2'

services:
  db:
    image: postgres:12-alpine
    restart: always
    volumes:
      - ./volumes/db/data:/var/lib/postgresql/data
    env_file:
      - db.env
    networks:
      - db

  app:
    image: meyca/tt-rss-fpm:latest
    restart: always
    volumes:
      - ./volumes/app/html:/var/www/html
    env_file:
      - app.env
    depends_on:
      - db
    networks:
      - db

  scraper:
    image: meyca/tt-rss-fpm:latest
    restart: always
    volumes:
      - ./volumes/app/html:/var/www/html
    env_file:
      - app.env
    user: www-data
    command: "php /var/www/html/update_daemon2.php"
    depends_on:
      - app
    networks:
      - db

  web:
    image: nginx:alpine
    restart: always
    volumes:
      - ./volumes/app/html:/var/www/html:ro
      - ./tt-rss-nginx/nginx.conf:/etc/nginx/conf.d/default.conf
    depends_on:
      - app
    networks:
      - db
    ports:
      - 80:80

networks:
  db:
```

app.env:

```sh
TT_RSS_DB_TYPE=pgsql
TT_RSS_DB_HOST=db
TT_RSS_DB_USER=tt-rss
TT_RSS_DB_NAME=tt-rss
TT_RSS_DB_PASS=
TT_RSS_DB_PORT=5432
TT_RSS_SELF_URL_PATH=
TT_RSS_SMTP_FROM_ADDRESS=
```

db.env:

```sh
POSTGRES_PASSWORD=
POSTGRES_USER=tt-rss
```

nginx.conf:

```nginx
server {
    listen       80;
    server_name  localhost;

    location / {
        root   /var/www/html;
        index index.php;
        try_files $uri $uri/ =404;
    }

    location ~ \.php$ {
        root           /var/www/html;
        fastcgi_pass   app:9000;
        fastcgi_index  index.php;
        fastcgi_param  SCRIPT_FILENAME  $document_root/$fastcgi_script_name;
        fastcgi_param  HTTP_PROXY "";
        include        fastcgi_params;
    }

    location ~ /\.ht {
        deny  all;
    }
}

```