#!/usr/bin/env python3

import argparse
import json
import re
import sys
from pprint import pprint

if sys.version_info <= (3, 0):
    sys.stdout.write("Sorry, requires Python 3.x, not Python 2.x\n")
    sys.exit(1)

TF_STATE = "terraform.tfstate"

parser = argparse.ArgumentParser(
    description='A terraform state file parser for IPs.')
parser.add_argument('--tfstate',
                    dest='tfstate',
                    nargs='?',
                    type=argparse.FileType('r'),
                    default=TF_STATE,
                    help='the terraform file to parse')
parser.add_argument('--count',
                    action='store_true',
                    help='just count the number of IPs')
parser.add_argument('--map',
                    dest='map',
                    action='store_true',
                    help='print the list of <name> <IP>')
parser.add_argument('--name',
                    nargs='?',
                    dest='name',
                    metavar='VM_NAME(s)',
                    help='print the IP(s) for the VM(s) with this name(s)')
parser.add_argument('--regex',
                    nargs='?',
                    dest='regex',
                    help='print the IP for the VM that match this regex')
parser.add_argument('--names',
                    dest='names',
                    action='store_true',
                    help='print all the machines names')

args = parser.parse_args()

res = {}
try:
    json_data = args.tfstate.read()
    data = json.loads(json_data)
except ValueError as e:
    print('ERROR: parsing tfstate file: {}'.format(e), file=sys.stderr)
    sys.exit(1)

for resource_name, resource_contents in data['modules'][0]['resources'].items():
    if re.search('libvirt_domain\..*', resource_name):
        try:
            attrs = resource_contents['primary']['attributes']

            name = attrs['name']
            ipaddr = attrs['network_interface.0.addresses.0']

            if args.regex and not re.search(args.regex, name):
                continue
            else:
                res[name] = ipaddr
        except KeyError as e:
            print('ERROR: cannot parse IP address from {}: {} not found'.format(
                args.tfstate.name, e), file=sys.stderr)
            sys.exit(1)

if args.count:
    # print the number of VMs
    print(len(res))
elif args.names:
    # print the list of VMs names
    print(" ".join(res.keys()))
elif args.name:
    # print the IPs for a VM name
    for name in re.split(' |,', args.name):
        try:
            print(res[name])
        except KeyError as e:
            print('ERROR: {} does not exist'.format(name), file=sys.stderr)
            print('ERROR: valid names: {}'.format(" ".join(res.keys())), file=sys.stderr)
            sys.exit(1)
elif args.map:
    # print the list of <name> <IP>
    for name, ip in res.items():
        print("{} {}".format(name, ip))
else:
    # print all the IPs
    print(' '.join(res.values()))
