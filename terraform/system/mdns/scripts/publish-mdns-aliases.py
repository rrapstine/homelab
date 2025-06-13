#!/usr/bin/env python3
import os

args = ['mdns-publish-cname']

with open('/home/richard/.mdns-aliases', 'r') as f:
    for line in f.readlines():
      line = line.strip()
      if line:
        args.append(line.strip())
os.execv('/opt/venv/venv_mdns_publisher/bin/mdns-publish-sname', args)
