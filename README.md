# Overview
These are instructions to demo Cohort using the provided test programs in the Cohort SOC repository on the Genesys 2 FPGA. The two steps are to:
1. generate a bitstream with OpenPiton, an Ariane tile, and Cohort tile 
2. build a Linux payload and preload it with the test program

Note this was tested on Jura.

## Generate the bistream for the FPGA

1. Clone the Cohort SOC repo: https://github.com/cohort-project/cohort-soc
```bash
git clone git@github.com:cohort-project/cohort-soc.git
cd cohort-soc
git submodule update --init --recursive
```

2. Enter the repo directory and set appropriate environment variables
```
phere
source /tools/Xilinx/Vivado/2022.1/settings64.sh
```

phere is set like this in my .bashrc:
```
alias phere="export PITON_ROOT=\$PWD; source piton/piton_settings.bash; export ARIANE_ROOT=\$PITON_ROOT/piton/design/chip/tile/ariane"
```

3. Generate the bitstream
```
protosyn -b genesys2 --define DECADES_DECOUPLING -d system -c cohort --y_tiles 2 -j 20 --cohort_tiles 1
```

The output bitstream will be at 

```
build/genesys2/system/genesys2_system/genesys2_system.runs/impl_1/system.bit
```

4. Copy the bitstream file from your local machine to a USB stick.

## Software
Now we will build the Linux Kernel payload and preload the rootfs with the Cohort tests
### Cohort tests

1. Open `piton/verif/diag/c/riscv/ariane/cohort_linux/Makefile`

2. Replace `GCC=riscv64-buildroot-linux-gnu-gcc` with the location of this compiler if it's not in your PATH.

3. Make sure `DNO_DRIVER` is *not* added to GCC_OPTS.

4. Make sure `DDRIVER_EVALS=1` *is* added to GCC_OPTS 

5. From the same directory as this Makefile, `cohort_linux`, compile the test program
```
make cohort_benchmarks
```

### Linux Payload
1. Traverse out of the Cohort SOC directory
2. Clone the ariane-sdk: https://github.com/cohort-project/ariane-sdk-private/tree/a-vinod_g2_cohort.
```
git clone git@github.com:cohort-project/ariane-sdk-private.git
cd ariane-sdk
git checkout a-vinod_g2_cohort
git submodule update --init --recursive
```

3. Create a `cohort` directory in the `rootfs` directory.
```
mkdir rootfs/cohort
```

4. Copy the benchmark binaries from Cohort SOC `verif/diag/c/riscv/ariane/cohort_linux/build` to the Ariane SDK `cohort` directory

5. Build the Linux payload
```
make fw_payload.bin
```

6. Plug in the micoSD to your local machine

7. Find the location of the microSD
```
sudo fdisk -l
```

8. Partition the disk (substitute `/dev/sda` with the location of your miroSD)
```
sudo sgdisk --clear --new=1:2048:67583 --new=2 --typecode=1:3000 --typecode=2:8300 /dev/sda 
```

9. Copy the payload to a partition on the disk (NOTE: here it is sda1 not sda)
```
sudo dd if=fw_payload.bin of=/dev/sda1 status=progress oflag=sync bs=1M
```

10. Make sure data is persisted
```
sync
```

## Booting the FPGA
Now plug in the USB into the top of the two USB ports on the FPGA and insert the microSD card. Switch it on and the Linux kernel will boot!