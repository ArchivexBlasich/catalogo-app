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
