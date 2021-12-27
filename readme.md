# 🛠 Dev Zabbix | Instalar e configurar o Zabbix.

Zabbix é uma ferramenta de software de monitoramento de código aberto para diversos componentes de TI, incluindo redes, servidores, máquinas virtuais e serviços em nuvem. 

> O Zabbix fornece métricas de monitoramento, entre outras, utilização da rede, carga da CPU e consumo de espaço em disco.


##### ✅ Referências de dados





### 🛠 Etapa 4: Abra a porta do firewall para Grafana
Se você tiver um serviço firewalld em execução, permita a porta `3000` de acesso ao painel da rede:

```
sudo firewall-cmd --remove-service=dhcpv6-client --permanent
sudo firewall-cmd --remove-service=cockpit --permanent
sudo firewall-cmd --add-port=3000/tcp --permanent
sudo firewall-cmd --reload
sudo firewall-cmd --list-all 
```
```cockipt
sudo rm -f /etc/motd.d/cockpit
```

