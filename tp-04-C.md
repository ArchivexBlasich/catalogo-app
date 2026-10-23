## Ejercicio 1

docker-compose.yml con los tres servicios, reproduciendo exactamente la configuración de la semana 3:
```yml
services:
  catalogo-db:
    image: mongo:7
    container_name: catalogo-db
    environment:
      - MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME}
      - MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD}
    volumes:
      - catalogo-db-data:/data/db
    networks:
      - catalogo-net
  catalogo-api:
    build: 
      context: backend
      dockerfile: ./v1.dockerfile
    container_name: catalogo-api
    environment:
      - DB_HOST=${DB_HOST}
      - DB_NAME=${DB_NAME}
      - DB_USER=${DB_USER}
      - DB_PASSWORD=${DB_PASSWORD}
      - APP_VERSION=${APP_VERSION}
      - ROOT_PATH=${ROOT_PATH}
      - SEED_DEMO=${SEED_DEMO}
    ports:
      - "8000:8000"
    networks:
      - catalogo-net
  
  catalogo-frontend:
    build: ./frontend
    container_name: catalogo-frontend
    environment:
      - API_HOST=${API_HOST}
      - API_PORT=${API_PORT}
    ports:
      - "3000:8080"
    networks:
      - catalogo-net
    

volumes:
  catalogo-db-data:
    name: catalogo-db-data
networks:
  catalogo-net:
    name: catalogo-net
```

## Ejercicio 2
Healthcheck agregado a catalogo-db:

 ```yml
   healthcheck:
     test:
       - CMD-SHELL
       - mongosh --quiet --eval "db.adminCommand('ping').ok" || exit 1
     interval: 5s
     timeout: 3s
     retries: 10
     start_period: 10s
 ```

 Por qué no lleva credenciales: db.adminCommand('ping') no requiere autenticación. Solo comprueba que el proceso mongod esté corriendo y aceptando conexiones, que es todo lo que el
 healthcheck necesita confirmar: "el motor está levantado".

 Ventaja frente a la variante B (autenticar dentro del check): la contraseña no viaja en el comando ni queda a la vista en el docker-compose.yml ni en la config del contenedor (docker inspect catalogo-db la mostraría). El secreto vive únicamente en el .env y el healthcheck sigue válido aunque las credenciales roten.

 Qué NO verifica: No prueba que catalogo_user exista ni que la contraseña configurada en el .env sea la correcta; eso se valida recién cuando la API se conecta con sus credenciales reales.

> [! NOTE] Advertencia
El healthcheck de MongoDB no verifica las credenciales. db.adminCommand('ping') no
requiere autenticación, y eso tiene una contracara: la base puede encontrarse en estado
healthy y la API fallar igualmente con Authentication failed. El caso más frecuente es
el siguiente: el volumen catalogo-db-data ya contiene una base inicializada —la de la semana 3— y se modifica MONGO_INITDB_ROOT_PASSWORD en el docker-compose.yml.
Las variables MONGO_INITDB_* se aplican solo sobre un volumen vacío: MongoDB arranca
con el usuario y la contraseña anteriores, el ping responde, Compose declara el servicio
healthy y la API, al autenticarse con la contraseña nueva, falla. Un healthcheck verifica lo
que verifica, no que todo funcione.





## Ejercicio 3
Health check agregado a catalogo-api

```yml
  healthcheck:
	test:
	  - CMD
	  - python
	  - -c
	  - "import urllib.request; \
		 urllib.request.urlopen('http://127.0.0.1:8000/health')"
	interval: 15s
	timeout: 5s
	retries: 3
	start_period: 10s
```

Cómo funciona: cada `interval` (15 s), el daemon lanza un proceso Python dentro del contenedor, importa `urllib.request` (biblioteca estándar de Python) y abre `http://127.0.0.1:8000/health`. Si la URL no responde, el proceso muere con traceback y exit code 1 (unhealthy); solo un HTTP 200 deja exit 0 (healthy). Apunta a 127.0.0.1 porque el check corre adentro del propio contenedor, no desde el host.

### Por qué no instalamos curl en la imagen

