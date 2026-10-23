## Arquitectura

    navegador ──► catalogo-frontend ──────► catalogo-api ──────► catalogo-db
                  React + Vite               Python + FastAPI     MongoDB 7
                  nginx :8080                :8000                :27017
                  (host 3000)                (host 8000, solo     (sin puerto
                                              depuración)          publicado)

| Capa | Imagen | Puerto interno | Puerto publicado |
| --- | --- | --- | --- |
| `catalogo-frontend` | React + Vite servido por nginx | 8080 | 3000 |
| `catalogo-api` | Python + FastAPI | 8000 | 8000 (solo depuración) |
| `catalogo-db` | MongoDB 7 | 27017 | — |

El frontend es el único punto de entrada: nadie le habla a la base
directamente, y a la API le habla el frontend.

## Autenticación de MongoDB

La cadena de conexión debe incluir `?authSource=admin`. El usuario root que crea la
imagen oficial (`MONGO_INITDB_ROOT_USERNAME` y `MONGO_INITDB_ROOT_PASSWORD`) vive en
la base `admin`, y `authSource` toma por defecto la base que aparece en el path de la
URI. Con `mongodb://usuario:pass@host:27017/catalogodb` la autenticación falla con
`Authentication failed.` aunque las credenciales sean correctas.

El entrypoint de nginx construye una lista con los **nombres** de las variables de entorno que matchean `^API_` y la pasa como `SHELL-FORMAT` a `envsubst`: solo se sustituye esa lista. Así `API_HOST` y `API_PORT` se resuelven al arrancar el contenedor, y ninguna variable de entorno puede pisar variables propias de nginx (`$uri`, `$host`, `$proxy_add_x_forwarded_for`). Sin el filtro, cualquier nombre de variable de entorno que coincida con una variable de nginx se reemplaza por su valor.

## TP3 – Ejercicio 2: base de datos

```bash
docker run -d --name catalogo-db \
	--network catalogo-net \
	-v catalogo-db-data:/data/db \
	-e MONGO_INITDB_ROOT_USERNAME=catalogo_user \
	-e MONGO_INITDB_ROOT_PASSWORD=catalogo_pass \
	mongo:7
```


### Línea del registro que informa que el motor se encuentra a la espera de conexiones

```json
{"t":{"$date":"..."},"s":"I", "c":"NETWORK", "id":23016, "ctx":"listener",
"msg":"Waiting for connections","attr":{"port":27017,"ssl":"off"}}
```

### Por qué no se publica ningún puerto

El parámetro -p crea la regla que expone el puerto en el anfitrión, por defecto en todas
sus interfaces (0.0.0.0). Sin -p el contenedor no ocupa ningún puerto del anfitrión y solo lo alcanzan los contenedores de catalogo-net, donde se resuelve por nombre.

La base es la capa más interna, con un solo cliente: catalogo-api, que la busca como
catalogo-db:27017. Un puerto publicado no lo consume nadie y agrega una capa de seguridad


## Orden de arranque

```bash
docker network create catalogo-net                                 # 1 red
docker volume create catalogo-db-data                              # 2 volumen
docker run -d --name catalogo-db \
	--network catalogo-net \
	-v catalogo-db-data:/data/db \
	-e MONGO_INITDB_ROOT_USERNAME=catalogo_user \
	-e MONGO_INITDB_ROOT_PASSWORD=catalogo_pass \
	mongo:7                                                        # 3 base
docker run -d --name catalogo-api \
     --network catalogo-net \
     -e DB_HOST=catalogo-db \
     -e DB_NAME=catalogodb \
     -e DB_USER=catalogo_user \
     -e DB_PASSWORD=catalogo_pass \
     -e APP_VERSION=v1 \
     -e ROOT_PATH=/api \
     -e SEED_DEMO=true \
     -p 8000:8000 \
     catalogo-api:v1                                               # 4 API
docker run -d --name catalogo-frontend \
	--network catalogo-net \
	-e API_HOST=catalogo-api \
	-e API_PORT=8000 \
	-p 3000:8080 \
	catalogo-frontend:v1                                           # 5 frontend
```

### Qué falla al invertir cada paso

