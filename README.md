# bypassn1z
JUMP SETUP ON DUALBOOTED/DOWNGRADED DEVICES FOR iOS 15/14/13

# Usage

EXAMPLES: ./bypassn1z.sh --tethered 14.3 FOR down1z OR NORMAL iOS

		./bypassn1z.sh --dualboot 14.3 FOR down1z

OPTIONS: 
   --dualboot          IF YOU WANT TO BYPASS iCloud IN THE DUIALBOOT USE THIS: ./bypassn1z.sh --dualboot 14.3
   
    --jail_palera1n   USE THIS ONLY WHEN YOU ARE ALREADY JAILBROKEN WITH SEMITETHERED palera1n/nizira1n TO AVOID DISK ERRORS. ./bypassn1z.sh --dualboot 14.3  --jail_palera1n 
    
    --tethered            TO BYPASS THE MAIN iOS, USE THIS IF YOU HAVE checkra1n, palera1n or nizira1n TETHERED JAILBREAK (THE DEVICE WILL BOOTLOOP IF YOU TRY TO BOOT WITHOUT JAILBREAK) ./bypassn1z.sh --tethered 14.3

    --backup-activations    THIS COMMAND WILL SAVE YOUR ACTIVATIONFILES INTO activationsBackup/, SO LATER YOU CAN RESTORE THEM
    --restore-activations   THIS COMMAND WILL RESTORE YOUR ACTIVATIONFILES RIGHT BACK TO YOUR iDevice.

    --back              IF YOU WANT TO BRING iCloud BACK YOU CAN USE FOR EXAMPLE ./bypassn1z.sh --tethered 14.3 --back (IF TETHERED YOU CAN CHANGE TO ANY KIND OF JAILBREAK LIKE --semitethered OR --dualboot)

    --dfuhelper         A HELPER TO GET A11 DEVICES INTO DFU FROM RECOVERY
    --debug             DEBUGS THIS SCRIPT


_ _ _


# or you can use the gui version, python3 gui.py

- depend of PyQt5, pip3 install PyQt5


# Credits

- [palera1n](https://github.com/palera1n) for some of the code

- [verygenericname](https://github.com/verygenericname) for the SSH Ramdisk

- [Divise](https://github.com/MatthewPierson/Divise) for the mobileactivationd

- Assassin, THANK YOU FOR THE GUI.
