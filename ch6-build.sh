#!/bin/bash
#
# PiLFS Build Script SVN-20120722 v1.0
# Builds chapters 6.7 - Raspberry Linux API Headers to 6.62 - Vim
# http://www.intestinate.com/pilfs
#
# Optional parameteres below:

LOCAL_TIMEZONE=Europe/London    # Use this timezone from /usr/share/zoneinfo/ to set /etc/localtime. See "6.9.2. Configuring Glibc".
GROFF_PAPER_SIZE=A4             # Use this default paper size for Groff. See "6.44. Groff-1.21".
INSTALL_OPTIONAL_DOCS=1         # Install optional documentation when given a choice?
INSTALL_ALL_LOCALES=0           # Install all glibc locales? By default only en_US.ISO-8859-1 and en_US.UTF-8 are installed.

# End of optional parameters

set -o nounset
set -o errexit

function prebuild_sanity_check() {
    if [[ $(whoami) != "root" ]] ; then
        echo "You should be running as root for chapter 6!"
        exit 1
    fi
                        
    if ! [[ -d /sources ]] ; then
        echo "Can't find your sources directory! Did you forget to chroot?"
        exit 1
    fi

    if ! [[ -d /tools ]] ; then
        echo "Can't find your tools directory! Did you forget to chroot?"
        exit 1
    fi
}

function check_tarballs() {
LIST_OF_TARBALLS="
man-pages-3.41.tar.xz
glibc-2.15.tar.xz
glibc-2.15-fixes-1.patch
glibc-2.15-gcc_fix-1.patch
glibc-ports-2.15.tar.xz
glibc-ports-2.15-arm_build_fix.patch
zlib-1.2.7.tar.bz2
file-5.11.tar.gz
binutils-2.22.tar.bz2
binutils-2.22-build_fix-1.patch
gmp-5.0.5.tar.xz
mpfr-3.1.1.tar.xz
mpc-0.9.tar.gz
gcc-4.7.1.tar.bz2
gcc-4.7.1-gnueabihf-triplet-support.patch
sed-4.2.1.tar.bz2
bzip2-1.0.6.tar.gz
bzip2-1.0.6-install_docs-1.patch
pkg-config-0.27.tar.gz
ncurses-5.9.tar.gz
util-linux-2.21.2.tar.xz
psmisc-22.19.tar.gz
e2fsprogs-1.42.4.tar.gz
coreutils-8.17.tar.xz
coreutils-8.17-i18n-1.patch
iana-etc-2.30.tar.bz2
m4-1.4.16.tar.bz2
bison-2.5.1.tar.xz
procps-3.2.8.tar.gz
procps-3.2.8-fix_HZ_errors-1.patch
procps-3.2.8-watch_unicode-1.patch
grep-2.13.tar.xz
readline-6.2.tar.gz
readline-6.2-fixes-1.patch
bash-4.2.tar.gz
bash-4.2-fixes-8.patch
libtool-2.4.2.tar.gz
gdbm-1.10.tar.gz
inetutils-1.9.1.tar.gz
perl-5.16.0.tar.bz2
autoconf-2.69.tar.xz
automake-1.12.2.tar.xz
diffutils-3.2.tar.gz
gawk-4.0.1.tar.xz
findutils-4.4.2.tar.gz
flex-2.5.35.tar.bz2
flex-2.5.35-gcc44-1.patch
gettext-0.18.1.1.tar.gz
groff-1.21.tar.gz
xz-5.0.4.tar.xz
less-444.tar.gz
gzip-1.5.tar.xz
iproute2-3.4.0.tar.xz
kbd-1.15.3.tar.gz
kbd-1.15.3-backspace-1.patch
kbd-1.15.3-upstream_fixes-1.patch
kmod-9.tar.xz
kmod-9-testsuite-1.patch
libpipeline-1.2.1.tar.gz
make-3.82.tar.bz2
man-db-2.6.2.tar.xz
patch-2.6.1.tar.bz2
patch-2.6.1-test_fix-1.patch
shadow-4.1.5.1.tar.bz2
sysklogd-1.5.tar.gz
sysvinit-2.88dsf.tar.bz2
tar-1.26.tar.bz2
texinfo-4.13a.tar.gz
systemd-187.tar.xz
udev-lfs-187.tar.bz2
vim-7.3.tar.bz2
"

for tarball in $LIST_OF_TARBALLS ; do
    if ! [[ -f /sources/$tarball ]] ; then
        echo "Can't find /sources/$tarball!"
        exit 1
    fi
done
}