- **Red después de los contenedores:** quedan en la red `bridge` por defecto y `getent hosts catalogo-db` no resuelve; la API falla por resolución de nombre, no por credenciales, y no se corrige reiniciando: hay que conectar o recrear el contenedor.
- **Volumen después de la base:** `-v` solo se aplica al crear el contenedor. Sin volumen, `/data/db` queda en la capa escribible y `docker rm -f catalogo-db` se lleva el producto cargado del punto 6. Y sobre un volumen ya inicializado, `MONGO_INITDB_*` no se reaplica: el motor sigue aceptando la contraseña anterior.
- **API antes que la base:** arranca igual, pero la poblacion inicial a la db y las consultas fallan (`/health` con `db` en error). Cuando la base aparece después (o se recrea con otra IP) hay que reiniciar la API para que vuelva a resolver el nombre.
- **Frontend antes que la API:** nginx resuelve el `upstream` una sola vez, al leer su configuración, así que muere con `[emerg] host not found in upstream "catalogo-api"` y `Exited (1)`; no queda degradado esperando reintentos.

### Limitación registrada

El orden no vive en ningún archivo ejecutable: hoy reside en la memoria de quien levanta la aplicación, que debe recordar la secuencia y los `--network`. 

## TP4 – Ejercicio 2: healthcheck de catalogo-db

```yaml
healthcheck:
  test:
    - CMD-SHELL
    - mongosh --quiet --eval "db.adminCommand('ping').ok" || exit 1
  interval: 5s
  timeout: 3s
  retries: 10
  start_period: 10s
```

### Por qué no lleva credenciales

`ping` es uno de los pocos comandos que no requieren autenticación: alcanza para confirmar que el proceso `mongod` está levantado y aceptando conexiones, que es todo lo que el check necesita. `mongosh` ya viene incluido en la imagen `mongo:7`, así que tampoco agrega dependencias.

La ventaja frente a la variante B, donde el check autentica y la contraseña debe viajar en el comando: acá el secreto no queda escrito en el `docker-compose.yml` ni visible en la configuración del contenedor (`docker inspect` la mostraría). Vive únicamente en el `.env`, y el healthcheck sigue siendo válido aunque las credenciales roten.

### Qué no verifica

Que `ping` responda no prueba que `catalogo_user` exista ni que la contraseña configurada sea la correcta: eso recién se valida cuando la API autentica con sus credenciales reales. La contracara es que la base puede figurar `healthy` y la API fallar igual con `Authentication failed` — el caso típico es un volumen ya inicializado (el de la semana 3) con `MONGO_INITDB_ROOT_PASSWORD` modificada, porque las variables `MONGO_INITDB_*` solo se aplican sobre un volumen vacío. Un healthcheck verifica lo que verifica, no que todo funcione.

## TP4 – Ejercicio 3: healthcheck de catalogo-api

```yaml
healthcheck:
  test:
    - CMD
    - python
    - -c
    - "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health')"
```

El check corre dentro del propio contenedor (por eso apunta a `127.0.0.1`) y cada `interval` lanza un proceso Python: si la URL falla, la excepción termina el proceso con exit code != 0 y el contenedor pasa a `unhealthy`; el 200 de `GET /health` deja exit 0 y `healthy`. Confirma que el proceso vive y que el endpoint contesta; no reemplaza la verificación funcional de la app.

### Por qué no se instala curl solo para el healthcheck

Podría usarse: no hay limitación de capacidad y el efecto es el mismo que el de `urllib`. El problema es dónde corre el check: la imagen de la API se construye sobre `python:3.12-slim`, que no trae el binario `curl`, así que usarlo obliga a agregarlo como dependencia del Dockerfile (`apt-get install -y curl`): una capa más, decenas de MB en la imagen, y un binario con CVEs propios para vigilar aunque la app nunca lo ejecute. `urllib` viene incluido con el intérprete de Python (biblioteca estándar): cero dependencias nuevas, mismo resultado.

## TP4 – Ejercicio 4: healthcheck del frontend

```yaml
healthcheck:
  test: ["CMD-SHELL", "wget -q -O - http://127.0.0.1:8080/healthz"]
  interval: 15s
  timeout: 5s
  retries: 3
  start_period: 10s
```

La imagen se construye sobre `nginxinc/nginx-unprivileged:1.27-alpine`: BusyBox ya está presente en Alpine y aporta `wget`, así que el check no agrega ninguna dependencia a la imagen. `/healthz` es una `location` dedicada de nginx que responde 200 sin consultar el upstream.

## TP4 – Ejercicio 5: depends_on con condición

