#Services tests
SERVTEST_LOCAL_PATH = '~/images'
SERVTEST_USERNAME = 'admin'
SERVTEST_PASSWORD = SERVTEST_USERNAME
SERVTEST_TENANT = SERVTEST_USERNAME

images = [
    {
        "url": "http://sahara-files.mirantis.com",
        "image": "savanna-0.3-vanilla-1.2.1-ubuntu-13.04.qcow2",
        "name": "savanna",
        "md5sum": "9ab37ec9a13bb005639331c4275a308d",
        "meta": {'_sahara_tag_1.2.1': 'True', '_sahara_tag_vanilla': 'True',
                 '_sahara_username': 'ubuntu'}
    },
    {
        "url": "http://public-repo-1.hortonworks.com/sahara/images",
        "image": "savanna-itests-ci-hdp-image-jdk-iptables-off.qcow2",
        "name": "hdp",
        "md5sum": "4d90a480b6fc696ad38bfb4323a4a6ea",
        "meta": {'_sahara_tag_1.3.2': 'True', '_sahara_tag_hdp': 'True',
                 '_sahara_username': 'root'}
    },
    {
        "url": "http://sahara-files.mirantis.com",
        "image": "sahara-icehouse-vanilla-2.3.0-ubuntu-13.10.qcow2",
        "name": "savanna2",
        "md5sum": "21b30d7c09e688d979b1cdc6953ba8f3",
        "meta": {'_sahara_tag_2.3.0': 'True', '_sahara_tag_vanilla': 'True',
                 '_sahara_username': 'ubuntu'}
    },
    {
        "url": "https://s3.amazonaws.com/public-repo-1.hortonworks.com/sahara/images",
        "image": "centos-6_4-64-hdp-2_0_6.qcow2",
        "name": "hdp2",
        "md5sum": "94fc2f4b616c9a726383d02ff218d992",
        "meta": {'_sahara_tag_2.0.6': 'True', '_sahara_tag_hdp': 'True',
                 '_sahara_username': 'root'}
    }
]
