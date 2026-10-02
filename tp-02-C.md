
## Ejercicio 1

#### Dockerfile usado:
```dockerfile
FROM python:3.12
COPY . .
RUN pip install -r requirements.txt
```

La imagen  tardo 50s en construirse
```bash
❯ docker build -f 'v1.dockerfile' -t catalogo-api
[+] Building 50.0s (9/9) FINISHED
```

Y tiene un tamaño de 1.71GB 

```bash
❯ docker images
IMAGE                ID             DISK USAGE    CONTENT SIZE   EXTRA
catalogo-api:v1      761c197cd5f3       1.71GB           445MB
```


## Ejercicio 2

#### Dockerfile usado:
```dockerfile
FROM python:3.12-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user --no-cache-dir -r requirements.txt

FROM python:3.12-slim
WORKDIR /app
RUN useradd --create-home --shell /bin/bash appuser
COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local
COPY --chown=appuser:appuser . .

ARG APP_VERSION=v1
ENV APP_VERSION=${APP_VERSION}

ENV PATH=/home/appuser/.local/bin:$PATH \
    PYTHONUNBUFFERED=1

USER appuser
EXPOSE 8000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

La imagen tardo 59.6s en construirse:

```bash
❯ docker build -t catalogo-api:v2 -f 'v2.dockerfile' .
[+] Building 59.6s (12/12) FINISHED  
```


Y tiene un tamaño de 245MB:
```bash
❯ docker images
IMAGE                ID             DISK USAGE    CONTENT SIZE   EXTRA
catalogo-api:v2      cc5f00b95eb5        245MB          58.2MB
```

## Ejercicio 3

El archivo .dockerignore contiene:

```dockerignore
__pycache__
.git
.env
*.pyc
.venv
```

## Ejercicio 4

La segunda imagen imprime v2, entonces comprobamos que la variable de versión se hornea efectivamente.
```bash
❯ docker build -f backend/v1.dockerfile -t catalogo-api:v1 ./backend
[+] Building 22.4s (9/9) FINISHED

❯ docker build -f backend/v2.dockerfile --build-arg APP_VERSION=v2 -t catalogo-api:v2 ./backend
[+] Building 1.1s (12/12) FINISHED

❯ docker run --rm --entrypoint sh catalogo-api:v2 -c 'echo $APP_VERSION' 
v2
```

## Ejercicio 5 y 6

```dockerfile
FROM node:20-alpine AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build 


FROM nginxinc/nginx-unprivileged:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html

COPY nginx/templates/default.conf.template /etc/nginx/templates/default.conf.template

ENV API_HOST=catalogo-api \
    API_PORT=8000 \
    NGINX_ENVSUBST_FILTER=^API_