Podríamos hacerlo: curl no está prohibido y el efecto es equivalente (`urllib.request.urlopen(...)` y `curl -fsS http://127.0.0.1:8000/health` se comportan igual: exit 0 con un 2xx, exit != 0 si falla conexión o si el servidor devuelve 5xx con `-f`). El problema es otro: la imagen de la API se construye sobre `python:3.12-slim`, que **no trae el binario curl** (las variantes slim recortan todo lo no esencial, curl incluido). Para usarlo habría que agregar un `apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*` en el Dockerfile, una capa de instalación extra que cuesta:

- **Tamaño de imagen**: curl y su árbol de dependencias agregan decenas de MB, que se pagan en cada pull, en el build cache y en el disco del host.
- **Superficie de ataque**: un binario más en la imagen, con CVEs propios para vigilar en cada scan (Trivy, `docker scout`), aunque la app no lo use: menos es más seguro.
- **Mantenimiento**: un paquete más que puede marcarse como deprecado o requerir rebuilds; mientras que `urllib` vive dentro de la imagen base de Python y se actualiza con ella.

La conclusión práctica: el healthcheck necesita un cliente HTTP trivial, y traer uno externo solo para eso no se justifica; `urllib` da el mismo resultado sin costo.

### Qué NO verifica

Lo que confirma es una señal: que el proceso del contenedor está vivo y que `/health` responde dentro del contenedor. Qué más cubre depende de qué implementa ese endpoint:  no valida la conexión a MongoDB ni la lógica de negocio (el contenedor puede estar `healthy` mientras una query a la base falla). Si `/health` chequeara la base, sumaría esa cobertura, pero con un costo: una falla de dependencia externa marcaría unhealthy a un proceso que en sí está bien. Vale mirar qué responde `/health` antes de tratar al check como verificación completa.

## Ejercicio 4
Health check agregado a catalogo-frontend:

```yml
healthcheck:
  test: ["CMD-SHELL", "wget -q -O - http://127.0.0.1:8080/healthz"]
  interval: 15s
  timeout: 5s
  retries: 3
  start_period: 10s
```

Es una caja de herramientas de Unix comprimida en un solo binario: un único ejecutable estático de ~1 MB que implementa un montón de utilidades comunes (sh, ls, cp, cat, wget, ping, nc, ps...), son symlinks apuntando a /bin/busybox

## Ejercicio 5

docker-compose.yml con los servicios de catalogo-api y catalogo-frontend con sus respectivos depends_on

```yml
services:
  catalogo-db:
    image: mongo:7
    container_name: catalogo-db
    environment:
      - MONGO_INITDB_ROOT_USERNAME=${MONGO_INITDB_ROOT_USERNAME}
      - MONGO_INITDB_ROOT_PASSWORD=${MONGO_INITDB_ROOT_PASSWORD}
    volumes:
      - catalogo-db-data:/data/db
    networks:
      - catalogo-net
    healthcheck:
      test:
        - CMD-SHELL
        - mongosh --quiet --eval "db.adminCommand('ping').ok" || exit 1
      interval: 5s
      timeout: 3s
      retries: 10
      start_period: 10s

  catalogo-api:
    build: 
      context: backend
      dockerfile: ./v1.dockerfile
    container_name: catalogo-api
    environment:
      - DB_HOST=${DB_HOST}
      - DB_NAME=${DB_NAME}
      - DB_USER=${DB_USER}
      - DB_PASSWORD=${DB_PASSWORD}
      - APP_VERSION=${APP_VERSION}
      - ROOT_PATH=${ROOT_PATH}
      - SEED_DEMO=${SEED_DEMO}
    ports:
      - "8000:8000"
    networks:
      - catalogo-net
    depends_on:
      catalogo-db:
        condition: service_healthy
    healthcheck:
      test:
        - CMD
        - python
        - -c
        - "import urllib.request; \
          urllib.request.urlopen('http://127.0.0.1:8000/health')"
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 10s
  
  catalogo-frontend:
    build: ./frontend
    container_name: catalogo-frontend
    environment:
      - API_HOST=${API_HOST}
      - API_PORT=${API_PORT}
    ports:
      - "3000:8080"
    networks:
      - catalogo-net
    depends_on:
      - catalogo-api
    healthcheck:
      test: ["CMD-SHELL", "wget -q -O - http://127.0.0.1:8080/healthz"]
      interval: 15s
      timeout: 5s
      retries: 3
      start_period: 10s
    
    
volumes:
  catalogo-db-data:
    name: catalogo-db-data
networks:
  catalogo-net:
    name: catalogo-net
```

