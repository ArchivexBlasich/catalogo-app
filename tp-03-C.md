## Ejercicio 1

```bash
❯ docker network create catalogo-net e6cd3bcd332a5d36669753fc839854ab32a838631ed72e45429ce798cc940bd9
```

```bash
❯ docker volume create catalogo-db-data
catalogo-db-data
```

Salida deejecutar `docker network ls`

```bash
❯ docker network ls
NETWORK ID     NAME           DRIVER    SCOPE
0df9adf2ec48   bridge         bridge    local
e6cd3bcd332a   catalogo-net   bridge    local
8b58d94ab9f2   host           host      local
bdfd4faebe4c   none           null      local
```

Salida deejecutar `docker volume ls`

```bash
❯ docker volume ls
DRIVER    VOLUME NAME
local     catalogo-db-data
```

## Ejercicio 2

```bash
❯ docker run -d --name catalogo-db \
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

## Ejercicio 3

```bash
❯ docker run -d --name catalogo-api \
     --network catalogo-net \
     -e DB_HOST=catalogo-db \
     -e DB_NAME=catalogodb \
     -e DB_USER=catalogo_user \
     -e DB_PASSWORD=catalogo_pass \
     -e APP_VERSION=v1 \
     -e ROOT_PATH=/api \
     -e SEED_DEMO=true \
     -p 8000:8000 \
     catalogo-api:v1