EXPOSE 8080
```

#### `frontend/.dockerignore`

```dockerignore
node_modules
dist
.git
.env
```

#### `nginx/templates/default.conf.template`

```nginx
server {
    listen 8080;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    # Healthcheck propio del frontend: no depende del backend, así el
    # contenedor puede estar sano aunque catalogo-api esté caída.
    location = /healthz {
        access_log off;
        add_header Content-Type text/plain;
        return 200 "ok\n";
    }

    # ---- API: mismo origen para el navegador, proxy hacia catalogo-api ----
    # ${API_HOST} y ${API_PORT} los reemplaza envsubst AL ARRANCAR el
    # contenedor (script /docker-entrypoint.d/20-envsubst-on-templates.sh de
    # la imagen oficial). La imagen no sabe a qué backend apunta hasta que
    # arranca: la misma imagen sirve para cualquier entorno.
    location /api/ {
        # OJO: la barra final de proxy_pass es la que ELIMINA el prefijo /api.
        # Sin ella, catalogo-api recibiría /api/productos y devolvería 404.
        proxy_pass http://${API_HOST}:${API_PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Host              $host;
        proxy_set_header X-Real-IP         $remote_addr;
        proxy_set_header X-Forwarded-For   $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_connect_timeout 5s;
        proxy_read_timeout    30s;
        client_max_body_size  1m;
    }

    # nginx resuelve el upstream de proxy_pass UNA sola vez, al arrancar: si
    # ${API_HOST} todavía no resuelve, el proceso muere con
    #   nginx: [emerg] host not found in upstream "catalogo-api"
    # Por eso el contenedor de la API tiene que estar corriendo, y en la misma
    # red, ANTES de arrancar este.
    #
    # Alternativa independiente del orden de arranque (resuelve en cada
    # request en vez de al arrancar); requiere saber la IP del resolver:
    #   resolver 127.0.0.11 valid=10s ipv6=off;   # DNS embebido de Docker
    #   location /api/ {
    #       set $upstream http://${API_HOST}:${API_PORT};
    #       rewrite ^/api/(.*)$ /$1 break;   # con variable, proxy_pass NO reescribe la URI
    #       proxy_pass $upstream;
    #   }

    # Los assets llevan hash en el nombre: son inmutables.
    location /assets/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # index.html nunca se cachea: al desplegar una imagen nueva del frontend,
    # el navegador la toma en el próximo reload.
    location = /index.html {
        add_header Cache-Control "no-store";
    }

    # Fallback de SPA: cualquier ruta desconocida devuelve index.html.
    location / {
        try_files $uri $uri/ /index.html;
    }
}
```

#### Para el README: por qué `NGINX_ENVSUBST_FILTER` no es opcional

El entrypoint de nginx construye una lista con los **nombres** de las variables de entorno que matchean `^API_` y la pasa como `SHELL-FORMAT` a `envsubst`: solo se sustituye esa lista. Así `API_HOST` y `API_PORT` se resuelven al arrancar el contenedor, y ninguna variable de entorno puede pisar variables propias de nginx (`$uri`, `$host`, `$proxy_add_x_forwarded_for`). Sin el filtro, cualquier nombre de variable de entorno que coincida con una variable de nginx se reemplaza por su valor.

#### Usuario y permisos: por qué no se declara `USER` ni `--chown`

`nginx-unprivileged` ya provee el usuario `nginx` (uid 101) y ya asignó a ese usuario los paths que nginx escribe (`/etc/nginx/conf.d`, `/var/cache/nginx`). Los archivos copiados son de **solo lectura** y `0644` alcanza: la propia imagen oficial sirve `/usr/share/nginx/html` como `root:root`. Distinto del backend, donde hubo que crear el usuario con `useradd` porque `python:3.12-slim` no trae ninguno.


## Ejercicio 7

```bash
❯ docker run --rm catalogo-frontend:v1 whoami 
nginx
```

```bash
❯ docker run --rm catalogo-frontend:v1 node --version 
/docker-entrypoint.sh: exec: line 47: node: not found
```

```bash
❯ docker images catalogo-frontend
IMAGE                  ID             DISK USAGE   CONTENT SIZE   EXTRA
catalogo-frontend:v1   3c3bfa2c384b       73.9MB           21MB
```


## Ejercicio 8

### Imágenes base, medidas con `docker run --rm`

```bash
❯ docker run --rm --entrypoint sh python:3.12 -c 'du -sh / 2>/dev/null'
1.1G	/
❯ docker run --rm --entrypoint sh python:3.12-slim -c 'du -sh / 2>/dev/null'
125M	/
❯ docker run --rm --entrypoint sh node:20-alpine -c 'du -sh / 2>/dev/null'
137.9M	/
❯ docker run --rm --entrypoint sh nginxinc/nginx-unprivileged:1.27-alpine -c 'du -sh / 2>/dev/null'
49.6M	/
```

```bash
# El tamaño de cada base, pero en la métrica que usa la tabla
❯ docker images | grep -E '^(python|node|nginx)'
nginxinc/nginx-unprivileged:1.27-alpine   65e3e85dbaed       73.7MB        21MB
node:20-alpine                            fb4cd12c85ee        194MB      48.8MB
python:3.12                               4f80f7924032       1.62GB       429MB
python:3.12-slim                          dddfd7e07f9d        191MB      48.4MB
```

El `grep` deja solo las bases; los tamaños de las tres imágenes comparadas son los de los ejercicios 1, 2 y 7.

`du` mide el filesystem resultante y `docker images` cuenta además lo que capas posteriores reemplazaron, así que los números de los dos bloques no coinciden entre sí (por eso cada bloque muestra la métrica que mide).

### Tabla comparativa

Reducción calculada sobre `catalogo-api:v1` (la versión ingenua).

| Imagen | Imagen base | Tamaño en disco | Tamaño de contenido | Reducción (disco) | Reducción (contenido) |
| --- | --- | --- | --- | --- | --- |
| `catalogo-api:v1` (ingenua) | `python:3.12` (1,62 GB) | 1,71 GB | 445 MB | — | — |
| `catalogo-api:v2` (definitiva) | `python:3.12-slim` (191 MB), también en el *builder* | 245 MB | 58,2 MB | **85,7 %** | **86,9 %** |
| `catalogo-frontend:v1` | build `node:20-alpine` (194 MB) → final `nginxinc/nginx-unprivileged:1.27-alpine` (73,7 MB) | 73,9 MB | 21 MB | **95,7 %** | **95,3 %** |

### Una línea por decisión

- **Base `python:3.12` → `python:3.12-slim`**: la base baja de 1,62 GB a 191 MB; es la reducción principal.
- **Multi-etapa (*builder* + runtime)**: a la imagen final sólo viaja `/root/.local` (53 MB); no quedan herramientas de compilación ni caché de pip.
- **`pip install --user`**: deja las dependencias en un solo directorio (`~/.local`), que es el que copia el `COPY --from`.
- **`--no-cache-dir`**: evita que pip guarde su caché de descargas (17 MB medidos con estos `requirements.txt`), bytes que no hacen falta para ejecutar.
- **`COPY --chown` en lugar de `COPY` + `RUN chown -R`**: 257 MB contra 325 MB (+68 MB) medidos en la máquina; el `chown` posterior reescribe el árbol en una capa nueva.
- **`useradd` + `USER appuser`**: 0 B; aporta correr sin privilegios.
- **`ENV PATH`**: 0 B; sin ella el contenedor muere con `exec: "uvicorn": executable file not found in $PATH`.
- **`ENV PYTHONUNBUFFERED=1`**: 0 B; sin ella `docker logs` no muestra nada.
- **`CMD` con `--host 0.0.0.0`**: 0 B; sin eso el puerto se publica pero rechaza las conexiones de afuera.
- **`backend/.dockerignore`**: 0 B; mantiene el `.venv` local fuera del contexto y del `COPY . .`.
- **Orden `COPY requirements.txt` → `pip install` → `COPY . .`**: 0 B; aporta tiempo (22,4 s la primera vez, 1,1 s con caché).
- **Frontend multi-etapa fuerte**: Node, npm y `node_modules` no quedan (por eso falla el `node --version` del ejercicio 7); el `dist/` aporta 193 kB.
- **`nginx-unprivileged` como base**: ya trae usuario `nginx` (uid 101) y los paths escribibles: 0 B, sin `useradd` ni `--chown`.
- **`ENV API_HOST`/`API_PORT` + `NGINX_ENVSUBST_FILTER=^API_`**: 0 B; la misma imagen apunta a cualquier backend.


## Ejercicio 9

```bash
❯ docker history catalogo-api:v1 | grep -v "0B"
IMAGE          CREATED        CREATED BY                                      SIZE      COMMENT
669040ec9fbb   16 hours ago   RUN /bin/sh -c pip install -r requirements.t…   79.5MB    buildkit.dockerfile.v0
<missing>      16 hours ago   COPY . . # buildkit                             573kB     buildkit.dockerfile.v0
<missing>      21 hours ago   RUN /bin/sh -c set -eux;  for src in idle3 p…   16.4kB    buildkit.dockerfile.v0
<missing>      21 hours ago   RUN /bin/sh -c set -eux;   wget -O python.ta…   72.8MB    buildkit.dockerfile.v0
<missing>      22 hours ago   RUN /bin/sh -c set -eux;  apt-get update;  a…   19.9MB    buildkit.dockerfile.v0
<missing>      13 days ago    RUN /bin/sh -c set -ex;  apt-get update;  ap…   694MB     buildkit.dockerfile.v0
<missing>      13 days ago    RUN /bin/sh -c set -eux;  apt-get update;  a…   202MB     buildkit.dockerfile.v0
<missing>      13 days ago    RUN /bin/sh -c set -eux;  apt-get update;  a…   65MB      buildkit.dockerfile.v0
<missing>      2 weeks ago    # debian.sh --arch 'amd64' out/ 'trixie' '@1…   134MB     debuerreotype 0.17
```

El `grep -v "0B"` descarta las capas de solo metadatos (`ENV`, `CMD`, `WORKDIR`, labels).

**La capa más pesada es la de 694 MB** (54,7 % del total de capas). No la produce este Dockerfile: es el `apt-get install` de `buildpack-deps`, del que cuelga `python:3.12` (`FROM buildpack-deps:trixie`) porque compila CPython desde cero.

`docker history --no-trunc python:3.12`

| Capa | Qué instala | Binarios / herramientas que quedan | Origen |
| --- | --- | --- | --- |
| **694 MB** | toolchain C/C++: `gcc`, `g++`, `make`, `autoconf`, `automake`, `libtool`, `patch`, `file`, `imagemagick`, `bzip2`, `unzip`, `xz-utils`, `dpkg-dev` + 29 libs `-dev` (`libbz2-dev`, `libpq-dev`, `libssl-dev`, `libsqlite3-dev`, `libjpeg-dev`, …) | `cc`, `gcc`, `g++`, `make`, `autoconf`, `automake`/`aclocal`, `libtoolize`, `dpkg-buildpackage`, `file`, `patch`, `xz`, `unzip`, `bzip2`, `convert`/`magick`, `mysql_config` | base |
| 202 MB | `git`, `mercurial`, `openssh-client`, `subversion`, `procps` | `git`, `hg`, `svn`, `ssh`, `ps` | base |
| 134 MB | rootfs Debian trixie | `bash`, `coreutils`, `apt`, `dpkg` | base |
| 72,8 MB | build de CPython: `wget` del tarball + `./configure` + `make install` | `python3`, `/usr/local/lib/python3.12` | base |
| 65 MB | `ca-certificates`, `curl`, `wget`, `gnupg`, `netbase`, `sq` | `curl`, `wget`, `gpg`, `sq` | base |
| 19,9 MB | `tk-dev`, `libbluetooth-dev`, `uuid-dev` | módulos opcionales de CPython (`tkinter`, `uuid`) | base |
| 16,4 kB | symlinks `pip`, `idle`, `pydoc3`, `python3-config` | — | base |
| 79,5 MB | `pip install -r requirements.txt` | `uvicorn` + las libs en `site-packages` | **este Dockerfile** |
| 573 kB | `COPY . .` | código de la app | **este Dockerfile** |

## Ejercicio 10

Efecto del cache de construcción: modificar el contenido de un archivo de código, reconstruir y comprobar en la salida que la instalación de dependencias aparece como CACHED:
```bash
❯ docker build -t catalogo-api:v2 -f 'v2.dockerfile' .
[+] Building 0.8s (12/12) FINISHED                                 docker:default
 => [internal] load build definition from v2.dockerfile                      0.0s
 => => transferring dockerfile: 579B                                         0.0s
 => [internal] load metadata for docker.io/library/python:3.12-slim          0.0s
 => [internal] load .dockerignore                                            0.0s
 => => transferring context: 73B                                             0.0s
 => [internal] load build context                                            0.0s
 => => transferring context: 12.69kB                                         0.0s
 => [builder 1/4] FROM docker.io/library/python:3.12-slim@sha256:dddfd7e07f9d15aeeca61529320492139d21cac7f0070c00609243e51e4e0    0.0s
 => => resolve docker.io/library/python:3.12-slim@sha256:dddfd7e07f9d15aeeca61529320492139d21cac7f0070c00609243e51e4e0016 0.0s
 => CACHED [builder 2/4] WORKDIR /app                                        0.0s
 => CACHED [stage-1 3/5] RUN useradd --create-home --shell /bin/bash appuser 0.0s
 => CACHED [builder 3/4] COPY requirements.txt .                             0.0s
 => CACHED [builder 4/4] RUN pip install --user --no-cache-dir -r requirements.txt                                                             0.0s
 => CACHED [stage-1 4/5] COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local                                            0.0s
 => [stage-1 5/5] COPY --chown=appuser:appuser . .                           0.1s
 => exporting to image                                                       0.4s
 => => exporting layers                                                      0.2s
 => => exporting manifest sha256:d8e4e79cdd9e1049132513a76c9daaabaf9cf4530e807102d1d9f0ab54c25559      0.0s
 => => exporting config sha256:f59c5d336ba4ee8dd44a2c7553b23e715e94e1fd5d596de460477f2c7a700dc8      0.0s
 => => exporting attestation manifest sha256:870747eece6b41fb582efd9aa09007ccf90f8d32d92ec42ecaab56690d9f44a1      0.0s
 => => exporting manifest list sha256:22e11bc4bb45eefcd399d808e8a458aa77820885e06b00bcc498f88e6005c338      0.0s
 => => naming to docker.io/library/catalogo-api:v2                           0.0s
 => => unpacking to docker.io/library/catalogo-api:v2                        0.1s
