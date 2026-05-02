# MyDesk

> A native macOS visual workbench for reconnecting files, folders, prompts, commands, and project thinking across complex work systems.

[![简体中文](https://img.shields.io/badge/语言-简体中文-1677ff)](#中文)
[![English](https://img.shields.io/badge/Language-English-24292f)](#english)

<p align="center">
  <img src="Sources/MyDesk/Resources/AppIcon.png" alt="MyDesk logo" width="128">
</p>

![Platform](https://img.shields.io/badge/platform-macOS%2014%2B-111827)
![Swift](https://img.shields.io/badge/Swift-6.0-F05138)
![UI](https://img.shields.io/badge/UI-SwiftUI-0A84FF)
![Storage](https://img.shields.io/badge/storage-SwiftData-34C759)
![License](https://img.shields.io/badge/license-MIT-22C55E)
![Release](https://img.shields.io/badge/release-v1.3.0-0A84FF)

---

<a id="english"></a>

## English

### Index

- [Product Positioning](#product-positioning)
- [Problem](#problem)
- [Core Idea](#core-idea)
- [What MyDesk Provides](#what-mydesk-provides)
- [Use Cases](#use-cases)
- [Install the App Package](#install-the-app-package)
- [Use the Source Package](#use-the-source-package)
- [Build From Source](#build-from-source)
- [Data, Privacy, and Reliability](#data-privacy-and-reliability)
- [Release Notes](#release-notes)
- [What's New in v1.3.0](#whats-new-in-v130)
- [Project Structure](#project-structure)
- [Roadmap](#roadmap)
- [中文说明](#中文)

### Product Positioning

MyDesk is a macOS workbench for people who already maintain disciplined file systems, project names, folder structures, and research or production archives, but still need a faster way to understand how the same resources are reused across different projects.

Traditional folders are excellent for storage. They are less effective for explaining relationships: which dataset belongs to which experiment, which script generated which output, which prompt supports which workflow, and why the same file matters in multiple project contexts. MyDesk adds a visual layer above the file system without replacing the file system.

The goal is to turn a well-organized local archive into a reusable visual knowledge base: one source file can appear in multiple project workspaces, with different notes, links, frames, and workflow meaning each time.

### Problem

Complex projects often create three kinds of friction:

| Pain Point | Why It Matters |
| --- | --- |
| One file, many contexts | The same folder, script, paper, prompt, or output can be relevant to multiple projects, but a single folder tree cannot show every relationship cleanly. |
| Tags become noisy | Tags help retrieval, but large tag systems become abstract, hard to maintain, and disconnected from project reasoning. |
| Project thinking is scattered | Files live in Finder, commands live in Terminal history, prompts live in notes, and workflow logic lives in memory. |
| Re-entry is expensive | Returning to a complex project requires remembering paths, decisions, dependencies, and next actions. |

MyDesk is designed to reduce that re-entry cost. It gives each project a visual workspace where resources are not merely listed, but placed, connected, annotated, and grouped.

### Core Idea

MyDesk keeps your real files where they are. It stores lightweight metadata that maps those files into visual workspaces.

```mermaid
flowchart LR
    A["Existing local file system"] --> B["Global Library"]
    B --> C["Workspace-specific visual canvas"]
    C --> D["Cards, notes, frames, and connections"]
    D --> E["Faster project re-entry and reuse"]
    B --> F["Pinned resources and snippets"]
    F --> C
```

This creates a practical middle layer between strict file classification and free-form note taking:

- Files remain in their original locations.
- Workspaces describe project-specific meaning.
- Cards can represent folders, files, prompts, commands, or notes.
- Organization frames capture project sections or reasoning blocks.
- Connections show direction, dependency, or workflow flow.
- Reusable snippets keep common prompts and commands close to the project.

### What MyDesk Provides

| Area | Capability |
| --- | --- |
| Home | Reopen recent workspaces, pinned resources, and recent snippets quickly. |
| Global Library | Keep reusable file and folder sources available across workspaces, see where each resource is used, and filter by workspace. |
| Pinned Folders / Files | Keep high-priority resources close, expand folders, copy paths, and open Finder targets. |
| Snippet Library | Store prompts, commands, text blocks, and operational references. Snippets can be copied, edited, deleted, expanded, and reused in workspaces. |
| Workspace Canvas | Build visual workflow maps with global resources, workspace resources, prompt cards, note cards, and organization frames. |
| Connections | Draw directional workflow links with visible arrows, animated flow, draggable bend points, lockable anchors, and automatic obstacle avoidance. |
| Layout | Auto-arrange workflow cards, align selected nodes, resize cards and frames, zoom like a visual board, and box-select groups. |
| macOS Integration | Open folders in Finder, reveal files, copy full paths, create Finder aliases after confirmation, and prepare command workflows. |
| Data Portability | Export and import schema-versioned JSON manifests for backup and migration. |
| Reliability | Uses an app-specific SwiftData store path, startup recovery behavior, backup retention logic, and a regression checklist for core workflows. |
| Todo Board | Track project tasks in workspace groups with task details, pinned items, DDL dates, and linked resources. |

### Use Cases

| Scenario | Example |
| --- | --- |
| Research systems | Connect papers, datasets, simulation inputs, scripts, derived outputs, and interpretation notes. |
| Multi-project asset reuse | Reuse one reference folder or source dataset across several project canvases without duplicating files. |
| Development work | Organize repos, specs, terminal commands, reusable prompts, environment scripts, and generated artifacts. |
| Creative production | Map references, drafts, exports, prompt libraries, and delivery folders by project stage. |
| Personal operations | Maintain a visual dashboard for frequently used folders, documents, commands, and recurring workflows. |

### Install the App Package

Download the latest package from [GitHub Releases](https://github.com/QiushanHuang/MyDesk/releases).

Recommended app package:

1. Download `MyDesk-v1.3.0-macOS.dmg`.
2. Open the DMG.
3. Drag `MyDesk.app` into `Applications`.
4. Launch `MyDesk` from Applications.

Alternative app archive:

1. Download `MyDesk-v1.3.0-macOS.zip`.
2. Unzip it.
3. Move `MyDesk.app` to `Applications`.

The current public build is ad-hoc signed and not notarized because this repository does not yet have a configured Developer ID certificate. If macOS blocks the first launch, right-click `MyDesk.app` and choose **Open**, or allow it in **System Settings > Privacy & Security**.

### Use the Source Package

GitHub Releases also provide source packages:

- `Source code (zip)`
- `Source code (tar.gz)`

Use the source package when you want to inspect the implementation, build locally, modify the app, or run the test suite.

You can also clone the repository directly:

```bash
git clone https://github.com/QiushanHuang/MyDesk.git
cd MyDesk
```

### Build From Source

Requirements:

- macOS 14 or newer
- Xcode command line tools
- Swift 6 toolchain

Run tests:

```bash
swift test
```

Build and launch a local app bundle:

```bash
./script/build_and_run.sh
```

Verify that the app launches:

```bash
./script/build_and_run.sh --verify
```

Create release artifacts locally:

```bash
./script/package_release.sh
```

Release artifacts are written to:

```text
dist/release/MyDesk-v1.3.0-macOS/artifacts/
```

The release script creates:

- `MyDesk-v1.3.0-macOS.dmg`
- `MyDesk-v1.3.0-macOS.zip`
- `RELEASE-NOTES.md`
- `INSTALL.txt`
- `SHA256SUMS.txt`

### Data, Privacy, and Reliability

MyDesk does not move or delete your real Finder files when you remove app metadata. It stores references, notes, layout positions, snippets, and workspace relationships in local app data.

Current data model principles:

- Real files and folders stay in their original Finder locations.
- MyDesk stores lightweight metadata and visual mapping.
- Resource deletion inside MyDesk removes MyDesk metadata, not the original file.
- Finder alias creation and command execution require explicit confirmation.
- SwiftData uses an app-specific storage location:

```text
~/Library/Application Support/studio.qiushan.mydesk/Stores/MyDesk.store
```

### Release Notes

Current release: `v1.3.0`

Highlights:

- Workspace todo groups with task details, pinned tasks, DDL dates, and linked resources.
- Global Library workspace-usage display with filtering by selected workspace.
- Safer resource import deduplication across global and workspace scopes.
- Canvas resource menus that can add global, current-workspace, and other-workspace resources.
- Refined navigation titles, detail layout, status bar spacing, and README release guidance.
- Added the new MyDesk logo to the README and release documentation.

Full release notes are available in [`docs/releases/v1.3.0.md`](docs/releases/v1.3.0.md).

### What's New in v1.3.0

This release makes MyDesk more useful when the same source material appears across several workspaces. Global Library now shows workspace usage, canvas references count as usage, and the library can be filtered to a specific workspace. Resource import also keeps global and workspace-scoped records separate, so the same path can be reused intentionally without corrupting scope meaning.

The workspace todo board is now closer to a project planning surface: tasks can be grouped, pinned, edited with details, assigned optional DDL dates, and linked back to resources. This keeps next actions attached to the same visual workspace where files, prompts, notes, and workflow connections already live.

### Project Structure

```text
Sources/MyDesk/       macOS SwiftUI application target
Sources/MyDeskCore/   testable core layout, routing, export, storage, and utility logic
Tests/                XCTest coverage for core behavior
docs/                 release notes, design notes, and feature checklist
script/               build, run, and release packaging helpers
```

### Roadmap

| Theme | Direction |
| --- | --- |
| Visual workflow database | Make project canvases stronger as a reusable knowledge layer above local files. |
| Resource intelligence | Improve previews, relationship search, source classification, and reuse across workspaces. |
| Canvas operations | Add richer routing, grouping, selection, keyboard shortcuts, and large-canvas performance work. |
| Packaging | Move from ad-hoc signed builds toward notarized Developer ID releases. |
| Import / Export | Improve portable project exchange, backups, and migration workflows. |

---

<a id="中文"></a>

## 中文

### 索引

- [产品定位](#产品定位)
- [解决的问题](#解决的问题)
- [核心思路](#核心思路)
- [功能框架](#功能框架)
- [适用场景](#适用场景)
- [安装 App 包](#安装-app-包)
- [使用源码包](#使用源码包)
- [从源码构建](#从源码构建)
- [数据、隐私与稳定性](#数据隐私与稳定性)
- [版本更新](#版本更新)
- [v1.3.0 新增内容](#v130-新增内容)
- [项目结构](#项目结构-1)
- [路线图](#路线图)
- [English README](#english)

### 产品定位

MyDesk 是一个原生 macOS 可视化工作台，用来在严谨的文件分类、项目命名和本地归档体系之上，重新组织文件、文件夹、Prompt、命令、笔记和项目思路之间的关系。

它不是要替代 Finder，也不是把一切都变成复杂标签。MyDesk 的目标是在现有文件系统上增加一个“可视化关系层”：真实文件仍然保持原来的路径和结构，但同一套文件可以在不同项目中以不同方式被引用、连接、注释和分组。

这适合把个人或团队已有的资料库，逐步组织成一个可复用的标准数据库。你可以围绕项目来管理资源关系，而不是只靠文件夹层级或不断膨胀的 tag 系统来回忆上下文。

### 解决的问题

复杂项目经常有这些痛点：

| 痛点 | 影响 |
| --- | --- |
| 同一份文件服务多个项目 | 单一文件夹路径无法表达它在不同项目里的不同意义。 |
| tag 体系越来越繁杂 | tag 方便检索，但当项目多、资源多时，tag 往往变成另一个需要维护的抽象系统。 |
| 项目思路散落在不同地方 | 文件在 Finder，命令在 Terminal 历史，Prompt 在笔记，工作流逻辑留在记忆里。 |
| 重新进入项目成本高 | 过一段时间再回来，需要重新找路径、想依赖关系、回忆为什么这样组织。 |

MyDesk 试图降低“重新进入项目”的成本。每个 Workspace 都可以成为一个项目框架：你看到的不只是资源列表，而是文件、命令、Prompt、说明、组织框和连接关系。

### 核心思路

MyDesk 保留你的真实文件位置，只在应用中保存轻量 metadata，用可视化方式映射这些资源。

```mermaid
flowchart LR
    A["已有本地文件系统"] --> B["Global Library 全局资源库"]
    B --> C["项目 Workspace"]
    C --> D["卡片、笔记、组织框、连接线"]
    D --> E["更快找回项目思路和资源关系"]
    B --> F["Pinned 资源与 Snippet"]
    F --> C
```

这种方式处在严格文件分类和自由笔记之间：

- 文件保持原路径，不强制搬家。
- Workspace 负责表达项目里的使用语境。
- 卡片可以代表文件夹、文件、Prompt、命令或笔记。
- Organization Frame 可以表达项目阶段、模块、流程区域或思考框架。
- 连接线表达方向、依赖或工作流顺序。
- Snippet Library 保存常用 Prompt、命令和文本片段，方便复用。

### 功能框架

| 模块 | 功能 |
| --- | --- |
| Home | 快速回到最近工作区、Pinned 资源和常用 Snippet。 |
| Global Library | 统一登记可跨项目复用的文件和文件夹来源，展示资源被哪些 Workspace 使用，并支持按 Workspace 筛选。 |
| Pinned Folders / Files | 把高频文件夹和文件放在侧边栏，可展开、复制路径、进入 Finder。 |
| Snippet Library | 管理 Prompt、命令、文本片段和操作参考，可复制、编辑、删除、展开全文并复用到工作区。 |
| Workspace Canvas | 用全局资源、工作区资源、Prompt 卡片、Note 卡片和 Organization Frame 搭建项目可视化工作流。 |
| Connections | 方向箭头、蓝色流光、可拖拽控制点、锁定/解锁控制点、自动避开卡片的连接线。 |
| Layout | 自动布局、对齐、框选、缩放、卡片和组织框自由拉伸。 |
| macOS 集成 | 打开 Finder 文件夹、定位文件、复制完整路径、确认后创建 Finder alias、配合 Terminal 工作流。 |
| 数据导入导出 | 使用带 schema version 的 JSON manifest 做备份、迁移和恢复。 |
| 稳定性 | 独立 SwiftData 存储路径、启动失败提示、备份保留逻辑、功能回归清单和核心测试。 |
| Todo Board | 在 Workspace 内按 Group 管理任务，支持任务详情、Pinned、DDL 和关联资源。 |

### 适用场景

| 场景 | 例子 |
| --- | --- |
| 科研项目 | 连接论文、数据集、模拟输入、脚本、输出文件夹和解释笔记。 |
| 多项目资产复用 | 同一个数据源、参考文件夹或脚本库可以出现在多个项目画布里，而不复制真实文件。 |
| 软件开发 | 管理 repo、spec、Terminal 命令、Prompt、环境脚本和生成文件。 |
| 创作生产 | 整理参考资料、草稿、导出文件、Prompt 库和交付目录。 |
| 个人工作台 | 管理常用文件夹、文档、命令和周期性工作流。 |

### 安装 App 包

从 [GitHub Releases](https://github.com/QiushanHuang/MyDesk/releases) 下载最新版本。

推荐安装方式：

1. 下载 `MyDesk-v1.3.0-macOS.dmg`。
2. 打开 DMG。
3. 将 `MyDesk.app` 拖入 `Applications`。
4. 从 Applications 启动 MyDesk。

备用方式：

1. 下载 `MyDesk-v1.3.0-macOS.zip`。
2. 解压。
3. 将 `MyDesk.app` 移动到 `Applications`。

当前公开构建为 ad-hoc signed，尚未 notarized，因为此仓库还没有配置 Developer ID 证书。如果 macOS 首次启动时拦截，可以右键 `MyDesk.app` 选择 **Open**，或在 **System Settings > Privacy & Security** 中允许打开。

### 使用源码包

GitHub Releases 会同时提供源码包：

- `Source code (zip)`
- `Source code (tar.gz)`

如果你想查看实现、二次开发、从源码构建或运行测试，可以下载源码包。

也可以直接克隆仓库：

```bash
git clone https://github.com/QiushanHuang/MyDesk.git
cd MyDesk
```

### 从源码构建

环境要求：

- macOS 14 或更新版本
- Xcode Command Line Tools
- Swift 6 toolchain

运行测试：

```bash
swift test
```

构建并启动本地 app bundle：

```bash
./script/build_and_run.sh
```

验证 app 是否能启动：

```bash
./script/build_and_run.sh --verify
```

创建发布包：

```bash
./script/package_release.sh
```

发布产物会生成在：

```text
dist/release/MyDesk-v1.3.0-macOS/artifacts/
```

其中包括：

- `MyDesk-v1.3.0-macOS.dmg`
- `MyDesk-v1.3.0-macOS.zip`
- `RELEASE-NOTES.md`
- `INSTALL.txt`
- `SHA256SUMS.txt`

### 数据、隐私与稳定性

在 MyDesk 里删除资源时，只删除 MyDesk 的 metadata，不会删除 Finder 中的真实文件。MyDesk 保存的是资源引用、说明、布局、Snippet 和工作区关系。

当前数据规则：

- 文件和文件夹保持原始 Finder 位置。
- MyDesk 只保存轻量映射和可视化关系。
- 删除 MyDesk 资源不会删除原始文件。
- 创建 Finder alias、运行命令等外部操作需要确认。
- SwiftData 使用应用专属存储路径：

```text
~/Library/Application Support/studio.qiushan.mydesk/Stores/MyDesk.store
```

### 版本更新

当前版本：`v1.3.0`

重点更新：

- Workspace Todo Board 支持 Group、任务详情、Pinned、DDL 日期和关联资源。
- Global Library 会显示资源被哪些 Workspace 使用，并支持按 Workspace 筛选。
- 修复资源导入去重逻辑，避免全局资源和工作区资源因为相同路径被错误合并。
- Canvas 添加资源时可以从全局库、当前 Workspace 和其他 Workspace 的资源分组中选择。
- 改进导航标题、详情页布局、底部状态栏密度和 README 发布说明。
- 在 README 和更新说明中加入新的 MyDesk logo 说明。

完整更新内容见 [`docs/releases/v1.3.0.md`](docs/releases/v1.3.0.md)。

### v1.3.0 新增内容

这个版本重点解决“同一资源在多个 Workspace 中被复用时难以追踪”的问题。Global Library 现在会展示资源的 Workspace 使用关系，Canvas 上引用过的资源也会计入使用关系，并且可以按 Workspace 快速筛选。资源导入时也会区分 global scope 和 workspace scope，避免相同路径在不同语境下被错误合并。

Workspace Todo Board 也从简单任务列表扩展为更接近项目计划的工作区页面。任务可以分组、置顶、填写详情、设置 DDL，并关联到具体资源，让下一步行动和项目里的文件、Prompt、笔记、连接线保持在同一个上下文里。

### 项目结构

```text
Sources/MyDesk/       macOS SwiftUI app target
Sources/MyDeskCore/   可测试的布局、连线路由、导出、存储和工具逻辑
Tests/                XCTest 核心行为测试
docs/                 发布说明、设计文档和功能回归清单
script/               构建、启动和发布打包脚本
```

### 路线图

| 方向 | 计划 |
| --- | --- |
| 可视化工作流数据库 | 让 Workspace Canvas 更适合作为本地文件系统之上的知识关系层。 |
| 资源智能管理 | 改进预览、关系搜索、来源分类和跨工作区复用。 |
| Canvas 操作体验 | 继续完善连线路由、分组、选择、快捷键和大画布性能。 |
| 发布流程 | 从 ad-hoc signed 构建升级到 Developer ID notarized 正式发布。 |
| 导入导出 | 加强项目交换、备份和迁移能力。 |

## Maintainer

Built and maintained by **Qiushan Huang**.

- GitHub: [@QiushanHuang](https://github.com/QiushanHuang)
- Role: Product contributor, designer, and developer

## License

MyDesk is released under the [MIT License](LICENSE).