```

### a)
```bash
❯ docker exec catalogo-api getent hosts catalogo-db
172.18.0.2      catalogo-db
```

### b)
```bash
❯ curl -s localhost:8000/health | jq
{
  "status": "ok",
  "db": "ok",
  "version": "v1"
}
```

### c)
Cantidad de productos sembrados = 12
```bash
❯ curl -s localhost:8000/productos | jq
[
  {
    "sku": 999666,
    "categoria": "Apple",
    "creado_en": "2026-10-04T20:39:54.797000",
    "descripcion": "Clásico de 4.7\" con Touch ID y cuerpo de aluminio.",
    "imagen_hash": "7e23251b780a76a1",
    "imagen_tipo": "image/jpeg",
    "nombre": "Apple iPhone 6 (Gold, 32 GB)",
    "precio": 44000,
    "stock": 2,
    "id": "6ac2b99ae3c60a4b5d4027f7",
    "imagen": true
  },
  {
    "sku": 379182,
    "categoria": "Apple",
    "creado_en": "2026-10-04T20:39:54.803000",
    "descripcion": "Pantalla Retina HD de 5.5\", carga inalámbrica y chip A11.",
    "imagen_hash": "27cf5a0cc72a5c03",
    "imagen_tipo": "image/jpeg",
    "nombre": "Apple iPhone 8 Plus (Silver, 64 GB)",
    "precio": 48000,
    "stock": 6,
    "id": "6ac2b99ae3c60a4b5d4027fd",
    "imagen": true
  },
  {
    "sku": 456654,
    "categoria": "Apple",
    "creado_en": "2026-10-04T20:39:54.787000",
    "descripcion": "Super Retina de 5.8\", Face ID y chip A11 Bionic.",
    "imagen_hash": "8101c6ff7c22f74d",
    "imagen_tipo": "image/jpeg",
    "nombre": "Apple iPhone X (Space Gray, 256 GB)",
    "precio": 25000,
    "stock": 3,
    "id": "6ac2b99ae3c60a4b5d4027ed",
    "imagen": true
  },
  {
    "sku": 963852,
    "categoria": "Asus",
    "creado_en": "2026-10-04T20:39:54.795000",
    "descripcion": "Batería de 4000 mAh que funciona también como power bank.",
    "imagen_hash": "95255abbb146483b",
    "imagen_tipo": "image/jpeg",
    "nombre": "Asus ZenFone Max M1 (Black, 32 GB) (3 GB RAM)",
    "precio": 84000,
    "stock": 0,
    "id": "6ac2b99ae3c60a4b5d4027f5",
    "imagen": true
  },
  {
    "sku": 123222,
    "categoria": "Honor",
    "creado_en": "2026-10-04T20:39:54.791000",
    "descripcion": "Pantalla FullView de 5.84\" con notch y cámara dual de 13 MP.",
    "imagen_hash": "1e45d7360052e1e1",
    "imagen_tipo": "image/jpeg",
    "nombre": "Honor 9N (Midnight Black, 32 GB) (3 GB RAM)",
    "precio": 39000,
    "stock": 11,
    "id": "6ac2b99ae3c60a4b5d4027f1",
    "imagen": true
  },
  {
    "sku": 741852,
    "categoria": "Lenovo",
    "creado_en": "2026-10-04T20:39:54.793000",
    "descripcion": "Procesador Helio X23 de diez núcleos y Android puro.",
    "imagen_hash": "5bf64a1fb53294cd",
    "imagen_tipo": "image/jpeg",
    "nombre": "Lenovo K8 Note (Venom Black, 64 GB) (4 GB RAM)",
    "precio": 36000,
    "stock": 5,
    "id": "6ac2b99ae3c60a4b5d4027f3",
    "imagen": true
  },
  {
    "sku": 357842,
    "categoria": "OPPO",
    "creado_en": "2026-10-04T20:39:54.785000",
    "descripcion": "Lector de huellas bajo la pantalla AMOLED y cámara frontal de 25 MP.",
    "imagen_hash": "24b3652bc891267c",
    "imagen_tipo": "image/jpeg",
    "nombre": "OPPO K1 (Piano Black, 64 GB) (4 GB RAM)",
    "precio": 65000,
    "stock": 6,
    "id": "6ac2b99ae3c60a4b5d4027eb",
    "imagen": true
  },
  {
    "sku": 852369,
    "categoria": "Xiaomi",
    "creado_en": "2026-10-04T20:39:54.777000",
    "descripcion": "Pantalla 5.99\" HD+, cámara dual de 12 MP y batería de 3080 mAh.",
    "imagen_hash": "3926b6235eecc7b3",
    "imagen_tipo": "image/jpeg",
    "nombre": "Redmi Y2 (Black, 32 GB) (3 GB RAM)",
    "precio": 25000,
    "stock": 14,
    "id": "6ac2b99ae3c60a4b5d4027e7",
    "imagen": true
  },
  {
    "sku": 848484,
    "categoria": "Samsung",
    "creado_en": "2026-10-04T20:39:54.801000",
    "descripcion": "Super AMOLED de 6.3\" y cámara dual de 16 MP + 24 MP.",
    "imagen_hash": "6e0b6f7b0f8514c0",
    "imagen_tipo": "image/jpeg",
    "nombre": "Samsung Galaxy A8 Star (White, 64 GB) (6 GB RAM)",
    "precio": 78000,
    "stock": 8,
    "id": "6ac2b99ae3c60a4b5d4027fb",
    "imagen": true
  },
  {
    "sku": 332211,
    "categoria": "Samsung",
    "creado_en": "2026-10-04T20:39:54.799000",
    "descripcion": "Primer smartphone con cuatro cámaras traseras y pantalla de 6.3\".",
    "imagen_hash": "97b0b86fea2f5dc7",
    "imagen_tipo": "image/jpeg",
    "nombre": "Samsung Galaxy A9 (Bubblegum Pink, 128 GB)",
    "precio": 97000,
    "stock": 4,
    "id": "6ac2b99ae3c60a4b5d4027f9",
    "imagen": true
  },
  {
    "sku": 159753,
    "categoria": "Samsung",
    "creado_en": "2026-10-04T20:39:54.783000",
    "descripcion": "Batería de 5000 mAh con carga rápida y pantalla Infinity-V de 6.3\".",
    "imagen_hash": "178a6127bb70f3cb",
    "imagen_tipo": "image/jpeg",
    "nombre": "Samsung Galaxy M20 (Charcoal Black, 4+64GB)",
    "precio": 58000,
    "stock": 9,
    "id": "6ac2b99ae3c60a4b5d4027e9",
    "imagen": true
  },
  {
    "sku": 358426,
    "categoria": "Vivo",
    "creado_en": "2026-10-04T20:39:54.789000",
    "descripcion": "Cámara frontal pop-up de 32 MP y triple cámara trasera de 48 MP.",
    "imagen_hash": "11814686e87c1818",
    "imagen_tipo": "image/jpeg",
    "nombre": "Vivo V15 Pro (Topaz Blue, 128 GB) (6 GB RAM)",
    "precio": 55000,
    "stock": 7,
    "id": "6ac2b99ae3c60a4b5d4027ef",
    "imagen": true
  }
]
```

## Ejercicio 4

### a)
Vuelvo a crear la API con DB_HOST mal escrito, DB_HOST=catalogo-**bd** 
```bash
❯ docker rm -f catalogo-api 
catalogo-api

