## Ejercicio 3

#### a) Registrar la salida de docker ps:
```bash
catalogo-app on 🌿 main ❯  docker ps -a
CONTAINER ID   IMAGE     COMMAND                  CREATED          STATUS          PORTS       NAMES
76373c503259   mongo:7   "docker-entrypoint.s…"   43 seconds ago   Up 43 seconds   27017/tcp   catalogo-db
```

#### b) Listar las bases existentes con mongosh, sin proporcionar credenciales, y consignar el resultado

```bash
catalogo-app on 🌿 main ❯  docker exec -it catalogo-db bash
root@76373c503259:/# mongosh
Current Mongosh Log ID:	6ab44631e6721fb2663c885d
Connecting to:		mongodb://127.0.0.1:27017/?directConnection=true&serverSelectionTimeoutMS=2000&appName=mongosh+2.10.0
Using MongoDB:		7.0.40
Using Mongosh:		2.10.0

For mongosh info see: https://www.mongodb.com/docs/mongodb-shell/

------
   The server generated these startup warnings when booting
   2026-09-23T21:30:02.809+00:00: Using the XFS filesystem is strongly recommended with the WiredTiger storage engine. See http://dochub.mongodb.org/core/prodnotes-filesystem
   2026-09-23T21:30:03.862+00:00: Access control is not enabled for the database. Read and write access to data and configuration is unrestricted
   2026-09-23T21:30:03.863+00:00: Soft rlimits for open file descriptors too low
------

test> show dbs
admin    40.00 KiB
config  108.00 KiB
local    40.00 KiB
test> db
test
test> show collections

test> _
```

##### Explicar, en dos o tres líneas, por qué esta situación resulta más riesgosa que un contenedor que se detiene con un mensaje de error.

A cambio de otras imágenes como la de motores como PostgreSQL que te piden obligatoriamente pasar como variable de entorno la contraseña del superusuario,
en mongo esto no es obligación, este contenedor arranca y acepta conexiones sin pedir credenciales, lo cual es un problema grave de seguridad, pues cualquiera podría 
ver los datos almacenados en nuestra db


## Ejercicio 4

Variables de entorno que crean el usuario inicial:

```txt
  MONGO_INITDB_ROOT_USERNAME, MONGO_INITDB_ROOT_PASSWORD
```

These variables, used in conjunction, create a new user and set that user's password. This user is created in the admin authentication database and given the role of root, which is a "superuser" role

```bash
catalogo-app on 🌿 main ❯ docker run -d  --name catalogo-db \
        -e MONGO_INITDB_ROOT_USERNAME=catalogo_user \
        -e MONGO_INITDB_ROOT_PASSWORD=catalogo_pass \
        mongo:7
00b5542cbd87a62b8e40e86bc39396b4857d282de86a61c1b6e7e3af216957b7
```

Salida de `docker logs -f`, recortada hasta el mensaje que indica que el servidor espera conexiones:

```bash
catalogo-app on 🌿 main ❯ docker logs -f catalogo-db
about to fork child process, waiting until server is ready for connections.
forked process: 28
{"t":{"$date":"2026-09-26T03:19:52.261+00:00"},"s":"I",  "c":"NETWORK",  "id":23015,   "ctx":"listener","msg":"Listening on","attr":{"address":"0.0.0.0"}}
{"t":{"$date":"2026-09-26T03:19:52.261+00:00"},"s":"I",  "c":"NETWORK",  "id":23016,   "ctx":"listener","msg":"Waiting for connections","attr":{"port":27017,"ssl":"off"}}
^C
```

El mensaje que confirma que el motor está listo es `"msg":"Waiting for connections"`.

Cuando añadimos las variables de entorno, ahora cuando entramos al servicio de mongo, no tenemos autorización y no estamos logeados, recibimos este error: MongoServerError[Unauthorized]