Los dos casos no son equivalentes: cada capa necesita una cosa distinta de su dependencia al arrancar. La forma corta `depends_on: [X]` solo garantiza **orden** (el contenedor de X está *running*); `condition: service_healthy` garantiza **orden + salud** (el healthcheck de X da healthy). En Kubernetes no existe `depends_on`.

|                             | a) API → DB                                                         | b) Frontend → API                                                   |
| --------------------------- | ------------------------------------------------------------------- | ------------------------------------------------------------------- |
| Lo que necesita al arrancar | Que Mongo **acepte conexiones** y recién ahí conectar y sembrar     | Que el **nombre resuelva** en el DNS de la red                      |
| Sin `depends_on`            | Primera conexión falla: `ServerSelectionTimeoutError`               | nginx muere: `host not found in upstream` (Exited (1))              |
| ¿Alcanza la forma corta?    | **No**: running ≠ aceptando conexiones                              | **Sí**: con orden basta, el nombre ya resuelve                      |
| `service_healthy`           | **Necesario**: el ping del Ej. 2 es la señal de «acepta conexiones» | **Mejora**: sin 502 en los primeros segundos (via `/health`, Ej. 3) |


a) `catalogo-api` → `catalogo-db`: la API debe conectarse y sembrar el catálogo. mongod está *running* varios segundos antes de aceptar conexiones (inicialización interna, creación de usuarios), así que la forma corta no alcanza y hace falta `service_healthy`. La API además reintenta la conexión ~30 s por sí sola: eso no reemplaza a `depends_on`, lo complementa. Y como en Kubernetes no existe `depends_on`, ahí queda solo el reintento.

b) `catalogo-frontend` → `catalogo-api`: nginx resuelve el upstream **una sola vez al arrancar**; si el nombre no resuelve, muere sin reintento. Sin depends_on el frontend arranca antes que la API y el nombre todavía no existe en el DNS de la red → `host not found in upstream`. Lo que no puede faltar es *algún* depends_on: la forma corta ya salva ese crash; `service_healthy` añade que arranque con la API ya en funcionamiento, sin 502 iniciales.


## Ejercicio 6

`docker compose config` valida el archivo y lo devuelve en su versión final: variables del `.env` resueltas y formato normalizado de Compose. Que salga sin errores confirma que el YAML está bien escrito.
```bash
❯ docker compose config

name: catalogo-app
services:
  catalogo-api:
    container_name: catalogo-api
    environment:
      APP_VERSION: v1
      DB_HOST: catalogo-db
      DB_NAME: catalogodb
      DB_PASSWORD: catalogo_pass
      DB_USER: catalogo_user
      ROOT_PATH: /api
      SEED_DEMO: "true"
    networks:
      catalogo-net: null
    build:
      context: /home/fblasich/Desktop/Kubernetes101/catalogo-app/backend
      dockerfile: ./v1.dockerfile
    depends_on:
      catalogo-db:
        condition: service_healthy
        required: true
    healthcheck:
      test:
        - CMD
        - python
        - -c
        - import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')
      timeout: 5s
      interval: 15s
      retries: 3
      start_period: 10s
    ports:
      - mode: ingress
        target: 8000
        published: "8000"
        protocol: tcp
  catalogo-db:
    container_name: catalogo-db
    environment:
      MONGO_INITDB_ROOT_PASSWORD: catalogo_pass
      MONGO_INITDB_ROOT_USERNAME: catalogo_user
    image: mongo:7
    networks:
      catalogo-net: null
    volumes:
      - type: volume
        source: catalogo-db-data
        target: /data/db
        volume: {}
    healthcheck:
      test:
        - CMD-SHELL
        - mongosh --quiet --eval "db.adminCommand('ping').ok" || exit 1
      timeout: 3s
      interval: 5s
      retries: 10
      start_period: 10s
  catalogo-frontend:
    container_name: catalogo-frontend
    environment:
      API_HOST: catalogo-api
      API_PORT: "8000"
    networks:
      catalogo-net: null
    build:
      context: /home/fblasich/Desktop/Kubernetes101/catalogo-app/frontend
      dockerfile: Dockerfile
    depends_on:
      catalogo-api:
        condition: service_started
        required: true
    healthcheck:
      test:
        - CMD-SHELL
        - wget -q -O - http://127.0.0.1:8080/healthz
      timeout: 5s
      interval: 15s
      retries: 3
      start_period: 10s
    ports:
      - mode: ingress
        target: 8080
        published: "3000"
        protocol: tcp
networks:
  catalogo-net:
    name: catalogo-net
volumes:
  catalogo-db-data:
    name: catalogo-db-data
```

