# 青茄阅读 (Qingqie Reader)

> 基于 [Wenku8_Flutter](https://github.com/mikufoxxx/Wenku8_Flutter)（GPL-3.0）重构的
> **本地 + 书源双引擎**小说阅读器。Flutter + Dart，Android 8.0+。

## ⚠️ 免责声明（必读）

**本项目仅用于个人学习研究。书源规则仅为网页解析规则（CSS 选择器 + 正则清洗），
不执行任何自定义脚本代码。严禁将本项目用于小说盗版抓取与传播，
由此产生的一切后果由使用者自行承担。**

## 功能

| 模块 | 能力 |
|---|---|
| 阅读核心 | TXT / EPUB 本地导入；分页 / 滚动双模式；自定义字体（系统/宋体/楷体/黑体）、字号、行间距、5 套背景（含墨水屏/夜读）；书签管理；阅读进度自动保存（防抖 500ms）；章内查找；自动滚动 |
| 书架 | 立体书架（立式斜视图 · 选中上浮 · 拖拽吸附）+ 传统列表；分类管理（在读/想读/读完…）；本地搜索（书名/作者）；导入 / 移出 / 移动分组 |
| 书源 | YAML/JSON 声明式书源；导入（文件/粘贴）/ 导出 / 启用禁用 / 排序 / 在线校验；在线搜索 → 目录预览 → 加入书架 → 在线阅读 |
| 批注 | 长按选句 → 划线（4 色下划线）/ 批注（行内「批」字块，可折叠）/ 书摘 / 复制 |
| 其他 | 书架数据备份导出 / 恢复（JSON）；阅读设置持久化；日间/夜间/跟随系统 |

## 快速开始

```bash
# 环境要求：Flutter SDK（Dart >= 3.10），Android SDK 34
flutter pub get
flutter devices          # 确认手机已识别（开启 USB 调试）
flutter run              # 真机运行
# 热重载：改代码后按 r；改类结构按 R；改 android/ 需重新 flutter run
flutter build apk        # 打包发布
```

详细开发调试与打包说明见 [docs/06-开发调试与打包.md](docs/06-开发调试与打包.md)。

## 目录结构

```
lib/
├── main.dart / app.dart            # 入口与依赖装配（provider）
├── core/                           # AppError（友好错误文案）/ Result
├── data/
│   ├── model/                      # Book/Chapter/BookSource/Bookmark/…（不可变模型）
│   ├── local/                      # sqflite 建表 + 6 个 DAO + PreferencesStore
│   ├── remote/                     # dio 封装 + TXT 编码检测（GB18030）
│   ├── parser/                     # TXT / EPUB / 书源规则引擎（CSS 选择器）
│   ├── file/                       # 章节缓存 + 本地导入服务
│   └── repository/                 # 书架 / 阅读 / 书源 / 备份 四个 Repository
└── feature/
    ├── bookshelf/                  # 书架（立体书架 + 列表）
    ├── reader/                     # 阅读器（滚动/翻页/选句批注/查找/自动滚）
    ├── source/                     # 书源管理
    ├── search/                     # 在线搜索
    └── settings/                   # 备份 / 外观 / 统计 / 关于
```

分层约束：**UI(Widget) → ViewModel → Repository → DataSource**，
所有 IO / 网络 / 数据库操作只出现在 `data/` 层。

## 文档

| 文档 | 内容 |
|---|---|
| [docs/01-代码结构分析报告.md](docs/01-代码结构分析报告.md) | 上游项目结构 / 模块 / 可复用点 / 需重构点 |
| [docs/02-增删功能方案.md](docs/02-增删功能方案.md) | 保留 / 重构 / 删除三张清单 + 迭代路线 |
| [docs/03-数据库表结构设计.md](docs/03-数据库表结构设计.md) | 六张表 DDL / 索引 / 迁移策略 |
| [docs/04-书源YAML配置规范.md](docs/04-书源YAML配置规范.md) | 书源规则规范 + 安全约束 |
| [docs/05-核心模块重构说明.md](docs/05-核心模块重构说明.md) | 重构前后对比 + Dart 代码 |
| [docs/06-开发调试与打包.md](docs/06-开发调试与打包.md) | 真机调试 / 热重载 / 打包 / CI |

## 书源示例

`book_sources/` 下两条模板示例（example.com 占位域名，演示规则格式）。
真实使用时请自行添加**合法授权**的站点规则。

## 开源协议

GPL-3.0。本项目为 Wenku8_Flutter（GPL-2.0 or later, Copyright (C) 2015 MewX）
的衍生作品，上游 LICENSE 全文保留于 `docs/licenses/Wenku8_Flutter-LICENSE.txt`，
版权与致谢见 [NOTICE](NOTICE)。新增代码以 `【新增】/【重构】` 注释标注，
移植代码以 `【原项目保留】` 注释标注。

## 发布

推送 `v*` tag 自动编译 Release APK（见 `.github/workflows/release.yml`）：

```bash
git tag v0.1.0 && git push origin v0.1.0
```
