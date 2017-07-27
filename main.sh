#! /bin/bash

POSTGRES_CONTAINER="postgres-prueba-rp"
RAPIDPRO_CONTAINER="rapidpro-prueba-rp"
CELERYB_CONTAINER="celery-beat-rp"
CELERYH_CONTAINER="celery-handler-rp"
CELERYF_CONTAINER="celery-flow-rp"
CELERYM_CONTAINER="celery-msgs-rp"


REDIS_CONTAINER="redis-prueba-rp"
PATH_RAPIDPRO="./rapidpro"
RAPIPRO_IMAGE="mvilchis/rapidpro:v1.4.26"
POSTGRES_IMAGE="mvilchis/postgres-rp:v1.0"
##########################################################
#             Remove all old dockers
function remove  {
  for i in "${containers[@]}"
  do
    docker rm -f i
  done
}
function pp() {
echo $POSTGRES_MEM
}
##########################################################
#             First create Docker of postgres

function  create_postgres(){

  is_running=`docker ps -a --format "{{.Names}}"|grep "${POSTGRES_CONTAINER}"`
  if [ -z "$is_running" ]; then
    docker run --name $POSTGRES_CONTAINER --memory=$POSTGRES_MEM -e TEMBAPASSWD=supersecret -d $POSTGRES_IMAGE ||{
      echo "$POSTGRES_CONTAINER error"
    }
    sleep 20s
    docker cp temba.sql  $POSTGRES_CONTAINER:/tmp/tmp.sql
    remove_temba="UPDATE pg_database SET datistemplate='false' WHERE datname='temba'; DROP DATABASE temba;"
    create_temba="CREATE DATABASE temba"
    update_temba="psql temba < /tmp/tmp.sql"
    docker exec -i  $POSTGRES_CONTAINER psql -U postgres <<EOF
    $remove_temba
    $create_temba
EOF
    docker exec -i  $POSTGRES_CONTAINER   bash <<EOF
    su postgres
    psql
    $update_temba
EOF
  else
    echo "$POSTGRES_CONTAINER corriendo"
  fi
}

function init_celery() {
  celery_name="$1"
  celery_flags="$2"
  is_running=`docker ps --format "{{.Names}}"|grep "${celery_name}"`
  if [ -z "$is_running" ]; then
    docker run  --name $celery_name --link $POSTGRES_CONTAINER:postgres --link $REDIS_CONTAINER:redis \
    -e SEND_MAIL=True \
    -e DEBUG=False \
    -e EMAIL_HOST_USER=rapidpro@email.com \
    -e EMAIL_HOST_PASSWORD=supersecret \
    -e DEFAULT_LANGUAGE=es \
    -e SEND_WEBHOOKS=True  \
    -e SECRET_KEY=supersecret \
    -e CONTAINER_INIT=start_celery.sh \
    -e SEND_MESSAGES=True \
     $celery_flags -d $RAPIPRO_IMAGE
  else
    echo "$RAPIDPRO_CONTAINER corriendo"
  fi

}

function connect_containers() {
  result=`docker images --format "{{.Repository}}:{{.Tag}}" | grep "$RAPIPRO_IMAGE"`

  is_running=`docker ps --format "{{.Names}}"|grep "${RAPIDPRO_CONTAINER}"`
  if [ -z "$is_running" ]; then
    docker run --name $REDIS_CONTAINER -p 6379:6379 -d redis &> /dev/null ||{
      echo "Redis ya esta corriendo"
    }
    docker run  --name $RAPIDPRO_CONTAINER --link $POSTGRES_CONTAINER:postgres --link $REDIS_CONTAINER:redis \
    -e SEND_MAIL=True \
    -e DEBUG=False \
    -e EMAIL_HOST_USER=rapidpro@email.com \
    -e EMAIL_HOST_PASSWORD=supersecret \
    -e DEFAULT_LANGUAGE=es \
    -e SEND_WEBHOOKS=True  \
    -e SECRET_KEY=supersecret \
    -e CONTAINER_INIT=start_rapidpro.sh \
    -e SEND_MESSAGES=True -p 8000:8000 -d $RAPIPRO_IMAGE
  else
    echo "$RAPIDPRO_CONTAINER corriendo"
  fi
   init_celery $CELERYB_CONTAINER "-e CELERY_BEAT=True -e CELERY_WORKERS=8  -p 5555:5555"
   init_celery $CELERYH_CONTAINER "-e CELERY_WORKERS=8  -e CELERY_QUEUE=handler"
   init_celery $CELERYF_CONTAINER "-e CELERY_WORKERS=6  -e CELERY_QUEUE=flows"
   init_celery $CELERYM_CONTAINER "-e CELERY_WORKERS=12 -e CELERY_QUEUE=msgs"
  }


function main() {
  POSTGRES_MEM="2G"
      create_postgres;
      connect_containers; }

main "$@"
