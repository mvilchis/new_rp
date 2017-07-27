#! /bin/sh
#
# main.sh
# Copyright (C) 2017 mvilchis <miguel.vilchis@datos.mx>
#
# Distributed under terms of the MIT license.
#
    docker-compose up -d
    docker cp temba.sql  rapidprodocker_postgresql-rp_1:/tmp/tmp.sql

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


