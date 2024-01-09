from simbricks.orchestration.experiments import Experiment
from simbricks.orchestration.simulators import SwitchNet, E1000NIC

import sys
import os
EXP_ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.append(EXP_ROOT)
from components import LegoPComponentNode, LegoMComponentNode, \
    LegoKernelQemuHost, LegoModuleConfig, LegoModuleNode, LegoModuleQemuHost, \
    DISK_RESOURCES_DIR

PROJECT_ROOT = os.path.dirname(EXP_ROOT)


SYNC             = os.getenv('sync')
SYNC_PERIOD      = int(os.getenv('sync_period'))
PCOMPONENT_MAC   = os.getenv('pcomponent_mac')
MCOMPONENT_MAC   = os.getenv('mcomponent_mac')
SCOMPONENT_MAC   = os.getenv('scomponent_mac')

if SYNC is None or SYNC_PERIOD is None or \
    PCOMPONENT_MAC is None or MCOMPONENT_MAC is None or SCOMPONENT_MAC is None:
    sys.stderr.write('hello-world: Environment variables not set.\n')
    sys.exit(1)

SYNC = True if SYNC == '1' else False

e = Experiment('LegoOS-phoenix-mapreduce')
e.checkpoint = True

# Processor component
pcomponent_node = LegoPComponentNode(initcmd=f'{DISK_RESOURCES_DIR}/word_count {DISK_RESOURCES_DIR}/words.txt')
pcomponent = LegoKernelQemuHost(pcomponent_node)
pcomponent.name = 'pcomponent'
pcomponent.wait = True
e.add_host(pcomponent)

pcomponent_nic = E1000NIC()
pcomponent_nic.mac = PCOMPONENT_MAC
pcomponent.add_nic(pcomponent_nic)
e.add_nic(pcomponent_nic)

# Memory component
mcomponent_node = LegoMComponentNode()
mcomponent = LegoKernelQemuHost(mcomponent_node)
mcomponent.name = 'mcomponent'
e.add_host(mcomponent)

mcomponent_nic = E1000NIC()
mcomponent_nic.mac = MCOMPONENT_MAC
mcomponent.add_nic(mcomponent_nic)
e.add_nic(mcomponent_nic)

# Storage component
scomponent_config = LegoModuleConfig()
scomponent_config.modules = ['ethfit', 'storage']
scomponent_config.resources = [
    ('word_count', f'{PROJECT_ROOT}/output/phoenix/word_count'),
    ('words.txt', f'{EXP_ROOT}/phoenix/words.txt')
]
scomponent_node = LegoModuleNode(scomponent_config)
scomponent = LegoModuleQemuHost(scomponent_node)
scomponent.name = 'scomponent'
e.add_host(scomponent)

scomponent_nic = E1000NIC()
scomponent_nic.mac = SCOMPONENT_MAC
scomponent.add_nic(scomponent_nic)
e.add_nic(scomponent_nic)

# Network
net = SwitchNet()
pcomponent_nic.set_network(net)
mcomponent_nic.set_network(net)
scomponent_nic.set_network(net)
e.add_network(net)

# Synchronization
for h in e.hosts:
    h.sync = SYNC
    h.sync_mode = 1 if SYNC else 0
    h.sync_period = SYNC_PERIOD
    h.pci_latency = SYNC_PERIOD

for n in e.nics:
    h.sync = SYNC
    n.sync_mode = 1 if SYNC else 0
    n.sync_period = SYNC_PERIOD
    n.pci_latency = SYNC_PERIOD
    n.eth_latency = SYNC_PERIOD

for n in e.networks:
    n.sync_mode = 1 if SYNC else 0
    n.sync_period = SYNC_PERIOD
    n.eth_latency = SYNC_PERIOD

experiments = [e]