❯ docker run -d --name catalogo-api \
     --network catalogo-net \
     -e DB_HOST=catalogo-bd \
     -e DB_NAME=catalogodb \
     -e DB_USER=catalogo_user \
     -e DB_PASSWORD=catalogo_pass \
     -e APP_VERSION=v1 \
     -e ROOT_PATH=/api \
     -e SEED_DEMO=true \
     -p 8000:8000 \
     catalogo-api:v1
```

Revisando los logs, veo que hay un error de resolución de nombres:

```bash
docker logs catalogo-api
INFO:     Started server process [1]
INFO:     Waiting for application startup.
[2026-10-04T21:05:30+0000] WARNING intento 1/10 de conexión falló: catalogo-bd:27017: [Errno -3] Temporary failure in name resolution (configured timeouts: socketTimeoutMS: 20000.0ms, connectTimeoutMS: 20000.0ms), Timeout: 3.0s, Topology Description: <TopologyDescription id: 6ac2bf970649992ed12db516, topology_type: Unknown, servers: [<ServerDescription ('catalogo-bd', 27017) server_type: Unknown, rtt: None, error=AutoReconnect('catalogo-bd:27017: [Errno -3] Temporary failure in name resolution (configured timeouts: socketTimeoutMS: 20000.0ms, connectTimeoutMS: 20000.0ms)')>]>
```

## b)
conectarse con mongosh empleando una cadena de conexión sin el parámetro ? authSource=admin y registrar el mensaje, que informará un fallo de autenticación:
```bash
❯ docker run --rm --network catalogo-net mongo:7 \
       mongosh --quiet "mongodb://catalogo_user:catalogo_pass@catalogo-db:27017/catalogo-db"
       
MongoServerError: Authentication failed.
```

### c)
En (a) el fallo es del resolver del cliente: catalogo-bd no existe en el DNS interno de catalogo-net, así que el driver nunca obtuvo una IP ni abrió un socket hacia el motor — la base no fue alcanzada. 
En (b) el error lo devuelve mongod (MongoServerError) después del handshake de autenticación, y para contestar eso ya hubo TCP, server discovery y protocolo exitosos — la base sí fue alcanzada.

## Ejercicio 5

```bash
❯ docker run -d --name catalogo-frontend \
	-e API_HOST=catalogo-api \
	-e API_PORT=8000 \
	-p 3000:8080 \
	catalogo-frontend:v1
