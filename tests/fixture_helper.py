#!/usr/bin/env python3
"""Deterministic process fixture for the isolated QML integration harness."""
import argparse,json,time
p=argparse.ArgumentParser();p.add_argument('--stream',action='store_true');p.add_argument('--symbols',nargs='+');a=p.parse_args()
for symbol in a.symbols:
    if symbol == "TIMEOUT": time.sleep(20)
    now=int(time.time())
    if symbol=='BAD':
        event={'quotes':[], 'errors':[{'symbol':symbol,'message':'HTTP 404'}], 'fetchedAt':now}
    else:
        q={'symbol':symbol,'price':305.15 if symbol=='KC=F' else 100.12,'changePercent':-1.23 if symbol in ['GC=F','SI=F'] else 0.82,'timestamp':now-120,'fetchedAt':now,'marketState':'UNKNOWN','priceHint':2,'currency':'USD'}
        event={'quotes':[q],'errors':[],'fetchedAt':now}
    print(json.dumps(event),flush=True)
