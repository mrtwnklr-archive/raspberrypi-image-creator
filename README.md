# raspberrypi-image-creator

## Summary

Creates a raspbian lite sd card image, preconfigured with gpu memory and wifi access.

## Sample

```
export WIFI_SSID=wlan-name
export WIFI_PASSWORD=wlan-password

bash create_image.sh

unset WIFI_SSID
unset WIFI_PASSWORD
```

## Copy image to sd card
```
lsblk
# should list e.g. "/mmcblk0"
sudo dd bs=4M if=${IMAGE_NAME}.img of=/dev/mmcblk0 conv=fsync status=progress
```

## Expand root filesystem
```
ssh pi@${IP_ADRESS}
# default password: raspberry
sudo raspi-config --expand-rootfs
```