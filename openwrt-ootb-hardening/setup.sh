#!/bin/sh -ex
MYDIR="$(dirname "$(readlink -f "${0}")")"

opkg update
opkg remove wpad-basic

# defaulting to openssl as TLS impl, because openvpn-easy-rsa depends on it
opkg install \
  ca-bundle \
  luci-app-dnscrypt-proxy \
  \
  freeradius3-mod-always \
  freeradius3-mod-eap-pwd \
  freeradius3-mod-eap-tls \
  freeradius3-mod-files \
  freeradius3-mod-preprocess \
  freeradius3-utils \
  openvpn-easy-rsa \
  wpad-openssl

/etc/init.d/dnscrypt-proxy enable

## if you have rogue DHCP servers on your home network, you have more pressing worries in your life
#opkg install arptables ebtables kmod-br-netfilter
#cat << EOF >> /etc/sysctl.d/brigde-tables.conf
#net.bridge.bridge-nf-call-arptables=1
#net.bridge.bridge-nf-call-iptables=1
#net.bridge.bridge-nf-call-ip6tables=1
#EOF
#
##echo 'arptables -P FORWARD DROP'
#for br in $(brctl show | tail -n+2 | grep -Ev '^[[:space:]]' | awk '{print $1}'); do
#  BR_MAC="$(ip addr show dev "${br}" | awk '/ether / {print $2}')";
#  for ip in $(ip addr show dev "${br}" | awk '/ inet6? / {print $2}'); do
#    echo "arptables -A FORWARD -s ${ip%/*} --src-mac ! ${BR_MAC} -j DROP" >> /etc/firewall.user
#  done
#  echo "ebtables -A FORWARD -p IPV4 -i ${br} --ip-proto udp --ip-sport 67 -j DROP" >> /etc/firewall.user
#done

# be sure to guide Windows guest users into either of:
# - EAP-TLS on WPA2
# - WPA3-SAE (defacto EAP-PWD, but "new")
# more in freeradius3/mods-available/eap

# known placeholders:
# - "ap" for access point identity
# - RADIUS Network Access Server password: "pleasechangeme"
# - "idiot" for network where you should plug your idIoT devices in, very likely stupifying them

# provision your own CA trust chains for EAP-TLS authentication
PKI_NO_NAG=1
PKI_NO_NAG="${PKI_NO_NAG:+nopass}"
PKI_GOOD_CLIENT="client"

for pki_dir in "${HOST_PKI_DIR:-/etc/easy-rsa}" "${GUEST_PKI_DIR:-/etc/easy-rsa-guest}"; do
  mkdir -p "${pki_dir}"
  cd "${pki_dir}"
  easyrsa init-pki
  easyrsa build-ca "${PKI_NO_NAG}"
  #easyrsa gen-dh  # probably want to do this on a separate machine

  # convert for Android (and Windows?) clients:
  openssl x509 -inform PEM -in ${pki_dir}/pki/ca.crt -outform DER -out ${pki_dir}/pki/ca.cer

  easyrsa build-server-full ap "${PKI_NO_NAG}"
  easyrsa build-client-full "${PKI_GOOD_CLIENT}" "${PKI_NO_NAG}"
  easyrsa export-p12 "${PKI_GOOD_CLIENT}"

  # make sure you have a CRL (default length is half-year)
  easyrsa revoke badclient ||:
  easyrsa gen-crl
  cat ${pki_dir}/pki/ca.crt ${pki_dir}/pki/crl.pem > ${pki_dir}/pki/cacrl.pem
done

mkdir -p "${MYDIR}/freeradius3"
for i in $(find "${MYDIR}/freeradius3" -type f); do
  cp "${i}" "/etc/${i##${MYDIR}}"
done
cd /etc/freeradius3/sites-enabled
rm *
for i in guestnet guestnet-inner hostnet; do
  ln -sf "../sites-available/${i}"
done
# LD_LIBRARY_PATH=/usr/lib/freeradius3 radiusd -X
/etc/init.d/radiusd enable