Ejecución del comando `docker compose up --build -d` :

```bash
❯ docker compose up --build -d
...
[+] up 7/7
 ✔ Image catalogo-app-catalogo-api      Built                                1.9s
 ✔ Image catalogo-app-catalogo-frontend Built                                2.0s
 ✔ Volume catalogo-db-data              Created                              0.0s
 ✔ Network catalogo-net                 Created                              0.1s
 ✔ Container catalogo-db                Healthy                             11.4s
 ✔ Container catalogo-api               Started                             11.6s
 ✔ Container catalogo-frontend          Started                             11.8s
```

Ejecución del comando `docker compose ps` :

```bash
❯ docker compose ps
NAME                IMAGE                            COMMAND                  SERVICE             CREATED         STATUS                   PORTS
catalogo-api        catalogo-app-catalogo-api        "uvicorn main:app --…"   catalogo-api        3 minutes ago   Up 3 minutes (healthy)   0.0.0.0:8000->8000/tcp, [::]:8000->8000/tcp
catalogo-db         mongo:7                          "docker-entrypoint.s…"   catalogo-db         3 minutes ago   Up 3 minutes (healthy)   27017/tcp
catalogo-frontend   catalogo-app-catalogo-frontend   "/docker-entrypoint.…"   catalogo-frontend   3 minutes ago   Up 3 minutes (healthy)   0.0.0.0:3000->8080/tcp, [::]:3000->8080/tcp
```

Ejecución de `docker compose logs -f catalogo-api` :

```bash
❯ docker compose logs -f catalogo-api
catalogo-api  | INFO:     Started server process [1]
catalogo-api  | INFO:     Waiting for application startup.
catalogo-api  | [2026-10-14T18:52:16+0000] INFO conexión a MongoDB establecida (base=catalogodb)
catalogo-api  | [2026-10-14T18:52:16+0000] INFO catálogo de demo sembrado (12 productos)
catalogo-api  | INFO:     Application startup complete.
catalogo-api  | INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
catalogo-api  | INFO:     127.0.0.1:45168 - "GET /health HTTP/1.1" 200 OK
catalogo-api  | INFO:     127.0.0.1:36716 - "GET /health HTTP/1.1" 200 OK
catalogo-api  | INFO:     127.0.0.1:37698 - "GET /health HTTP/1.1" 200 OK
```

## Ejercicio 7

```bash
❯ docker compose down
[+] down 4/4
 ✔ Container catalogo-frontend Removed                                       0.3s
 ✔ Container catalogo-api      Removed                                       0.8s
 ✔ Container catalogo-db       Removed                                       0.2s
 ✔ Network catalogo-net        Removed                                       0.1s
 
❯ docker compose up -d
[+] up 4/4
 ✔ Network catalogo-net        Created                                       0.0s
 ✔ Container catalogo-db       Healthy                                       5.9s
 ✔ Container catalogo-api      Started                                       6.0s
 ✔ Container catalogo-frontend Started                                       6.1s
 
❯ curl -s localhost:3000/api/productos | jq length 
13

docker compose down -v
[+] down 5/5
 ✔ Container catalogo-frontend Removed                                       0.2s
 ✔ Container catalogo-api      Removed                                       0.8s
 ✔ Container catalogo-db       Removed                                       0.2s
 ✔ Network catalogo-net        Removed                                       0.1s
 ✔ Volume catalogo-db-data     Removed                                       0.0s
 
# Los productos vivían en el volumen catalogo-db-data, que `down` no borra:
# por eso sobrevivieron al reinicio. `down -v` sí lo elimina: los 13
# desaparecen y el próximo `up` vuelve a sembrar los 12 del seed
# (SEED_DEMO sigue en true).
```

La diferencia entre `down` y `down - v` se muestra en la siguiente tabla:

