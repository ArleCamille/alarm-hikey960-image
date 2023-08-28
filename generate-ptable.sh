#!/bin/bash
if [ "$(id -u)" -ne 0 ]; then echo "WARNING: not run as root. Might not work." >&2; fi

DEVICE_TYPE=${DEVICE_TYPE:-32g}
SECTOR_SIZE=${SECTOR_SIZE:-4096}
TEMP_FILE=$(mktemp /tmp/${DEVICE_TYPE}.XXXXXX)
# 128 entries at most
ENTRIES_IN_SECTOR=$(expr ${SECTOR_SIZE} / 128)
ENTRY_SECTORS=$(expr 128 / ${ENTRIES_IN_SECTOR})
PRIMARY_SECTORS=$(expr ${ENTRY_SECTORS} + 2)
SECONDARY_SECTORS=$(expr ${ENTRY_SECTORS} + 1)

# SECTOR_NUMBER means device size in 512-byte sectors
case ${DEVICE_TYPE} in
	4g)
		SECTOR_NUMBER=7471104
		;;
	8g)
		SECTOR_NUMBER=15269888
		;;
	32g)
		SECTOR_NUMBER=62447650
		;;
	64g)
		SECTOR_NUMBER=124895300
		;;
esac

SECTOR_ALIGNMENT=$(expr ${SECTOR_SIZE} / 512)
SECTOR_NUMBER=$(expr '(' ${SECTOR_NUMBER} '*' 512 + ${SECTOR_SIZE} - 1 ')' / ${SECTOR_SIZE})