```

Registro de `docker ps -a`

```bash
❯ docker ps -a
CONTAINER ID   IMAGE                  COMMAND                  CREATED          STATUS                     PORTS                                         NAMES
52cd3752c247   catalogo-frontend:v1   "/docker-entrypoint.…"   3 seconds ago    Exited (1) 3 seconds ago                                                 catalogo-frontend
```

Registro de `docker logs catalogo-frontend`

```bash
❯ docker logs catalogo-frontend
/docker-entrypoint.sh: /docker-entrypoint.d/ is not empty, will attempt to perform configuration
/docker-entrypoint.sh: Looking for shell scripts in /docker-entrypoint.d/
/docker-entrypoint.sh: Launching /docker-entrypoint.d/10-listen-on-ipv6-by-default.sh
10-listen-on-ipv6-by-default.sh: info: Getting the checksum of /etc/nginx/conf.d/default.conf
10-listen-on-ipv6-by-default.sh: info: /etc/nginx/conf.d/default.conf differs from the packaged version
/docker-entrypoint.sh: Sourcing /docker-entrypoint.d/15-local-resolvers.envsh
/docker-entrypoint.sh: Launching /docker-entrypoint.d/20-envsubst-on-templates.sh
20-envsubst-on-templates.sh: Running envsubst on /etc/nginx/templates/default.conf.template to /etc/nginx/conf.d/default.conf
/docker-entrypoint.sh: Launching /docker-entrypoint.d/30-tune-worker-processes.sh
/docker-entrypoint.sh: Configuration complete; ready for start up
2026/10/04 22:10:30 [emerg] 1#1: host not found in upstream "catalogo-api" in /etc/nginx/conf.d/default.conf:24
nginx: [emerg] host not found in upstream "catalogo-api" in /etc/nginx/conf.d/default.conf:24
```



> [!NOTE] proxy_pass 
> es la directiva de nginx que convierte a nginx en reverse proxy: en vez de
> responder desde su propio filesystem (/usr/share/nginx/html), abre una conexión a otro
> servidor, le pasa el request y devuelve esa respuesta al cliente. El cliente cree que habló
> con nginx; en realidad habló con catalogo-api.

**Por qué el proceso termina en lugar de arrancar en estado degradado**: nginx necesita saber a qué IP corresponde el nombre catalogo-api en el momento en que lee su configuración, o sea al arrancar, porque proxy_pass http://catalogo-api:8000 es una instrucción que tiene que quedar "armada" antes de que el servidor empiece a escuchar; entonces le pregunta al DNS de Docker, y si el contenedor de la API no está corriendo y en la misma red, ese nombre no existe, nginx tira [emerg] host not found in upstream "catalogo-api" y se apaga con error (Exited (1)) sin abrir nunca el puerto 8080. Lo que no hace es arrancar "degradado" (arrancar igual y devolver 502 cuando llegue el request), y la razón es simple: el error le pasó al leer la configuración, no atendiendo un pedido, así que nunca hubo un nginx vivo esperando para reintentar más tarde


## Ejercicio 6

```bash
❯ docker rm catalogo-frontend
catalogo-frontend

❯ docker run -d --name catalogo-frontend \
	--network catalogo-net \
	-e API_HOST=catalogo-api \
	-e API_PORT=8000 \
	-p 3000:8080 \
	catalogo-frontend:v1
38161da2c4fe58f542c015d8158a23f8242fc9d1b62145890315526b295017e3

❯ docker ps -a
CONTAINER ID   IMAGE                  COMMAND                  CREATED          STATUS          PORTS                                         NAMES
38161da2c4fe   catalogo-frontend:v1   "/docker-entrypoint.…"   27 seconds ago   Up 27 seconds   0.0.0.0:3000->8080/tcp, [::]:3000->8080/tcp   catalogo-frontend
```

```txt
Request URL: http://localhost:3000/api/productos
Request method: POST
Status code: 201 Created
```

response: 
```json
{
    "sku": 73413,
    "nombre": "Test mobile phone",
    "precio": 140.0,
    "categoria": "Samsung",
    "stock": 20,
    "descripcion": "Test Description",
    "imagen_tipo": "image/jpeg",
    "imagen_hash": "7e282b2a7996a9a1",
    "creado_en": "2026-10-04T22:50:03.956000",
    "id": "6ac2d81be1a9954eef37eb42",
    "imagen": true
}
```

![[tp3_ejercicio6.png]]

### Observación en la pestaña Network: mismo origen, sin OPTIONS
 El pedido va al mismo origen (localhost:3000): sin origen cruzado no hay CORS, y sin CORS el navegador no manda el preflight OPTIONS.

## Ejercicio 7

### a) `curl -s localhost:8000/productos` vs `curl -s localhost:3000/api/productos`

Ambas consultas devuelven el mismo contenido

|                | `:8000/productos`           | `:3000/api/productos`                                        |
| -------------- | --------------------------- | ------------------------------------------------------------ |
| Quién contesta | `server: uvicorn` (FastAPI) | `Server: nginx/1.27.5`                                       |
| Contenedor     | `catalogo-api`              | `catalogo-frontend` (nginx escuchando 8080 → mapeado a 3000) |
| Body           | 4319 bytes                  | 4319 bytes **idénticos**                                     |
### b)

```bash
❯ curl -s localhost:8000/openapi.json | jq

