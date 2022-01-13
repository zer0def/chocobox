#!/usr/bin/env python

import argparse
import base64
import csv
import itertools
import json
import re
import sys
import urllib.request


DNSCRYPT_FIELDS = [
    "Name", "Full name", "Description", "Location", "Coordinates", "URL",
    "Version", "DNSSEC validation", "No logs", "Namecoin", "Resolver address",
    "Provider name", "Provider public key", "Provider public key TXT record"
]
DNSCRYPT_PUBLIC_RESOLVERS_ENDPOINT = "https://download.dnscrypt.info/dnscrypt-resolvers/json/public-resolvers.json"


def generate_filter():
    parser = argparse.ArgumentParser(
        description="DNSCrypt (not DoH!) resolver list generator"
    )
    parser.add_argument(
        "--no-dnssec", action="store_false", default=True, dest="dnssec",
        help="allow resolvers not verifying DNS query response authenticity"
    )
    parser.add_argument(
        "--allow-logging", action="store_false", default=True, dest="nolog",
        help="allow resolvers not declaring they don't log queries"
    )
    parser.add_argument(
        "--allow-filtering", action="store_false", default=True, dest="nofilter",
        help="allow resolvers not declaring they don't filter responses"
    )
    parser.add_argument(
        "--ipv6", action="store_true", default=False, dest="ipv6",
        help="allow resolvers available over IPv6"
    )
    options = parser.parse_args()

    return lambda i: all([
        i.get("dnssec") == True if options.dnssec else True,
        i.get("nolog") == True if options.nolog else True,
        i.get("nofilter") == True if options.nofilter else True,
        i.get("ipv6") == False if not options.ipv6 else True,
        i.get("proto") == "DNSCrypt",
    ])

if __name__ == "__main__":
    _csv = csv.DictWriter(
        open("dnscrypt-resolvers.csv", "w"), DNSCRYPT_FIELDS, dialect="unix"
    )
    _csv.writeheader()
    _csv.writerows(map(
        lambda i: {
            "Name": i.get("name"),
            "Full name": "",
            "Description": i.get("description", "").replace("\n", " "),
            "Location": i.get("country", ""),
            "Coordinates": "{lat:+.4f}, {long:+.4f}".format(**i.get("location", {})),
            "URL": "",
            "Version": 1 if i.get("proto") == "DNSCrypt" else 2,
            "DNSSEC validation": "yes" if i.get("dnssec") == True else "no",
            "No logs": "yes" if i.get("nolog") == True else "no",
            "Namecoin": "no",
            "Resolver address": ",".join(map(
                lambda y: ":".join(y),
                itertools.product(
                    i.get("addrs", []),
                    map(str, i.get("ports", []))
                )
            )),
            "Provider name": base64.urlsafe_b64decode(
                # wtf, broken padding in stamp?
                "{}==".format(i.get("stamp", "").lstrip("sdns://"))
            ).split(b" ")[-1][33:].decode("utf-8"),
            "Provider public key": re.sub(
                r"(....)",
                r"\1:",
                "".join(map(
                    lambda j: "{:0>2X}".format(j),
                    base64.urlsafe_b64decode("{}==".format(
                        i.get("stamp", "").lstrip("sdns://")
                    )).split(b" ")[-1][:32]
                )),
                15
            ),
        },
        filter(
            generate_filter(),
            json.load(urllib.request.urlopen(DNSCRYPT_PUBLIC_RESOLVERS_ENDPOINT))
        )
    ))
