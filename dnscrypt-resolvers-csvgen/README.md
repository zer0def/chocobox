# DNS-over-TLS resolver list generator

## Summary

With the dawn of DNS-over-HTTPS effectively hijacking the now legacy DNSCrypt implementation, there's a class of devices which may never end up seeing a DoH-based implementation.

This (rather clunky and poorly written) Python3 script scrapes the list of public resolvers and extracts a [legacy DNSCrypt-Proxy](https://github.com/dyne/dnscrypt-proxy) consumable CSV list of those still running the legacy protocol, with some personal preferences of mine.

## Usage

```
usage: generator.py [-h] [--no-dnssec] [--allow-logging] [--allow-filtering] [--ipv6]

DNSCrypt (not DoH!) resolver list generator

optional arguments:
  -h, --help         show this help message and exit
  --no-dnssec        allow resolvers not verifying DNS query response authenticity
  --allow-logging    allow resolvers not declaring they don't log queries
  --allow-filtering  allow resolvers not declaring they don't filter responses
  --ipv6             allow resolvers available over IPv6
```
