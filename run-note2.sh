#!/bin/bash
#
#    Copyright (C) 2014  Arif Hendrawan
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <http://www.gnu.org/licenses/>


APKTOOL=$(pwd)/apktool.jar
AAPT_DIR=$(pwd)
PATH=$PATH:$AAPT_DIR

mkdir -p work/tmp-boot/ramdisk
cd work
echo "Extract $1 ..."
unzip -q ../$1
echo "Unpack boot.img ..."
../unpackbootimg -i boot.img  -o tmp-boot

echo "Patch init.smdk4x12.rc ..."
cd tmp-boot/ramdisk
gzip -dc ../boot.img-ramdisk.gz | cpio -i
# change init.smdk4x12.rc
sed -i "/mkdir \/mnt\/shell\/emulated/d" init.smdk4x12.rc
sed -i "/mkdir \/storage\/emulated/d" init.smdk4x12.rc
sed -i "s/mkdir \/storage\/sdcard1/mkdir \/storage\/sdcard0/" init.smdk4x12.rc
sed -i "s/mkdir \/mnt\/media_rw\/sdcard1/mkdir \/mnt\/media_rw\/sdcard0/" init.smdk4x12.rc
sed -i "s/export EXTERNAL_STORAGE \/storage\/emulated\/legacy/export EXTERNAL_STORAGE \/storage\/sdcard0/" init.smdk4x12.rc 
sed -i "s/export SECONDARY_STORAGE \/storage\/sdcard1:/export SECONDARY_STORAGE /" init.smdk4x12.rc
sed -i "/EMULATED_STORAGE_SOURCE/d" init.smdk4x12.rc
sed -i "/EMULATED_STORAGE_TARGET/d" init.smdk4x12.rc
sed -i "s/symlink \/storage\/emulated\/legacy \/sdcard/symlink \/storage\/sdcard0 \/sdcard/" init.smdk4x12.rc
sed -i "s/symlink \/storage\/emulated\/legacy \/mnt\/sdcard/symlink \/storage\/sdcard0 \/mnt\/sdcard/" init.smdk4x12.rc
sed -i "/symlink \/storage\/emulated\/legacy \/storage\/sdcard0/d" init.smdk4x12.rc
sed -i "/symlink \/mnt\/shell\/emulated\/0 \/storage\/emulated\/legacy/d" init.smdk4x12.rc
sed -i "/symlink \/storage\/sdcard1 \/extSdCard/d" init.smdk4x12.rc
sed -i "/symlink \/storage\/sdcard1 \/mnt\/extSdCard/d" init.smdk4x12.rc

sed -i "/service sdcard \/system\/bin\/sdcard -u 1023 -g 1023 -l \/data\/media/,+1d" init.smdk4x12.rc
sed -i "s/service fuse_sdcard1 \/system\/bin\/sdcard -u 1023 -g 1023 \/mnt\/media_rw\/sdcard1 \/storage\/sdcard1/service fuse_sdcard0 \/system\/bin\/sdcard -u 1023 -g 1023 \/mnt\/media_rw\/sdcard0 \/storage\/sdcard0/" init.smdk4x12.rc
sed -i "s/service fuse_sdcard1 \/system\/bin\/sdcard -u 1023 -g 1023 -w 1023 \/mnt\/media_rw\/sdcard1 \/storage\/sdcard1/service fuse_sdcard0 \/system\/bin\/sdcard -u 1023 -g 1023 \/mnt\/media_rw\/sdcard0 \/storage\/sdcard0/" init.smdk4x12.rc

# change fstab.smdk4x12
echo "Patch fstab.smdk4x12 ..."
sed -i "s/voldmanaged=sdcard1:auto/voldmanaged=sdcard0:auto/" fstab.smdk4x12
sed -i "s/voldmanaged=sdcard0:auto$/voldmanaged=sdcard0:auto,noemulatedsd/" fstab.smdk4x12

find . | cpio -o -H newc | gzip > ../newramdisk.cpio.gz
cd ../../

echo "Create new-boot.img ..."
../mkbootimg --kernel tmp-boot/boot.img-zImage --ramdisk tmp-boot/newramdisk.cpio.gz --cmdline "$cat(cat tmp-boot/boot.img-cmdline)" --base $(cat tmp-boot/boot.img-base) --output new-boot.img
echo "Replace boot.img ..."
mv new-boot.img boot.img

echo "Decompile framework-res.apk ..."
# change storage-list.xml
java -jar $APKTOOL d -f -o tmp-framework-res system/framework/framework-res.apk 

echo "Patch storage-list.xml ..."
sed -i "/android:mountPoint=\"\/storage\/sdcard0\"/d" tmp-framework-res/res/xml/storage_list.xml
sed -i "s/storage_sd_card\" android:primary=\"false\" android:removable=\"true\"/storage_sd_card\" android:primary=\"true\" android:removable=\"true\"/" tmp-framework-res/res/xml/storage_list.xml
sed -i "s/android:mountPoint=\"\/storage\/sdcard1\"/android:mountPoint=\"\/storage\/sdcard0\"/" tmp-framework-res/res/xml/storage_list.xml

echo "Build new-framework-res.jar ..."
java -jar $APKTOOL b -o new-framework-res.jar tmp-framework-res

echo "Get compiled storage_list.xml ..."
mkdir tmp-framework-jar
unzip -q new-framework-res.jar -d tmp-framework-jar

echo "Replace storage-list.xml in original framwork-res.apk ..."
cd tmp-framework-jar
zip -f ../system/framework/framework-res.apk res/xml/storage_list.xml
cd ..

echo "Clean up temp files ..."
cp tmp-boot/ramdisk/init.smdk4x12.rc ../
cp tmp-boot/ramdisk/fstab.smdk4x12 ../
cp tmp-framework-res/res/xml/storage_list.xml ../
rm -rf tmp-boot tmp-framework-res tmp-framework-jar
rm new-framework-res.jar

echo "Create new zip ..."
zip -fr -O ../$1-patched.zip ../$1 .

cd ..
rm -rf work

echo "Done."