function check_kernel() {
    if ! [ -d /sources/raspberrypi-linux-??????? ] ; then
        if ! [[ -f /sources/raspberrypi-linux-git.tar.gz ]] ; then
            echo "Can't find the Raspberry Pi kernel sources (raspberrypi-linux-git.tar.gz)."
            echo "You need to exit your chroot and grab it with wget:"
            echo 'wget https://github.com/raspberrypi/linux/tarball/rpi-patches -O $LFS/sources/raspberrypi-linux-git.tar.gz'
            exit 1
        fi
        tar xvf raspberrypi-linux-git.tar.gz
    fi
}

function check_firmware() {
    if ! [ -d /sources/raspberrypi-firmware-??????? ] ; then
        if ! [[ -f /sources/raspberrypi-firmware-git.tar.gz ]] ; then
            echo "Can't find the Raspberry Pi firmware binaries (raspberrypi-firmware-git.tar.gz)."
            echo "You need to exit your chroot and grab it with wget:"
            echo 'wget https://github.com/raspberrypi/firmware/tarball/master -O $LFS/sources/raspberrypi-firmware-git.tar.gz'
            exit 1
        fi
        tar xvf raspberrypi-firmware-git.tar.gz
    fi
}

prebuild_sanity_check
check_kernel
check_tarballs

echo -e "\nThis is your last chance to quit before we start building... continue?"
echo "(Note that if anything goes wrong during the build, the script will abort mission)"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) break;;
        No ) exit;;
    esac
done
                        
# 6.7. Raspberry Linux API Headers
cd /sources
cd raspberrypi-linux-???????
make mrproper
make headers_check
make INSTALL_HDR_PATH=dest headers_install
find dest/include \( -name .install -o -name ..install.cmd \) -delete
cp -rv dest/include/* /usr/include
cd /sources

# 6.8. Man-pages-3.41
tar xvf man-pages-3.41.tar.xz
cd man-pages-3.41
make install
cd /sources
rm -rf man-pages-3.41

# 6.9. Glibc-2.15
tar xvf glibc-2.15.tar.xz
cd glibc-2.15
tar -Jxf ../glibc-ports-2.15.tar.xz
mv -v glibc-ports-2.15 ports
patch -Np1 -i ../glibc-ports-2.15-arm_build_fix.patch
DL=$(readelf -l /bin/sh | sed -n 's@.*interpret.*/tools\(.*\)]$@\1@p')
sed -i "s|libs -o|libs -L/usr/lib -Wl,-dynamic-linker=$DL -o|" \
        scripts/test-installation.pl
unset DL
sed -i -e 's/"db1"/& \&\& $name ne "nss_test1"/' scripts/test-installation.pl
sed -i 's|@BASH@|/bin/bash|' elf/ldd.bash.in
patch -Np1 -i ../glibc-2.15-fixes-1.patch
patch -Np1 -i ../glibc-2.15-gcc_fix-1.patch
mkdir -v ../glibc-build
cd ../glibc-build
../glibc-2.15/configure  \
    --prefix=/usr          \
    --disable-profile      \
    --enable-add-ons       \
    --enable-kernel=2.6.25 \
    --libexecdir=/usr/lib/glibc