```bash
catalogo-app on 🌿 main ❯ docker exec -it catalogo-db bash
root@69f310492bb1:/# mongosh
Current Mongosh Log ID: 6ab490be409f64cbbc9e0c46
Connecting to:          mongodb://127.0.0.1:27017/?directConnection=true&serverSelectionTimeoutMS=2000&appName=mongosh+2.10.0
Using MongoDB:          7.0.40
Using Mongosh:          2.10.0

For mongosh info see: https://www.mongodb.com/docs/mongodb-shell/


To help improve our products, anonymous usage data is collected and sent to MongoDB periodically (https://www.mongodb.com/legal/privacy-policy).
You can opt-out by running the disableTelemetry() command.

test> show dbs
MongoServerError[Unauthorized]: Command listDatabases requires authentication
test> db
test
test> show collections
MongoServerError[Unauthorized]: Command listCollections requires authentication
test>
```

Ahora bien, si usamos el servicio de mongo, pasando las credenciales correspondientes (mongosh -u catalogo_user -p catalogo_pass) ya nos autenticamos:

```bash
docker exec -it catalogo-db bash
root@69f310492bb1:/# mongosh -u catalogo_user -p catalogo_pass
Current Mongosh Log ID: 6ab4922ab956980be430f6d5
Connecting to:          mongodb://<credentials>@127.0.0.1:27017/?directConnection=true&serverSelectionTimeoutMS=2000&appName=mongosh+2.10.0
Using MongoDB:          7.0.40
Using Mongosh:          2.10.0

For mongosh info see: https://www.mongodb.com/docs/mongodb-shell/

------
  The server generated these startup warnings when booting
  2026-09-24T02:53:38.597+00:00: Using the XFS filesystem is strongly recommended with the WiredTiger storage engine. See http://dochub.mongodb.org/core/prodnotes-filesystem
  2026-09-24T02:53:39.301+00:00: Soft rlimits for open file descriptors too low
------

test> show dbs
admin   100.00 KiB
config   12.00 KiB
local    72.00 KiB
test> show collections

test>
```

## Ejercicio 5

##### a) Ping Administrativo

En ambos contenedores al que se le proporcionaron las variables de entorno con las credenciales y al que no, al hacer el ping obtenemos:
```bash
test> db.adminCommand({ ping: 1 })
{ ok: 1 }
test>
```
El ping no resulta rechazado porque mongod lo atiende antes del login. Solo confirma que el proceso está vivo y no expone ningún dato. Sirve principalmente para HealthCheck

##### b) Listado de bases de datos

Es el mismo comando ya ejecutado en el punto 4, así que el mensaje transcripto ahí sigue siendo válido:
```txt
MongoServerError[Unauthorized]: Command listDatabases requires authentication
```
A diferencia del ping, este comando muestra qué bases existen y cuánto ocupan, y por eso exige autenticación. Esa asimetría es la que va a definir las comprobaciones de estado de la semana 4: como el ping responde sin credenciales, sirve para saber si mongod está arriba. Con el ping devolviendo ok y el listado rechazado, queda verificado que la autenticación está efectivamente habilitada.

## Ejercicio 6

##### a) Cadena de conexión sin base de autenticación

```bash
docker exec catalogo-db mongosh "mongodb://catalogo_user:catalogo_pass@127.0.0.1:27017/catalogodb"
Current Mongosh Log ID: 6ab5e0a6b9036de885cebd32
Connecting to:          mongodb://<credentials>@127.0.0.1:27017/catalogodb?directConnection=true&serverSelectionTimeoutMS=2000&appName=mongosh+2.10.0
MongoServerError: Authentication failed.
```

##### b) Cadena de conexión con el parámetro ?authSource=admin

```bash
docker exec catalogo-db mongosh "mongodb://catalogo_user:catalogo_pass@127.0.0.1:27017/catalogodb?authSource=admin"
Current Mongosh Log ID: 6ab5e0be8e51b7deef8d6f7e
Connecting to:          mongodb://<credentials>@127.0.0.1:27017/catalogodb?authSource=admin&directConnection=true&serverSelectionTimeoutMS=2000&appName=mongosh+2.10.0
Using MongoDB:          7.0.40
Using Mongosh:          2.10.0

For mongosh info see: https://www.mongodb.com/docs/mongodb-shell/

------
   The server generated these startup warnings when booting
   2026-09-25T02:40:53.973+00:00: Using the XFS filesystem is strongly recommended with the WiredTiger storage engine. See http://dochub.mongodb.org/core/prodnotes-filesystem
   2026-09-25T02:40:54.663+00:00: Soft rlimits for open file descriptors too low
------

catalogodb>
```

