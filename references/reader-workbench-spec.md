# 阅读工作台规范

实施或检查阅读器时使用本规范。

## 产品形态

阅读器是私人阅读与思考空间，不是营销页面，也不是通用笔记仪表盘。

- 顶部栏：书籍信息、总阅读进度、保存状态、外观设置、备份与导出；
- 左侧栏：封面和元数据、章节总数、目录、当前章节和全文搜索；
- 书页：保留原书阅读层级与图片，提供宽松的纸张空间和章末导航；
- 书页边缘：使用低调的虚线分隔、浅色横纹纸效果和低对比度“页边笔记”标签；批注卡放在这里，并连接对应原文；
- 不要增加常驻的右侧笔记面板，也不要在书页上方增加吸顶章节工具栏。

窄屏时优先保证正文可读。目录可以变为抽屉，页边批注卡可以隐藏，但对应的持久高亮不能消失。

## 书籍数据

本地使用 `public/book/book-data.json` 保存稳定的书籍元数据和有序章节。每个章节至少包含：

```json
{
  "id": "stable-chapter-id",
  "order": 0,
  "section": "正文",
  "title": "章节标题",
  "source": "EPUB/original/path.xhtml",
  "html": "<p>经过清洗的本地 HTML</p>",
  "plainText": "用于搜索的纯文本"
}
```

资源地址必须是 `/book/` 下的本地根相对路径。尽量准确保留可见文字，确保重新打开后，已保存的文字偏移仍然稳定。

## 阅读状态

使用书籍专属的本地键名和带版本号的状态结构：

```ts
type ReaderState = {
  version: 1;
  currentChapterId: string;
  highlights: Array<{
    id: string;
    chapterId: string;
    start: number;
    end: number;
    text: string;
    note: string;
    color: 'yellow' | 'rose' | 'sage';
    createdAt: string;
    updatedAt: string;
  }>;
  positions: Record<string, number>;
  settings: {
    fontSize: number;
    lineHeight: number;
    pageWidth: number;
    theme: 'paper' | 'sepia' | 'night';
  };
};
```

使用短时间防抖后自动保存。JSON 导出必须能恢复完整状态；Markdown 导出按章节归纳引用和批注。

## 高亮渲染

根据清洗后章节的可见文字计算选择范围。在 React 渲染前，按照已保存边界拆分文字节点，并用带稳定高亮 ID 的语义化 `mark.reader-highlight` 元素包裹有效范围。

不能只依赖 CSS Custom Highlight API 保存高亮。也不能先向已经挂载的 DOM 注入标记，再通过 `dangerouslySetInnerHTML` 渲染原始正文，因为 React 会抹掉前面的标记。

点击已保存高亮时，在附近打开带“取消高亮”的小工具栏。新选择与旧高亮重叠时，用新标记替换重叠旧标记，不要堆叠不可见的重复记录。

## 页边批注

非空批注应增加：

- 用户选择颜色的正文高亮；
- 原文下方的波浪线；
- 从最后一个高亮片段连接到页边卡片的浅色引线；
- 包含批注内容、原文短提示、编辑和删除操作的页边卡片。

按原文顺序排列卡片，并避免垂直重叠。连接线和卡片的几何位置必须以书页为参照，滚动时不能与原文脱离。

## 本地启动器

每个阅读器使用固定的 localhost 端口。启动器应当：

1. 检查阅读器是否已经可以访问；
2. 必要时以隐藏进程启动项目现有的开发或正式运行命令；
3. 在限定时间内等待 HTTP 请求成功；
4. 打开固定地址；
5. 启动失败时显示有用的本地错误信息，并指出日志位置。

首次交付后不要随机更换端口，因为浏览器存储与来源地址绑定。