|         | removes containers | removes networks | named volumes (catalogo-db-data) |
| ------- | ------------------ | ---------------- | -------------------------------- |
| down    | ✅                  | ✅                | ❌ kept                           |
| down -v | ✅                  | ✅                | ✅ deleted                        |

## Ejercicio 8

```bash
❯ curl -s localhost:8000/api/productos | jq length
13
```

```bash
❯ docker compose up -d --force-recreate catalogo-api
[+] up 2/2
 ✔ Container catalogo-db  Healthy                                            1.1s
 ✔ Container catalogo-api Started                                            1.3s
```

```bash
❯ curl -s localhost:8000/api/productos | jq length
13
```

La siembra es idempotente: recreamos el contenedor de la API y el conteo siguió en 13 (12 del seed + 1 de prueba), no se re-sembró.


## Ejercicio 9
This is the `.env.example` file:

```env
# This are catalogo-db related variables
MONGO_INITDB_ROOT_USERNAME=catalogo-db-user
MONGO_INITDB_ROOT_PASSWORD=catalogo-db-pass


# This are catalogo-api related variables
DB_HOST=catalogo-db 
DB_NAME=catalogodb
DB_USER=catalogo-api-user
DB_PASSWORD=catalogo-api-pass
APP_VERSION=v1
ROOT_PATH=/api
SEED_DEMO=true

# This are catalogo-frontend related variables
API_HOST=catalogo-api
API_PORT=8000
```


## Ejercicio 10

Revisión de seguridad de los tres servicios del compose. La síntesis, con números, es la tabla del ítem d), la que se registra en el README.md.

### a) Usuario con el que se ejecuta cada contenedor

```bash
❯ docker compose exec catalogo-api id
uid=1000(appuser) gid=1000(appuser) groups=1000(appuser)

❯ docker compose exec catalogo-frontend id
uid=101(nginx) gid=101(nginx) groups=101(nginx)
```

Las dos imágenes propias corren con usuario distinto de root: `appuser` (UID 1000) y `nginx` (UID 101).

La API no salió así de primera: con el Dockerfile de la v1 corría como root:

```bash
❯ docker compose exec catalogo-api id
uid=0(root) gid=0(root) groups=0(root)
```

El compose estaba apuntando al Dockerfile de la v1; se lo cambia al non-root (v2, `USER appuser`) y se reconstruye:

```diff
   build:
     context: backend
-    dockerfile: ./v1.dockerfile
+    dockerfile: ./v2.dockerfile
```

```bash
❯ docker compose down
❯ docker compose up --build -d
...
❯ docker compose exec catalogo-api id
uid=1000(appuser) gid=1000(appuser) groups=1000(appuser)
```


### b) Servicios que publican puertos (según docker compose ps)

Salida capturada con el stack levantado (la del ejercicio 6; los mapeos los fija el compose y no cambian con el rebuild del punto a)):

```bash
❯ docker compose ps
NAME                IMAGE                            COMMAND                  SERVICE             CREATED         STATUS                   PORTS
catalogo-api        catalogo-app-catalogo-api        "uvicorn main:app --…"   catalogo-api        3 minutes ago   Up 3 minutes (healthy)   0.0.0.0:8000->8000/tcp, [::]:8000->8000/tcp
catalogo-db         mongo:7                          "docker-entrypoint.s…"   catalogo-db         3 minutes ago   Up 3 minutes (healthy)   27017/tcp
catalogo-frontend   catalogo-app-catalogo-frontend   "/docker-entrypoint.…"   catalogo-frontend   3 minutes ago   Up 3 minutes (healthy)   0.0.0.0:3000->8080/tcp, [::]:3000->8080/tcp
```

- `catalogo-db`: la columna PORTS muestra solo `27017/tcp` (interno, en la red `catalogo-net`), sin mapeo al host: **la base de datos no publica ningún puerto hacia fuera**. En el compose, el servicio no declara `ports`.
- `catalogo-api`: publica `0.0.0.0:8000 → 8000`.
- `catalogo-frontend`: publica `0.0.0.0:3000 → 8080`.

### c) catalogo-api: el 8000 se publica solo para depuración

