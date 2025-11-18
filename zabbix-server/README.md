# zabbix-server (Docker)

Arquivos nesta pasta:

- `Dockerfile` - Dockerfile baseado na imagem oficial `zabbix-server-mysql`.
- `zabbix_server.conf` - template opcional de configuração do `zabbix_server`.
- `docker-compose.yml` - exemplo para subir MariaDB, zabbix-server e frontend `zabbix-web`.

Como usar (build local):

1. Build da imagem:

```powershell
docker build -t local/zabbix-server:latest .
```

2. Iniciar com `docker-compose` (exemplo):

```powershell
docker-compose up -d
```

Notas:
- Altere as senhas e variáveis em `docker-compose.yml` antes de usar em produção.
- O `zabbix-server` depende de um banco de dados configurado (MariaDB/MySQL/Postgres).
- A imagem oficial aceita várias variáveis de ambiente (por exemplo `DB_SERVER_HOST`, `MYSQL_USER`, `MYSQL_PASSWORD`).
- Se quiser personalizar o `zabbix_server.conf`, edite o arquivo `zabbix_server.conf` nesta pasta — ele será copiado para `/etc/zabbix/zabbix_server.conf` na imagem.

Referências:
- https://hub.docker.com/r/zabbix/zabbix-server-mysql
- https://www.zabbix.com/documentation/current/en/manual/installation