...
"servers": [
{
  "url": "/api"
}
],
...

```

### c)
```bash
❯ docker rm -f catalogo-api 
catalogo-api

❯ docker run -d --name catalogo-api \
     --network catalogo-net \
     -e DB_HOST=catalogo-db \
     -e DB_NAME=catalogodb \
     -e DB_USER=catalogo_user \
     -e DB_PASSWORD=catalogo_pass \
     -e APP_VERSION=v1 \
     -e ROOT_PATH= \
     -e SEED_DEMO=true \
     -p 8000:8000 \
     catalogo-api:v1
```

El resultado de `curl -s localhost:8000/openapi.json` no contiene ninguna clave `servers` :

 ```bash
 ❯ curl -s localhost:8000/openapi.json | grep 'servers'
 
 ```

### d)

Hay que separar dos cosas que parecen una: **cómo la API atiende los pedidos** y **cómo la API se describe**.

`localhost:3000/api/docs` pasa por nginx, y la barra final de `proxy_pass http://catalogo-api:8000/` **elimina el prefijo `/api`**: la API recibe siempre `/docs`, `/productos`, `/openapi.json`, nunca ve el `/api`. Por eso, cuando arma el HTML de `/docs` y el `openapi.json`, necesita que le declaren ese prefijo con `ROOT_PATH`, y esa declaración es la clave `servers`.

- **Con `ROOT_PATH=/api`**: el HTML de `/docs` pide `/api/openapi.json`, nginx lo reenvía y la documentación carga, con el server `/api` declarado.
- **Con `ROOT_PATH` vacío**: el HTML pide `/openapi.json` (ruta absoluta: se resuelve contra `localhost:3000`, no contra `/api/`); nginx no tiene ningún `location` que sirva el spec, así que cae en el fallback de SPA (`try_files $uri $uri/ /index.html`) y devuelve el `index.html` con **HTTP 200 y `content-type: text/html`**. Swagger UI recibe HTML donde esperaba JSON y muestra `Unable to render this definition`.

Dónde queda escrito ese `/api`, y qué hace el navegador con eso:

| Dónde          | Qué queda escrito            |
| -------------- | ---------------------------- |
| HTML de `/docs` | `url: '/api/openapi.json'`   |
| `openapi.json` | `"servers": [{"url": "/api"}]` |

### Qué hace el navegador con eso

Nada inteligente: ejecuta el JS y sigue la URL que le dieron. El HTML de /docs es un cascarón que trae, entre otras cosas, esto (recolectado de tu contenedor):

```js
  const ui = SwaggerUIBundle({
	  url: '/api/openapi.json',
```

El navegador ejecuta ese bloque, Swagger UI hace fetch('/api/openapi.json'), y acá está la clave: resuelve esa ruta contra el origen de la página, o sea localhost:3000, porque de ahí
vino el HTML. El navegador no sabe que existe catalogo-api: nunca habla con la API
directamente, todo lo pide a nginx.

```
/docs en :3000  → HTML dice url: '/api/openapi.json'
			 → navegador pide  http://localhost:3000/api/openapi.json
			 → nginx: location /api/ → borra /api → API sirve el JSON  ✅
```

Sin root_path, el HTML dice url: '/openapi.json', el navegador pide  http://localhost:3000/openapi.json, eso no cae en location /api/, agarra el fallback de SPA, recibe el index.html (200, text/html) y Swagger UI no puede parsearlo → Unable to render this definition.


## Ejercicio 8

```bash
❯ docker rm -f catalogo-db
catalogo-db
```

```bash
❯ docker volume ls
DRIVER    VOLUME NAME
local     catalogo-db-data
```

```bash
❯ docker run -d --name catalogo-db \
	--network catalogo-net \
	-v catalogo-db-data:/data/db \
	-e MONGO_INITDB_ROOT_USERNAME=catalogo_user \
	-e MONGO_INITDB_ROOT_PASSWORD=catalogo_pass \
	mongo:7
```

