#!/bin/bash
# IPv6 WHOIS & BGP Lookup Script
# Usage: ./ipv6_lookup.sh <IPv6 Address>

if [ -z "$1" ]; then
    echo "Usage: $0 <IPv6 Address>"
    exit 1
fi

IP=$1

echo "====================================="
echo " WHOIS Lookup for $IP "
echo "====================================="
whois $IP | grep -E "^(NetName|Organization|NetRange|CIDR|OriginAS|AS Name|Country)" || echo "No WHOIS data found."

echo "====================================="
echo " BGP & ASN Lookup via Cymru "
echo "====================================="
whois -h whois.cymru.com " -v $IP" 2>/dev/null || echo "No BGP/ASN data found."

echo "====================================="
echo " Reverse DNS Lookup "
echo "====================================="
dig -x $IP +short || echo "No PTR record found."


