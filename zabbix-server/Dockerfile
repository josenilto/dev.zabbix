FROM zabbix/zabbix-server-mysql:latest

# Copia um arquivo de configuração personalizado, se houver.
# O arquivo é opcional: se não existir, a imagem oficial usa o padrão.
COPY zabbix_server.conf /etc/zabbix/zabbix_server.conf

# Porta padrão do zabbix-server
EXPOSE 10051

# Healthcheck simples: verifica se o processo existe
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s \
  CMD pgrep zabbix_server || exit 1

# Executa o servidor Zabbix (a imagem base já fornece entrypoint, manter comando padrão)
CMD ["zabbix_server", "-f"]
