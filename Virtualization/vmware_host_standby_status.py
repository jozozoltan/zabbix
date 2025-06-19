#!/usr/bin/env python3.10

import ssl
from pyVim.connect import SmartConnect, Disconnect
from pyVmomi import vim
import argparse

# Disable SSL verification
context = ssl._create_unverified_context()

def dump_hosts_info(vcenter, user, password, hostname):
    # Ensure the vcenter does not contain protocol schema or path
    if vcenter.startswith('https://'):
        vcenter = vcenter.replace('https://', '')
    elif vcenter.startswith('http://'):
        vcenter = vcenter.replace('http://', '')

    # Remove the SDK path if present
    if vcenter.endswith('/sdk'):
        vcenter = vcenter.replace('/sdk', '')

    # Connect to vCenter
    si = SmartConnect(host=vcenter, user=user, pwd=password, sslContext=context)
    content = si.RetrieveContent()

    try:
        found_host = False
        # Iterate through all hosts and print all available information
        for datacenter in content.rootFolder.childEntity:
            for cluster in datacenter.hostFolder.childEntity:
                for esxi_host in cluster.host:
                    if esxi_host.name == hostname:
                        print(f"{esxi_host.runtime.powerState}")
                        found_host = True
                        break
                if found_host:
                    break
            if found_host:
                break

        if not found_host:
            print(f"Host '{hostname}' not found in vCenter.")

    except Exception as e:
        print(f"Error: {e}")
    finally:
        Disconnect(si)

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('--vcenter', help='vCenter server')
    parser.add_argument('--user', help='vCenter username')
    parser.add_argument('--password', help='vCenter password')
    parser.add_argument('--hostname', help='Host name')
    args = parser.parse_args()

    # Print arguments for verification
#    print(f"vCenter: {args.vcenter}")
#    print(f"User: {args.user}")
#    print(f"Password: {args.password}")
#    print(f"Hostname: {args.hostname}")

    try:
        dump_hosts_info(args.vcenter, args.user, args.password, args.hostname)
    except Exception as e:
        print(f"Failed to connect to vCenter: {e}")
