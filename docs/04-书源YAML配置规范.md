# 04 · 书源 YAML 配置规范

> 定位：**轻量化声明式书源**——YAML/JSON 静态规则文件，程序只做「网页抓取 + 选择器提取」，
> **不执行任何自定义脚本代码**（无 JS 脚本、无 Python 求值、无正则即代码）。
> 代码对应：`lib/data/model/book_source.dart`（规则模型）、`lib/data/parser/book_source_engine.dart`（引擎）、`lib/data/parser/html_rule_parser.dart`（选择器提取）。

---

## 1. 设计原则

| 原则 | 说明 |
|---|---|
| 声明式 | 只描述「去哪里取、取哪一段」，不描述「怎么算」 |
| 白名单字段 | 仅 4 组规则：`search`（搜索）、`toc`（章节列表）、`content`（正文）、`replace`（清洗） |
| 无脚本执行 | 引擎只调用 HTTP + CSS 选择器 + 正则替换，不 `eval` 任何用户代码 |
| 可导入导出 | YAML/JSON 双格式；导出即原文，导入即校验 |
| 失败可诊断 | 校验功能对每条书源做真实抓取探测，返回命中数 |

---

## 2. 字段规范

### 2.1 顶层字段

| 字段 | 类型 | 必填 | 说明 |
|---|---|---|---|
| `bookSourceName` | string | ✅ | 书源名称（书架/搜索页展示） |
| `bookSourceUrl` | string | ✅ | 站点根地址，用于拼接相对链接，**仅允许 http/https** |
| `bookSourceGroup` | string | | 分组名，如「在线综合」 |
| `enabled` | bool | | 默认 `true` |
| `search` | map | ✅ | 搜索规则（见 2.2） |
| `toc` | map | ✅ | 章节列表规则（见 2.3） |
| `content` | map | ✅ | 正文规则（见 2.4） |

### 2.2 search 搜索规则

| 字段 | 说明 |
|---|---|
| `url` | 搜索地址模板，支持变量 `{{key}}`（关键词，URL 编码后替换）与 `{{page}}`（页码，从 1 开始） |
| `method` | `GET`（默认）或 `POST` |
| `list` | 结果列表 CSS 选择器（相对整页） |
| `title` | 书名提取规则（相对 `list` 每一项） |
| `bookUrl` | 详情页地址提取规则（相对 `list`，一般为 `::attr(href)`） |
| `cover` | 封面提取规则（可选） |
| `author` | 作者（可选） |
| `intro` | 简介（可选） |

### 2.3 toc 章节列表规则

| 字段 | 说明 |
|---|---|
| `url` | 目录页地址模板；**留空则直接用书籍详情页 `bookUrl`**；支持变量 `{{bookUrl}}` 等 |
| `list` | 章节列表 CSS 选择器 |
| `title` | 章节名（相对 `list` 每一项） |
| `chapterUrl` | 章节地址（相对 `list`） |
| `next` | （可选）章节列表翻页选择器，如 `#pager-next::attr(href)` |

### 2.4 content 正文规则

| 字段 | 说明 |
|---|---|
| `list` | 正文段 CSS 选择器，多个段落按顺序拼接（段间空行） |
| `next` | （可选）正文翻页选择器；命中则继续抓取并拼接 |
| `replace` | （可选）正则清洗数组，按顺序执行：`{pattern, replacement}` |

### 2.5 提取规则语法（相对选择器）

```
"css 选择器::text"           取元素文本（默认，::text 可省略）
"css 选择器::attr(href)"     取属性值
"sel1::text || sel2::text"   多个规则用 || 分隔，前者无命中时尝试后者
```

### 2.6 引擎安全约束

- 仅 http/https；拒绝 file://、javascript: 等协议；
- 单请求超时 15s，正文页大小上限 2 MiB，搜索结果页上限 1 MiB；
- UA 固定为移动端 Chrome，不携带用户 Cookie；
- 翻页最多 5 页（toc.next 与 content.next 均受限），防死循环；
- 所有网络异常映射为中文友好文案（见 `lib/core/app_error.dart`）。

---

## 3. 示例书源

仓库根目录 `book_sources/` 下提供两条**模板示例**（使用 example.com 占位域名，仅供演示规则格式，不指向任何真实站点）：

| 文件 | 演示能力 |
|---|---|
| `01-example-novel-site.yaml` | 完整三段规则 + 正则清洗 + GET 搜索 |
| `02-example-json-mirror.yaml` | POST 搜索 + `||` 回退选择器 + 目录翻页 + 正文翻页 |

> 真实使用时，请自行添加**合法授权**的站点规则，或从社区导入后自行校验。
> **本项目书源规则仅为网页解析规则，严禁用于小说盗版抓取与传播。**

---

## 4. YAML 与 JSON 等价

引擎同时接受 YAML 与 JSON（`yaml` 包加载 YAML，`jsonDecode` 兜底判断）。
同一条书源的 JSON 形式：

```json
{
  "bookSourceName": "示例书源",
  "bookSourceUrl": "https://www.example.com",
  "bookSourceGroup": "在线综合",
  "enabled": true,
  "search": { "url": "https://www.example.com/search?q={{key}}", "list": "ul.result li",
              "title": "h3 a::text", "bookUrl": "h3 a::attr(href)" },
  "toc":    { "list": "#chapterList li a", "title": "::text", "chapterUrl": "::attr(href)" },
  "content": { "list": "#content p", "replace": [{ "pattern": "最新章节.*", "replacement": "" }] }
}
```

## 5. 导入导出格式

- **单条导入**：一个 YAML/JSON 对象；
- **批量导入**：多文档 YAML（`---` 分隔）或 JSON 数组；
- **导出**：全部启用的书源按 `---` 分隔导出为 `.yaml` 文本；
- **校验**：导入时校验必填字段与协议；「校验」按钮对已存书源做真实搜索探测并返回命中数。
