# Verify the gRPC service with grpcurl

Run these commands on `192.168.138.129`. `grpcurl` is already installed on this host.

## Start the service

```sh
cd /home/nmei/envoy-study/grpc
grpcurl -version
./setup.sh start
./setup.sh status
```

The default endpoint is `192.168.138.129:50051`. The service uses the Python environment in `.venv/`; see `./setup.sh --help` if that environment needs to be recreated.

## Call GetInfo

From the `grpc/` directory:

```sh
grpcurl -plaintext \
  -import-path . \
  -proto info.proto \
  -d '{}' \
  192.168.138.129:50051 \
  envoystudy.v1.InfoService/GetInfo
```

A successful call exits with status `0` and returns JSON containing:

- `serviceName`: `envoy-study-grpc`
- `version`: `1.0.0`
- `hostname`: the server's hostname
- `metadata`: incoming request metadata, including grpcurl's user-agent

`-plaintext` selects unencrypted gRPC, matching this lab server. `-d '{}'` sends an empty `InfoRequest`.

The server does **not** enable reflection. Supply `info.proto` explicitly; a bare `grpcurl ... list` will not discover its services. The relative `-import-path .` assumes the working directory above. From another directory, use `-import-path /home/nmei/envoy-study/grpc` instead.

## Verify metadata forwarding and redaction

Use dummy credentials only: this lab connection is not encrypted.

```sh
grpcurl -plaintext \
  -import-path . \
  -proto info.proto \
  -H 'x-request-id: grpcurl-check' \
  -H 'authorization: Bearer dummy-token' \
  -d '{}' \
  192.168.138.129:50051 \
  envoystudy.v1.InfoService/GetInfo
```

In the response's `metadata` array, expect `x-request-id` to have value `grpcurl-check` and `authorization` to have value `[REDACTED]`. Redaction applies to the response; it does not encrypt metadata in transit.

## Stop the service

```sh
./setup.sh stop
```

To manage it through the project-level orchestrator instead, use `../setup.sh start grpc`, `../setup.sh status grpc`, or `../setup.sh stop grpc` from this directory.

## Troubleshooting

- **Connection refused:** run `./setup.sh status` and inspect `.state/grpc_service.log`. Start the service if stopped.
- **Reflection not supported:** keep `-import-path` and `-proto info.proto` in the command.
- **Cannot find `info.proto`:** run from this directory or use the absolute import path above.
- **Different bind address or port:** replace the endpoint in both grpcurl examples with the address configured using `BIND` and `PORT` when starting the service.