```

Misma operacion pero  modificando requirements.txt:

```bash
[+] Building 15.0s (12/12) FINISHED                                docker:default
 => [internal] load build definition from v2.dockerfile                      0.0s
 => => transferring dockerfile: 579B                                         0.0s
 => [internal] load metadata for docker.io/library/python:3.12-slim          0.0s
 => [internal] load .dockerignore                                            0.0s
 => => transferring context: 73B                                             0.0s
 => [builder 1/4] FROM docker.io/library/python:3.12-slim@sha256:dddfd7e07f9d15aeeca61529320492139d21cac7f0070c00609243e51e4e0    0.0s
 => => resolve docker.io/library/python:3.12-slim@sha256:dddfd7e07f9d15aeeca61529320492139d21cac7f0070c00609243e51e4e0016 0.0s
 => [internal] load build context                                            0.0s
 => => transferring context: 12.76kB                                         0.0s
 => CACHED [builder 2/4] WORKDIR /app                                        0.0s
 => [builder 3/4] COPY requirements.txt .                                    0.0s
 => [builder 4/4] RUN pip install --user --no-cache-dir -r requirements.txt 11.5s
 => CACHED [stage-1 3/5] RUN useradd --create-home --shell /bin/bash appuser 0.0s
 => [stage-1 4/5] COPY --from=builder --chown=appuser:appuser /root/.local /home/appuser/.local                                                         0.2s
 => [stage-1 5/5] COPY --chown=appuser:appuser . .                           0.1s
 => exporting to image                                                       2.7s
 => => exporting layers                                                      2.1s
 => => exporting manifest sha256:1b6e0a1d926bf8e6f9593d7f30ba44f30882e85c93ad0bc3bbe87d83ae38eed2      0.0s
 => => exporting config sha256:3dd2846ffd570d997eac6152b92845e9208d934b832eb663675024dc6ae7aced      0.0s
 => => exporting attestation manifest sha256:0339af747f638904af811197a1bd38513d638574f42d4c81f56fd27153e34226      0.0s
 => => exporting manifest list sha256:0921e5479e620355e92e2d6a8f00f62c3ff420efd912a00db1008b72d812e157      0.0s
 => => naming to docker.io/library/catalogo-api:v2                           0.0s
 => => unpacking to docker.io/library/catalogo-api:v2                        0.4s