```bash
❯ docker restart catalogo-api
catalogo-api
```

```bash
❯ curl -s localhost:8000/productos | jq
[
  {
    "sku": 999666,
    "categoria": "Apple",
    "creado_en": "2026-10-04T20:39:54.797000",
    "descripcion": "Clásico de 4.7\" con Touch ID y cuerpo de aluminio.",
    "imagen_hash": "7e23251b780a76a1",
    "imagen_tipo": "image/jpeg",
    "nombre": "Apple iPhone 6 (Gold, 32 GB)",
    "precio": 44000,
    "stock": 2,
    "id": "6ac2b99ae3c60a4b5d4027f7",
    "imagen": true
  },
  {
    "sku": 379182,
    "categoria": "Apple",
    "creado_en": "2026-10-04T20:39:54.803000",
    "descripcion": "Pantalla Retina HD de 5.5\", carga inalámbrica y chip A11.",
    "imagen_hash": "27cf5a0cc72a5c03",
    "imagen_tipo": "image/jpeg",
    "nombre": "Apple iPhone 8 Plus (Silver, 64 GB)",
    "precio": 48000,
    "stock": 6,
    "id": "6ac2b99ae3c60a4b5d4027fd",
    "imagen": true
  },
  {
    "sku": 456654,
    "categoria": "Apple",
    "creado_en": "2026-10-04T20:39:54.787000",
    "descripcion": "Super Retina de 5.8\", Face ID y chip A11 Bionic.",
    "imagen_hash": "8101c6ff7c22f74d",
    "imagen_tipo": "image/jpeg",
    "nombre": "Apple iPhone X (Space Gray, 256 GB)",
    "precio": 25000,
    "stock": 3,
    "id": "6ac2b99ae3c60a4b5d4027ed",
    "imagen": true
  },
  {
    "sku": 963852,
    "categoria": "Asus",
    "creado_en": "2026-10-04T20:39:54.795000",
    "descripcion": "Batería de 4000 mAh que funciona también como power bank.",
    "imagen_hash": "95255abbb146483b",
    "imagen_tipo": "image/jpeg",
    "nombre": "Asus ZenFone Max M1 (Black, 32 GB) (3 GB RAM)",
    "precio": 84000,
    "stock": 0,
    "id": "6ac2b99ae3c60a4b5d4027f5",
    "imagen": true
  },
  {
    "sku": 123222,
    "categoria": "Honor",
    "creado_en": "2026-10-04T20:39:54.791000",
    "descripcion": "Pantalla FullView de 5.84\" con notch y cámara dual de 13 MP.",
    "imagen_hash": "1e45d7360052e1e1",
    "imagen_tipo": "image/jpeg",
    "nombre": "Honor 9N (Midnight Black, 32 GB) (3 GB RAM)",
    "precio": 39000,
    "stock": 11,
    "id": "6ac2b99ae3c60a4b5d4027f1",
    "imagen": true
  },
  {
    "sku": 741852,
    "categoria": "Lenovo",
    "creado_en": "2026-10-04T20:39:54.793000",
    "descripcion": "Procesador Helio X23 de diez núcleos y Android puro.",
    "imagen_hash": "5bf64a1fb53294cd",
    "imagen_tipo": "image/jpeg",
    "nombre": "Lenovo K8 Note (Venom Black, 64 GB) (4 GB RAM)",
    "precio": 36000,
    "stock": 5,
    "id": "6ac2b99ae3c60a4b5d4027f3",
    "imagen": true
  },
  {
    "sku": 357842,
    "categoria": "OPPO",
    "creado_en": "2026-10-04T20:39:54.785000",
    "descripcion": "Lector de huellas bajo la pantalla AMOLED y cámara frontal de 25 MP.",
    "imagen_hash": "24b3652bc891267c",
    "imagen_tipo": "image/jpeg",
    "nombre": "OPPO K1 (Piano Black, 64 GB) (4 GB RAM)",
    "precio": 65000,
    "stock": 6,
    "id": "6ac2b99ae3c60a4b5d4027eb",
    "imagen": true
  },
  {
    "sku": 852369,
    "categoria": "Xiaomi",
    "creado_en": "2026-10-04T20:39:54.777000",
    "descripcion": "Pantalla 5.99\" HD+, cámara dual de 12 MP y batería de 3080 mAh.",
    "imagen_hash": "3926b6235eecc7b3",
    "imagen_tipo": "image/jpeg",
    "nombre": "Redmi Y2 (Black, 32 GB) (3 GB RAM)",
    "precio": 25000,
    "stock": 14,
    "id": "6ac2b99ae3c60a4b5d4027e7",
    "imagen": true
  },
  {
    "sku": 848484,
    "categoria": "Samsung",
    "creado_en": "2026-10-04T20:39:54.801000",
    "descripcion": "Super AMOLED de 6.3\" y cámara dual de 16 MP + 24 MP.",
    "imagen_hash": "6e0b6f7b0f8514c0",
    "imagen_tipo": "image/jpeg",
    "nombre": "Samsung Galaxy A8 Star (White, 64 GB) (6 GB RAM)",
    "precio": 78000,
    "stock": 8,
    "id": "6ac2b99ae3c60a4b5d4027fb",
    "imagen": true
  },
  {
    "sku": 332211,
    "categoria": "Samsung",
    "creado_en": "2026-10-04T20:39:54.799000",
    "descripcion": "Primer smartphone con cuatro cámaras traseras y pantalla de 6.3\".",
    "imagen_hash": "97b0b86fea2f5dc7",
    "imagen_tipo": "image/jpeg",
    "nombre": "Samsung Galaxy A9 (Bubblegum Pink, 128 GB)",
    "precio": 97000,
    "stock": 4,
    "id": "6ac2b99ae3c60a4b5d4027f9",
    "imagen": true
  },
  {
    "sku": 159753,
    "categoria": "Samsung",
    "creado_en": "2026-10-04T20:39:54.783000",
    "descripcion": "Batería de 5000 mAh con carga rápida y pantalla Infinity-V de 6.3\".",
    "imagen_hash": "178a6127bb70f3cb",
    "imagen_tipo": "image/jpeg",
    "nombre": "Samsung Galaxy M20 (Charcoal Black, 4+64GB)",
    "precio": 58000,
    "stock": 9,
    "id": "6ac2b99ae3c60a4b5d4027e9",
    "imagen": true
  },
  {
    "sku": 73413,
    "nombre": "Test mobile phone",
    "precio": 140.0,
    "categoria": "Samsung",
    "stock": 20,
    "descripcion": "Test Description",
    "imagen_tipo": "image/jpeg",
    "imagen_hash": "7e282b2a7996a9a1",
    "creado_en": "2026-10-04T22:50:03.956000",
    "id": "6ac2d81be1a9954eef37eb42",
    "imagen": true
  },
  {
    "sku": 358426,
    "categoria": "Vivo",
    "creado_en": "2026-10-04T20:39:54.789000",
    "descripcion": "Cámara frontal pop-up de 32 MP y triple cámara trasera de 48 MP.",
    "imagen_hash": "11814686e87c1818",
    "imagen_tipo": "image/jpeg",
    "nombre": "Vivo V15 Pro (Topaz Blue, 128 GB) (6 GB RAM)",
    "precio": 55000,
    "stock": 7,
    "id": "6ac2b99ae3c60a4b5d4027ef",
    "imagen": true
  }
]
```

Hay en total 13 productos luego de eliminar el contenedor de la base y levantarlo de nuevo. El producto cargado en el punto 6 continua disponible con su imagen y con su identificador original

## Ejercicio 9

### Orden de arranque (contenido para el README.md)

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

El orden no vive en ningún archivo ejecutable: hoy reside en la memoria de quien levanta la aplicación, que debe recordar la secuencia y los `--network`. Se resuelve la semana siguiente, declarando las cinco etapas en un único archivo de Compose, donde el orden queda escrito y Docker lo respeta con `depends_on`.
