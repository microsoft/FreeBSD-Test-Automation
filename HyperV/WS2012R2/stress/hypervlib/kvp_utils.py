#!/usr/bin/env python

from xml.dom import minidom

def _get_text(nodes):
    rc = []
    for node in nodes:
        if node.nodeType == node.TEXT_NODE:
            rc.append(node.data)
    return ''.join(rc)

# parse CIM-XML data to KvpExchangeDataItem
def parse_kvp_data_item(cim_data):
    dom = minidom.parseString(cim_data)
    props = dom.getElementsByTagName('PROPERTY')

    item = {}
    for p in props:
        name = p.attributes['NAME'].value
        value = p.getElementsByTagName('VALUE')
        if len(value) > 0:
            item[name] = _get_text(value[0].childNodes)

    return item



