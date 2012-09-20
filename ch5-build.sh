#!/bin/bash
#
# PiLFS Build Script SVN-20120916 v1.0
# Builds chapters 5.4 - Binutils to 5.32 - Xz
# http://www.intestinate.com/pilfs
#
# Optional parameteres below:

STRIP_AND_DELETE_DOCS=1     # Strip binaries and delete manpages to save space at the end of chapter 5?

# End of optional parameters

set -o nounset
set -o errexit

function prebuild_sanity_check() {
    if [[ $(whoami) != "lfs" ]] ; then
        echo "Not running as user lfs, you should be!"
        exit 1
    fi

    if ! [[ -v LFS ]] ; then
        echo "You forgot to set your LFS environment variable!"
        exit 1
    fi

    if ! [[ -v LFS_TGT ]] || [[ $LFS_TGT != "armv6l-lfs-linux-gnueabihf" ]] ; then
        echo "Your LFS_TGT variable should be set to armv6l-lfs-linux-gnueabihf"
        exit 1
    fi

    if ! [[ -d $LFS ]] ; then
        echo "Your LFS directory doesn't exist!"
        exit 1
    fi

    if ! [[ -d $LFS/sources ]] ; then
        echo "Can't find your sources directory!"
        exit 1
    fi

    if [[ $(stat -c %U $LFS/sources) != "lfs" ]] ; then
        echo "The sources directory should be owned by user lfs!"
        exit 1
    fi

    if ! [[ -d $LFS/tools ]] ; then
        echo "Can't find your tools directory!"
        exit 1
    fi

    if [[ $(stat -c %U $LFS/tools) != "lfs" ]] ; then
        echo "The tools directory should be owned by user lfs!"
        exit 1
    fi
}

function check_tarballs() {
LIST_OF_TARBALLS="
binutils-2.22.tar.bz2
binutils-2.22-build_fix-1.patch
gcc-4.7.1.tar.bz2
gcc-4.7.1-gnueabihf-triplet-support.patch
mpfr-3.1.1.tar.xz 
gmp-5.0.5.tar.xz
mpc-1.0.1.tar.gz  
glibc-2.16.0.tar.xz
glibc-ports-2.16.0.tar.xz
tcl8.5.12-src.tar.gz
expect5.45.tar.gz
dejagnu-1.5.tar.gz   
check-0.9.8.tar.gz
ncurses-5.9.tar.gz
bash-4.2.tar.gz
bash-4.2-fixes-9.patch
bzip2-1.0.6.tar.gz
coreutils-8.19.tar.xz
diffutils-3.2.tar.gz 
file-5.11.tar.gz 
findutils-4.4.2.tar.gz
gawk-4.0.1.tar.xz  
gettext-0.18.1.1.tar.gz
grep-2.14.tar.xz
gzip-1.5.tar.xz  
m4-1.4.16.tar.bz2
make-3.82.tar.bz2    
patch-2.7.tar.xz
perl-5.16.1.tar.bz2
perl-5.16.1-libc-2.patch
sed-4.2.1.tar.bz2  
tar-1.26.tar.bz2   
texinfo-4.13a.tar.gz
xz-5.0.4.tar.xz
"

for tarball in $LIST_OF_TARBALLS ; do
    if ! [[ -f $LFS/sources/$tarball ]] ; then
        echo "Can't find $LFS/sources/$tarball!"
        exit 1
    fi
done
}

function check_kernel() {
    if ! [[ -f $LFS/sources/raspberrypi-linux-git.tar.gz ]] ; then
        echo "Can't find the Raspberry Pi kernel sources (raspberrypi-linux-git.tar.gz)."
        echo "Would you like to download it now?"
        select yn in "Yes" "No"; do
            case $yn in
                Yes ) wget https://github.com/raspberrypi/linux/tarball/rpi-3.2.27 -O $LFS/sources/raspberrypi-linux-git.tar.gz; break;;
                No ) exit;;
            esac
        done
    fi
}

function check_firmware() {
    if ! [[ -f $LFS/sources/raspberrypi-firmware-git.tar.gz ]] ; then
        echo "Can't find the Raspberry Pi firmware binaries (raspberrypi-firmware-git.tar.gz)."
        echo "These will come in handy at the end of chapter 6."
        echo "Would you like to download it now?"
        select yn in "Yes" "No"; do
            case $yn in
                Yes ) wget https://github.com/raspberrypi/firmware/tarball/master -O $LFS/sources/raspberrypi-firmware-git.tar.gz; break;;
                No ) exit;;
            esac
        done
    fi
}

