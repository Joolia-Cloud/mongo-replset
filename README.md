# mongo-replset
A single instance MongoDB ReplicaSet

# Description
This repo is based on the "official" MongoDB-Docker-Repository (https://github.com/docker-library/mongo) and should only be used for testing or local development.

This Docker image starts up the database and initializes a MongoDB ReplicaSet (https://docs.mongodb.com/manual/replication/) named 'joolia'. If you have to override the `COMMAND` of the `docker run` command, make sure to include the two parameters `--replSet joolia --bind_ip_all`. Otherwise this image won't work.

To run this image as container just execute:

`docker run --name mongo-replset -d -p 27017:27017 joolia/mongo-replset`
