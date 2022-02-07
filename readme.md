# 🛠 DEV ZABBIX | Instalar e configuração.

Zabbix é uma ferramenta de software de monitoramento de código aberto para diversos componentes de TI, incluindo redes, servidores, máquinas virtuais e serviços em nuvem. 

> O Zabbix fornece métricas de monitoramento, entre outras, utilização da rede, carga da CPU e consumo de espaço em disco.

✅ **Referências de dados**

✅**Mantenha seu servidor atualizado**

```Atualização
yum update -y && yum upgrade -y
```

🛠 **Etapa 4 :** Abra a porta do firewall para Grafana
Se você tiver um serviço firewalld em execução, permita a porta `10050 10051` de acesso ao painel da rede:

```
sudo firewall-cmd --permanent --remove-service=dhcpv6-client
sudo firewall-cmd --permanent --remove-service=cockpit

sudo firewall-cmd --permanent --add-service=zabbix-server

sudo firewall-cmd --reload
sudo firewall-cmd --list-all 
```
```cockipt
sudo rm -f /etc/motd.d/cockpit
```

