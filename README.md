# OpenVPN in Docker

(**This project is no longer maintained**)

This is a script to install OpenVPN on a Docker container. While it is not recommended to install the server and CA together on the server/container, this script installs both of them together.

## Installation: Building from source

1. Build Docker image using
```
docker build -t <IMAGE_NAME> .
```

2. Create a Docker volume using the command
```
docker volume create <VOLUME_NAME>
```

3. Start the container in interactive mode for the initial setup
```
docker run -it --name <CONTAINER_NAME> -v <VOLUME_NAME>:<VOLUME_MOUNT_PATH> -p <PORT>:1194/<PROTOCOL> --cap-add=NET_ADMIN --device /dev/net/tun:/dev/net/tun <IMAGE_NAME>
```

4. Copy the client config files from the container to the server. The config file will be saved as `<CLIENT_NAME>.ovpn` in the volume.
```
docker cp <CONTAINER_NAME>:<VOLUME_MOUNT_PATH> <PATH_ON_SERVER>
```

5. Copy the config files from the server to your clients using `scp`.


6. To create a new client or to start the server use
```
docker container start -i <CONTAINER_NAME>
```

## Important Notes

1. The client will not connect if your client system does not have group named `nobody`. Creating a group named `nobody` (user with the least permissions on the system) or deleting the line `group nobody` in the config file (not recommended) will solve the problem.

2. Does not support certificate revocation.