```yaml
# catalogo-api

depends_on:
  catalogo-db:
    condition: service_healthy

# catalogo-frontend

depends_on:
  - catalogo-api
```

Los dos casos no son equivalentes: cada capa necesita algo distinto de la que tiene debajo. La forma corta `depends_on: [X]` garantiza **orden** (el contenedor de X está *running*); `condition: service_healthy` garantiza **orden y salud** (el healthcheck de X da *healthy*).

| | a) API → DB | b) Frontend → API |
| --- | --- | --- |
| Qué necesita al arrancar | Que MongoDB **acepte conexiones**, para conectar y sembrar | Que el **nombre resuelva** en el DNS de la red |
| Sin `depends_on` | `ServerSelectionTimeoutError` | nginx muere: `host not found in upstream` (Exited (1)) |
| ¿Alcanza la forma corta? | No: *running* ≠ aceptando conexiones | Sí: con orden basta, el nombre ya resuelve |
| `service_healthy` | Necesario: el `ping` del Ej. 2 es la señal de «acepta conexiones» | Mejora: arranca con la API funcionando, sin 502 en los primeros segundos |

a) `catalogo-api` respecto de `catalogo-db`: `mongod` está *running* varios segundos antes de aceptar conexiones (inicialización interna, creación de usuarios), así que la forma corta no alcanza. La API reintenta la conexión unos 30 s por sí sola: eso complementa al `depends_on`, no lo reemplaza — y es lo único que subsistirá en Kubernetes, donde no existe `depends_on`.

b) `catalogo-frontend` respecto de `catalogo-api`: nginx resuelve el `upstream` una sola vez, al leer su configuración; si el nombre no resuelve, termina sin reintentos. Lo que no puede faltar es *algún* `depends_on`; la forma corta ya salva ese crash, y `service_healthy` agrega que arranque con la API ya en funcionamiento.

## TP4 – Ejercicio 7: ciclo de vida de los datos

```bash
docker compose down                      # contenedores y red fuera
docker compose up -d                     # vuelve a levantar
curl -s localhost:3000/api/productos | jq length   # 13: los productos sobrevivieron
docker compose down -v                   # además elimina catalogo-db-data
```

| | Contenedores | Red | Volumen `catalogo-db-data` |
| --- | --- | --- | --- |
| `down` | elimina | elimina | **conserva** |
| `down -v` | elimina | elimina | **elimina** |

Los productos viven en el volumen, que `down` no toca: por eso sobreviven al reinicio. `down -v` lo elimina y el próximo `up` vuelve a sembrar los 12 del demo (`SEED_DEMO=true`). Para conservar el catálogo de las semanas anteriores, el `down -v` se ejecuta al final — o sobre una copia.

## TP4 – Ejercicio 8: idempotencia de la siembra

Con la base poblada (13 productos: 12 del seed + 1 de prueba), `docker compose up -d --force-recreate catalogo-api` recrea la API y el conteo sigue en 13: la siembra no duplica. Realiza un **upsert por nombre** a propósito, porque en la semana 6 arrancarán tres réplicas de la API al mismo tiempo y las tres ejecutarán la siembra.

## TP4 – Ejercicio 9: contrato de variables

`.env.example` documenta las variables de las tres capas con comentarios que indican qué componente consume cada una, y `.env` figura en el `.gitignore`. Se optó por las variables `DB_*` por separado en lugar de `MONGO_URI`: si se usara `MONGO_URI`, la cadena completa — incluida la contraseña — tendría que viajar entera en el Secret de la semana 7, nunca en un ConfigMap. Con `DB_*`, las sensibles son `MONGO_INITDB_ROOT_PASSWORD` y `DB_PASSWORD`, con la misma condición para la semana 7.

## TP4 – Ejercicio 10: revisión de seguridad

| Chequeo | catalogo-db | catalogo-api | catalogo-frontend |
| --- | --- | --- | --- |
| Usuario del contenedor | root (imagen oficial; se degrada a `mongodb` vía gosu) | `uid=1000(appuser)` | `uid=101(nginx)` |
| Puertos publicados | ninguno (`27017/tcp` solo dentro de la red) | `0.0.0.0:8000→8000` | `0.0.0.0:3000→8080` |

