#!/bin/bash
#
# PiLFS Build Script SVN-20150811 v1.0
# Builds chapters 5.4 - Binutils to 5.34 - Xz
# http://www.intestinate.com/pilfs
#
# Optional parameteres below:

PARALLEL_JOBS=1             # Number of parallel make jobs, 1 for RPi1 and 4 for RPi2 recommended.
STRIP_AND_DELETE_DOCS=1     # Strip binaries and delete manpages to save space at the end of chapter 5?

# End of optional parameters

set -o nounset
set -o errexit

function prebuild_sanity_check {
    if [[ $(whoami) != "lfs" ]] ; then
        echo "Not running as user lfs, you should be!"
        exit 1
    fi

    if ! [[ -v LFS ]] ; then
        echo "You forgot to set your LFS environment variable!"
        exit 1
    fi

    if ! [[ -v LFS_TGT ]] || [[ $LFS_TGT != "armv6l-lfs-linux-gnueabihf" && $LFS_TGT != "armv7l-lfs-linux-gnueabihf" ]] ; then
        echo "Your LFS_TGT variable should be set to armv6l-lfs-linux-gnueabihf for Raspberry Pi or armv7l-lfs-linux-gnueabihf for Raspberry Pi 2"
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

function check_tarballs {
LIST_OF_TARBALLS="
binutils-2.25.1.tar.bz2
gcc-5.2.0.tar.bz2
gcc-5.2.0-pi-cpu-default.patch
gcc-5.2.0-rpi2-cpu-default.patch
mpfr-3.1.3.tar.xz
gmp-6.0.0a.tar.xz
mpc-1.0.3.tar.gz
rpi-4.1.y.tar.gz
glibc-2.22.tar.xz
tcl-core8.6.4-src.tar.gz
expect5.45.tar.gz
dejagnu-1.5.3.tar.gz
check-0.10.0.tar.gz
ncurses-6.0.tar.gz
bash-4.3.30.tar.gz
bzip2-1.0.6.tar.gz
coreutils-8.24.tar.xz
diffutils-3.3.tar.xz
file-5.24.tar.gz
findutils-4.4.2.tar.gz
gawk-4.1.3.tar.xz
gettext-0.19.5.1.tar.xz
grep-2.21.tar.xz
gzip-1.6.tar.xz
m4-1.4.17.tar.xz
make-4.1.tar.bz2
patch-2.7.5.tar.xz
perl-5.22.0.tar.bz2
sed-4.2.2.tar.bz2
tar-1.28.tar.xz
texinfo-6.0.tar.xz
util-linux-2.26.2.tar.xz
xz-5.2.1.tar.xz
"

for tarball in $LIST_OF_TARBALLS ; do
    if ! [[ -f $LFS/sources/$tarball ]] ; then
        echo "Can't find $LFS/sources/$tarball!"
        exit 1
    fi
done
}

function do_strip {
    set +o errexit
    if [[ $STRIP_AND_DELETE_DOCS = 1 ]] ; then
        strip --strip-debug /tools/lib/*
        /usr/bin/strip --strip-unneeded /tools/{,s}bin/*
        rm -rf /tools/{,share}/{info,man,doc}
    fi
}

function timer {
    if [[ $# -eq 0 ]]; then
        echo $(date '+%s')
    else
        local stime=$1
        etime=$(date '+%s')
        if [[ -z "$stime" ]]; then stime=$etime; fi
        dt=$((etime - stime))
        ds=$((dt % 60))
        dm=$(((dt / 60) % 60))
        dh=$((dt / 3600))
        printf '%02d:%02d:%02d' $dh $dm $ds
    fi
}

prebuild_sanity_check
check_tarballs

echo -e "\nThis is your last chance to quit before we start building... continue?"
echo "(Note that if anything goes wrong during the build, the script will abort mission)"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit;;
    esac
done

total_time=$(timer)
sbu_time=$(timer)

echo "# 5.4. Binutils-2.25.1 - Pass 1"
cd $LFS/sources
tar -jxf binutils-2.25.1.tar.bz2
cd binutils-2.25.1
mkdir -v ../binutils-build
cd ../binutils-build
../binutils-2.25.1/configure   \
    --prefix=/tools            \
    --with-sysroot=$LFS        \
    --with-lib-path=/tools/lib \
    --target=$LFS_TGT          \
    --disable-nls              \
    --disable-werror
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf binutils-build binutils-2.25.1

echo -e "\n=========================="
printf 'Your SBU time is: %s\n' $(timer $sbu_time)
echo -e "==========================\n"

echo "# 5.5. gcc-5.2.0 - Pass 1"
tar -jxf gcc-5.2.0.tar.bz2
cd gcc-5.2.0
case $(uname -m) in
  armv6l) patch -Np1 -i ../gcc-5.2.0-pi-cpu-default.patch ;;
  armv7l) patch -Np1 -i ../gcc-5.2.0-rpi2-cpu-default.patch ;;
esac
tar -Jxf ../mpfr-3.1.3.tar.xz
mv -v mpfr-3.1.3 mpfr
tar -Jxf ../gmp-6.0.0a.tar.xz
mv -v gmp-6.0.0 gmp
tar -zxf ../mpc-1.0.3.tar.gz
mv -v mpc-1.0.3 mpc
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
mkdir -v ../gcc-build
cd ../gcc-build
../gcc-5.2.0/configure                             \
    --target=$LFS_TGT                              \
    --prefix=/tools                                \
    --with-glibc-version=2.11                      \
    --with-sysroot=$LFS                            \
    --with-newlib                                  \
    --without-headers                              \
    --with-local-prefix=/tools                     \
    --with-native-system-header-dir=/tools/include \
    --disable-nls                                  \
    --disable-shared                               \
    --disable-multilib                             \
    --disable-decimal-float                        \
    --disable-threads                              \
    --disable-libatomic                            \
    --disable-libgomp                              \
    --disable-libquadmath                          \
    --disable-libssp                               \
    --disable-libvtv                               \
    --disable-libstdcxx                            \
    --enable-languages=c,c++
# Workaround for a problem introduced with GMP 5.1.0.
# If configured by gcc with the "none" host & target, it will result in undefined references to '__gmpn_invert_limb' during linking.
case $(uname -m) in
  armv6l) sed -i 's/none-/armv6l-/' Makefile ;;
  armv7l) sed -i 's/none-/armv7l-/' Makefile ;;
esac
make
make install
cd $LFS/sources
rm -rf gcc-build gcc-5.2.0

echo "# 5.6. Raspberry Pi Linux API Headers"
tar -zxf rpi-4.1.y.tar.gz
cd linux-rpi-4.1.y
make mrproper
make INSTALL_HDR_PATH=dest headers_install
cp -rv dest/include/* /tools/include
cd $LFS/sources

echo "# 5.7. Glibc-2.22"
tar -Jxf glibc-2.22.tar.xz
cd glibc-2.22
mkdir -v ../glibc-build
cd ../glibc-build
../glibc-2.22/configure                             \
      --prefix=/tools                               \
      --host=$LFS_TGT                               \
      --build=$(../glibc-2.22/scripts/config.guess) \
      --disable-profile                             \
      --enable-kernel=2.6.32                        \
      --enable-obsolete-rpc                         \
      --with-headers=/tools/include                 \
      libc_cv_forced_unwind=yes                     \
      libc_cv_ctors_header=yes                      \
      libc_cv_c_cleanup=yes
make -j $PARALLEL_JOBS
make install
# Compatibility symlink for non ld-linux-armhf awareness
ln -sv ld-2.22.so $LFS/tools/lib/ld-linux.so.3
cd $LFS/sources
rm -rf glibc-build glibc-2.22

echo "# 5.8. Libstdc++-5.2.0"
tar -jxf gcc-5.2.0.tar.bz2
cd gcc-5.2.0
mkdir -pv ../gcc-build
cd ../gcc-build
../gcc-5.2.0/libstdc++-v3/configure \
    --host=$LFS_TGT                 \
    --prefix=/tools                 \
    --disable-multilib              \
    --disable-nls                   \
    --disable-libstdcxx-threads     \
    --disable-libstdcxx-pch         \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/5.2.0
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf gcc-build gcc-5.2.0

echo "# 5.9. Binutils-2.25.1 - Pass 2"
tar -jxf binutils-2.25.1.tar.bz2
cd binutils-2.25.1
mkdir -v ../binutils-build
cd ../binutils-build
CC=$LFS_TGT-gcc                \
AR=$LFS_TGT-ar                 \
RANLIB=$LFS_TGT-ranlib         \
../binutils-2.25.1/configure   \
    --prefix=/tools            \
    --disable-nls              \
    --disable-werror           \
    --with-lib-path=/tools/lib \
    --with-sysroot
make -j $PARALLEL_JOBS
make install
make -C ld clean
make -C ld LIB_PATH=/usr/lib:/lib
cp -v ld/ld-new /tools/bin
cd $LFS/sources
rm -rf binutils-build binutils-2.25.1

echo "# 5.10. gcc-5.2.0 - Pass 2"
tar -jxf gcc-5.2.0.tar.bz2
cd gcc-5.2.0
case $(uname -m) in
  armv6l) patch -Np1 -i ../gcc-5.2.0-pi-cpu-default.patch ;;
  armv7l) patch -Np1 -i ../gcc-5.2.0-rpi2-cpu-default.patch ;;
esac
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
tar -Jxf ../mpfr-3.1.3.tar.xz
mv -v mpfr-3.1.3 mpfr
tar -Jxf ../gmp-6.0.0a.tar.xz
mv -v gmp-6.0.0 gmp
tar -zxf ../mpc-1.0.3.tar.gz
mv -v mpc-1.0.3 mpc
mkdir -v ../gcc-build
cd ../gcc-build
CC=$LFS_TGT-gcc                                    \
CXX=$LFS_TGT-g++                                   \
AR=$LFS_TGT-ar                                     \
RANLIB=$LFS_TGT-ranlib                             \
../gcc-5.2.0/configure                             \
    --prefix=/tools                                \
    --with-local-prefix=/tools                     \
    --with-native-system-header-dir=/tools/include \
    --enable-languages=c,c++                       \
    --disable-libstdcxx-pch                        \
    --disable-multilib                             \
    --disable-bootstrap                            \
    --disable-libgomp
# Workaround for a problem introduced with GMP 5.1.0.
# If configured by gcc with the "none" host & target, it will result in undefined references to '__gmpn_invert_limb' during linking.
case $(uname -m) in
  armv6l) sed -i 's/none-/armv6l-/' Makefile ;;
  armv7l) sed -i 's/none-/armv7l-/' Makefile ;;
esac
make
make install
ln -sv gcc /tools/bin/cc
cd $LFS/sources
rm -rf gcc-build gcc-5.2.0

echo "# 5.11. Tcl-core-8.6.4"
tar -zxf tcl-core8.6.4-src.tar.gz
cd tcl8.6.4
cd unix
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
chmod -v u+w /tools/lib/libtcl8.6.so
make install-private-headers
ln -sv tclsh8.6 /tools/bin/tclsh
cd $LFS/sources
rm -rf tcl8.6.4

echo "# 5.12. Expect-5.45"
tar -zxf expect5.45.tar.gz
cd expect5.45
cp -v configure{,.orig}
sed 's:/usr/local/bin:/bin:' configure.orig > configure
./configure --prefix=/tools       \
            --with-tcl=/tools/lib \
            --with-tclinclude=/tools/include
make -j $PARALLEL_JOBS
make SCRIPTS="" install
cd $LFS/sources
rm -rf expect5.45

echo "# 5.13. DejaGNU-1.5.3"
tar -zxf dejagnu-1.5.3.tar.gz
cd dejagnu-1.5.3
./configure --prefix=/tools
make install
cd $LFS/sources
rm -rf dejagnu-1.5.3

echo "# 5.14. Check-0.10.0"
tar -zxf check-0.10.0.tar.gz
cd check-0.10.0
PKG_CONFIG= ./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf check-0.10.0

echo "# 5.15. Ncurses-6.0"
tar -zxf ncurses-6.0.tar.gz
cd ncurses-6.0
./configure --prefix=/tools \
            --with-shared   \
            --without-debug \
            --without-ada   \
            --enable-widec  \
            --enable-overwrite
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf ncurses-6.0

echo "# 5.16. Bash-4.3.30"
tar -zxf bash-4.3.30.tar.gz
cd bash-4.3.30
./configure --prefix=/tools --without-bash-malloc
make -j $PARALLEL_JOBS
make install
ln -sv bash /tools/bin/sh
cd $LFS/sources
rm -rf bash-4.3.30

echo "# 5.17. Bzip2-1.0.6"
tar -zxf bzip2-1.0.6.tar.gz
cd bzip2-1.0.6
make -j $PARALLEL_JOBS
make PREFIX=/tools install
cd $LFS/sources
rm -rf bzip2-1.0.6

echo "# 5.18. Coreutils-8.24"
tar -Jxf coreutils-8.24.tar.xz
cd coreutils-8.24
./configure --prefix=/tools --enable-install-program=hostname
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf coreutils-8.24

echo "# 5.19. Diffutils-3.3"
tar -Jxf diffutils-3.3.tar.xz
cd diffutils-3.3
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf diffutils-3.3

echo "# 5.20. File-5.24"
tar -zxf file-5.24.tar.gz
cd file-5.24
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf file-5.24

echo "# 5.21. Findutils-4.4.2"
tar -zxf findutils-4.4.2.tar.gz
cd findutils-4.4.2
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf findutils-4.4.2

echo "# 5.22. Gawk-4.1.3"
tar -Jxf gawk-4.1.3.tar.xz
cd gawk-4.1.3
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf gawk-4.1.3

echo "# 5.23. Gettext-0.19.5.1"
tar -Jxf gettext-0.19.5.1.tar.xz
cd gettext-0.19.5.1
cd gettext-tools
EMACS="no" ./configure --prefix=/tools --disable-shared
make -C gnulib-lib
make -C intl pluralx.c
make -C src msgfmt
make -C src msgmerge
make -C src xgettext
cp -v src/{msgfmt,msgmerge,xgettext} /tools/bin
cd $LFS/sources
rm -rf gettext-0.19.5.1

echo "# 5.24. Grep-2.21"
tar -Jxf grep-2.21.tar.xz
cd grep-2.21
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf grep-2.21

echo "# 5.25. Gzip-1.6"
tar -Jxf gzip-1.6.tar.xz
cd gzip-1.6
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf gzip-1.6

echo "# 5.26. M4-1.4.17"
tar -Jxf m4-1.4.17.tar.xz
cd m4-1.4.17
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf m4-1.4.17

echo "# 5.27. Make-4.1"
tar -jxf make-4.1.tar.bz2
cd make-4.1
./configure --prefix=/tools --without-guile
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf make-4.1

echo "# 5.28. Patch-2.7.5"
tar -Jxf patch-2.7.5.tar.xz
cd patch-2.7.5
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf patch-2.7.5

echo "# 5.29. Perl-5.22.0"
tar -jxf perl-5.22.0.tar.bz2
cd perl-5.22.0
sh Configure -des -Dprefix=/tools -Dlibs=-lm
make -j $PARALLEL_JOBS
cp -v perl cpan/podlators/pod2man /tools/bin
mkdir -pv /tools/lib/perl5/5.22.0
cp -Rv lib/* /tools/lib/perl5/5.22.0
cd $LFS/sources
rm -rf perl-5.22.0

echo "# 5.30. Sed-4.2.2"
tar -jxf sed-4.2.2.tar.bz2
cd sed-4.2.2
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf sed-4.2.2

echo "# 5.31. Tar-1.28"
tar -Jxf tar-1.28.tar.xz
cd tar-1.28
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf tar-1.28

echo "# 5.32. Texinfo-6.0"
tar -Jxf texinfo-6.0.tar.xz
cd texinfo-6.0
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf texinfo-6.0

echo "# 5.33. Util-linux-2.26.2"
tar -Jxf util-linux-2.26.2.tar.xz
cd util-linux-2.26.2
./configure --prefix=/tools                \
            --without-python               \
            --disable-makeinstall-chown    \
            --without-systemdsystemunitdir \
            PKG_CONFIG=""
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf util-linux-2.26.2

echo "# 5.34. Xz-5.2.1"
tar -Jxf xz-5.2.1.tar.xz
cd xz-5.2.1
./configure --prefix=/tools
make -j $PARALLEL_JOBS
make install
cd $LFS/sources
rm -rf xz-5.2.1

do_strip

echo -e "----------------------------------------------------"
echo -e "\nYou made it! This is the end of chapter 5!"
printf 'Total script time: %s\n' $(timer $total_time)
echo -e "Now continue reading from \"5.36. Changing Ownership\""