function do_strip {
    set +o errexit
    if [[ $STRIP_AND_DELETE_DOCS = 1 ]] ; then
        strip --strip-debug /tools/lib/*
        strip --strip-unneeded /tools/{,s}bin/*
        rm -rf /tools/{,share}/{info,man,doc}
    fi
}

prebuild_sanity_check
check_kernel
check_firmware
check_tarballs

echo -e "\nThis is your last chance to quit before we start building... continue?"
echo "(Note that if anything goes wrong during the build, the script will abort mission)"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit;;
    esac
done

# 5.4. Binutils-2.22 - Pass 1
cd $LFS/sources
tar xvf binutils-2.22.tar.bz2
cd binutils-2.22
patch -Np1 -i ../binutils-2.22-build_fix-1.patch
mkdir -v ../binutils-build
cd ../binutils-build
../binutils-2.22/configure     \
    --prefix=/tools            \
    --with-sysroot=$LFS        \
    --with-lib-path=/tools/lib \
    --target=$LFS_TGT          \
    --disable-nls              \
    --disable-werror
make
make install
cd $LFS/sources
rm -rf binutils-build binutils-2.22

# 5.5. GCC-4.7.1 - Pass 1
tar xvf gcc-4.7.1.tar.bz2
cd gcc-4.7.1

patch -Np1 -i ../gcc-4.7.1-gnueabihf-triplet-support.patch

tar -Jxf ../mpfr-3.1.1.tar.xz
mv -v mpfr-3.1.1 mpfr
tar -Jxf ../gmp-5.0.5.tar.xz
mv -v gmp-5.0.5 gmp
tar -zxf ../mpc-1.0.1.tar.gz
mv -v mpc-1.0.1 mpc

for file in \
 $(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h -o -name linux-eabi.h -o -name linux-elf.h)
do
  cp -uv $file{,.orig}
  sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
      -e 's@/usr@/tools@g' $file.orig > $file
  echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
  touch $file.orig
done

sed -i '/k prot/agcc_cv_libc_provides_ssp=yes' gcc/configure

mkdir -v ../gcc-build
cd ../gcc-build
../gcc-4.7.1/configure         \
    --target=$LFS_TGT          \
    --prefix=/tools            \
    --with-sysroot=$LFS        \
    --with-newlib              \
    --without-headers          \
    --with-local-prefix=/tools \
    --with-native-system-header-dir=/tools/include \
    --disable-nls              \
    --disable-shared           \
    --disable-multilib         \
    --disable-decimal-float    \
    --disable-threads          \
    --disable-libmudflap       \
    --disable-libssp           \
    --disable-libgomp          \
    --disable-libquadmath      \
    --enable-languages=c       \
    --with-mpfr-include=$(pwd)/../gcc-4.7.1/mpfr/src \
    --with-mpfr-lib=$(pwd)/mpfr/src/.libs
make
make install
ln -vs libgcc.a `$LFS_TGT-gcc -print-libgcc-file-name | sed 's/libgcc/&_eh/'`
cd $LFS/sources
rm -rf gcc-build gcc-4.7.1

# 5.6. Raspberry Pi Linux API Headers
tar xvf raspberrypi-linux-git.tar.gz
cd raspberrypi-linux-???????
make mrproper
make headers_check
make INSTALL_HDR_PATH=dest headers_install
cp -rv dest/include/* /tools/include
cd $LFS/sources

# 5.7. Glibc-2.16.0
tar xvf glibc-2.16.0.tar.xz
cd glibc-2.16.0
tar -Jxf ../glibc-ports-2.16.0.tar.xz
mv -v glibc-ports-2.16.0 ports
if [ ! -r /usr/include/rpc/types.h ]; then
  su -c 'mkdir -p /usr/include/rpc'
  su -c 'cp -v sunrpc/rpc/*.h /usr/include/rpc'
fi
sed -i 's/ -lgcc_s//' Makeconfig
mkdir -v ../glibc-build
cd ../glibc-build
../glibc-2.16.0/configure                             \
      --prefix=/tools                                 \
      --host=$LFS_TGT                                 \
      --build=$(../glibc-2.16.0/scripts/config.guess) \
      --disable-profile                               \
      --enable-add-ons                                \
      --enable-kernel=2.6.25                          \
      --with-headers=/tools/include                   \
      libc_cv_forced_unwind=yes                       \
      libc_cv_ctors_header=yes                        \
      libc_cv_c_cleanup=yes
make
make install
# Compatibility symlink for non ld-linux-armhf awareness
ln -sv ld-2.16.so $LFS/tools/lib/ld-linux.so.3
cd $LFS/sources
rm -rf glibc-build glibc-2.16.0

# 5.8. Binutils-2.22 - Pass 2
tar xvf binutils-2.22.tar.bz2
cd binutils-2.22
patch -Np1 -i ../binutils-2.22-build_fix-1.patch
mkdir -v ../binutils-build
cd ../binutils-build
CC=$LFS_TGT-gcc            \
AR=$LFS_TGT-ar             \
RANLIB=$LFS_TGT-ranlib     \
../binutils-2.22/configure \
    --prefix=/tools        \
    --disable-nls          \
    --with-lib-path=/tools/lib
make
make install
make -C ld clean
make -C ld LIB_PATH=/usr/lib:/lib
cp -v ld/ld-new /tools/bin
cd $LFS/sources
rm -rf binutils-build binutils-2.22

# 5.9. GCC-4.7.1 - Pass 2
tar xvf gcc-4.7.1.tar.bz2
cd gcc-4.7.1

patch -Np1 -i ../gcc-4.7.1-gnueabihf-triplet-support.patch

cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  `dirname $($LFS_TGT-gcc -print-libgcc-file-name)`/include-fixed/limits.h

for file in \
 $(find gcc/config -name linux64.h -o -name linux.h -o -name sysv4.h -o -name linux-eabi.h -o -name linux-elf.h)
do
  cp -uv $file{,.orig}
  sed -e 's@/lib\(64\)\?\(32\)\?/ld@/tools&@g' \
  -e 's@/usr@/tools@g' $file.orig > $file
  echo '
#undef STANDARD_STARTFILE_PREFIX_1
#undef STANDARD_STARTFILE_PREFIX_2
#define STANDARD_STARTFILE_PREFIX_1 "/tools/lib/"
#define STANDARD_STARTFILE_PREFIX_2 ""' >> $file
  touch $file.orig
done

tar -Jxf ../mpfr-3.1.1.tar.xz
mv -v mpfr-3.1.1 mpfr
tar -Jxf ../gmp-5.0.5.tar.xz
mv -v gmp-5.0.5 gmp
tar -zxf ../mpc-1.0.1.tar.gz
mv -v mpc-1.0.1 mpc

mkdir -v ../gcc-build
cd ../gcc-build
CC=$LFS_TGT-gcc \
AR=$LFS_TGT-ar                  \
RANLIB=$LFS_TGT-ranlib          \
../gcc-4.7.1/configure          \
    --prefix=/tools             \
    --with-local-prefix=/tools  \
    --with-native-system-header-dir=/tools/include \
    --enable-clocale=gnu        \
    --enable-shared             \
    --enable-threads=posix      \
    --enable-__cxa_atexit       \
    --enable-languages=c,c++    \
    --disable-libstdcxx-pch     \
    --disable-multilib          \
    --disable-bootstrap         \
    --disable-libgomp           \
    --with-mpfr-include=$(pwd)/../gcc-4.7.1/mpfr/src \
    --with-mpfr-lib=$(pwd)/mpfr/src/.libs
make
make install
ln -vs gcc /tools/bin/cc
cd $LFS/sources
rm -rf gcc-build gcc-4.7.1

# 5.10. Tcl-8.5.12
tar xvf tcl8.5.12-src.tar.gz
cd tcl8.5.12
cd unix
./configure --prefix=/tools
make
make install
chmod -v u+w /tools/lib/libtcl8.5.so
make install-private-headers
ln -sv tclsh8.5 /tools/bin/tclsh
cd $LFS/sources
rm -rf tcl8.5.12

# 5.11. Expect-5.45
tar xvf expect5.45.tar.gz
cd expect5.45
cp -v configure{,.orig}
sed 's:/usr/local/bin:/bin:' configure.orig > configure
./configure --prefix=/tools --with-tcl=/tools/lib \
  --with-tclinclude=/tools/include
make
make SCRIPTS="" install
cd $LFS/sources
rm -rf expect5.45

# 5.12. DejaGNU-1.5
tar xvf dejagnu-1.5.tar.gz
cd dejagnu-1.5
./configure --prefix=/tools
make install
cd $LFS/sources
rm -rf dejagnu-1.5

# 5.13. Check-0.9.8
tar xvf check-0.9.8.tar.gz
cd check-0.9.8
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf check-0.9.8

# 5.14. Ncurses-5.9
tar xvf ncurses-5.9.tar.gz
cd ncurses-5.9
./configure --prefix=/tools --with-shared \
    --without-debug --without-ada --enable-overwrite
make
make install
cd $LFS/sources
rm -rf ncurses-5.9

# 5.15. Bash-4.2
tar xvf bash-4.2.tar.gz
cd bash-4.2
patch -Np1 -i ../bash-4.2-fixes-9.patch
./configure --prefix=/tools --without-bash-malloc
make
make install
ln -vs bash /tools/bin/sh
cd $LFS/sources
rm -rf bash-4.2

# 5.16. Bzip2-1.0.6
tar xvf bzip2-1.0.6.tar.gz
cd bzip2-1.0.6
make
make PREFIX=/tools install
cd $LFS/sources
rm -rf bzip2-1.0.6

# 5.17. Coreutils-8.19
tar xvf coreutils-8.19.tar.xz
cd coreutils-8.19
./configure --prefix=/tools --enable-install-program=hostname
make
make install
cd $LFS/sources
rm -rf coreutils-8.19

# 5.18. Diffutils-3.2
tar xvf diffutils-3.2.tar.gz
cd diffutils-3.2
sed -i -e '/gets is a/d' lib/stdio.in.h
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf diffutils-3.2

# 5.19. File-5.11
tar xvf file-5.11.tar.gz
cd file-5.11
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf file-5.11

# 5.20. Findutils-4.4.2
tar xvf findutils-4.4.2.tar.gz
cd findutils-4.4.2
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf findutils-4.4.2

# 5.21. Gawk-4.0.1
tar xvf gawk-4.0.1.tar.xz
cd gawk-4.0.1
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf gawk-4.0.1

# 5.22. Gettext-0.18.1.1
tar xvf gettext-0.18.1.1.tar.gz
cd gettext-0.18.1.1
sed -i -e '/gets is a/d' gettext-*/*/stdio.in.h
cd gettext-tools
EMACS="no" ./configure --prefix=/tools --disable-shared
make -C gnulib-lib
make -C src msgfmt
cp -v src/msgfmt /tools/bin
cd $LFS/sources
rm -rf gettext-0.18.1.1

# 5.23. Grep-2.14
tar xvf grep-2.14.tar.xz
cd grep-2.14
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf grep-2.14

# 5.24. Gzip-1.5
tar xvf gzip-1.5.tar.xz
cd gzip-1.5
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf gzip-1.5

# 5.25. M4-1.4.16
tar xvf m4-1.4.16.tar.bz2
cd m4-1.4.16
sed -i -e '/gets is a/d' lib/stdio.in.h
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf m4-1.4.16

# 5.26. Make-3.82
tar xvf make-3.82.tar.bz2
cd make-3.82
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf make-3.82

# 5.27. Patch-2.7
tar xvf patch-2.7.tar.xz
cd patch-2.7
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf patch-2.7

# 5.28. Perl-5.16.1
tar xvf perl-5.16.1.tar.bz2
cd perl-5.16.1
patch -Np1 -i ../perl-5.16.1-libc-2.patch
sh Configure -des -Dprefix=/tools
make
cp -v perl cpan/podlators/pod2man /tools/bin
mkdir -pv /tools/lib/perl5/5.16.1
cp -Rv lib/* /tools/lib/perl5/5.16.1
cd $LFS/sources
rm -rf perl-5.16.1

# 5.29. Sed-4.2.1
tar xvf sed-4.2.1.tar.bz2
cd sed-4.2.1
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf sed-4.2.1

# 5.30. Tar-1.26
tar xvf tar-1.26.tar.bz2
cd tar-1.26
sed -i -e '/gets is a/d' gnu/stdio.in.h
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf tar-1.26

# 5.31. Texinfo-4.13a
tar xvf texinfo-4.13a.tar.gz
cd texinfo-4.13
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf texinfo-4.13

# 5.32. Xz-5.0.4
tar xvf xz-5.0.4.tar.xz
cd xz-5.0.4
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf xz-5.0.4

do_strip

echo -e "------------------------------------------"
echo -e "\nYou made it! This is the end of chapter 5!"