```

**Sólo cambia el código:** `COPY requirements.txt` y `RUN pip install --user --no-cache-dir -r requirements.txt` salen `CACHED` (build total 0,8 s) porque el cache se resuelve capa por capa sobre las entradas de esa capa, y a `pip install` sólo le importa el contenido de `requirements.txt`: el código nuevo recién entra después, en `COPY . .` (esa capa sí se reconstruye, 0,1 s).

**Cambia `requirements.txt`:** esa capa se invalida y arrastra a todas las posteriores — `pip install` 11,5s, `COPY --from=builder` 0,2 s, export 2,7 s — así que el orden funciona porque invalidar una capa invalida las siguientes, nunca las anteriores; con `COPY . .` antes de `pip install` (el Dockerfile del ejercicio 1), cualquier retoque de código reinstalaría las dependencias.


## Ejercicio 11

```bash
# 1. Autenticarse (Docker Hub; con 2FA la contraseña es un Personal Access Token)
docker login

# 2. Ponerle a cada imagen su nombre completo
docker tag catalogo-api:v2      archivex/catalogo-api:v2
docker tag catalogo-frontend:v1 archivex/catalogo-frontend:v1

# 3. Publicar
docker push archivex/catalogo-api:v2
docker push archivex/catalogo-frontend:v1
```


## Observaciones del TP

El tp menciona: 

```txt
El error más difícil de esta variante es el de la variable PATH. El comando pip install --user deja los ejecutables en el subdirectorio .local/bin del directorio personal, que no forma parte del PATH por omisión. La construcción termina correctamente, la imagen se crea, y el contenedor muere al arrancar con exec: "uvicorn": executable file not found in $PATH. La imagen «está bien construida» y no funciona: el error aparece recién en el docker run.
```

Efectivamente es lo que me paso, al ejecutar:
```bash
❯ docker run catalogo-api:v2 

