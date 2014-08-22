#!/usr/bin/python

"""
        python nailgun.py test_config.cfg FUEL_IP
"""

from ConfigParser import SafeConfigParser
from sys import argv
import time
import json
import urllib2
from netaddr import *

import python.nailgun_client as fuel


def delete_environment():
        #   Clean Fuel cluster

    client = fuel.NailgunClient(str(fuel_ip))
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

def create_environment():
    #   Connect to Fuel Main Server

    client = fuel.NailgunClient(str(fuel_ip))

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

    #    settings = json.loads(cluster_settings['settings'])
    settings = generate_components_config()

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
                                   and k['status'] == 'discover'])

        if actual_kvm_count >= int(kvm_count):
            break
        counter += 5
        if counter > 600:
            raise RuntimeError
        time.sleep(5)

        #   Add all available nodes to cluster

    #    for node_name, params in json.loads(cluster_settings['node_roles']).items():
    for node_name, params in json.loads(generate_nodes_config()).items():
        node = next(k for k in client.list_nodes()
                    if not k['cluster'] and k['online'])
        data = {"cluster_id": str(cluster_id),
                "pending_roles": params['roles'],
                "pending_addition": True,
                "name": node_name,
        }
        client.update_node(node['id'], data)

    #   Move networks on interfaces

    for node in client.list_cluster_nodes(cluster_id):
#        networks_dict = json.loads(cluster_settings['interfaces'])
        networks_dict = generate_interfaces_config()
        update_node_networks(client, node['id'], networks_dict)

    #   Update network

    default_networks = client.get_networks(cluster_id)

#    networks = json.loads(cluster_settings['networks'])
    networks = generate_network_config()

    change_dict = networks.get('networking_parameters', {})
    for key, value in change_dict.items():
        default_networks['networking_parameters'][key] = value

    for net in default_networks['networks']:
        change_dict = networks.get(net['name'], {})
        for key, value in change_dict.items():
            net[key] = value

    client.update_network(cluster_id,
                          default_networks['networking_parameters'],
                          default_networks['networks'])


def deploy_environment():
    client = fuel.NailgunClient(str(fuel_ip))
    cluster_id = client.get_cluster_id(cluster_settings['env_name'])
    client.deploy_cluster_changes(cluster_id)


def update_node_networks(client, node_id, interfaces_dict, raw_data=None):

#    interfaces_dict['eth0'] = interfaces_dict.get('eth0', [])
#    if 'fuelweb_admin' not in interfaces_dict['eth0']:
#        interfaces_dict['eth0'].append('fuelweb_admin')

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
    notif_count = 0
    done_deploy = 0
    list_notification = []

    while True:
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


def generate_nodes_config():
    controller = ["controller"]
    compute = ["compute"]
    ceph_controller = int(cluster_settings.get('ceph_controller'))
    ceph_compute = int(cluster_settings.get('ceph_compute'))
    d = {}
    ceph = False
    cnt_count = int(cluster_settings.get('controller_count'))
    cmp_count = int(cluster_settings.get('compute_count'))

    if cluster_settings.get('ceilometer', 'false') == 'true':
        controller.append("mongo")
    for option in cluster_settings.viewkeys():
        if "ceph" in option:
            if cluster_settings.get(option) == "true":
                ceph = True

    for i in xrange(cnt_count):
        s = "controller_%d" % i
        d[s] = {"manufacturer": "QEMU"}
        d[s]["roles"] = controller
    for i in xrange(cmp_count):
        s = "compute_%d" % i
        d[s] = {"manufacturer": "QEMU"}
        d[s]["roles"] = compute

    if ceph:
        for i in xrange(ceph_compute):
            s = "compute_%d" % i
            d[s]["roles"] = compute + ["ceph-osd"]
        for i in xrange(ceph_controller):
            s = "controller_%d" % i
            d[s]["roles"] = controller + ["ceph-osd"]

    if cluster_settings.get('volumes_lvm') == "true":
        controller.append("cinder")

    return str(json.dumps(d))

def generate_interfaces_config():
    interfaces = dict(parser.items('interfaces'))
    netmap = {}
    for key in interfaces.keys():
        if interfaces[key] != "":
            netmap["%s" % key] = interfaces[key].split(',')
    return netmap

def generate_network_config():
    networks = {}
    cidr = cluster_settings.get("cidr")
    mask = IPNetwork(cidr).netmask
    net_size = int(IPNetwork(cidr).prefixlen)
    public_start = cluster_settings.get("public_range").split('-')[0]
    public_end = cluster_settings.get("public_range").split('-')[1]
    floating_start = cluster_settings.get("floating_range").split('-')[0]
    floating_end = cluster_settings.get("floating_range").split('-')[1]

    networks["public"] = {"network_size": net_size,
                          "netmask": "%s" % mask,
                          "ip_ranges": [["%s" % public_start, "%s" % public_end]],
                          "cidr": "%s" % cidr,
                          "gateway": cluster_settings.get("gateway")}
    networks["management"] = {"vlan_start": int(cluster_settings.get("management_vlan"))}
    networks["storage"] = {"vlan_start": int(cluster_settings.get("storage_vlan"))}
    networks["networking_parameters"] = {"floating_ranges": [["%s" % floating_start, "%s" % floating_end]]}

    if cluster_settings.get("net_segment_type") == "vlan":
        floating_vlan_start = cluster_settings.get("floating_vlan_range").split('-')[0]
        floating_vlan_end = cluster_settings.get("floating_vlan_range").split('-')[1]
        networks["networking_parameters"]["vlan_range"] = [int(floating_vlan_start), int(floating_vlan_end)]

    if cluster_settings.get("net_provider") == "nova_network":
        nn_floating_vlan = cluster_settings.get("nn_floating_vlan")
#        networks["fixed"] = {"vlan_start": int(cluster_settings.get("fixed_vlan"))}
        networks["networking_parameters"]["fixed_networks_vlan_start"] = int(nn_floating_vlan)

    return networks

def generate_components_config():
    settings = {}
    settings["sahara"] = s2b(cluster_settings.get('sahara', 'false'))
    settings["murano"] = s2b(cluster_settings.get('murano', 'false'))
    settings["ceilometer"] = s2b(cluster_settings.get('ceilometer', 'false'))
    settings["volumes_lvm"] = s2b(cluster_settings.get('volumes_lvm', 'false'))
    settings["volumes_ceph"] = s2b(cluster_settings.get('volumes_ceph', 'false'))
    settings["images_ceph"] = s2b(cluster_settings.get('images_ceph', 'false'))
    settings["ephemeral_ceph"] = s2b(cluster_settings.get('ephemeral_ceph', 'false'))
    settings["osd_pool_size"] = cluster_settings.get('osd_pool_size', 1)
    return settings


def s2b(v):
    return v.lower() in ("yes", "true", "t", "1")


if __name__ == '__main__':
    parser = SafeConfigParser()
    parser.read(argv[1])
    cluster_settings = dict(parser.items('cluster'))
    fuel_ip = argv[2]
    kvm_count = int(cluster_settings.get('node_count'))

    delete_environment()
    create_environment()
    deploy_environment()
    await_deploy()
#    print generate_network_config()
#    print generate_interfaces_config()
#    print generate_nodes_config()