Publica `8000` al host únicamente para depurar durante el desarrollo (curl directo a `/health`, consola de la API). En producción es superfluo: el único consumidor de la API es el frontend, que la alcanza por la red interna del compose (`API_HOST=catalogo-api`, `API_PORT=8000`), sin pasar por el puerto publicado. En la semana 6, al migrar a Kubernetes, ese mapeo desaparece.

### d) Escaneo de vulnerabilidades con Trivy

```bash
❯ docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image <imagen>
```

Escaneo del 16/10/2026. De la API escaneé `catalogo-api:v2`, la imagen vigente: la `v1` del enunciado era la que corría como root (corregido en a).

| Imagen | Total | Sistema base | Python | Con Fixed Version |
|---|---|---|---|---|
| `catalogo-frontend:v1` (Alpine 3.21.3) | 159 | 159 | 0 | 159/159 |
| `catalogo-api:v2` (Debian 13.7) | 184 | 167 | 17 | 20/184 |

- Los 2 CRITICAL del frontend son el mismo `CVE-2026-31789` (openssl) contado dos veces (`libcrypto3`, `libssl3`); con la base parcheada sale en el próximo build.
- 164 de 167 del sistema base no tienen fix publicado (solo xz y pcre2). Las 17 de Python sí: actualizar pip, pymongo y starlette.

## Ejercicio 11

Principio de mínimo privilegio: `cap_drop: [ALL]` en los tres servicios ([Runtime privileges and Linux capabilities](https://docs.docker.com/engine/containers/run/#runtime-privileges-and-linux-capabilities)). Las dos imágenes propias siguen funcionando sin ninguna capability; catalogo-db termina. Errores que fui teniendo, agregando de a una capability por vez y leyendo el error de cada paso:

### 1
```bash
❯ docker compose logs catalogo-db
catalogo-db  | find: '/data/db/diagnostic.data': Permission denied
catalogo-db  | find: '/data/db/.mongodb': Permission denied
catalogo-db  | find: '/data/db/journal': Permission denied
```
Para arreglarlo agregué `cap_add: [DAC_OVERRIDE]`

### 2
```bash
❯ docker compose logs catalogo-db
catalogo-db  | chown: changing ownership of '/data/db/.mongodb/mongosh/6ad172474a4ccd2d16e69977_log': Operation not permitted
catalogo-db  | chown: changing ownership of '/data/db/.mongodb/mongosh/6ad17221c02541b72791c4ae_log': Operation not permitted
catalogo-db  | chown: changing ownership of '/data/db/.mongodb/mongosh/6ad171a3478ba33240ed42a9_log': Operation not permitted
```

Para arreglarlo agregué `cap_add: [DAC_OVERRIDE, CHOWN]`

### 3
```bash
❯ docker compose logs catalogo-db
catalogo-db  | error: failed switching to 'mongodb': operation not permitted
```

Lo arreglé agregando `cap_add: [DAC_OVERRIDE, CHOWN, SETUID, SETGID]`

Con las dos últimas capabilities, `docker compose up -d` levanta y catalogo-db alcanza el estado healthy.

### Lista final

```yml
  catalogo-db:
    cap_drop: [ALL]
    cap_add: [DAC_OVERRIDE, CHOWN, SETUID, SETGID]
  catalogo-api:
    cap_drop: [ALL]
  catalogo-frontend:
    cap_drop: [ALL]
```

```bash
❯ docker compose up -d
[+] up 3/3
 ✔ Container catalogo-db       Healthy                                       6.4s
 ✔ Container catalogo-api      Started                                       0.2s
 ✔ Container catalogo-frontend Started                                       0.2s
```
### Por qué la base requiere capabilities y las otras dos capas no

La imagen oficial de MongoDB arranca como root y se degrada sola al usuario mongodb (vía gosu); antes de eso corrige el ownership de /data/db (`find`/`chown`) para los archivos que no son del usuario mongodb (incluidos los logs de mongosh que deja el healthcheck, que corre como el usuario root de la imagen). Cambiar de identidad pide `SETUID`/`SETGID`; ajustar ownership pide `CHOWN`/`DAC_OVERRIDE`. El orden de los errores es el orden del entrypoint: primero find, después chown, recién al final el switching.

Las imágenes propias arrancan directamente como no-root (appuser y nginx, punto a del ejercicio 10): nunca cambian de identidad ni corrigen ownership, así que `cap_drop: [ALL]` las deja intactas.


