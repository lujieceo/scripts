#!/bin/bash
#
# PiLFS Build Script SVN-20130515 v1.0
# Builds chapters 5.4 - Binutils to 5.33 - Xz
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
binutils-2.23.2.tar.bz2
binutils-2.23.2-gas-whitespace-fix.patch
gcc-4.8.0.tar.bz2
gcc-4.8.0-pi-cpu-default.patch
mpfr-3.1.2.tar.xz
gmp-5.1.1.tar.xz
mpc-1.0.1.tar.gz
rpi-3.6.y.tar.gz
glibc-2.17.tar.xz
glibc-2.17-arm-ld-cache-fix.patch
tcl8.6.0-src.tar.gz
expect5.45.tar.gz
dejagnu-1.5.1.tar.gz
check-0.9.10.tar.gz
ncurses-5.9.tar.gz
bash-4.2.tar.gz
bash-4.2-fixes-12.patch
bzip2-1.0.6.tar.gz
coreutils-8.21.tar.xz
diffutils-3.3.tar.xz
file-5.14.tar.gz
findutils-4.4.2.tar.gz
gawk-4.1.0.tar.xz
gettext-0.18.2.1.tar.gz
grep-2.14.tar.xz
gzip-1.5.tar.xz
m4-1.4.16.tar.bz2
make-3.82.tar.bz2
patch-2.7.1.tar.xz
perl-5.16.3.tar.bz2
perl-5.16.3-libc-1.patch
sed-4.2.2.tar.bz2
tar-1.26.tar.bz2
texinfo-5.1.tar.xz
xz-5.0.4.tar.xz
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
        strip --strip-unneeded /tools/{,s}bin/*
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

echo "# 5.4. Binutils-2.23.2 - Pass 1"
cd $LFS/sources
tar -jxf binutils-2.23.2.tar.bz2
cd binutils-2.23.2
patch -Np1 -i ../binutils-2.23.2-gas-whitespace-fix.patch
sed -i -e 's/@colophon/@@colophon/' \
       -e 's/doc@cygnus.com/doc@@cygnus.com/' bfd/doc/bfd.texinfo
mkdir -v ../binutils-build
cd ../binutils-build
../binutils-2.23.2/configure   \
    --prefix=/tools            \
    --with-sysroot=$LFS        \
    --with-lib-path=/tools/lib \
    --target=$LFS_TGT          \
    --disable-nls              \
    --disable-werror
make
make install
cd $LFS/sources
rm -rf binutils-build binutils-2.23.2

echo -e "\n=========================="
printf 'Your SBU time is: %s\n' $(timer $sbu_time)
echo -e "==========================\n"

echo "# 5.5. GCC-4.8.0 - Pass 1"
tar -jxf gcc-4.8.0.tar.bz2
cd gcc-4.8.0
patch -Np1 -i ../gcc-4.8.0-pi-cpu-default.patch
tar -Jxf ../mpfr-3.1.2.tar.xz
mv -v mpfr-3.1.2 mpfr
tar -Jxf ../gmp-5.1.1.tar.xz
mv -v gmp-5.1.1 gmp
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
../gcc-4.8.0/configure                               \
    --target=$LFS_TGT                                \
    --prefix=/tools                                  \
    --with-sysroot=$LFS                              \
    --with-newlib                                    \
    --without-headers                                \
    --with-local-prefix=/tools                       \
    --with-native-system-header-dir=/tools/include   \
    --disable-nls                                    \
    --disable-shared                                 \
    --disable-multilib                               \
    --disable-decimal-float                          \
    --disable-threads                                \
    --disable-libatomic                              \
    --disable-libgomp                                \
    --disable-libitm                                 \
    --disable-libmudflap                             \
    --disable-libquadmath                            \
    --disable-libsanitizer                           \
    --disable-libssp                                 \
    --disable-libstdc++-v3                           \
    --enable-languages=c,c++                         \
    --with-mpfr-include=$(pwd)/../gcc-4.8.0/mpfr/src \
    --with-mpfr-lib=$(pwd)/mpfr/src/.libs
# Workaround for a problem introduced with GMP 5.1.0.
# If configured by gcc with the "none" host & target, it will result in undefined references to '__gmpn_invert_limb' during linking.
sed -i 's/none-/armv6l-/' Makefile
make
make install
ln -sv libgcc.a `$LFS_TGT-gcc -print-libgcc-file-name | sed 's/libgcc/&_eh/'`
cd $LFS/sources
rm -rf gcc-build gcc-4.8.0

echo "# 5.6. Raspberry Pi Linux API Headers"
tar -zxf rpi-3.6.y.tar.gz
cd linux-rpi-3.6.y
make mrproper
make headers_check
make INSTALL_HDR_PATH=dest headers_install
cp -rv dest/include/* /tools/include
cd $LFS/sources

echo "# 5.7. Glibc-2.17"
tar -Jxf glibc-2.17.tar.xz
cd glibc-2.17
patch -Np1 -i ../glibc-2.17-arm-ld-cache-fix.patch
if [ ! -r /usr/include/rpc/types.h ]; then
  su -c 'mkdir -p /usr/include/rpc'
  su -c 'cp -v sunrpc/rpc/*.h /usr/include/rpc'
fi
mkdir -v ../glibc-build
cd ../glibc-build
../glibc-2.17/configure                             \
      --prefix=/tools                               \
      --host=$LFS_TGT                               \
      --build=$(../glibc-2.17/scripts/config.guess) \
      --disable-profile                             \
      --enable-kernel=2.6.25                        \
      --with-headers=/tools/include                 \
      libc_cv_forced_unwind=yes                     \
      libc_cv_ctors_header=yes                      \
      libc_cv_c_cleanup=yes
make
make install
# Compatibility symlink for non ld-linux-armhf awareness
ln -sv ld-2.17.so $LFS/tools/lib/ld-linux.so.3
cd $LFS/sources
rm -rf glibc-build glibc-2.17

echo "# 5.8. Libstdc++-4.8.0"
tar -jxf gcc-4.8.0.tar.bz2
cd gcc-4.8.0
mkdir -pv ../gcc-build
cd ../gcc-build
../gcc-4.8.0/libstdc++-v3/configure      \
    --host=$LFS_TGT                      \
    --prefix=/tools                      \
    --disable-multilib                   \
    --disable-shared                     \
    --disable-nls                        \
    --disable-libstdcxx-threads          \
    --disable-libstdcxx-pch              \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/4.8.0
make
make install
cd $LFS/sources
rm -rf gcc-build gcc-4.8.0

echo "# 5.9. Binutils-2.23.2 - Pass 2"
tar -jxf binutils-2.23.2.tar.bz2
cd binutils-2.23.2
patch -Np1 -i ../binutils-2.23.2-gas-whitespace-fix.patch
sed -i -e 's/@colophon/@@colophon/' \
       -e 's/doc@cygnus.com/doc@@cygnus.com/' bfd/doc/bfd.texinfo
mkdir -v ../binutils-build
cd ../binutils-build
CC=$LFS_TGT-gcc                \
AR=$LFS_TGT-ar                 \
RANLIB=$LFS_TGT-ranlib         \
../binutils-2.23.2/configure   \
    --prefix=/tools            \
    --disable-nls              \
    --with-lib-path=/tools/lib \
    --with-sysroot
make
make install
make -C ld clean
make -C ld LIB_PATH=/usr/lib:/lib
cp -v ld/ld-new /tools/bin
cd $LFS/sources
rm -rf binutils-build binutils-2.23.2

echo "# 5.10. GCC-4.8.0 - Pass 2"
tar -jxf gcc-4.8.0.tar.bz2
cd gcc-4.8.0
patch -Np1 -i ../gcc-4.8.0-pi-cpu-default.patch
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
tar -Jxf ../mpfr-3.1.2.tar.xz
mv -v mpfr-3.1.2 mpfr
tar -Jxf ../gmp-5.1.1.tar.xz
mv -v gmp-5.1.1 gmp
tar -zxf ../mpc-1.0.1.tar.gz
mv -v mpc-1.0.1 mpc
mkdir -v ../gcc-build
cd ../gcc-build
CC=$LFS_TGT-gcc                                      \
CXX=$LFS_TGT-g++                                     \
AR=$LFS_TGT-ar                                       \
RANLIB=$LFS_TGT-ranlib                               \
../gcc-4.8.0/configure                               \
    --prefix=/tools                                  \
    --with-local-prefix=/tools                       \
    --with-native-system-header-dir=/tools/include   \
    --enable-clocale=gnu                             \
    --enable-shared                                  \
    --enable-threads=posix                           \
    --enable-__cxa_atexit                            \
    --enable-languages=c,c++                         \
    --disable-libstdcxx-pch                          \
    --disable-multilib                               \
    --disable-bootstrap                              \
    --disable-libgomp                                \
    --with-mpfr-include=$(pwd)/../gcc-4.8.0/mpfr/src \
    --with-mpfr-lib=$(pwd)/mpfr/src/.libs
# Workaround for a problem introduced with GMP 5.1.0.
# If configured by gcc with the "none" host & target, it will result in undefined references to '__gmpn_invert_limb' during linking.
sed -i 's/none-/armv6l-/' Makefile
make
make install
ln -sv gcc /tools/bin/cc
cd $LFS/sources
rm -rf gcc-build gcc-4.8.0

echo "# 5.11. Tcl-8.6.0"
tar -zxf tcl8.6.0-src.tar.gz
cd tcl8.6.0
sed -i s/500/5000/ generic/regc_nfa.c
cd unix
./configure --prefix=/tools
make
make install
chmod -v u+w /tools/lib/libtcl8.6.so
make install-private-headers
ln -sv tclsh8.6 /tools/bin/tclsh
cd $LFS/sources
rm -rf tcl8.6.0

echo "# 5.12. Expect-5.45"
tar -zxf expect5.45.tar.gz
cd expect5.45
cp -v configure{,.orig}
sed 's:/usr/local/bin:/bin:' configure.orig > configure
./configure --prefix=/tools --with-tcl=/tools/lib \
  --with-tclinclude=/tools/include
make
make SCRIPTS="" install
cd $LFS/sources
rm -rf expect5.45

echo "# 5.13. DejaGNU-1.5.1"
tar -zxf dejagnu-1.5.1.tar.gz
cd dejagnu-1.5.1
./configure --prefix=/tools
make install
cd $LFS/sources
rm -rf dejagnu-1.5.1

echo "# 5.14. Check-0.9.10"
tar -zxf check-0.9.10.tar.gz
cd check-0.9.10
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf check-0.9.10

echo "# 5.15. Ncurses-5.9"
tar -zxf ncurses-5.9.tar.gz
cd ncurses-5.9
./configure --prefix=/tools --with-shared \
    --without-debug --without-ada --enable-overwrite
make
make install
cd $LFS/sources
rm -rf ncurses-5.9

echo "# 5.16. Bash-4.2"
tar -zxf bash-4.2.tar.gz
cd bash-4.2
patch -Np1 -i ../bash-4.2-fixes-12.patch
./configure --prefix=/tools --without-bash-malloc
make
make install
ln -sv bash /tools/bin/sh
cd $LFS/sources
rm -rf bash-4.2

echo "# 5.17. Bzip2-1.0.6"
tar -zxf bzip2-1.0.6.tar.gz
cd bzip2-1.0.6
make
make PREFIX=/tools install
cd $LFS/sources
rm -rf bzip2-1.0.6

echo "# 5.18. Coreutils-8.21"
tar -Jxf coreutils-8.21.tar.xz
cd coreutils-8.21
./configure --prefix=/tools --enable-install-program=hostname
make
make install
cd $LFS/sources
rm -rf coreutils-8.21

echo "# 5.19. Diffutils-3.3"
tar -Jxf diffutils-3.3.tar.xz
cd diffutils-3.3
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf diffutils-3.3

echo "# 5.20. File-5.14"
tar -zxf file-5.14.tar.gz
cd file-5.14
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf file-5.14

echo "# 5.21. Findutils-4.4.2"
tar -zxf findutils-4.4.2.tar.gz
cd findutils-4.4.2
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf findutils-4.4.2

echo "# 5.22. Gawk-4.1.0"
tar -Jxf gawk-4.1.0.tar.xz
cd gawk-4.1.0
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf gawk-4.1.0

echo "# 5.23. Gettext-0.18.2.1"
tar -zxf gettext-0.18.2.1.tar.gz
cd gettext-0.18.2.1
cd gettext-tools
EMACS="no" ./configure --prefix=/tools --disable-shared
make -C gnulib-lib
make -C src msgfmt
cp -v src/msgfmt /tools/bin
cd $LFS/sources
rm -rf gettext-0.18.2.1

echo "# 5.24. Grep-2.14"
tar -Jxf grep-2.14.tar.xz
cd grep-2.14
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf grep-2.14

echo "# 5.25. Gzip-1.5"
tar -Jxf gzip-1.5.tar.xz
cd gzip-1.5
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf gzip-1.5

echo "# 5.26. M4-1.4.16"
tar -jxf m4-1.4.16.tar.bz2
cd m4-1.4.16
sed -i -e '/gets is a/d' lib/stdio.in.h
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf m4-1.4.16

echo "# 5.27. Make-3.82"
tar -jxf make-3.82.tar.bz2
cd make-3.82
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf make-3.82

echo "# 5.28. Patch-2.7.1"
tar -Jxf patch-2.7.1.tar.xz
cd patch-2.7.1
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf patch-2.7.1

echo "# 5.29. Perl-5.16.3"
tar -jxf perl-5.16.3.tar.bz2
cd perl-5.16.3
patch -Np1 -i ../perl-5.16.3-libc-1.patch
sh Configure -des -Dprefix=/tools
make
cp -v perl cpan/podlators/pod2man /tools/bin
mkdir -pv /tools/lib/perl5/5.16.3
cp -Rv lib/* /tools/lib/perl5/5.16.3
cd $LFS/sources
rm -rf perl-5.16.3

echo "# 5.30. Sed-4.2.2"
tar -jxf sed-4.2.2.tar.bz2
cd sed-4.2.2
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf sed-4.2.2

echo "# 5.31. Tar-1.26"
tar -jxf tar-1.26.tar.bz2
cd tar-1.26
sed -i -e '/gets is a/d' gnu/stdio.in.h
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf tar-1.26

echo "# 5.32. Texinfo-5.1"
tar -Jxf texinfo-5.1.tar.xz
cd texinfo-5.1
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf texinfo-5.1

echo "# 5.33. Xz-5.0.4"
tar -Jxf xz-5.0.4.tar.xz
cd xz-5.0.4
./configure --prefix=/tools
make
make install
cd $LFS/sources
rm -rf xz-5.0.4

do_strip

echo -e "----------------------------------------------------"
echo -e "\nYou made it! This is the end of chapter 5!"
printf 'Total script time: %s\n' $(timer $total_time)
echo -e "Now continue reading from \"5.34. Changing Ownership\""