make
touch /etc/ld.so.conf
make install
cp -v ../glibc-2.15/sunrpc/rpc/*.h /usr/include/rpc
cp -v ../glibc-2.15/sunrpc/rpcsvc/*.h /usr/include/rpcsvc
cp -v ../glibc-2.15/nis/rpcsvc/*.h /usr/include/rpcsvc

if [[ $INSTALL_ALL_LOCALES = 1 ]] ; then
    make localedata/install-locales
else
    mkdir -pv /usr/lib/locale
    localedef -i en_US -f ISO-8859-1 en_US
    localedef -i en_US -f UTF-8 en_US.UTF-8
fi

cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF

if ! [[ -f /usr/share/zoneinfo/$LOCAL_TIMEZONE ]] ; then
    echo "Seems like your timezone won't work out. Defaulting to London. Either fix it yourself later or consider moving there :)"
    cp -v --remove-destination /usr/share/zoneinfo/Europe/London /etc/localtime
else
    cp -v --remove-destination /usr/share/zoneinfo/$LOCAL_TIMEZONE /etc/localtime
fi

cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF

cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF

mkdir /etc/ld.so.conf.d
cd /sources
rm -rf glibc-build glibc-2.15

# 6.10. Adjusting the Toolchain
mv -v /tools/bin/{ld,ld-old}
mv -v /tools/$(gcc -dumpmachine)/bin/{ld,ld-old}
mv -v /tools/bin/{ld-new,ld}
ln -sv /tools/bin/ld /tools/$(gcc -dumpmachine)/bin/ld
gcc -dumpspecs | sed -e 's@/tools@@g' \
    -e '/\*startfile_prefix_spec:/{n;s@.*@/usr/lib/ @}' \
    -e '/\*cpp:/{n;s@$@ -isystem /usr/include@}' > \
    `dirname $(gcc --print-libgcc-file-name)`/specs

# 6.11. Zlib-1.2.7
tar xvf zlib-1.2.7.tar.bz2
cd zlib-1.2.7
./configure --prefix=/usr
make
make install
mv -v /usr/lib/libz.so.* /lib
ln -sfv ../../lib/libz.so.1.2.7 /usr/lib/libz.so
cd /sources
rm -rf zlib-1.2.7

# 6.12. File-5.11
tar xvf file-5.11.tar.gz
cd file-5.11
./configure --prefix=/usr
make
make install
cd /sources
rm -rf file-5.11

# 6.13. Binutils-2.22
tar xvf binutils-2.22.tar.bz2
cd binutils-2.22
rm -fv etc/standards.info
sed -i.bak '/^INFO/s/standards.info //' etc/Makefile.in
patch -Np1 -i ../binutils-2.22-build_fix-1.patch
mkdir -v ../binutils-build
cd ../binutils-build
../binutils-2.22/configure --prefix=/usr --enable-shared
make tooldir=/usr
make tooldir=/usr install
cp -v ../binutils-2.22/include/libiberty.h /usr/include
cd /sources
rm -rf binutils-build binutils-2.22

# 6.14. GMP-5.0.5
tar xvf gmp-5.0.5.tar.xz
cd gmp-5.0.5
./configure --prefix=/usr --enable-cxx --enable-mpbsd
make
make install

if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    mkdir -v /usr/share/doc/gmp-5.0.5
    cp    -v doc/{isa_abi_headache,configuration} doc/*.html \
    /usr/share/doc/gmp-5.0.5
fi

cd /sources
rm -rf gmp-5.0.5

# 6.15. MPFR-3.1.1
tar xvf mpfr-3.1.1.tar.xz
cd mpfr-3.1.1
./configure  --prefix=/usr        \
             --enable-thread-safe \
             --docdir=/usr/share/doc/mpfr-3.1.1
make
make install

if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    make html
    make install-html
fi

cd /sources
rm -rf mpfr-3.1.1

# 6.16. MPC-0.9
tar xvf mpc-0.9.tar.gz
cd mpc-0.9
./configure --prefix=/usr
make
make install
cd /sources
rm -rf mpc-0.9

# 6.17. GCC-4.7.1
tar xvf gcc-4.7.1.tar.bz2
cd gcc-4.7.1
patch -Np1 -i ../gcc-4.7.1-gnueabihf-triplet-support.patch
sed -i 's/install_to_$(INSTALL_DEST) //' libiberty/Makefile.in
mkdir -v ../gcc-build
cd ../gcc-build
../gcc-4.7.1/configure --prefix=/usr            \
                       --libexecdir=/usr/lib    \
                       --enable-shared          \
                       --enable-threads=posix   \
                       --enable-__cxa_atexit    \
                       --enable-clocale=gnu     \
                       --enable-languages=c,c++ \
                       --disable-multilib       \
                       --disable-bootstrap      \
                       --with-system-zlib
make
make install
ln -sv ../usr/bin/cpp /lib
ln -sv gcc /usr/bin/cc
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
cd /sources
rm -rf gcc-build gcc-4.7.1

# 6.18. Sed-4.2.1
tar xvf sed-4.2.1.tar.bz2
cd sed-4.2.1
./configure --prefix=/usr --bindir=/bin --htmldir=/usr/share/doc/sed-4.2.1
make
make install

if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    make -C doc install-html
fi

cd /sources
rm -rf sed-4.2.1

# 6.19. Bzip2-1.0.6
tar xvf bzip2-1.0.6.tar.gz
cd bzip2-1.0.6
patch -Np1 -i ../bzip2-1.0.6-install_docs-1.patch
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
make -f Makefile-libbz2_so
make clean
make
make PREFIX=/usr install
cp -v bzip2-shared /bin/bzip2
cp -av libbz2.so* /lib
ln -sv ../../lib/libbz2.so.1.0 /usr/lib/libbz2.so
rm -v /usr/bin/{bunzip2,bzcat,bzip2}
ln -sv bzip2 /bin/bunzip2
ln -sv bzip2 /bin/bzcat
cd /sources
rm -rf bzip2-1.0.6

# 6.20. Pkg-config-0.27
tar xvf pkg-config-0.27.tar.gz
cd pkg-config-0.27
./configure --prefix=/usr         \
            --with-internal-glib  \
            --docdir=/usr/share/doc/pkg-config-0.27
make
make install
cd /sources
rm -rf pkg-config-0.27

# 6.21. Ncurses-5.9
tar xvf ncurses-5.9.tar.gz
cd ncurses-5.9
./configure --prefix=/usr --mandir=/usr/share/man --with-shared \
            --without-debug --enable-widec
make
make install
mv -v /usr/lib/libncursesw.so.5* /lib
ln -sfv ../../lib/libncursesw.so.5 /usr/lib/libncursesw.so
for lib in ncurses form panel menu ; do \
    rm -vf /usr/lib/lib${lib}.so ; \
    echo "INPUT(-l${lib}w)" >/usr/lib/lib${lib}.so ; \
    ln -sfv lib${lib}w.a /usr/lib/lib${lib}.a ; \
done
ln -sfv libncurses++w.a /usr/lib/libncurses++.a
rm -vf /usr/lib/libcursesw.so
echo "INPUT(-lncursesw)" >/usr/lib/libcursesw.so
ln -sfv libncurses.so /usr/lib/libcurses.so
ln -sfv libncursesw.a /usr/lib/libcursesw.a
ln -sfv libncurses.a /usr/lib/libcurses.a

if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    mkdir -v /usr/share/doc/ncurses-5.9
    cp -v -R doc/* /usr/share/doc/ncurses-5.9
fi

cd /sources
rm -rf ncurses-5.9

# 6.22. Util-linux-2.21.2
tar xvf util-linux-2.21.2.tar.xz
cd util-linux-2.21.2
sed -i -e 's@etc/adjtime@var/lib/hwclock/adjtime@g' \
    $(grep -rl '/etc/adjtime' .)
mkdir -pv /var/lib/hwclock
./configure
make
make install
cd /sources
rm -rf util-linux-2.21.2

# 6.23. Psmisc-22.19
tar xvf psmisc-22.19.tar.gz
cd psmisc-22.19
./configure --prefix=/usr
make
make install
mv -v /usr/bin/fuser /bin
mv -v /usr/bin/killall /bin
cd /sources
rm -rf psmisc-22.19

# 6.24. E2fsprogs-1.42.4
tar xvf e2fsprogs-1.42.4.tar.gz
cd e2fsprogs-1.42.4
mkdir -v build
cd build
PKG_CONFIG=/tools/bin/true         \
LDFLAGS="-lblkid -luuid"           \
../configure --prefix=/usr         \
             --with-root-prefix="" \
             --enable-elf-shlibs   \
             --disable-libblkid    \
             --disable-libuuid     \
             --disable-uuidd       \
             --disable-fsck
make
make install
make install-libs
chmod -v u+w /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a

if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    gunzip -v /usr/share/info/libext2fs.info.gz
    install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
    makeinfo -o doc/com_err.info ../lib/et/com_err.texinfo
    install -v -m644 doc/com_err.info /usr/share/info
    install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
fi

cd /sources
rm -rf e2fsprogs-1.42.4

# 6.25. Coreutils-8.17
tar xvf coreutils-8.17.tar.xz
cd coreutils-8.17
sed -i -e 's/! isatty/isatty/' \
       -e '45i\              || errno == ENOENT' gnulib-tests/test-getlogin.c
patch -Np1 -i ../coreutils-8.17-i18n-1.patch
FORCE_UNSAFE_CONFIGURE=1 ./configure \
            --prefix=/usr         \
            --libexecdir=/usr/lib \
            --enable-no-install-program=kill,uptime
make
make install
mv -v /usr/bin/{cat,chgrp,chmod,chown,cp,date,dd,df,echo} /bin
mv -v /usr/bin/{false,ln,ls,mkdir,mknod,mv,pwd,rm} /bin
mv -v /usr/bin/{rmdir,stty,sync,true,uname} /bin
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i s/\"1\"/\"8\"/1 /usr/share/man/man8/chroot.8
mv -v /usr/bin/{head,sleep,nice} /bin
cd /sources
rm -rf coreutils-8.17

# 6.26. Iana-Etc-2.30
tar xvf iana-etc-2.30.tar.bz2
cd iana-etc-2.30
make
make install
cd /sources
rm -rf iana-etc-2.30

# 6.27. M4-1.4.16
tar xvf m4-1.4.16.tar.bz2
cd m4-1.4.16
./configure --prefix=/usr
make
make install
cd /sources
rm -rf m4-1.4.16

# 6.28. Bison-2.5.1
tar xvf bison-2.5.1.tar.xz
cd bison-2.5.1
./configure --prefix=/usr
echo '#define YYENABLE_NLS 1' >> lib/config.h
make
make install
cd /sources
rm -rf bison-2.5.1

# 6.29. Procps-3.2.8
tar xvf procps-3.2.8.tar.gz
cd procps-3.2.8
patch -Np1 -i ../procps-3.2.8-fix_HZ_errors-1.patch
patch -Np1 -i ../procps-3.2.8-watch_unicode-1.patch
sed -i -e 's@\*/module.mk@proc/module.mk ps/module.mk@' Makefile
make
make install
cd /sources
rm -rf procps-3.2.8