# get the partition table
dd if=/dev/zero of=${TEMP_FILE} bs=${SECTOR_SIZE} count=${SECTOR_NUMBER} conv=sparse
LOOP_DEVICE=$(losetup -f)
losetup --sector-size ${SECTOR_SIZE} ${LOOP_DEVICE} ${TEMP_FILE}
sgdisk -U 2CB85345-6A91-4043-8203-723F0D28FBE8 -v ${LOOP_DEVICE}
case ${DEVICE_TYPE} in
	4g|8g)
		#[1: vrl: 1M-2M]
		sgdisk -n 1:0:+1M -t 1:0700 -u 1:496847AB-56A1-4CD5-A1AD-47F4ACF055C9 -c 1:"vrl" ${LOOP_DEVICE}
		#[2: vrl_backup: 2M-3M]
		sgdisk -n 2:0:+1M -t 2:0700 -u 2:61A36FC1-8EFB-4899-84D8-B61642EFA723 -c 2:"vrl_backup" ${LOOP_DEVICE}
		#[3: mcuimage: 3M-4M]
		sgdisk -n 3:0:+1M -t 3:0700 -u 3:65007411-962D-4781-9B2C-51DD7DF22CC3 -c 3:"mcuimage" ${LOOP_DEVICE}
		#[4: fastboot: 4M-12M]
		sgdisk -n 4:0:+8M -t 4:EF02 -u 4:496847AB-56A1-4CD5-A1AD-47F4ACF055C9 -c 4:"fastboot" ${LOOP_DEVICE}
		#[5: nvme: 12M-14M]
		sgdisk -n 5:0:+2M -t 5:0700 -u 5:00354BCD-BBCB-4CB3-B5AE-CDEFCB5DAC43 -c 5:"nvme" ${LOOP_DEVICE}
		#[6: boot: 14M-78M]
		sgdisk -n 6:0:+64M -t 6:EF00 -u 6:5C0F213C-17E1-4149-88C8-8B50FB4EC70E -c 6:"boot" ${LOOP_DEVICE}
		#[7: reserved: 78M-334M]
		sgdisk -n 7:0:+256M -t 7:0700 -u 7:BED8EBDC-298E-4A7A-B1F1-2500D98453B7 -c 7:"reserved" ${LOOP_DEVICE}
		#[8: cache: 334M-590M]
		sgdisk -n 8:0:+256M -t 8:8301 -u 8:A092C620-D178-4CA7-B540-C4E26BD6D2E2 -c 8:"cache" ${LOOP_DEVICE}
		#[9: system: 590M-End]
		sgdisk -n -E -t 9:8300 -u 9:FC56E345-2E8E-49AE-B2F8-5B9D263FE377 -c 9:"system" ${LOOP_DEVICE}
		;;
	32g|64g)
		#[1: vrl: 1M-2M]
		sgdisk -n 1:0:+1M -t 1:0700 -u 1:697c41e0-7a59-4dfa-a9a6-aa43ac5be684 -c 1:"vrl" ${LOOP_DEVICE}
		#[2: fastboot: 2M-14M]
		sgdisk -n 2:0:+12M -t 2:0700 -u 2:3f5f8c48-4402-4ace-9058-30bfea4fa53f -c 2:"fastboot" ${LOOP_DEVICE}
		#[3: nvme: 14M-20M]
		sgdisk -n 3:0:+6M -t 3:0700 -u 3:e2f5e2a9-c9b7-4089-9859-4498f1d3ef7e -c 3:"nvme" ${LOOP_DEVICE}
		#[4: fip: 20M-32M]
		sgdisk -n 4:0:+12M -t 3:0700 -u 4:dc1a888e-f17c-4964-92d6-f8fcc402ed8b -c 4:"fip" ${LOOP_DEVICE}
		#[5: cache: 32M-288M. Use this for ESP/boot instead]
		sgdisk -n 5:0:+256M -t 5:EF00 -u 5:10cc3268-05f0-4db2-aa00-707361427fc8 -c 5:"cache" ${LOOP_DEVICE}
		#[6: fw_lpm3: 288M-289M]
		sgdisk -n 6:0:+1M -t 6:0700 -u 6:5d8481d4-c170-4aa8-9438-8743c73ea8f5 -c 6:"fw_lpm3" ${LOOP_DEVICE}
		#[7: boot: 289M-353M. Obsolete in favor of cache]
		sgdisk -n 7:0:+64M -t 7:0700 -u 7:d3340696-9b95-4c64-8df6-e6d4548fba41 -c 7:"boot" ${LOOP_DEVICE}
		#[8: dts: 353M-369M]
		sgdisk -n 8:0:+16M -t 8:0700 -u 8:6e53b0bb-fa7e-4206-b607-5ae699e9f066 -c 8:"dts" ${LOOP_DEVICE}
		#[9: trustfirmware: 369M-371M]
		sgdisk -n 9:0:+2M -t 9:0700 -u 9:f1e126a6-ceef-45c1-aace-29f33ac9cf13 -c 9:"trustfirmware" ${LOOP_DEVICE}
		#[10: system: 371M-5059M]
		sgdisk -n 10:0:+4688M -t 10:8300 -u 10:c3e50923-fb85-4153-b925-759614d4dfcd -c 10:"system" ${LOOP_DEVICE}
		#[11: vendor: 5059M-5843M, XBOOTLDR]
		sgdisk -n 11:0:+784M -t 11:EA00 -u 11:919d7080-d71a-4ae1-9227-e4585210c837 -c 11:"vendor" ${LOOP_DEVICE}
		#[12: reserved: 5843M-5844M]
		sgdisk -n 12:0:+1M -t 12:0700 -u 12:611eac6b-bc42-4d72-90ac-418569c8e9b8 -c 12:"reserved" ${LOOP_DEVICE}
		#[13: userdata: 5844M-End]
		sgdisk -n -E -t 13:8300 -u 13:fea80d9c-f3e3-45d9-aed0-1d06e4abd77f -c 13:"userdata" ${LOOP_DEVICE}
		;;
esac

# print out the partition table before deleting the scratch file
echo 'Printing the partition table...'
fdisk -l ${LOOP_DEVICE}
echo 'Also outputting to ptable.log'
fdisk -l ${LOOP_DEVICE} > ptable.log

# get the primary partition table
dd if=${LOOP_DEVICE} of=prm_ptable.img bs=${SECTOR_SIZE} count=${PRIMARY_SECTORS}

BK_PTABLE_LBA=$(expr ${SECTOR_NUMBER} - ${SECONDARY_SECTORS})
dd if=${LOOP_DEVICE} of=sec_ptable.img skip=${BK_PTABLE_LBA} bs=${SECTOR_SIZE} count=${SECONDARY_SECTORS}

losetup -d ${LOOP_DEVICE}
rm -f ${TEMP_FILE}
