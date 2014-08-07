"""
    This script allows to create new environment in Fuel and
    include all descovered nodes to this environment.

    How to use this script

      First of all need to install requirements:

        git clone https://github.com/sergeygalkin/fuel-main -b stable/4.0
        cd fuel-main
        sudo pip install -r requirements.txt

      After that need to copy this script in fuel-main folder
      and run:

        python deploy_environment_in_fuel.py --ip_address FUEL_IP
"""

from ConfigParser import SafeConfigParser
import libvirt
from sys import argv
import time
import json
import urllib2

import python.nailgun_client as fuel


def create_environment():

    #   Connect to Fuel Main Server

    client = fuel.NailgunClient(str(fuel_ip))

    #   Clean Fuel cluster

    for cluster in client.list_clusters():
        client.delete_cluster(cluster['id'])
        while True:
            try:
                client.get_cluster(cluster['id'])
            except urllib2.HTTPError as e:
                if str(e) == "HTTP Error 404: Not Found":
                    break
                else:
                    raise
            except Exception:
                raise
            time.sleep(1)

    #   Create cluster

    release_id = client.get_release_id(cluster_settings['release_name'])

    data = {"name": cluster_settings['env_name'], "release": release_id,
            "mode": cluster_settings['config_mode'],
            "net_provider": cluster_settings['net_provider']}
    if cluster_settings.get('net_segment_type'):
        data['net_segment_type'] = cluster_settings['net_segment_type']

    client.create_cluster(data)

    #   Update cluster configuration

    cluster_id = client.get_cluster_id(cluster_settings['env_name'])
    attributes = client.get_cluster_attributes(cluster_id)

    settings = json.loads(cluster_settings['settings'])

    for option in settings:
        section = False
        if option in ('sahara', 'murano', 'ceilometer'):
            section = 'additional_components'
        if option in ('volumes_ceph', 'images_ceph', 'ephemeral_ceph',
                      'objects_ceph', 'osd_pool_size', 'volumes_lvm'):
            section = 'storage'
        if section:
            attributes['editable'][section][option]['value'] = settings[option]

    hpv_data = attributes['editable']['common']['libvirt_type']
    hpv_data['value'] = str(cluster_settings['virt_type'])

    debug = cluster_settings.get('debug', 'false')
    auto_assign = cluster_settings.get('auto_assign_floating_ip', 'false')
    nova_quota = cluster_settings.get('nova_quota', 'false')

    attributes['editable']['common']['debug']['value'] = json.loads(debug)
    attributes['editable']['common'][
        'auto_assign_floating_ip']['value'] = json.loads(auto_assign)
    attributes['editable']['common']['nova_quota']['value'] = \
        json.loads(nova_quota)

    client.update_cluster_attributes(cluster_id, attributes)

    counter = 0
    while True:

        actual_kvm_count = len([k for k in client.list_nodes()
                    if not k['cluster'] and k['online']
            and k['status'] == 'discover' and k['manufacturer'] == 'KVM'])

        actual_machines_count = len([k for k in client.list_nodes()
                    if not k['cluster'] and k['online']
            and k['status'] == 'discover'
        and k['manufacturer'] == 'Supermicro'])

        if actual_kvm_count >= int(kvm_count) \
            and actual_machines_count >= int(machines_count):
            break
        counter += 5
        if counter > 600:
            raise RuntimeError
        time.sleep(5)

    #   Add all available nodes to cluster

    for node_name, params in json.loads(cluster_settings['node_roles']).items():

        node = next(k for k in client.list_nodes()
                    if k['manufacturer'] == params['manufacturer']
        and not k['cluster'] and k['online'])

        data = {"cluster_id": str(cluster_id),
                "pending_roles": params['roles'],
                "pending_addition": True,
                "name": node_name,
                }

        client.update_node(node['id'], data)

    #   Move networks on interfaces

    for node in client.list_cluster_nodes(cluster_id):
        networks_dict = json.loads(cluster_settings['interfaces'])
        update_node_networks(client, node['id'], networks_dict)

    #   Update network

    default_networks = client.get_networks(cluster_id)

    networks = json.loads(cluster_settings['networks'])

    change_dict = networks.get('networking_parameters', {})
    for key, value in change_dict.items():
        default_networks['networking_parameters'][key] = value

    for net in default_networks['networks']:
        change_dict = networks.get(net['name'], {})
        for key, value in change_dict.items():
            net[key] = value

    client.update_network(cluster_id, default_networks, all_set=True)


def deploy_environment():
    client = fuel.NailgunClient(str(fuel_ip))
    cluster_id = client.get_cluster_id(cluster_settings['env_name'])
    client.deploy_cluster_changes(cluster_id)


def update_node_networks(client, node_id, interfaces_dict, raw_data=None):

    # fuelweb_admin is always on eth0

    interfaces_dict['eth0'] = interfaces_dict.get('eth0', [])
    if 'fuelweb_admin' not in interfaces_dict['eth0']:
        interfaces_dict['eth0'].append('fuelweb_admin')

    interfaces = client.get_node_interfaces(node_id)

    if raw_data:
        interfaces.append(raw_data)

    all_networks = dict()
    for interface in interfaces:
        all_networks.update(
            {net['name']: net for net in interface['assigned_networks']})

    for interface in interfaces:
        name = interface["name"]
        interface['assigned_networks'] = \
            [all_networks[i] for i in interfaces_dict.get(name, [])]

    client.put_node_interfaces([{'id': node_id, 'interfaces': interfaces}])


def await_deploy():
    client = fuel.NailgunClient(str(fuel_ip))
    cluster_id = client.get_cluster_id(cluster_settings['env_name'])
    conn = libvirt.open("qemu:///system")
    notif_count = 0
    done_deploy = 0
    list_notification = []

    while True:
        for domain_name in conn.listDefinedDomains():
            conn.lookupByName(domain_name).create()

        try:
            list_notification = client.get_notifications()
        except urllib2.URLError:
            pass

        if len(list_notification) > notif_count:
	    log_file = open('await_deploy.log', 'aw')
            log_file.write("{}\n{}\n".format(notif_count,
                                           list_notification[notif_count:]))
	    log_file.close()

            for notification in list_notification[notif_count:]:

                if notification['cluster'] == cluster_id:

                    if notification['topic'] == 'error':
                        raise RuntimeError(notification['message'])

                    if notification['topic'] == 'done':
                        print notification['message']
			return

        notif_count = len(list_notification)

        time.sleep(10)


def return_controller_ip(config, fuel_ip):

    parser = SafeConfigParser()
    parser.read(config)

    cluster_settings = dict(parser.items('cluster'))

    client = fuel.NailgunClient(str(fuel_ip))
    cluster_id = client.get_cluster_id(cluster_settings['env_name'])

    notification = [q for q in client.get_notifications()
                    if q['topic'] == "done" and q['cluster'] == cluster_id]
    print [word for word in notification[0][
        'message'].split() if word.startswith('http://')][0][7:-1]

if __name__ == '__main__':

    parser = SafeConfigParser()
    parser.read(argv[1])

    fuel_ip = argv[2]
    kvm_count = argv[3]
    machines_count = argv[4]
    cluster_settings = dict(parser.items('cluster'))

    create_environment()
    deploy_environment()
    await_deploy()