docker: Error response from daemon: failed to create task for container: failed to create shim task: OCI runtime create failed: runc create failed: unable to start container process: error during container init: exec: "gunicorn": executable file not found in $PATH
```

## Advertencias frecuentes del tp

- El error más difícil de esta variante es el de la variable PATH. El comando pip install
--user deja los ejecutables en el subdirectorio .local/bin del directorio personal, que no
forma parte del PATH por omisión. La construcción termina correctamente, la imagen se crea,
y el contenedor muere al arrancar con exec: "uvicorn": executable file not found
in $PATH. La imagen «está bien construida» y no funciona: el error aparece recién en el
docker run.
- Un error ModuleNotFoundError: No module named 'fastapi' indica que el directorio
de dependencias se copió a un destino distinto del directorio personal del usuario declarado en
USER. El destino del COPY --from= debe coincidir con ese directorio.
- El segundo error difícil es la dirección de escucha. Con la configuración por omisión, el
servidor escucha en 127.0.0.1, que dentro de un contenedor significa únicamente el propio
contenedor: el puerto se publica correctamente y toda conexión desde afuera es rechazada.
Corresponde declarar --host 0.0.0.0 en el CMD. El síntoma es una conexión rechazada o
reiniciada con el contenedor en estado Up y el registro informando que el servidor arrancó
bien.
- Si docker logs no muestra nada mientras el contenedor está en ejecución, falta ENV
PYTHONUNBUFFERED=1.
- Un error EACCES o Permission denied al arrancar indica que la instrucción USER se
declaró antes de los COPY, de modo que los archivos quedaron con propietario root.
- Si la construcción tarda lo mismo en todos los casos, el código se está copiando antes de
instalar las dependencias: cualquier modificación invalida la capa de instalación.
- Adviértase que un touch sobre un archivo no invalida el cache: la comparación se realiza
sobre el contenido, no sobre la fecha de modificación. Para forzar la invalidación es necesario
modificar el archivo.
- Si catalogo-api:v2 informa v1, falta ENV APP_VERSION=${APP_VERSION}: el ARG no
sobrevive a la construcción.
- El docker push falla si el nombre de la imagen no comienza con el usuario del registry.
docker push catalogo-api:v1 intenta publicar en el espacio de las imágenes oficiales y
es rechazado.

