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