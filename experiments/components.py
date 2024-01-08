from simbricks.orchestration.simulators import QemuHost
from simbricks.orchestration.nodeconfig import NodeConfig, AppConfig
from simbricks.orchestration.experiment.experiment_environment import ExpEnv

import typing as tp
import math

import os
PROJECT_ROOT=os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

'''
LegosOS Kernel Nodes (Memory Component and Processor Component)
'''
class LegoKernelNode(NodeConfig):

    def __init__(self) -> None:
        super().__init__()
        self.app = AppConfig() # No app is needed
        self.lego_kernel = '' # pcomponent / mcomponent


class LegoPComponentNode(LegoKernelNode):

    def __init__(self, initcmd: str) -> None:
        super().__init__()
        self.lego_kernel = 'pcomponent'
        self.kcmd_append = 'initcmd=\\"' + initcmd +'\\"'
        self.memory = '8G'
        self.cores = 8


class LegoMComponentNode(LegoKernelNode):
    
    def __init__(self) -> None:
        super().__init__()
        self.lego_kernel = 'mcomponent'
        self.kcmd_append = ''
        self.memory = '8G'
        self.cores = 8


class LegoKernelQemuHost(QemuHost):
    
    def __init__(self, node_config: LegoKernelNode) -> None:
        super().__init__(node_config)

    def prep_cmds(self, env: ExpEnv) -> tp.List[str]:
        return [ ] # Running LegoOS images does not require disk images
    
    def run_cmd(self, env: ExpEnv) -> tp.List[str]:
        accel = ',accel=kvm:tcg' if not self.sync else ''
        if self.node_config.kcmd_append:
            kcmd_append = ' ' + self.node_config.kcmd_append
        else:
            kcmd_append = ''

        cmd = (
            f'{env.qemu_path} -machine q35{accel} -serial mon:stdio '
            '-cpu Skylake-Server -display none -nic none '
            f'-m {self.node_config.memory} -smp {self.node_config.cores} '
            f'-kernel {PROJECT_ROOT}/output/images/lego-kernels/{self.node_config.lego_kernel}.bzImage '
            f'-append "earlyprintk=ttyS0 console=ttyS0 memmap=2G$4G {self.node_config.kcmd_append}" '
            f'-L {env.repodir}/sims/external/qemu/pc-bios/ '
        )

        if self.sync:
            unit = self.cpu_freq[-3:]
            if unit.lower() == 'ghz':
                base = 0
            elif unit.lower() == 'mhz':
                base = 3
            else:
                raise ValueError('cpu frequency specified in unsupported unit')
            num = float(self.cpu_freq[:-3])
            shift = base - int(math.ceil(math.log(num, 2)))

            cmd += f' -icount shift={shift},sleep=off '

        for dev in self.pcidevs:
            cmd += f'-device simbricks-pci,socket={env.dev_pci_path(dev)}'
            if self.sync:
                cmd += ',sync=on'
                cmd += f',pci-latency={self.pci_latency}'
                cmd += f',sync-period={self.sync_period}'
            else:
                cmd += ',sync=off'
            cmd += ' '

        # qemu does not currently support net direct ports
        assert len(self.net_directs) == 0
        # qemu does not currently support mem device ports
        assert len(self.memdevs) == 0
        return cmd


'''
LegosOS Linux Module Nodes (Storage Component, etc.)
'''
DISK_RESOURCES_DIR = f'/tmp/guest/resources'

class LegoModuleConfig(AppConfig):

    def __init__(self) -> None:
        super().__init__()
        self.modules = []
        self.resources = []

    def config_files(self) -> tp.Dict[str, tp.IO]:
        files = {}
        for m in self.modules:
            files[f'modules/{m}.ko'] = open(f'{PROJECT_ROOT}/output/images/lego-linux-modules/{m}.ko', 'rb')
        for target, source in self.resources:
            files[f'resources/{target}'] = open(f'{source}', 'rb')
        return {**files, **super().config_files()}
    
    def run_cmds(self, node: NodeConfig) -> tp.List[str]:
        cmds = []
        for m in self.modules:
            cmds.append(f'insmod /tmp/guest/modules/{m}.ko')
        cmds.append('sleep infinity')
        return cmds


class LegoModuleNode(NodeConfig):

    def __init__(self, lego_module_config: LegoModuleConfig) -> None:
        super().__init__()
        self.app = lego_module_config
        self.memory = '8G'
        self.cores = 8


class LegoModuleQemuHost(QemuHost):
    
    def __init__(self, node_config: LegoModuleNode) -> None:
        super().__init__(node_config)

    def prep_cmds(self, env: ExpEnv) -> tp.List[str]:
        return [
            f'{env.qemu_img_path} create -f qcow2 -o '
            f'backing_file="{PROJECT_ROOT}/output/images/linux4lego" '
            f'{env.hdcopy_path(self)}'
        ]
    
    def run_cmd(self, env: ExpEnv) -> str:
        accel = ',accel=kvm:tcg' if not self.sync else ''

        cmd = (
            f'{env.qemu_path} -machine q35{accel} -serial mon:stdio '
            '-cpu Skylake-Server -display none -nic none '
            f'-m {self.node_config.memory} -smp {self.node_config.cores} '
            f'-kernel {PROJECT_ROOT}/output/images/vmlinuz '
            f'-drive file={env.hdcopy_path(self)},if=ide,index=0,media=disk '
            f'-drive file={env.cfgtar_path(self)},if=ide,index=1,media=disk,'
            'driver=raw '
            '-append "earlyprintk=ttyS0 console=ttyS0 root=/dev/sda1 '
            f'init=/simbricks/guestinit.sh rw" '
            f'-L {env.repodir}/sims/external/qemu/pc-bios/ '
        )

        if self.sync:
            unit = self.cpu_freq[-3:]
            if unit.lower() == 'ghz':
                base = 0
            elif unit.lower() == 'mhz':
                base = 3
            else:
                raise ValueError('cpu frequency specified in unsupported unit')
            num = float(self.cpu_freq[:-3])
            shift = base - int(math.ceil(math.log(num, 2)))

            cmd += f' -icount shift={shift},sleep=off '

        for dev in self.pcidevs:
            cmd += f'-device simbricks-pci,socket={env.dev_pci_path(dev)}'
            if self.sync:
                cmd += ',sync=on'
                cmd += f',pci-latency={self.pci_latency}'
                cmd += f',sync-period={self.sync_period}'
            else:
                cmd += ',sync=off'
            cmd += ' '

        # qemu does not currently support net direct ports
        assert len(self.net_directs) == 0
        # qemu does not currently support mem device ports
        assert len(self.memdevs) == 0
        return cmd
    