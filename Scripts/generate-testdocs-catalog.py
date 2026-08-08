#!/usr/bin/env python3
"""Regenerate App/TestDocs/CATALOG.md from scenario Markdown files."""

from __future__ import annotations

import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TESTDOCS = ROOT / "App" / "TestDocs"
DOMAINS = ["MenuBar", "Cost", "Settings", "Budget", "Cursor"]


def front_matter(text: str, key: str) -> str:
    match = re.search(rf"^{re.escape(key)}:\s*(.+)$", text, re.M)
    return match.group(1).strip() if match else ""


def scenario_summary(text: str) -> str:
    match = re.search(r"## シナリオ\n\n(.+?)(?:\n\n|\n## )", text, re.S)
    if not match:
        return ""
    summary = re.sub(r"\s+", " ", match.group(1).strip())
    if len(summary) > 80:
        return summary[:77] + "…"
    return summary


def completion_means(text: str) -> str:
    means = []
    for mean in ("E2E", "UT&IT", "VRT"):
        if re.search(rf"^- \*\*{re.escape(mean)}\*\*", text, re.M):
            means.append(mean)
    return ", ".join(means)


def esc(cell: str) -> str:
    return cell.replace("|", "\\|")


def collect() -> dict[str, list[dict[str, str]]]:
    rows: dict[str, list[dict[str, str]]] = defaultdict(list)
    for domain in DOMAINS:
        directory = TESTDOCS / domain
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.md")):
            text = path.read_text(encoding="utf-8")
            rows[domain].append(
                {
                    "id": front_matter(text, "id"),
                    "file": f"{domain}/{path.name}",
                    "title": front_matter(text, "title"),
                    "status": front_matter(text, "status"),
                    "means": completion_means(text),
                    "summary": scenario_summary(text),
                }
            )
    return rows


def render(rows: dict[str, list[dict[str, str]]]) -> str:
    total = sum(len(rows[domain]) for domain in DOMAINS)
    lines: list[str] = [
        "# シナリオ一覧（網羅確認用）",
        "",
        "TestDocs の全シナリオをドメイン別に並べた索引です。網羅の抜け漏れ確認に使います。",
        "個別シナリオの正本は各 MD、運用規約は [`AGENTS.md`](AGENTS.md)、手段の優先は [`coverage-strategy.md`](coverage-strategy.md) です。",
        "",
        "このファイルはシナリオ MD から生成します。シナリオを足したら同じ手順で更新してください。",
        "",
        "```bash",
        "python3 Scripts/generate-testdocs-catalog.py",
        "```",
        "",
        "## 件数",
        "",
        "| Domain | 件数 |",
        "| --- | ---: |",
    ]
    for domain in DOMAINS:
        lines.append(f"| {domain} | {len(rows[domain])} |")
    lines.append(f"| **合計** | **{total}** |")
    lines.extend(
        [
            "",
            "## status の見方",
            "",
            "| status | 意味 |",
            "| --- | --- |",
            "| `ideation` | 壁打ち中 |",
            "| `ready` | 実装着手可 |",
            "| `in-progress` | 実装中 |",
            "| `review` | レビュー中 |",
            "| `done` | 実装完了 |",
            "",
        ]
    )

    for domain in DOMAINS:
        lines.append(f"## {domain}（{len(rows[domain])}）")
        lines.append("")
        lines.append("| ID | title | status | 完了条件 | シナリオ要約 |")
        lines.append("| --- | --- | --- | --- | --- |")
        for row in rows[domain]:
            lines.append(
                "| "
                + " | ".join(
                    [
                        f"[`{esc(row['id'])}`]({row['file']})",
                        esc(row["title"]),
                        esc(row["status"]),
                        esc(row["means"]),
                        esc(row["summary"]),
                    ]
                )
                + " |"
            )
        lines.append("")

    lines.extend(
        [
            "## 面ごとの確認チェック",
            "",
            "実装の UI 面と、対応するシナリオ群です。空欄や薄いところがあれば起票漏れの候補です。",
            "",
            "| 面 | 想定シナリオ |",
            "| --- | --- |",
            "| メニューバー開閉 | `MenuBar-01` … `03`, `33` |",
            "| ホームヒーロー / フッター | `MenuBar-04` … `08` |",
            "| メニューバー指標 / 表現 / ゲージ | `MenuBar-09` … `23`, `Settings-12` … `19` |",
            "| アップデート導線 | `MenuBar-29` … `32` |",
            "| 推移グラフ / 期間 | `Cost-01`, `02`, `07` … `11` |",
            "| 読み込み / エラー / CSV | `Cost-04` … `06`, `24` … `26` |",
            "| モデル別 / セッション / ヒント | `Cost-03`, `16` … `23` |",
            "| 設定一般 / ソース / 外観 | `Settings-01` … `11`, `36` |",
            "| 設定の予算 / プライバシー / 詳細 | `Settings-20` … `35` |",
            "| 予算メーター / 通知 / アラート | `Budget-01` … `18` |",
            "| Cursor 表示 / 劣化 / ヒント | `Cursor-01` … `18` |",
            "",
            "## 意図的な対象外",
            "",
            "- Cursor included 枠の専用 UI（未実装）",
            "- DEBUG 専用のデバッグ節",
            "- 利用データを Mac の外へ出す検証",
            "- Site（`Site/`）",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> None:
    rows = collect()
    output = TESTDOCS / "CATALOG.md"
    output.write_text(render(rows), encoding="utf-8")
    total = sum(len(rows[domain]) for domain in DOMAINS)
    print(f"wrote {output.relative_to(ROOT)} ({total} scenarios)")


if __name__ == "__main__":
    main()
