# img-installer
基于Debian Live系统的img镜像安装器，实现了在x86-64设备上快速安装ImmortalWrt和iStoreOS的功能。

## 使用方式
[图文教学](https://club.fnnas.com/forum.php?mod=viewthread&tid=26293)
1. 虚拟机使用：各种虚拟机直接选择iso即可
2. 物理机使用：建议将iso放入ventoy的U盘中
3. https://www.ventoy.net/cn/download.html
4. 视频教学：[![YouTube](https://img.shields.io/badge/YouTube-123456?logo=youtube&labelColor=ff0000)](https://youtu.be/6FWyACrNQIg)
[![Bilibili](https://img.shields.io/badge/Bilibili-123456?logo=bilibili&logoColor=fff&labelColor=fb7299)](https://www.bilibili.com/video/BV1DQXVYFENr)
- 【第一集 ESXI虚拟机 和 物理机使用】https://youtu.be/6FWyACrNQIg   【B站】https://www.bilibili.com/video/BV1DQXVYFENr
- 【第二集 飞牛NAS】https://youtu.be/RRBFc58SwXQ  【B站】https://www.bilibili.com/video/BV1gPXCYyEc2
- 【第三集 Hyper-V、绿联NAS虚拟机、飞牛虚拟机使用教程】 https://www.bilibili.com/video/BV1BoZVYsE7b
- 【第四集 PVE虚拟机里如何使用img安装器】https://www.bilibili.com/video/BV1Rx5Qz4EZB

5. 具体的操作方法是:在安装器所在系统里输入 `ddd` 命令 方可调出安装菜单
   ![localhost lan - VMware ESXi 2025-03-20 10-14-45](https://github.com/user-attachments/assets/ddae80a0-9ff5-4d63-83b5-1f49da18b008)

## 项目说明和相关Feature
1. 此项目生成的ISO同时支持物理机和虚拟机的安装
2. 此项目生成的安装器用于特定的img格式嵌入式系统：`ImmortalWrt`、`iStoreOS`
3. 通过运行项目根目录的脚本可以构建对应的安装器ISO
4. 支持自定义img镜像生成iso安装器,镜像压缩包格式为`img.gz`

## ISO自动制作流程
本项目基于开源项目[debian-live](https://github.com/dpowers86/debian-live)制作，代码采用MIT协议开源。

### 本地构建流程
1. 运行根目录的`imm.sh`或`istoreos.sh`脚本
2. 脚本会从GitHub Releases下载对应的img.gz镜像文件
3. 使用Docker运行debian容器，挂载必要的卷
4. 在容器内执行对应的build.sh脚本，构建流程如下：
   - 安装构建依赖
   - 使用debootstrap创建Debian chroot环境
   - 复制配置文件和installChroot.sh脚本到chroot环境
   - 挂载proc、dev、sys文件系统
   - 在chroot环境内执行installChroot.sh，安装必要软件包
   - 构建SquashFS文件系统
   - 配置GRUB引导
   - 生成最终的ISO文件
5. ISO文件输出到output目录

### GitHub Actions构建
- 项目配置了GitHub Workflow，支持手动触发构建
- 构建完成后自动发布ISO文件到GitHub Releases

## 项目参考
- https://willhaley.com/blog/custom-debian-live-environment/
- https://github.com/dpowers86/debian-live
- https://github.com/wukongdaily/img-installer
