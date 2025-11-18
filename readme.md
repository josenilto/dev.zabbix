# DEV ZABBIX

Repositório com arquivos e exemplos para executar um ambiente Zabbix usando Docker.

Zabbix é uma ferramenta de monitoramento de código aberto para redes, servidores, VMs e serviços em nuvem. Este repositório contém um `Dockerfile` para o `zabbix-server`, um template de configuração e um `docker-compose.yml` de exemplo.

## Arquivos principais

- `docker-compose.yml`: Compose principal na raiz (MariaDB, `zabbix-server`, `zabbix-web`).
- `zabbix-server/Dockerfile`: Dockerfile customizado para o serviço `zabbix-server`.
- `zabbix-server/zabbix_server.conf`: Template opcional de configuração do servidor Zabbix.
- `zabbix-server/README.md`: instruções específicas do diretório `zabbix-server`.

## Quickstart (PowerShell)

1. Na raiz do repositório, suba os serviços (build + start):

```powershell
cd C:\Users\josen\Downloads\dev.zabbix
docker-compose up -d --build
```

1. (Opcional) Build manual da imagem do `zabbix-server`:

```powershell
cd C:\Users\josen\Downloads\dev.zabbix\zabbix-server
docker build -t local/zabbix-server:latest .
```

1. Verificar logs do servidor Zabbix:

```powershell
cd C:\Users\josen\Downloads\dev.zabbix
docker-compose logs -f zabbix-server
```

## Acessos

- Front-end web: `http://localhost:8080`
- Porta do Zabbix Server (agent <> server): `10051`

## Variáveis importantes (no `docker-compose.yml`)

- `MYSQL_ROOT_PASSWORD`, `MYSQL_PASSWORD`: senhas do banco  substitua em produção.
- `DB_SERVER_HOST`, `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_PASSWORD`: configurações de conexão do Zabbix com o banco.

## Personalização

- Para ajustar o servidor Zabbix, edite `zabbix-server/zabbix_server.conf` e reconstrua a imagem.
- O `Dockerfile` em `zabbix-server` já copia `zabbix_server.conf` para `/etc/zabbix/zabbix_server.conf` se presente.

## Observações de produção

- Nunca use senhas padrão em ambientes públicos.
- Considere volumes persistentes para os dados do banco (`db_data` já definido no compose) e backups regulares.
- Ajuste timezones no serviço `zabbix-web` (`PHP_TZ`) conforme sua região.

## Referências úteis

- [Zabbix Docker Hub - zabbix-server-mysql](https://hub.docker.com/r/zabbix/zabbix-server-mysql)
- [Documentação oficial do Zabbix](https://www.zabbix.com/documentation/current/en/manual/installation)
