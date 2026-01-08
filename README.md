# iStoreOS ISO Builder

一个GitHub Action工作流，用于将iStoreOS的.img.gz安装包转换为基于Debian Live系统的ISO文件。

## 功能特性

- 自动从GitHub Releases下载最新iStoreOS镜像
- 支持手动指定iStoreOS版本
- 基于Debian Live系统构建
- 生成可引导的ISO文件
- 支持x86_64架构

## 使用方法

### 1. 创建空仓库

在GitHub上创建一个新的空仓库，用于存放构建工作流。

### 2. 上传文件

将以下文件上传到仓库根目录：

- `.github/workflows/build-iso.yml` - GitHub Action工作流
- `convert.sh` - 转换脚本
- `config/` - Debian Live配置目录
  - `config/config` - 主配置文件
  - `config/package-lists/istoreos.list.chroot` - 包列表

### 3. 触发构建

#### 自动触发
- 当推送代码到`main`分支时
- 当提交Pull Request到`main`分支时

#### 手动触发
1. 进入仓库的"Actions"标签页
2. 选择"Build iStoreOS ISO from img.gz"工作流
3. 点击"Run workflow"
4. 可选：输入iStoreOS版本号，例如"1.0.0"
5. 点击"Run workflow"

## 构建产物

构建完成后，ISO文件将作为GitHub Action的Artifacts上传，您可以在Actions页面下载。

## 构建流程

1. **设置环境**：安装所需的依赖包
2. **下载镜像**：从GitHub Releases下载iStoreOS的.img.gz文件
3. **解压镜像**：将.img.gz文件解压为.img文件
4. **转换镜像**：运行`convert.sh`脚本，将.img文件转换为ISO文件
5. **上传产物**：将生成的ISO文件上传为Artifact

## 技术细节

- **基础系统**：Debian Bookworm
- **构建工具**：live-build
- **架构**：amd64
- **引导方式**：isolinux

## 自定义配置

### 修改Debian Live配置

编辑`config/config`文件，可以修改以下参数：
- 发行版（distribution）
- 架构（architecture）
- 包仓库（archive-areas）
- 引导参数（bootappend-live）

### 修改包列表

编辑`config/package-lists/istoreos.list.chroot`文件，可以添加或删除所需的包。

### 修改转换脚本

编辑`convert.sh`文件，可以修改转换逻辑，例如：
- ISO文件名
- 工作目录
- 引导配置

## 注意事项

1. 构建过程需要约10-15分钟
2. 生成的ISO文件大小约为1-2GB
3. 请确保您的仓库有足够的存储空间
4. 仅支持x86_64架构的iStoreOS镜像

## 许可证

MIT License