# 6.30. Grep-2.13
tar xvf grep-2.13.tar.xz
cd grep-2.13
./configure --prefix=/usr --bindir=/bin
make
make install
cd /sources
rm -rf grep-2.13

# 6.31. Readline-6.2
tar xvf readline-6.2.tar.gz
cd readline-6.2
sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install
patch -Np1 -i ../readline-6.2-fixes-1.patch
./configure --prefix=/usr --libdir=/lib
make SHLIB_LIBS=-lncurses
make install
mv -v /lib/lib{readline,history}.a /usr/lib
rm -v /lib/lib{readline,history}.so
ln -sfv ../../lib/libreadline.so.6 /usr/lib/libreadline.so
ln -sfv ../../lib/libhistory.so.6 /usr/lib/libhistory.so

if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    mkdir -v /usr/share/doc/readline-6.2
    install -v -m644 doc/*.{ps,pdf,html,dvi} \
    /usr/share/doc/readline-6.2
fi

cd /sources
rm -rf readline-6.2

# 6.32. Bash-4.2
tar xvf bash-4.2.tar.gz
cd bash-4.2
patch -Np1 -i ../bash-4.2-fixes-8.patch
./configure --prefix=/usr                     \
            --bindir=/bin                     \
            --htmldir=/usr/share/doc/bash-4.2 \
            --without-bash-malloc             \
            --with-installed-readline
make
make install
# exec /bin/bash -e --login +h
# Don't know of a good way to keep running the script after entering bash here. Let me know!
cd /sources
rm -rf bash-4.2

# 6.33. Libtool-2.4.2
tar xvf libtool-2.4.2.tar.gz
cd libtool-2.4.2
./configure --prefix=/usr
make
make install
cd /sources
rm -rf libtool-2.4.2

# 6.34. GDBM-1.10
tar xvf gdbm-1.10.tar.gz
cd gdbm-1.10
./configure --prefix=/usr --enable-libgdbm-compat
make
make install
cd /sources
rm -rf gdbm-1.10

# 6.35. Inetutils-1.9.1
tar xvf inetutils-1.9.1.tar.gz
cd inetutils-1.9.1
./configure --prefix=/usr  \
    --libexecdir=/usr/sbin \
    --localstatedir=/var   \
    --disable-ifconfig     \
    --disable-logger       \
    --disable-syslogd      \
    --disable-whois        \
    --disable-servers
make
make install

if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    make -C doc html
    make -C doc install-html docdir=/usr/share/doc/inetutils-1.9.1
fi

mv -v /usr/bin/{hostname,ping,ping6} /bin
mv -v /usr/bin/traceroute /sbin
cd /sources
rm -rf inetutils-1.9.1

# 6.36. Perl-5.16.0
tar xvf perl-5.16.0.tar.bz2
cd perl-5.16.0
echo "127.0.0.1 localhost $(hostname)" > /etc/hosts
sed -i -e "s|BUILD_ZLIB\s*= True|BUILD_ZLIB = False|"           \
       -e "s|INCLUDE\s*= ./zlib-src|INCLUDE    = /usr/include|" \
       -e "s|LIB\s*= ./zlib-src|LIB        = /usr/lib|"         \
    cpan/Compress-Raw-Zlib/config.in
sh Configure -des -Dprefix=/usr                 \
                  -Dvendorprefix=/usr           \
                  -Dman1dir=/usr/share/man/man1 \
                  -Dman3dir=/usr/share/man/man3 \
                  -Dpager="/usr/bin/less -isR"  \
                  -Duseshrplib
make
make install
cd /sources
rm -rf perl-5.16.0


# 6.37. Autoconf-2.69
tar xvf autoconf-2.69.tar.xz
cd autoconf-2.69
./configure --prefix=/usr
make
make install
cd /sources
rm -rf autoconf-2.69

# 6.38. Automake-1.12.2
tar xvf automake-1.12.2.tar.xz
cd automake-1.12.2
sed -i -e '48i$sleep' t/aclocal7.sh
./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.12.2
make
make install
cd /sources
rm -rf automake-1.12.2

# 6.39. Diffutils-3.2
tar xvf diffutils-3.2.tar.gz
cd diffutils-3.2
./configure --prefix=/usr
make
make install
cd /sources
rm -rf diffutils-3.2

# 6.40. Gawk-4.0.1
tar xvf gawk-4.0.1.tar.xz
cd gawk-4.0.1
./configure --prefix=/usr --libexecdir=/usr/lib
make
make install

if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    mkdir -v /usr/share/doc/gawk-4.0.1
    cp -v doc/{awkforai.txt,*.{eps,pdf,jpg}} /usr/share/doc/gawk-4.0.1
fi

cd /sources
rm -rf gawk-4.0.1

# 6.41. Findutils-4.4.2
tar xvf findutils-4.4.2.tar.gz
cd findutils-4.4.2
./configure --prefix=/usr                   \
            --libexecdir=/usr/lib/findutils \
            --localstatedir=/var/lib/locate
make
make install
mv -v /usr/bin/find /bin
sed -i 's/find:=${BINDIR}/find:=\/bin/' /usr/bin/updatedb
cd /sources
rm -rf findutils-4.4.2

# 6.42. Flex-2.5.35
tar xvf flex-2.5.35.tar.bz2
cd flex-2.5.35
patch -Np1 -i ../flex-2.5.35-gcc44-1.patch
./configure --prefix=/usr --mandir=/usr/share/man --infodir=/usr/share/info
make
make install
ln -sv libfl.a /usr/lib/libl.a
cat > /usr/bin/lex << "EOF"
#!/bin/sh
# Begin /usr/bin/lex

exec /usr/bin/flex -l "$@"

# End /usr/bin/lex
EOF
chmod -v 755 /usr/bin/lex

if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    mkdir -v /usr/share/doc/flex-2.5.35
    cp -v doc/flex.pdf /usr/share/doc/flex-2.5.35
fi

cd /sources
rm -rf flex-2.5.35

# 6.43. Gettext-0.18.1.1
tar xvf gettext-0.18.1.1.tar.gz
cd gettext-0.18.1.1
./configure --prefix=/usr \
            --docdir=/usr/share/doc/gettext-0.18.1.1
make
make install
cd /sources
rm -rf gettext-0.18.1.1

# 6.44. Groff-1.21
tar xvf groff-1.21.tar.gz
cd groff-1.21
PAGE=$GROFF_PAPER_SIZE ./configure --prefix=/usr
make
make install
ln -sv eqn /usr/bin/geqn
ln -sv tbl /usr/bin/gtbl
cd /sources
rm -rf groff-1.21

# 6.45. Xz-5.0.4
tar xvf xz-5.0.4.tar.xz
cd xz-5.0.4
./configure --prefix=/usr --libdir=/lib --docdir=/usr/share/doc/xz-5.0.4
make
make pkgconfigdir=/usr/lib/pkgconfig install
cd /sources
rm -rf xz-5.0.4

# 6.46. GRUB-2.00

# 6.47. Less-444
tar xvf less-444.tar.gz
cd less-444
./configure --prefix=/usr --sysconfdir=/etc
make
make install
cd /sources
rm -rf less-444

# 6.48. Gzip-1.5
tar xvf gzip-1.5.tar.xz
cd gzip-1.5
./configure --prefix=/usr --bindir=/bin
make
make install
mv -v /bin/{gzexe,uncompress,zcmp,zdiff,zegrep} /usr/bin
mv -v /bin/{zfgrep,zforce,zgrep,zless,zmore,znew} /usr/bin
cd /sources
rm -rf gzip-1.5

# 6.49. IPRoute2-3.4.0
tar xvf iproute2-3.4.0.tar.xz
cd iproute2-3.4.0
sed -i '/^TARGETS/s@arpd@@g' misc/Makefile
sed -i /ARPD/d Makefile
sed -i 's/arpd.8//' man/man8/Makefile
make DESTDIR=
make DESTDIR=              \
     MANDIR=/usr/share/man \
     DOCDIR=/usr/share/doc/iproute2-3.4.0 install
cd /sources
rm -rf iproute2-3.4.0

# 6.50. Kbd-1.15.3
tar xvf kbd-1.15.3.tar.gz
cd kbd-1.15.3
patch -Np1 -i ../kbd-1.15.3-upstream_fixes-1.patch
patch -Np1 -i ../kbd-1.15.3-backspace-1.patch
sed -i '/guardado\ el/s/\(^.*en\ %\)\(.*\)/\14\$\2/' po/es.po
sed -i 's/\(RESIZECONS_PROGS=\)yes/\1no/' configure &&
sed -i 's/resizecons.8 //' man/man8/Makefile.in &&
touch -d '2011-05-07 08:30' configure.ac
./configure --prefix=/usr --datadir=/lib/kbd
make
make install
mv -v /usr/bin/{kbd_mode,loadkeys,openvt,setfont} /bin

if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    mkdir -v /usr/share/doc/kbd-1.15.3
    cp -R -v doc/* \
    /usr/share/doc/kbd-1.15.3
fi

cd /sources
rm -rf kbd-1.15.3

# 6.51. Kmod-9
tar xvf kmod-9.tar.xz
cd kmod-9
patch -Np1 -i ../kmod-9-testsuite-1.patch
./configure --prefix=/usr       \
            --bindir=/bin       \
            --libdir=/lib       \
            --sysconfdir=/etc   \
            --with-xz           \
            --with-zlib
make
make pkgconfigdir=/usr/lib/pkgconfig install
for target in depmod insmod modinfo modprobe rmmod; do
  ln -sv ../bin/kmod /sbin/$target
done
ln -sv kmod /bin/lsmod
cd /sources
rm -rf kmod-9

# 6.52. Libpipeline-1.2.1
tar xvf libpipeline-1.2.1.tar.gz
cd libpipeline-1.2.1
PKG_CONFIG_PATH=/tools/lib/pkgconfig ./configure --prefix=/usr
make
make install
cd /sources
rm -rf libpipeline-1.2.1

# 6.53. Make-3.82
tar xvf make-3.82.tar.bz2
cd make-3.82
./configure --prefix=/usr
make
make install
cd /sources
rm -rf make-3.82

# 6.54. Man-DB-2.6.2
tar xvf man-db-2.6.2.tar.xz
cd man-db-2.6.2
./configure --prefix=/usr                        \
            --libexecdir=/usr/lib                \
            --docdir=/usr/share/doc/man-db-2.6.2 \
            --sysconfdir=/etc                    \
            --disable-setuid                     \
            --with-browser=/usr/bin/lynx         \
            --with-vgrind=/usr/bin/vgrind        \
            --with-grap=/usr/bin/grap
make
make install
cd /sources
rm -rf man-db-2.6.2

# 6.55. Patch-2.6.1
tar xvf patch-2.6.1.tar.bz2
cd patch-2.6.1
patch -Np1 -i ../patch-2.6.1-test_fix-1.patch
./configure --prefix=/usr
make
make install
cd /sources
rm -rf patch-2.6.1

# 6.56. Shadow-4.1.5.1
tar xvf shadow-4.1.5.1.tar.bz2
cd shadow-4.1.5.1
sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /' {} \;
sed -i -e 's@#ENCRYPT_METHOD DES@ENCRYPT_METHOD SHA512@' \
       -e 's@/var/spool/mail@/var/mail@' etc/login.defs
./configure --sysconfdir=/etc
make
make install
mv -v /usr/bin/passwd /bin
pwconv
grpconv
sed -i 's/yes/no/' /etc/default/useradd
cd /sources
rm -rf shadow-4.1.5.1

# 6.57. Sysklogd-1.5
tar xvf sysklogd-1.5.tar.gz
cd sysklogd-1.5
make
make BINDIR=/sbin install
cat > /etc/syslog.conf << "EOF"
# Begin /etc/syslog.conf

auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *

# End /etc/syslog.conf
EOF
cd /sources
rm -rf sysklogd-1.5

# 6.58. Sysvinit-2.88dsf
tar xvf sysvinit-2.88dsf.tar.bz2
cd sysvinit-2.88dsf
sed -i 's@Sending processes@& configured via /etc/inittab@g' src/init.c
sed -i -e 's/utmpdump wall/utmpdump/' \
       -e '/= mountpoint/d' \
       -e 's/mountpoint.1 wall.1//' src/Makefile
make -C src
make -C src install
cd /sources
rm -rf sysvinit-2.88dsf

# 6.59. Tar-1.26
tar xvf tar-1.26.tar.bz2
cd tar-1.26
FORCE_UNSAFE_CONFIGURE=1  \
./configure --prefix=/usr \
            --bindir=/bin \
            --libexecdir=/usr/sbin
make
make install

if [[ $INSTALL_OPTIONAL_DOCS = 1 ]] ; then
    make -C doc install-html docdir=/usr/share/doc/tar-1.26
fi

cd /sources
rm -rf tar-1.26

# 6.60. Texinfo-4.13a
tar xvf texinfo-4.13a.tar.gz
cd texinfo-4.13
./configure --prefix=/usr
make
make install
# I don't know anybody who wants this... prove me wrong!
# make TEXMF=/usr/share/texmf install-tex
cd /sources
rm -rf texinfo-4.13

# 6.61. Udev-187 (Extracted from systemd-187)
tar xvf systemd-187.tar.xz
cd systemd-187
tar -xvf ../udev-lfs-187.tar.bz2
make -f udev-lfs-187/Makefile.lfs
make -f udev-lfs-187/Makefile.lfs install
cd /sources
rm -rf systemd-187

# 6.62. Vim-7.3
tar xvf vim-7.3.tar.bz2
cd vim73
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
./configure --prefix=/usr --enable-multibyte
make
make install
ln -sv vim /usr/bin/vi
for L in  /usr/share/man/{,*/}man1/vim.1; do
    ln -sv vim.1 $(dirname $L)/vi.1