- Las dos imágenes propias informan un usuario distinto de root. La API no salió así de entrada: con `v1.dockerfile` corría como root; el fix fue pasar el compose a `v2.dockerfile` (crea `appuser` y `USER appuser`). El frontend usa `nginxinc/nginx-unprivileged`, que corre como UID 101 de fábrica.
- La base de datos no publica ningún puerto: el servicio no declara `ports`, y su único cliente (`catalogo-api`) la alcanza por la red.
- El `8000` de la API se publica solo con fines de depuración (`curl` directo a `/health`, consola). Su único consumidor real es el frontend, que no pasa por el puerto publicado; en la semana 6 pasa a ser interno.

### Escaneo de vulnerabilidades con Trivy (16/10/2026)

| Imagen | Total | Del sistema base | De dependencias Python | Con Fixed Version |
| --- | --- | --- | --- | --- |
| `catalogo-frontend:v1` (Alpine 3.21.3) | 159 | 159 | 0 | 159 |
| `catalogo-api:v2` (Debian 13.7) | 184 | 167 | 17 | 20 |

- Frontend: los 2 CRITICAL son el mismo `CVE-2026-31789` (openssl) contado dos veces (`libcrypto3` y `libssl3`); con la base parcheada sale en el próximo build.
- API: 164 de las 167 del sistema base no tienen fix publicado (solo `xz` y `pcre2`); las 17 de Python sí — actualizar `pip`, `pymongo` y `starlette`.

## TP4 – Ejercicio 11: mínimo privilegio

```yaml
catalogo-db:
  cap_drop: [ALL]
  cap_add: [DAC_OVERRIDE, CHOWN, SETUID, SETGID]

catalogo-api:
  cap_drop: [ALL]

catalogo-frontend:
  cap_drop: [ALL]
```

Con `cap_drop: [ALL]`, las dos imágenes propias siguen funcionando: arrancan directamente como no-root y no necesitan ninguna capability. `catalogo-db` terminó; las capabilities se agregaron de a una, leyendo el error en cada paso, en el orden en que falla el entrypoint:

1. `find: '/data/db/...': Permission denied` → `DAC_OVERRIDE`
2. `chown: changing ownership of '/data/db/.mongodb/...': Operation not permitted` → `CHOWN`
3. `error: failed switching to 'mongodb': operation not permitted` → `SETUID, SETGID`

Con las cuatro, `docker compose up -d` levanta y `catalogo-db` alcanza el estado *healthy*.

### Por qué la base requiere capabilities y las otras dos capas no

La imagen oficial de MongoDB arranca como root y se degrada sola al usuario `mongodb` (vía gosu); antes de eso corrige con `find`/`chown` el ownership de `/data/db` para los archivos que no son del usuario `mongodb` — incluidos los logs de mongosh que deja el healthcheck. Cambiar de identidad pide `SETUID`/`SETGID`; ajustar ownership pide `CHOWN`/`DAC_OVERRIDE`. El orden de los errores es el orden del entrypoint: primero `find`, después `chown`, recién al final el *switching*.

Las imágenes propias nunca cambian de identidad ni corrigen ownership: arrancan y corren como `appuser` y `nginx` de entrada, así que `cap_drop: [ALL]` las deja intactas.

## TP4 – Ejercicio 12: docker-compose.yml frente a los tres docker run

| Semana 3 (tres `docker run` a mano) | TP4 (`docker-compose.yml`) |
| --- | --- |
| La secuencia y los `--network` viven en la memoria de quien levanta | El orden vive en el archivo: `depends_on` + healthchecks |
| `docker network create` y `docker volume create` a mano | Red y volumen declarados, con `name:` explícito para ser los mismos |
| Espera manual entre la base y la API | `condition: service_healthy` elimina la espera |
| Variables `-e` repetidas en cada comando | Centralizadas en `.env`, con contrato documentado en `.env.example` |
| Sin estados de salud: se mira `docker logs` a ojo | Healthchecks por servicio, *healthy* visible en `docker compose ps` |
| Privilegios sin revisar | `cap_drop: [ALL]` y `cap_add` mínimo en la base |
| Sin validación previa | `docker compose config` valida antes de levantar |
| Un comando por capa, en el orden correcto | `docker compose up --build -d` / `docker compose down` |

Desapareció lo manual y lo mnemónico: esto resuelve la limitación registrada de la semana 3, donde el orden residía en la memoria de quien levanta la aplicación. Apareció lo declarativo: un único archivo versionado en git que describe la arquitectura completa, se valida antes de ejecutar y queda como referencia contra la que se compararán los manifiestos de Kubernetes desde la semana 5.