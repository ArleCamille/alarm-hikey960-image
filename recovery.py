#!/usr/bin/env python3
from argparse import ArgumentParser
import requests
import typing
from shutil import which
from urllib.request import urlretrieve
import os
import sys
from stat import S_IXUSR, S_IXGRP, S_IXOTH
import subprocess
import time

url_prefix = 'https://snapshots.linaro.org/reference-platform/components/uefi-staging/latest/hikey960/release'

def get_trueurl(url: str) -> str:
    r = requests.head(url, allow_redirects=True)
    return r.url

# TODO: parse query string
def download_file(url: str, destination: str) -> str:
    true_url = get_trueurl(url)
    urlretrieve(true_url, destination)

if __name__ == '__main__':
    parser = ArgumentParser(prog='HiKey960 recovery script')
    parser.add_argument('--console-device', '-c', required=True,
                        help='TTY device to UART')
    parser.add_argument('--otg-device', '-d', required=True,
                        help='TTY device to HiKey recovery')

    args = parser.parse_args()

    # Before running, check the permissions.
    if os.geteuid != 0:
        sys.exit('hikey_idt requires root permission to work')
    
    # ... and whether the TTY devices exist.
    #if not os.path.exists(args.console_device):
    #    sys.exit(f'Nonexistent device: {args.console_device}')
    if not os.path.exists(args.otg_device):
        sys.exit(f'Nonexistent device: {args.otg_device}')
    
    try:
        os.mkdir('recovery')
    except FileExistsError:
        if not os.path.isdir('recovery'):
            sys.exit('path recovery exists and is not a directory')
        else:
            pass

    # Fetch required files: config, hikey_idt, hisi-sec_usb_xloader.img, hisi-sec_uce_boot.img, recovery.bin
    try:
        for f in ['config', 'hikey_idt', 'hisi-sec_usb_xloader.img', 'hisi-sec_uce_boot.img', 'recovery.bin']:
            if not os.path.isfile(f'recovery/{f}'):
                download_file(f'{url_prefix}/{f}', f'recovery/{f}')
    except:
        sys.exit('download from Linaro repository failed')
    
    # Make hikey_idt executable
    os.chmod('recovery/hikey_idt', S_IXUSR | S_IXGRP | S_IXOTH)

    print('Running hikey_idt . . .')
    subprocess.run(['./recovery/hikey_idt', '-c', 'recovery/config', '-p', args.otg_device])

    # After recovery, wait for some time and run fastboot
    time.sleep(1)
    with open(args.console_device, 'ab') as tty:
        print(b'f\n', file=tty)

    # Check whether the fastboot command exists
    fastboot_command = which('fastboot')
    if fastboot_command is None:
        print('Fastboot is not installed, so we cannot proceed further.', file=sys.stderr)
        print('Install Android Fastboot and try again.', file=sys.stderr)
        sys.exit(1)

    bash_command = which('bash')

    subprocess.run([fastboot_command, 'flash', 'ptable', 'prm_ptable.img'])
    subprocess.run([fastboot_command, 'flash', 'xloader', 'stock-images/hisi-sec_xloader.img'])
    subprocess.run([fastboot_command, 'flash', 'fastboot', 'stock-images/l-loader.bin'])
    subprocess.run([fastboot_command, 'flash', 'fip', 'fip.bin'])
    subprocess.run([fastboot_command, 'reboot-bootloader'])

    print('Flashed preliminary images.')
    print('From here, flash using your own images (presumably with ./flash-all.sh).')