template(){
    local _ZONE_=$1
    sed -e "s/_ZONE_/${_ZONE_}/g;" ZONE.template  > zones.${_ZONE_}
    sed -e "s/_ZONE_/${_ZONE_}/g;" QUERY.template > query.${_ZONE_}
    cat <<EOF >> ${_ZONE_}.key
key "${_ZONE_}.key" {
     algorithm hmac-md5;
     secret "aaaaaaaaaaaaaaaaaaaa";
};
EOF
    cat ${_ZONE_}.key >> mgmt.key
    cat <<EOF >> named.conf
zone "${_ZONE_}" {
	type master;
	file "zones.${_ZONE_}";
	update-policy{
		grant ${_ZONE_}.key wildcard *.${_ZONE_}. A;
	};
};
EOF
}

rm -f rm /etc/bind/*
rm -f /var/cache/bind/zones.*

cp named.conf.template named.conf
cp mgmt.key.template mgmt.key
if [ -n "$1" ]
then
    _ZONE_=$1
    for _ZONE_ in $*
    do
	template $_ZONE_
    done
else
    template "example.com"
fi

_SERIAL_=`date +%Y%m%d00`
for z in zones.*
do
    sed -e "s/_SERIAL_/${_SERIAL_}/;" $z > /var/cache/bind/$z
    touch /etc/bind/$z.jnl
done

cp named.conf mgmt.key /etc/bind/
chown bind.bind /etc/bind/*
chmod 666 /etc/bind/*
chown bind.bind /var/cache/bind/zones.*
chmod 644 /var/cache/bind/zones.*

systemctl restart bind9.service
sleep 1
rndc -c mgmt.conf freeze
rndc -c mgmt.conf thaw

for q in query.*
do
    _ZONE_=$(echo $q | sed -e "s/query\.//")
    dig @localhost ${_ZONE_} soa
    nsupdate -k ${_ZONE_}.key < $q
done
