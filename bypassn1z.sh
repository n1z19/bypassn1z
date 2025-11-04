#!/usr/bin/env bash

mkdir -p logs
mkdir -p boot
set -e

log="last".log
cd logs
touch "$log"
cd ..

{

echo "[*] Command ran:`if [ $EUID = 0 ]; then echo " sudo"; fi` ./bypassn1z.sh $@"

# =========
# Variables
# ========= 
version="3.0"
os=$(uname)
dir="$(pwd)/binaries/$os"
max_args=1
arg_count=0
disk=8

if [ ! -d "ramdisk/" ]; then
    git clone https://github.com/n1z19/ramdisk.git
fi
# =========
# Functions
# =========
remote_cmd() {
    sleep 1
    "$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "$@"
}

remote_cp() {
    sleep 1
    "$dir"/sshpass -p 'alpine' scp -r -o StrictHostKeyChecking=no -P2222 $@
}

step() {
    rm -f .entered_dfu
    for i in $(seq "$1" -1 0); do
        if [[ -e .entered_dfu ]]; then
            rm -f .entered_dfu
            break
        fi
        if [[ $(get_device_mode) == "dfu" || ($1 == "10" && $(get_device_mode) != "none") ]]; then
            touch .entered_dfu
        fi &
        printf '\r\e[K\e[1;36m%s (%d)' "$2" "$i"
        sleep 1
    done
    printf '\e[0m\n'
}

print_help() {
    cat << EOF
Usage: $0 [Options] [ subcommand | on ios 15 you have to use palera1n to jailbreak it when you jailbreak it you can bypass it 
./bypass

Options:
    --dualboot              IF YOU WANT TO BYPASS iCloud IN THE DUALBOOT USE THIS: ./bypassn1z --bypass 14.3 --dualboot
    --jail_palera1n         USE THIS ONLY WHEN YOU ALREADY JAILBROKEN WITH SEMITETHERED palera1n/nizira1n TO AVOID DISK ERRORS ON BYPASSED DUALBOOT ./bypassn1z.sh --bypass 14.3 --dualboot --jail_palera1n
    --tethered              BYPASS THE MAIN iOS 13,14,15, USE THIS IF YOU HAVE checkra1n or palera1n tethered jailbreak or semitethered (the device will BOOTLOOP IF YOU TRY TO BOOT WITHOUT JAILBREAK ./bypassn1z.sh --bypass 14.3, ALSO IF YOU WANT TO BRING BACK iCloud YOU CAN USE ./bypassn1z.sh --bypass 14.3 --back
    --debug                 DEBUG THIS SCRIPT
    --backup-activations    THIS COMMAND WILL BACKUP YOUR ACTIVATIONFILES INTO  activationsBackup/.
    --restore-activations   THIS COMMAND WILL RESTORE THE ACTIVATIONFILES BACK TO YOUR DEVICE.
Subcommands:
    clean               !!!!!CAUTION!!!!! THIS COMMAND DELETES YOUR CREATED BOOTFILES


THE iOS VERSION ARGUMENT SHOULD BE THE iOS VERSION OF YOUR DEVICE!!
IT IS REQUIRED WHEN STARTING FROM DFU MODE!!
EOF
}

parse_opt() {
    case "$1" in
        --)
            no_more_opts=1
            ;;
        --dualboot)
            dualboot=1
            ;;
        --tethered)
            tethered=1
            ;;
        --back)
            back=1
            ;;
        --jail_palera1n)
            jail_palera1n=1
            ;;
        --debug)
            debug=1
            ;;
        --backup-activations)
            backup_activations=1
            ;;
        --restore-activations)
            restore_activations=1
            ;;
        --help)
            print_help
            exit 0
            ;;
        *)
            echo "[-] UNKNOWN OPTION $1. USE $0 --help FOR HELP";
            exit 1;
    esac
}

parse_arg() {
    arg_count=$((arg_count + 1))
    case "$1" in
        dfuhelper)
            dfuhelper=1
            ;;
        clean)
            clean=1
            ;;
        *)
            version="$1"
            ;;
    esac
}

