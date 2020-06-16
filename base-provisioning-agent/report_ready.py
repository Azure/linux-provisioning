"""Python module to easily allow for reporting ready to Azure."""

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT license.

import http.client
from xml.etree import ElementTree

def get_vm_identifiers(wireserver_connection):
    """Get the ContainerId and InstanceId from the Wireserver."""

    wireserver_connection.request(
        'GET',
        '/machine?comp=goalstate',
        headers={'x-ms-version': '2012-11-30'}
    )

    resp = wireserver_connection.getresponse()

    wireserver_goalstate = resp.read().decode('utf-8')

    xml_el = ElementTree.fromstring(wireserver_goalstate)

    container_id = xml_el.findtext('Container/ContainerId')
    instance_id = xml_el.findtext('Container/RoleInstanceList/RoleInstance/InstanceId')

    return dict(container_id=container_id, instance_id=instance_id)

def construct_report_ready_xml(container_id, instance_id):
    """Construct the XML response we need to send to Wireserver to report ready."""

    health = ElementTree.Element('Health')
    goalstate_incarnation = ElementTree.SubElement(health, 'GoalStateIncarnation')
    goalstate_incarnation.text = '1'
    container = ElementTree.SubElement(health, 'Container')
    container_id_el = ElementTree.SubElement(container, 'ContainerId')
    container_id_el.text = container_id
    role_instance_list = ElementTree.SubElement(container, 'RoleInstanceList')
    role = ElementTree.SubElement(role_instance_list, 'Role')
    instance_id_el = ElementTree.SubElement(role, 'InstanceId')
    instance_id_el.text = instance_id
    health_second = ElementTree.SubElement(role, 'Health')
    state = ElementTree.SubElement(health_second, 'State')
    state.text = 'Ready'

    out_xml = ElementTree.tostring(
        health,
        encoding='unicode',
        method='xml'
    )
    return out_xml

def report_ready():
    """Make the report ready HTTP request to Wireserver."""

    wireserver_ip = '168.63.129.16'

    try:
        wireserver_connection = http.client.HTTPConnection(wireserver_ip)

        print('Retrieving goal state from the Wireserver')
        vm_identifiers = get_vm_identifiers(wireserver_connection=wireserver_connection)
        print(f'ContainerId: {vm_identifiers["container_id"]}')
        print(f'InstanceId: {vm_identifiers["instance_id"]}')

        ready_xml = construct_report_ready_xml(
            container_id=vm_identifiers['container_id'],
            instance_id=vm_identifiers['instance_id']
        )
        print('Sending the following data to Wireserver:')
        print(ready_xml)

        wireserver_connection.request(
            'POST',
            '/machine?comp=health',
            headers={
                'x-ms-version': '2012-11-30',
                'Content-Type': 'text/xml;charset=utf-8',
                'x-ms-agent-name': 'custom-provisioning'
            },
            body=ready_xml
        )

        resp = wireserver_connection.getresponse()
        print(f'Response: {resp.status} {resp.reason}')
    except http.client.HTTPException as http_exception:
        print(f'Error communicating with Wireserver: {http_exception}')
    finally:
        wireserver_connection.close()

if __name__ == '__main__':
    report_ready()
