#!/bin/sh
set -e

# 当前工作目录。拼接绝对路径的时候需要用到这个值。
WORKDIR=$(pwd)

# 如果存在旧的目录和文件，就清理掉
rm -rf *.tar.gz \
    ohos-sdk \
    unzip60 \
    unzip-6.0-ohos-arm64

# 准备 ohos-sdk
curl -fL -o ohos-sdk.tar.gz https://repo.huaweicloud.com/openharmony/os/7.0-Release/ohos-sdk-windows_linux-public_20260829.tar.gz
tar -zxf ohos-sdk.tar.gz -C ./ ohos-sdk/linux
cd ohos-sdk/linux
unzip -q native-*.zip
unzip -q toolchains-*.zip
rm -rf *.zip
cd ../..

# 设置交叉编译所需的环境变量
LLVM_BIN=$WORKDIR/ohos-sdk/linux/native/llvm/bin
export CC=$LLVM_BIN/aarch64-unknown-linux-ohos-clang
export CXX=$LLVM_BIN/aarch64-unknown-linux-ohos-clang++
export LD=$LLVM_BIN/ld.lld
export AR=$LLVM_BIN/llvm-ar
export AS=$LLVM_BIN/llvm-as
export NM=$LLVM_BIN/llvm-nm
export OBJCOPY=$LLVM_BIN/llvm-objcopy
export OBJDUMP=$LLVM_BIN/llvm-objdump
export RANLIB=$LLVM_BIN/llvm-ranlib
export STRIP=$LLVM_BIN/llvm-strip

# 编译 unzip
curl -fLO https://downloads.sourceforge.net/project/infozip/UnZip%206.x%20%28latest%29/UnZip%206.0/unzip60.tar.gz
tar -zxf unzip60.tar.gz
cd unzip60
make -j$(nproc) -f unix/Makefile unzips \
    CC="$CC" \
    LOC="-DLARGE_FILE_SUPPORT -DUNICODE_SUPPORT -DUNICODE_WCHAR -DUTF8_MAYBE_NATIVE -DNO_WORKING_ISPRINT -DNO_LCHMOD"
make -f unix/Makefile \
    prefix=$WORKDIR/unzip-6.0-ohos-arm64 \
    MANDIR=$WORKDIR/unzip-6.0-ohos-arm64/share/man/man1 \
    install
cd ..

# 进行代码签名
cd $WORKDIR/unzip-6.0-ohos-arm64
find . -type f \( -perm -0111 -o -name "*.so*" \) | while read FILE; do
    if file -b "$FILE" | grep -iqE "elf|sharedlib|ELF|shared object"; then
        echo "Signing binary file $FILE"
        ORIG_PERM=$(stat -c %a "$FILE")
        $WORKDIR/ohos-sdk/linux/toolchains/lib/binary-sign-tool sign -inFile "$FILE" -outFile "$FILE" -selfSign 1
        chmod "$ORIG_PERM" "$FILE"
    fi
done
cd $WORKDIR

# 履行开源义务，将 license 随制品一起发布
cp unzip60/LICENSE unzip-6.0-ohos-arm64/

# 打包最终产物
tar -zcf unzip-6.0-ohos-arm64.tar.gz unzip-6.0-ohos-arm64