parse_cmdline() {
    for arg in $@; do
        if [[ "$arg" == --* ]] && [ -z "$no_more_opts" ]; then
            parse_opt "$arg";
        elif [ "$arg_count" -lt "$max_args" ]; then
            parse_arg "$arg";
        else
            echo "[-] TOO MANY ARGUMENTS. USE $0 --help FOR HELP";
            exit 1;
        fi
    done
}

recovery_fix_auto_boot() {
    "$dir"/irecovery -c "setenv auto-boot true"
    "$dir"/irecovery -c "saveenv"
}

_info() {
    if [ "$1" = 'recovery' ]; then
        echo $("$dir"/irecovery -q | grep "$2" | sed "s/$2: //")
    elif [ "$1" = 'normal' ]; then
        echo $("$dir"/ideviceinfo | grep "$2: " | sed "s/$2: //")
    fi
}

_pwn() {
    pwnd=$(_info recovery PWND)
    if [ "$pwnd" = "" ]; then
        echo "[*] PWNING DEVICE"
        "$dir"/gaster pwn
        sleep 2
        #"$dir"/gaster reset
        #sleep 1
    fi
}

_reset() {
        echo "[*] RESETTING DFU STATE"
        "$dir"/gaster reset
}

get_device_mode() {
    if [ "$os" = "Darwin" ]; then
        sp="$(system_profiler SPUSBDataType 2> /dev/null)"
        apples="$(printf '%s' "$sp" | grep -B1 'Vendor ID: 0x05ac' | grep 'Product ID:' | cut -dx -f2 | cut -d' ' -f1 | tail -r)"
    elif [ "$os" = "Linux" ]; then
        apples="$(lsusb | cut -d' ' -f6 | grep '05ac:' | cut -d: -f2)"
    fi
    local device_count=0
    local usbserials=""
    for apple in $apples; do
        case "$apple" in
            12a8|12aa|12ab)
            device_mode=normal
            device_count=$((device_count+1))
            ;;
            1281)
            device_mode=recovery
            device_count=$((device_count+1))
            ;;
            1227)
            device_mode=dfu
            device_count=$((device_count+1))
            ;;
            1222)
            device_mode=diag
            device_count=$((device_count+1))
            ;;
            1338)
            device_mode=checkra1n_stage2
            device_count=$((device_count+1))
            ;;
            4141)
            device_mode=pongo
            device_count=$((device_count+1))
            ;;
        esac
    done
    if [ "$device_count" = "0" ]; then
        device_mode=none
    elif [ "$device_count" -ge "2" ]; then
        echo "[-] PLEASE ATTACH ONLY ONE DEVICE!" > /dev/tty
        kill -30 0
        exit 1;
    fi
    if [ "$os" = "Linux" ]; then
        usbserials=$(cat /sys/bus/usb/devices/*/serial)
    elif [ "$os" = "Darwin" ]; then
        usbserials=$(printf '%s' "$sp" | grep 'Serial Number' | cut -d: -f2- | sed 's/ //')
    fi

    if grep -qE '(ramdisk tool|SSHRD_Script) (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) [0-9]{1,2} [0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2}' <<< "$usbserials"; then
        device_mode=ramdisk
    fi
    echo "$device_mode"
}

_wait() {
    if [ "$(get_device_mode)" != "$1" ]; then
        echo "[*] WAITING FOR DEVICE IN $1 MODE"
    fi

    while [ "$(get_device_mode)" != "$1" ]; do
        sleep 1
    done

    if [ "$1" = 'recovery' ]; then
        recovery_fix_auto_boot;
    fi
}

_dfuhelper() {
    local step_one;
    deviceid=$( [ -z "$deviceid" ] && _info normal ProductType || echo $deviceid )
    if [[ "$1" = 0x801* && "$deviceid" != *"iPad"* ]]; then
        step_one="HOLD VOLUME DOWN + SIDE BUTTON"
    else
        step_one="HOLD HOME + POWER BUTTON"
    fi
    echo "[*] TO GET INTO DFU MODE, YOU WILL BE GUIDED THROUGH 2 STEPS:"
    echo "[*] PRESS ANY KEY WHEN READY TO BOOT INTO DFU MODE"
    read -n 1 -s
    step 3 "GET READY"
    step 4 "$step_one" &
    sleep 3
    "$dir"/irecovery -c "reset" &
    sleep 1
    if [[ "$1" = 0x801* && "$deviceid" != *"iPad"* ]]; then
        step 10 'RELEASE SIDE BUTTON, BUT KEEP HOLDING VOLUME DOWN.'
    else
        step 10 'RELEASE POWER BUTTON, BUT KEEP HOLDING HOME BUTTON.'
    fi
    sleep 1

    if [ "$(get_device_mode)" = "recovery" ]; then
        _dfuhelper
    fi

    if [ "$(get_device_mode)" = "dfu" ]; then
        echo "[*] DEVICE ENTERED DFU!"
    else
        echo "[-] DEVICE DID NOT ENTER DFU MODE, RERUN THE SCRIPT AND TRY AGAIN"
        return -1
    fi
}

_kill_if_running() {
    if (pgrep -u root -x "$1" &> /dev/null > /dev/null); then
        # yes, it's running as root. kill it
        sudo killall $1 &> /dev/null
    else
        if (pgrep -x "$1" &> /dev/null > /dev/null); then
            killall $1 &> /dev/null
        fi
    fi
}

ask_reboot_or_exit() {
    while true; do
        echo -n "WOULD YOU LIKE TO REBOOT YOUR DEVICE OR EXIT? (reboot/exit): "
        read -r choice

        case $choice in
            reboot)
                echo "[*] REBOOTING THE DEVICE..."
                remote_cmd "/usr/sbin/nvram auto-boot=true"
                remote_cmd "/sbin/reboot"
                break
                ;;
            exit)
                echo "[*] EXITING THE SCRIPT..."
                break;
                ;;
            *)
                echo "[!] INVALID OPTION. PLEASE ENTER 'reboot' OR 'exit'."
                ;;
        esac
    done
}

_exit_handler() {
    if [ "$os" = "Darwin" ]; then
        killall -CONT AMPDevicesAgent AMPDeviceDiscoveryAgent MobileDeviceUpdater || true
    fi

    [ $? -eq 0 ] && exit
    echo "[-] AN ERROR OCCURRED"

    if [ -d "logs" ]; then
        cd logs
        mv "$log" FAIL_${log}
        cd ..
    fi

    echo "[*] A FAILURE LOG HAS BEEN MADE. IF YOU'RE GOING TO ASK FOR HELP, PLEASE ATTACH THE LATEST LOG."
}
trap _exit_handler EXIT

# ===========
# Fixes
# ===========

# Prevent Finder from complaning
if [ "$os" = "Linux"  ]; then
    /bin/chmod +x getSSHOnLinux.sh
    sudo bash ./getSSHOnLinux.sh &
fi

if [ "$os" = 'Linux' ]; then
    linux_cmds='lsusb'
fi

for cmd in curl unzip python3 git ssh scp killall sudo grep pgrep ${linux_cmds}; do
    if ! command -v "${cmd}" > /dev/null; then
        echo "[-] COMMAND '${cmd}' NOT INSTALLED. PLEASE INSTALL IT!";
        cmd_not_found=1
    fi
done

if [ "$cmd_not_found" = "1" ]; then
    exit 1
fi

# Check for pyimg4
if ! python3 -c 'import pkgutil; exit(not pkgutil.find_loader("pyimg4"))'; then
    echo '[-PYTHON-] pyimg4 NOT INSTALLED.PRESS ANY KEY TO INSTALL IT OR PRESS CTRL + C TO CANCEL'
    read -n 1 -s
    python3 -m pip install pyimg4
fi

# ============disk0s1s
# Prep
# ============

# Update submodules
git submodule update --init --recursive

# Re-create work dir if it exists, else, make it
if [ -e work ]; then
    rm -rf work
    mkdir work
else
    mkdir work
fi

/bin/chmod +x "$dir"/*
#if [ "$os" = 'Darwin' ]; then
#    xattr -d com.apple.quarantine "$dir"/*
#fi

# ============
# Start
# ============

echo "dualboot/downgrade | Bypass :)"
echo "Written by MRX "
echo ""

parse_cmdline "$@"

if [ "$debug" = "1" ]; then
    set -o xtrace
fi

if [ "$clean" = "1" ]; then
    rm -rf  work blobs/ boot/$deviceid/  ipsw/*
    echo "[*] REMOVED THE CREATED BOOTFILES"
    exit
fi


# Get device's iOS version from ideviceinfo if in normal mode
echo "[*] WAITING FOR DEVICES"
while [ "$(get_device_mode)" = "none" ]; do
    sleep 1;
done
echo $(echo "[*] DETECTED $(get_device_mode) MODE DEVICE" | sed 's/dfu/DFU/')

if grep -E 'pongo|checkra1n_stage2|diag' <<< "$(get_device_mode)"; then
    echo "[-] DETECTED DEVICE IN UNSUPPORTED MODE!'$(get_device_mode)'"
    exit 1;
fi

if [ "$(get_device_mode)" != "normal" ] && [ -z "$version" ] && [ "$dfuhelper" != "1" ]; then
    echo "[-] YOU MUST PASS THE VERSiON YOUR DEVICE Is ON WHEN NOT STARTING FROM NORMAL MODE"
    exit
fi

if [ "$(get_device_mode)" = "ramdisk" ]; then
    # If a device is in ramdisk mode, perhaps iproxy is still running?
    _kill_if_running iproxy
    echo "[*] REBOOTING DEVICE IN SSH RAMDISK"
    if [ "$os" = 'Linux' ]; then
        sudo "$dir"/iproxy 2222 22 >/dev/null &
    else
        "$dir"/iproxy 2222 22 >/dev/null &
    fi
    sleep 1
    remote_cmd "/sbin/reboot"
    _kill_if_running iproxy
    _wait recovery
fi

if [ "$(get_device_mode)" = "normal" ]; then
    version=${version:-$(_info normal ProductVersion)}
    arch=$(_info normal CPUArchitecture)
    if [ "$arch" = "arm64e" ]; then
        echo "[-] BYPASS DOESN'T, AND NEVER WILL WORK ON NON-CHECKM8 DEVICES!"
        exit
    fi
    echo "HELLO, $(_info normal ProductType) ON $version!"

    echo "[*] SWITCHING DEVICE INTO RECOVErY MODE..."
    "$dir"/ideviceenterrecovery $(_info normal UniqueDeviceID)
    _wait recovery
fi

# Grab more info
echo "[*] GETTING DEVICE INFO..."
cpid=$(_info recovery CPID)
model=$(_info recovery MODEL)
deviceid=$(_info recovery PRODUCT)
ECID=$(_info recovery ECID)

echo "$cpid"
echo "$model"
echo "$deviceid"

if [ "$dfuhelper" = "1" ]; then
    echo "[*] RUNNING DFU HELPER"
    _dfuhelper "$cpid"
    exit
fi

# Have the user put the device into DFU
if [ "$(get_device_mode)" != "dfu" ]; then
    recovery_fix_auto_boot;
    _dfuhelper "$cpid" || {
        echo "[-] FAILED TO ENTER DFU MODE, RUN bypassn1z.sh AGAIN"
        exit -1
    }
fi
sleep 2


# ============
# Ramdisk
# ============

# Dump blobs, and install pogo if needed 
if [ true ]; then
    mkdir -p blobs

    cd ramdisk
    /bin/chmod +x sshrd.sh
    echo "[*] CREATING RAMDISK"
    ./sshrd.sh $(if [[ $version == 16.* ]]; then echo "16.0.3"; else echo "15.6"; fi)

    echo "[*] BOOTING RAMDISK"
    ./sshrd.sh boot
    cd ..
    # remove special lines from known_hosts
    if [ -f ~/.ssh/known_hosts ]; then
        if [ "$os" = "Darwin" ]; then
            sed -i.bak '/localhost/d' ~/.ssh/known_hosts
            sed -i.bak '/127\.0\.0\.1/d' ~/.ssh/known_hosts
        elif [ "$os" = "Linux" ]; then
            sed -i '/localhost/d' ~/.ssh/known_hosts
            sed -i '/127\.0\.0\.1/d' ~/.ssh/known_hosts
        fi
    fi

    # Execute the commands once the rd is booted
    if [ "$os" = 'Linux' ]; then
        sudo "$dir"/iproxy 2222 22 >/dev/null &
    else
        "$dir"/iproxy 2222 22 >/dev/null &
    fi

    if ! ("$dir"/sshpass -p 'alpine' ssh -o StrictHostKeyChecking=no -p2222 root@localhost "    looks like that ssh it's not working try to reboot your computer or send the log file trough discord"
                read -p "Press [ENTER] to continue"
            fi
        fi
    done

    echo $disk
    echo "[*] TESTING FOR BASEBAND PRESENCE "
    if [ "$(remote_cmd "/usr/bin/mgask HasBaseband | grep -E 'true|false'")" = "true" ] && [[ "${cpid}" == *"0x700"* ]]; then # checking if your device has baseband 
        disk=7
    elif [ "$(remote_cmd "/usr/bin/mgask HasBaseband | grep -E 'true|false'")" = "false" ]; then
        if [[ "${cpid}" == *"0x700"* ]]; then
            disk=6
        else
            disk=7
        fi
    fi

    # that is in order to know the partitions needed
    if [ "$dualboot" = "1" ]; then
        if [ "$jail_palera1n" = "1" ]; then
            disk=$(($disk + 1)) # if you have the palera1n jailbreak that will create + 1 partition for example your jailbreak is installed on disk0s1s8 that will create a new partition on disk0s1s9 so only you have to use it if you have palera1n
        fi
    fi
    echo $disk
    dataB=$(($disk + 1))
    prebootB=$(($dataB + 1))
    echo $dataB
    echo $prebootB

    if [ "$backup_activations" = "1" ] || [ "$restore_activations" = "1" ] && [ "$dualboot" = "1" ]; then
        remote_cmd "/sbin/mount_apfs /dev/disk0s1s${disk} /mnt1/"
        remote_cmd "/sbin/mount_apfs /dev/disk0s1s${dataB} /mnt2/"
    else
        remote_cmd "/usr/bin/mount_filesystems"
    fi

    
    if [ "$backup_activations" = "1" ]; then
        echo "[*] BACKUP ACTIVATIONFILES..."
        activationsDir=$(remote_cmd 'find /mnt2/containers/Data/System/ -type d | grep internal | sed "s|/internal.*||"')
        
        if ! remote_cmd "[ -f "$activationsDir/activation_records/activation_record.plist" ]"; then
            echo "[*] SADLY WE COULDN'T FIND THE ACTIVATIONFILES, IT COULD BE BECAUSE YOUR DEVICE IS NOT ACTIVATED"
            ask_reboot_or_exit
            exit;
        fi

        echo "[*] ACTIVATIONFILES DETECTED"
        echo "[*] BACKING UP ..."
        remote_cmd "mkdir -p /mnt1/activationsBackup/"
        remote_cmd "cp -rf $activationsDir/activation_records /mnt1/activationsBackup"
        remote_cmd "cp -rf $activationsDir/internal /mnt1/activationsBackup"
        remote_cmd "cp -rf /mnt2/mobile/Library/FairPlay /mnt1/activationsBackup"
        remote_cmd "cp -rf /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist /mnt1/activationsBackup"

        mkdir -p activationsBackup/
        mkdir -p "activationsBackup/$ECID/"
        
        remote_cp root@localhost:/mnt1/activationsBackup/ "activationsBackup/$ECID/"
        echo "[*] WE SAVED ACTIVATIONFILES IN activationsBackup/$ECID/ "

        echo "[*] REBOOTING THE DEVICE..."
        remote_cmd "/usr/sbin/nvram auto-boot=true"
        remote_cmd "/sbin/reboot"
        exit 0;
    fi

    if [ "$restore_activations" = "1" ]; then

        if [ ! -f "activationsBackup/$ECID/activationsBackup/activation_records/activation_record.plist" ]; then
            echo "[!] IT LOOKS LIKE YOU DON'T HAVE ACTIVATION FILES SAVED IN activationsBackup/$ECID"
            ask_reboot_or_exit
            exit;
        fi

        echo "[*] RESTORING ACTIVATIONFILES ..."
        activationsDir=$(remote_cmd 'find /mnt2/containers/Data/System/ -type d | grep internal | sed "s|/internal.*||"')
        
        if ! remote_cmd "[ ! -f \"$activationsDir/internal\" ]"; then
            echo "[*] SADLY WE COULDN'T FIND THE ACTIVATION DIRECTORY IN /mnt2/containers/Data/System/"
            ask_reboot_or_exit
            exit
        fi

        echo "[*] ACTIVATION DIRECTORY DETECTED IN $activationsDir"
        echo "[*] COPYING ACTIVATIONFILES"
        
        remote_cmd "
        if [ -d \"$activationsDir/activation_records/\" ]; then
            chflags -fR nouchg \"$activationsDir/activation_records/\";
        fi

        if [ -f \"$activationsDir/internal/data_ark.plist\" ]; then
            chflags -fR nouchg \"$activationsDir/internal/data_ark.plist\";
        fi

        if [ -f \"/mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist\" ]; then
            chflags -fR nouchg \"/mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist\";
        fi
        "

        remote_cmd "mkdir -p /mnt2/mobile/Media/Downloads/activationsBackup"
        remote_cp activationsBackup/"$ECID"/activationsBackup root@localhost:/mnt2/mobile/Media/Downloads/
        remote_cmd "chflags -fR nouchg /mnt2/mobile/Media/Downloads/activationsBackup"
        
        remote_cmd "/usr/sbin/chown -R mobile:mobile /mnt2/mobile/Media/Downloads/activationsBackup"

        remote_cmd "/bin/chmod -R 755 /mnt2/mobile/Media/Downloads/activationsBackup"
        remote_cmd "/bin/chmod 644 /mnt2/mobile/Media/Downloads/activationsBackup/internal/data_ark.plist /mnt2/mobile/Media/Downloads/activationsBackup/activation_records/activation_record.plist /mnt2/mobile/Media/Downloads/activationsBackup/com.apple.commcenter.device_specific_nobackup.plist"
        remote_cmd "/bin/chmod 664 /mnt2/mobile/Media/Downloads/activationsBackup/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"


        remote_cmd "cp -rf /mnt2/mobile/Media/Downloads/activationsBackup/activation_records $activationsDir/"
        remote_cmd "cp -rf /mnt2/mobile/Media/Downloads/activationsBackup/internal $activationsDir/"
        remote_cmd "cp -rf /mnt2/mobile/Media/Downloads/activationsBackup/FairPlay /mnt2/mobile/Library/"
        remote_cmd "cp -rf /mnt2/mobile/Media/Downloads/activationsBackup/com.apple.commcenter.device_specific_nobackup.plist /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
 
        remote_cmd "/bin/chmod -R 755 /mnt2/mobile/Library/FairPlay/"
        remote_cmd "/usr/sbin/chown -R mobile:mobile /mnt2/mobile/Library/FairPlay/"
        remote_cmd "/bin/chmod 664 /mnt2/mobile/Library/FairPlay/iTunes_Control/iTunes/IC-Info.sisv"
        
        remote_cmd "/bin/chmod -R 777 $activationsDir/activation_records/"
        remote_cmd "chflags -R uchg $activationsDir/activation_records/"

        remote_cmd "/bin/chmod 755 $activationsDir/internal/data_ark.plist"
        remote_cmd "chflags -R uchg $activationsDir/internal/data_ark.plist"

        remote_cmd "/usr/sbin/chown root:mobile /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
        remote_cmd "/bin/chmod 755 /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"
        remote_cmd "chflags uchg /mnt2/wireless/Library/Preferences/com.apple.commcenter.device_specific_nobackup.plist"

        echo "[*] WE RESTORED ACTIVATIONFILES FROM activationsBackup/$ECID/"

        echo "[*] REBOOTING THE DEVICE..."
        remote_cmd "/usr/sbin/nvram auto-boot=true"
        remote_cmd "/sbin/reboot"
        exit 0;
    fi

    has_active=$(remote_cmd "ls /mnt6/active" 2> /dev/null)
    if [ ! "$has_active" = "/mnt6/active" ]; then
        echo "[!] ACTIVE FILE DOES NOT EXIST! PLEASE USE SSH TO CREATE IT"
        echo "    /mnt6/active SHOULD CONTAIN THE NAME OF UUID IN /mnt6"
        echo "    WHEN DONE, TYPE REBOOT IN THE SSH SESSION, RERUN THE SCRIPT."
        echo "    ssh root@localhost -p 2222"
        exit
    fi
    active=$(remote_cmd "cat /mnt6/active" 2> /dev/null)

    if [ "$dualboot" = "1" ]; then
        remote_cmd "/sbin/mount_apfs /dev/disk0s1s${disk} /mnt8/"
        remote_cmd "/sbin/mount_apfs /dev/disk0s1s${dataB} /mnt9/"
        
        if [ "$back" = "1" ]; then
            remote_cmd "mv /mnt8/usr/libexec/mobileactivationdBackup /mnt8/usr/libexec/mobileactivationd "
            echo "DONE. BRINGING BACK iCloud " # that will bring back the normal icloud
            remote_cmd "/sbin/reboot"
            exit; 
        fi
        if [ $(remote_cmd "cp -av /mnt2/root/Library/Lockdown/* /mnt9/root/Library/Lockdown/.") ]; then
            echo "[*] GOT IT, COPIED THE LOCKDOWN FROM THE MAIN IOS ..."
        fi
        remote_cmd "mv /mnt8/usr/libexec/mobileactivationd /mnt8/usr/libexec/mobileactivationdBackup " # that will remplace mobileactivationd hacked
        remote_cp other/mobileactivationd root@localhost:/mnt8/usr/libexec/
        remote_cmd "ldid -e /mnt8/usr/libexec/mobileactivationdBackup > /mnt8/mob.plist"
        remote_cmd "ldid -S/mnt8/mob.plist /mnt8/usr/libexec/mobileactivationd"
        remote_cmd "rm -rv /mnt8/mob.plist"
        remote_cmd "/usr/sbin/nvram auto-boot=true"
        echo "THANK YOU FOR SHARE mobileactivationd @matty"
        echo "[*] DONE ... NOW REBOOT AND BOOT USING down1z REBOOT AND BOOT USING down1z."
        remote_cmd "/sbin/reboot"
        exit;
    fi

    
    if [ "$tethered" = "1" ]; then # use this if you just have tethered jailbreak
    
        if [ "$back" = "1" ]; then
            remote_cmd "mv /mnt1/usr/libexec/mobileactivationdBackup /mnt1/usr/libexec/mobileactivationd "
            echo "DONE. BRING BACK iCloud " # that will bring back the normal icloud
            remote_cmd "/sbin/reboot"
            exit; 
        fi
        remote_cmd "mv -i /mnt1/usr/libexec/mobileactivationd /mnt1/usr/libexec/mobileactivationdBackup " # that will remplace mobileactivationd hacked
        remote_cp other/mobileactivationd root@localhost:/mnt1/usr/libexec/
        remote_cmd "ldid -e /mnt1/usr/libexec/mobileactivationdBackup > /mnt1/mob.plist"
        remote_cmd "ldid -S/mnt1/mob.plist /mnt1/usr/libexec/mobileactivationd"
        remote_cmd "rm -rv /mnt1/mob.plist"
        remote_cmd "/usr/sbin/nvram auto-boot=false"

        echo "[*] THANK YOU FOR SHARE THE mobileactivationd @Hacktivation"
        echo "[*] PLEASE NOW TRY TO BOOT JAILBROKEN IN ORDER TO THAT THE BYPASS WORK"
        echo "[*] DONE ... NOW REBOOT AND BOOT JAILBROKEN USING palera1n, checkra1n or nizira1n"
        remote_cmd "/sbin/reboot"
    fi



fi

} 2>&1 | tee logs/${log}