# everything else
uci batch <<EOF
set dhcp.@dnsmasq[0].server='127.0.0.1#5353'
set dropbear.@dropbear[0].PasswordAuth='off'
set dropbear.@dropbear[0].RootPasswordAuth='off'
set firewall.@defaults[0].input='REJECT'
set network.wan.dns='127.0.0.1'
set network.wan.peerdns='0'
set network.wan6.dns='127.0.0.1'
set network.wan6.peerdns='0'

set wireless.default_radio0.encryption='wpa2+aes'
set wireless.default_radio0.wpa_disable_eapol_key_retries='1'
set wireless.default_radio0.ieee80211w='1'
set wireless.default_radio0.nasid='hostnet'
set wireless.default_radio0.auth_server='127.0.0.1'
set wireless.default_radio0.auth_port='1812'
set wireless.default_radio0.auth_secret='pleasechangeme'
set wireless.default_radio0.acct_server='127.0.0.1'
set wireless.default_radio0.acct_port='1813'
set wireless.default_radio0.acct_secret='pleasechangeme'

set wireless.default_radio1.encryption='wpa2+aes'
set wireless.default_radio1.wpa_disable_eapol_key_retries='1'
set wireless.default_radio1.ieee80211w='1'
set wireless.default_radio1.nasid='hostnet'
set wireless.default_radio1.auth_server='127.0.0.1'
set wireless.default_radio1.auth_port='1812'
set wireless.default_radio1.auth_secret='pleasechangeme'
set wireless.default_radio1.acct_server='127.0.0.1'
set wireless.default_radio1.acct_port='1813'
set wireless.default_radio1.acct_secret='pleasechangeme'

add network switch_vlan
set network.@switch_vlan[-1].device='switch0'
set network.@switch_vlan[-1].vlan='7'

set network.guest=interface
set network.guest.type='bridge'
set network.guest.ifname='eth0.7'
set network.guest.ipaddr='10.77.77.1'
set network.guest.netmask='255.255.255.0'
set network.guest.proto='static'

set dhcp.guest=dhcp
set dhcp.guest.interface='guest'
set dhcp.guest.leasetime='1h'
set dhcp.guest.limit='253'
set dhcp.guest.start='1'

set wireless.guest2_eap=wifi-iface
set wireless.guest2_eap.ssid='guest2_eap'
set wireless.guest2_eap.network='guest'
set wireless.guest2_eap.device='radio0'
set wireless.guest2_eap.mode='ap'
set wireless.guest2_eap.isolate='1'
set wireless.guest2_eap.wpa_disable_eapol_key_retries='1'
set wireless.guest2_eap.ieee80211w='1'
set wireless.guest2_eap.encryption='wpa2+aes'
set wireless.guest2_eap.nasid='guestnet'
set wireless.guest2_eap.auth_server='127.0.0.1'
set wireless.guest2_eap.auth_port='1814'
set wireless.guest2_eap.auth_secret='pleasechangeme'
set wireless.guest2_eap.acct_server='127.0.0.1'
set wireless.guest2_eap.acct_port='1815'
set wireless.guest2_eap.acct_secret='pleasechangeme'

set wireless.guest2_sae=wifi-iface
set wireless.guest2_sae.ssid='guest2_sae'
set wireless.guest2_sae.network='guest'
set wireless.guest2_sae.device='radio0'
set wireless.guest2_sae.mode='ap'
set wireless.guest2_sae.isolate='1'
set wireless.guest2_sae.wpa_disable_eapol_key_retries='1'
set wireless.guest2_sae.ieee80211w='2'
set wireless.guest2_eap.encryption='sae'
set wireless.guest2_sae.key='veryinsecurepasswordhere'