done
ln -sv ../vim/vim73/doc /usr/share/doc/vim-7.3
cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

set nocompatible
set backspace=2
syntax on
if (&term == "iterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF
cd /sources
rm -rf vim73

echo -e "--------------------------------------------------------------------"
echo -e "\nYou made it! Now there are just a few things left to take care of..."
echo -e "You have not set a root password yet. Go ahead, I'll wait here.\n"
passwd root

echo -e "\nNext you'll probably want the network fix..."
echo -e "Do you want me to add vm.min_free_kbytes=8192 to your /etc/sysctl.conf?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) echo "vm.min_free_kbytes=8192" >> /etc/sysctl.conf; break;;
        No ) break;;
    esac
done

check_firmware

echo -e "\nNow about the firmware..."
echo "You probably want to copy the supplied Broadcom libraries to /opt/vc?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) cp -rv /sources/raspberrypi-firmware-???????/hardfp/opt/vc /opt && echo "/opt/vc/lib" >> /etc/ld.so.conf.d/broadcom.conf && ldconfig; break;;
        No ) break;;
    esac
done

echo -e "\nLast question, if you want I can mount the boot partition and overwrite the kernel and bootloader with the one you downloaded?"
select yn in "Yes" "No"; do
    case $yn in
        Yes ) mount /dev/mmcblk0p1 /boot && cp -rv /sources/raspberrypi-firmware-???????/boot / && umount /boot; break;;
        No ) break;;
    esac
done

echo -e "\nThere, all done! Now continue reading from \"6.63. About Debugging Symbols\" to make your system bootable."
echo "If you are not compiling your own kernel you might want to copy the kernel modules from the firmware package before you reboot."
echo "And don't forget to check out http://www.intestinate.com/pilfs/#afterlfs when you're done with your build!"