##### Explicación de la diferencia

El usuario creado por las variables de entorno de la imagen reside en la base de autenticación admin. El parámetro authSource le indica al motor contra qué base validar la credencial, y su valor por defecto es la base que aparece en el path de la cadena de conexión, o admin cuando no se especifica ninguna. En el caso a) las credenciales se buscan en catalogodb, no se encuentran y la conexión termina en Authentication failed; en el caso b) se buscan en admin y la autenticación pasa.

Vale aclarar que el problema no es que la base catalogodb no exista: las bases en MongoDB se crean de forma perezosa, con el primer dato escrito, y la autenticación no necesita que la base del authSource exista. Lo que el motor busca es la credencial dentro de ese espacio de autenticación, y ahí no hay ninguna con ese nombre. Una prueba de esto es que, si la URI no nombra ninguna base en el path (mongodb://catalogo_user:catalogo_pass@127.0.0.1:27017/), el authSource por defecto vuelve a ser admin y el resultado es el mismo con o sin el parámetro. Esa redundancia desaparece en cuanto la URI incluye la base de la aplicación, que es el caso real: backend/main.py arma mongodb://usuario:pass@host:puerto/catalogodb?authSource=admin justamente por este motivo.


## Ejercicio 7

Las variables de entorno quedan almacenadas en texto plano en la configuración del contenedor (no dentro de la imagen), lo cual es un problema de seguridad grave: cualquiera con acceso al daemon de Docker puede leerlas con `docker inspect` o `docker exec catalogo-db env`, y la contraseña también queda en el historial del shell que ejecutó `docker run`.

```bash
docker inspect --format '{{json .Config.Env}}' catalogo-db | jq
[
  "MONGO_INITDB_ROOT_USERNAME=catalogo_user",
  "MONGO_INITDB_ROOT_PASSWORD=catalogo_pass",
  "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
  "GOSU_VERSION=1.19",
  "JSYAML_VERSION=3.13.1",
  "JSYAML_CHECKSUM=662e32319bdd378e91f67578e56a34954b0a2e33aca11d70ab9f4826af24b941",
  "MONGO_PACKAGE=mongodb-org",
  "MONGO_REPO=repo.mongodb.org",
  "MONGO_MAJOR=7.0",
  "MONGO_VERSION=7.0.40",
  "HOME=/data/db"
]
```

## Ejercicio 8

#### Insertar y contar
```bash
docker exec catalogo-db mongosh "mongodb://catalogo_user:catalogo_pass@127.0.0.1:27017/catalogodb?authSource=admin" --quiet --eval \
     'db.prueba.insertOne({nota:"test de persistencia", fecha:new Date()}); print("Documentos: " + db.prueba.countDocuments())'
     
Documentos: 1
```

#### Eliminar el contenedor
```bash
docker rm -f catalogo-db
```

#### Recrear con el comando del punto 4 y volver a contar
```bash
docker run -d --name catalogo-db \
     -e MONGO_INITDB_ROOT_USERNAME=catalogo_user \
     -e MONGO_INITDB_ROOT_PASSWORD=catalogo_pass \
     mongo:7
6888690a3d1ca42e48cc9c4f6fdeefdefc7ee02ea9db5814896973005c68a049

docker exec catalogo-db mongosh "mongodb://catalogo_user:catalogo_pass@127.0.0.1:27017/catalogodb?authSource=admin" --quiet --eval \
     'print("Documentos: " + db.prueba.countDocuments())'
Documentos: 0
```

##### Explicación

El contenedor se creó sin ningún volumen montado, así que todo lo que escribe MongoDB queda en su capa de escritura. `docker rm -f` elimina el contenedor junto con esa capa, y el contenedor nuevo arranca con el directorio de datos vacío: por eso el mismo documento pasa a contar 0. La persistencia recién se logra cuando ese path se respalda con un volumen.