set wireless.guest5_eap=wifi-iface
set wireless.guest5_eap.ssid='guest5_eap'
set wireless.guest5_eap.network='guest'
set wireless.guest5_eap.device='radio1'
set wireless.guest5_eap.mode='ap'
set wireless.guest5_eap.isolate='1'
set wireless.guest5_eap.wpa_disable_eapol_key_retries='1'
set wireless.guest5_eap.ieee80211w='1'
set wireless.guest5_eap.encryption='wpa2+aes'
set wireless.guest5_eap.nasid='guestnet'
set wireless.guest5_eap.auth_server='127.0.0.1'
set wireless.guest5_eap.auth_port='1814'
set wireless.guest5_eap.auth_secret='pleasechangeme'
set wireless.guest5_eap.acct_server='127.0.0.1'
set wireless.guest5_eap.acct_port='1815'
set wireless.guest5_eap.acct_secret='pleasechangeme'

set wireless.guest5_sae=wifi-iface
set wireless.guest5_sae.ssid='guest5_sae'
set wireless.guest5_sae.network='guest'
set wireless.guest5_sae.device='radio1'
set wireless.guest5_sae.mode='ap'
set wireless.guest5_sae.isolate='1'
set wireless.guest5_sae.wpa_disable_eapol_key_retries='1'
set wireless.guest5_sae.ieee80211w='2'
set wireless.guest5_eap.encryption='sae'
set wireless.guest5_sae.key='veryinsecurepasswordhere'

add firewall zone
set firewall.@zone[-1].name='guest'
set firewall.@zone[-1].network='guest'
set firewall.@zone[-1].input='REJECT'
set firewall.@zone[-1].output='ACCEPT'
set firewall.@zone[-1].forward='REJECT'

add firewall forwarding
set firewall.@forwarding[-1].src='guest'
set firewall.@forwarding[-1].dest='wan'

add firewall rule
set firewall.@rule[-1].name='guest-dns'
set firewall.@rule[-1].src='guest'
set firewall.@rule[-1].proto='udp'
set firewall.@rule[-1].dest_port='53'
set firewall.@rule[-1].target='ACCEPT'

add firewall rule
set firewall.@rule[-1].name='guest-dhcp-client'
set firewall.@rule[-1].src='guest'
set firewall.@rule[-1].proto='udp'
set firewall.@rule[-1].dest_port='67'
set firewall.@rule[-1].target='ACCEPT'

add network switch_vlan
set network.@switch_vlan[-1].device='switch0'
set network.@switch_vlan[-1].vlan='69'

set network.idiot=interface
set network.idiot.type='bridge'
set network.idiot.ifname='eth0.69'
set network.idiot.ipaddr='10.69.69.1'
set network.idiot.netmask='255.255.255.0'
set network.idiot.proto='static'

set dhcp.idiot=dhcp
set dhcp.idiot.interface='idiot'
set dhcp.idiot.leasetime='1h'
set dhcp.idiot.limit='253'
set dhcp.idiot.start='1'

set wireless.idiot2=wifi-iface
set wireless.idiot2.ssid='idiot2'
set wireless.idiot2.network='idiot'
set wireless.idiot2.device='radio0'
set wireless.idiot2.mode='ap'
set wireless.idiot2.encryption='none'
set wireless.idiot2.isolate='1'
set wireless.idiot2.wpa_disable_eapol_key_retries='1'

set wireless.idiot5=wifi-iface
set wireless.idiot5.ssid='idiot5'
set wireless.idiot5.network='idiot'
set wireless.idiot5.device='radio1'
set wireless.idiot5.mode='ap'
set wireless.idiot5.encryption='none'
set wireless.idiot5.isolate='1'
set wireless.idiot5.wpa_disable_eapol_key_retries='1'

add firewall zone
set firewall.@zone[-1].name='idiot'
set firewall.@zone[-1].network='idiot'
set firewall.@zone[-1].input='REJECT'
set firewall.@zone[-1].output='ACCEPT'
set firewall.@zone[-1].forward='REJECT'

add firewall rule
set firewall.@rule[-1].name='idiot-dhcp-client'
set firewall.@rule[-1].src='idiot'
set firewall.@rule[-1].proto='udp'
set firewall.@rule[-1].dest_port='67'
set firewall.@rule[-1].target='ACCEPT'
EOF
#uci commit
#for i in dnscrypt-proxy dnsmasq dropbear firewall network radiusd; do
#  "/etc/init.d/${i}" restart
#done
#reboot
