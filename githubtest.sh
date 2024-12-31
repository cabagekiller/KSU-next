{\rtf1\ansi\ansicpg1252\cocoartf2821
\cocoatextscaling0\cocoaplatform0{\fonttbl\f0\froman\fcharset0 Times-Roman;}
{\colortbl;\red255\green255\blue255;\red0\green0\blue0;}
{\*\expandedcolortbl;;\cssrgb\c0\c0\c0;}
\margl1440\margr1440\vieww11520\viewh8400\viewkind0
\deftab720
\pard\pardeftab720\partightenfactor0

\f0\fs24 \cf0 \expnd0\expndtw0\kerning0
\outl0\strokewidth0 \strokec2 name: Build and Release Kernel\
\
on:\
  push:\
    branches:\
      - main # Change to your main branch name if different\
\
jobs:\
  build:\
    runs-on: ubuntu-latest\
\
    steps:\
      - name: Checkout code\
        uses: actions/checkout@v3\
\
      - name: Set up Python\
        uses: actions/setup-python@v4\
        with:\
          python-version: '3.x' # Specify Python version if needed\
\
      - name: Install dependencies\
        run: |\
          sudo apt-get update\
          sudo apt-get install -y zip bc bison flex g++-multilib \\\
                                  gcc-multilib libc6-dev-i386 \\\
                                  lib32ncurses5-dev x11proto-core-dev \\\
                                  libx11-dev lib32z1-dev libgl1-mesa-glx \\\
                                  libxml2-utils xsltproc unzip repo \\\
                                  gh # Install the gh CLI\
\
      - name: Create builds folder\
        run: |\
          mkdir -p ./builds\
          cd ./builds\
\
      - name: Create root folder\
        run: |\
          ROOT_DIR="OP12-A15-$(date +'%Y-%m-%d-%I-%M-%p')-release"\
          mkdir -p "$ROOT_DIR"\
          cd "$ROOT_DIR"\
\
      - name: Clone repositories\
        run: |\
          git clone https://github.com/TheWildJames/AnyKernel3.git -b android14-5.15\
          git clone https://gitlab.com/simonpunk/susfs4ksu.git -b gki-android14-6.1\
          git clone https://github.com/TheWildJames/kernel_patches.git\
\
      - name: Get the kernel\
        run: |\
          mkdir oneplus12_v\
          cd ./oneplus12_v\
       curl -Lo repo https://storage.googleapis.com/git-repo-downloads/repo
          chmod a+x repo
          sudo mv repo /usr/local/bin/
          /usr/local/bin/repo init -u https://github.com/OnePlusOSS/kernel_manifest.git -b oneplus/sm8650 -m oneplus12_v.xml
          /usr/local/bin/repo sync -j$(nproc)
          rm -rf ./kernel_platform/common/android/abi_gki_protected_exports_*\
\
      - name: Add KernelSU\
        run: |\
          cd ./oneplus12_v/kernel_platform  # Navigate to the correct directory
          curl -LSs "https://raw.githubusercontent.com/rifsxd/KernelSU-Next/next/kernel/setup.sh" | bash -s next-susfs-a14-6.1\
          cd ./KernelSU-Next/kernel\
          sed -i 's/ccflags-y += -DKSU_VERSION=16/ccflags-y += -DKSU_VERSION=12113/' ./Makefile\
          cd ../../\
\
      - name: Add susfs\
        run: |\
          cp ../../susfs4ksu/kernel_patches/KernelSU/10_enable_susfs_for_ksu.patch ./KernelSU-Next/\
          cp ../../susfs4ksu/kernel_patches/50_add_susfs_in_gki-android14-6.1.patch ./common/\
          cp ../../susfs4ksu/kernel_patches/fs/susfs.c ./common/fs/\
          cp ../../susfs4ksu/kernel_patches/include/linux/susfs.h ./common/include/linux/\
          cp ../../susfs4ksu/kernel_patches/fs/sus_su.c ./common/fs/\
          cp ../../susfs4ksu/kernel_patches/include/linux/sus_su.h ./common/include/linux/\
          cd ./KernelSU-Next/\
          patch -p1 < 10_enable_susfs_for_ksu.patch\
          cd ../common\
          patch -p1 < 50_add_susfs_in_gki-android14-6.1.patch\
\
      - name: Build Kernel\
        run: |\
          cd ..\
          echo "CONFIG_KSU=y" >> ./common/arch/arm64/configs/gki_defconfig\
          echo "CONFIG_KSU_SUSFS=y" >> ./common/arch/arm64/configs/gki_defconfig\
          echo "CONFIG_KSU_SUSFS_SUS_PATH=y" >> ./common/arch/arm64/configs/gki_defconfig\
          echo "CONFIG_KSU_SUSFS_SUS_MOUNT=y" >> ./common/arch/arm64/configs/gki_defconfig\
          echo "CONFIG_KSU_SUSFS_SUS_KSTAT=y" >> ./common/arch/arm64/configs/gki_defconfig\
          echo "CONFIG_KSU_SUSFS_SUS_OVERLAYFS=y" >> ./common/arch/arm64/configs/gki_defconfig\
          echo "CONFIG_KSU_SUSFS_TRY_UMOUNT=y" >> ./common/arch/arm64/configs/gki_defconfig\
          echo "CONFIG_KSU_SUSFS_SPOOF_UNAME=y" >> ./common/arch/arm64/configs/gki_defconfig\
          echo "CONFIG_KSU_SUSFS_ENABLE_LOG=y" >> ./common/arch/arm64/configs/gki_defconfig\
          echo "CONFIG_KSU_SUSFS_OPEN_REDIRECT=y" >> ./common/arch/arm64/configs/gki_defconfig\
          echo "CONFIG_KSU_SUSFS_SUS_SU=y" >> ./common/arch/arm64/configs/gki_defconfig\
          cd ..\
          sed -i '2s/check_defconfig//' ./kernel_platform/common/build.config.gki\
          ./kernel_platform/oplus/build/oplus_build_kernel.sh pineapple gki\
\
      - name: Copy Image.lz4\
        run: |\
          cp ./out/dist/Image ../AnyKernel3/Image\
\
      - name: Navigate to AnyKernel3\
        run: |\
          cd ../AnyKernel3\
\
      - name: Create zip file\
        run: |\
          ZIP_NAME="Anykernel3-OP-A15-android14-6.1-KernelSU-SUSFS-$(date +'%Y-%m-%d-%H-%M-%S').zip"\
          zip -r "../$ZIP_NAME" ./*\
          cd ..\
\
      - name: Create GitHub Release\
        run: |\
          gh release create "v$(date +'%Y.%m.%d-%H%M%S')" "$ZIP_NAME" \\\
            --repo "Cabagekiller/OnePlus_KernelSU_SUSFS" \\\
            --title "OP12 A15 android14-6.1 With KernelSU & SUSFS" \\\
            --notes "Kernel release" \\\
            --token $\{\{ secrets.GITHUB_TOKEN \}\}}
