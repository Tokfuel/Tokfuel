#!/usr/bin/env python3
"""Regenerate TestDocs catalog and coverage metrics from scenario Markdown files.

Deterministic inputs: App/TestDocs/{Domain}/*.md front matter and sections.
Outputs:
  - App/TestDocs/CATALOG.md
  - App/TestDocs/coverage.json
  - coverage block in App/TestDocs/README.md (between markers)
"""

from __future__ import annotations

import json
import re
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TESTDOCS = ROOT / "App" / "TestDocs"
DOMAINS = ["MenuBar", "Cost", "Settings", "Budget", "Cursor"]
STATUSES = ["ideation", "ready", "in-progress", "review", "done"]
MEANS = ["E2E", "UT&IT", "VRT"]

README_START = "<!-- testdocs-coverage:start -->"
README_END = "<!-- testdocs-coverage:end -->"
PR_LINK_RE = re.compile(
    r"https://github\.com/[^/\s]+/[^/\s]+/pull/\d+"
    r"|\[[^\]]*\]\(https://github\.com/[^)]+/pull/\d+\)"
    r"|#\d+"
)


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


def listed_means(text: str) -> list[str]:
    means: list[str] = []
    for mean in MEANS:
        if re.search(rf"^- \*\*{re.escape(mean)}\*\*", text, re.M):
            means.append(mean)
    return means


def has_linked_pr(text: str) -> bool:
    match = re.search(r"## 対応済みPR\n\n(.+?)(?:\n## |\Z)", text, re.S)
    if not match:
        return False
    return PR_LINK_RE.search(match.group(1)) is not None


def esc(cell: str) -> str:
    return cell.replace("|", "\\|")


def pct(numerator: int, denominator: int) -> str:
    if denominator == 0:
        return "0.0%"
    return f"{(100.0 * numerator / denominator):.1f}%"


def collect() -> list[dict[str, object]]:
    scenarios: list[dict[str, object]] = []
    for domain in DOMAINS:
        directory = TESTDOCS / domain
        if not directory.is_dir():
            continue
        for path in sorted(directory.glob("*.md")):
            text = path.read_text(encoding="utf-8")
            means = listed_means(text)
            scenarios.append(
                {
                    "id": front_matter(text, "id"),
                    "domain": domain,
                    "file": f"{domain}/{path.name}",
                    "title": front_matter(text, "title"),
                    "status": front_matter(text, "status"),
                    "means": means,
                    "means_label": ", ".join(means),
                    "summary": scenario_summary(text),
                    "has_pr": has_linked_pr(text),
                }
            )
    return scenarios


def compute_coverage(scenarios: list[dict[str, object]]) -> dict[str, object]:
    total = len(scenarios)
    by_status = Counter(str(s["status"]) for s in scenarios)
    done = by_status.get("done", 0)
    started = sum(by_status.get(st, 0) for st in ("in-progress", "review", "done"))
    filed = total - by_status.get("ideation", 0)
    with_e2e = sum(1 for s in scenarios if "E2E" in s["means"])
    with_pr = sum(1 for s in scenarios if s["has_pr"])

    by_domain: dict[str, dict[str, object]] = {}
    for domain in DOMAINS:
        domain_rows = [s for s in scenarios if s["domain"] == domain]
        domain_total = len(domain_rows)
        domain_done = sum(1 for s in domain_rows if s["status"] == "done")
        domain_status = Counter(str(s["status"]) for s in domain_rows)
        by_domain[domain] = {
            "total": domain_total,
            "done": domain_done,
            "implementation_coverage": pct(domain_done, domain_total),
            "implementation_fraction": f"{domain_done}/{domain_total}",
            "by_status": {st: domain_status.get(st, 0) for st in STATUSES},
        }

    return {
        "total": total,
        "by_status": {st: by_status.get(st, 0) for st in STATUSES},
        "rates": {
            "implementation_coverage": {
                "label": "実装カバレッジ",
                "definition": "status が done のシナリオ数 / 全シナリオ数",
                "numerator": done,
                "denominator": total,
                "fraction": f"{done}/{total}",
                "percent": pct(done, total),
            },
            "started_coverage": {
                "label": "着手カバレッジ",
                "definition": "status が in-progress / review / done のシナリオ数 / 全シナリオ数",
                "numerator": started,
                "denominator": total,
                "fraction": f"{started}/{total}",
                "percent": pct(started, total),
            },
            "filed_coverage": {
                "label": "起票完了率",
                "definition": "status が ideation 以外のシナリオ数 / 全シナリオ数",
                "numerator": filed,
                "denominator": total,
                "fraction": f"{filed}/{total}",
                "percent": pct(filed, total),
            },
            "e2e_completion_spec_rate": {
                "label": "E2E 完了条件の記載率",
                "definition": "完了条件に E2E があるシナリオ数 / 全シナリオ数",
                "numerator": with_e2e,
                "denominator": total,
                "fraction": f"{with_e2e}/{total}",
                "percent": pct(with_e2e, total),
            },
            "pr_link_rate": {
                "label": "対応済み PR 紐付け率",
                "definition": "対応済みPR に pull リンクまたは #NNNN があるシナリオ数 / 全シナリオ数",
                "numerator": with_pr,
                "denominator": total,
                "fraction": f"{with_pr}/{total}",
                "percent": pct(with_pr, total),
            },
        },
        "by_domain": by_domain,
    }


def render_coverage_section(coverage: dict[str, object]) -> list[str]:
    rates = coverage["rates"]
    lines = [
        "## カバレッジ",
        "",
        "シナリオ MD の front matter と節から、スクリプトが決定的に集計します。"
        "主指標は **実装カバレッジ**（`status: done` / 全件）です。",
        "",
        "- 生成: `python3 Scripts/generate-testdocs-catalog.py`",
        "- 機械可読: [`coverage.json`](coverage.json)",
        "",
        "### 全体",
        "",
        "| 指標 | 率 | 件数 | 定義 |",
        "| --- | ---: | ---: | --- |",
    ]
    for key in (
        "implementation_coverage",
        "started_coverage",
        "filed_coverage",
        "e2e_completion_spec_rate",
        "pr_link_rate",
    ):
        rate = rates[key]
        lines.append(
            f"| {rate['label']} | {rate['percent']} | `{rate['fraction']}` | {rate['definition']} |"
        )

    lines.extend(
        [
            "",
            "### ドメイン別の実装カバレッジ",
            "",
            "| Domain | 実装カバレッジ | done / 全件 |",
            "| --- | ---: | ---: |",
        ]
    )
    for domain in DOMAINS:
        row = coverage["by_domain"][domain]
        lines.append(
            f"| {domain} | {row['implementation_coverage']} | `{row['implementation_fraction']}` |"
        )

    lines.extend(
        [
            "",
            "### status 内訳",
            "",
            "| status | 件数 |",
            "| --- | ---: |",
        ]
    )
    for status in STATUSES:
        lines.append(f"| `{status}` | {coverage['by_status'][status]} |")
    lines.append(f"| **合計** | **{coverage['total']}** |")
    lines.append("")
    return lines


def render_catalog(scenarios: list[dict[str, object]], coverage: dict[str, object]) -> str:
    by_domain: dict[str, list[dict[str, object]]] = defaultdict(list)
    for scenario in scenarios:
        by_domain[str(scenario["domain"])].append(scenario)

    lines: list[str] = [
        "# シナリオ一覧（網羅確認用）",
        "",
        "TestDocs の全シナリオをドメイン別に並べた索引です。網羅の抜け漏れ確認に使います。",
        "個別シナリオの正本は各 MD、運用規約は [`AGENTS.md`](AGENTS.md)、手段の優先は [`coverage-strategy.md`](coverage-strategy.md) です。",
        "",
        "このファイルと [`coverage.json`](coverage.json) はシナリオ MD から生成します。"
        "シナリオを足したら同じ手順で更新してください。",
        "",
        "```bash",
        "python3 Scripts/generate-testdocs-catalog.py",
        "```",
        "",
    ]
    lines.extend(render_coverage_section(coverage))
    lines.extend(
        [
            "## 件数",
            "",
            "| Domain | 件数 |",
            "| --- | ---: |",
        ]
    )
    for domain in DOMAINS:
        lines.append(f"| {domain} | {len(by_domain[domain])} |")
    lines.append(f"| **合計** | **{coverage['total']}** |")
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
        rows = by_domain[domain]
        lines.append(f"## {domain}（{len(rows)}）")
        lines.append("")
        lines.append("| ID | title | status | 完了条件 | シナリオ要約 |")
        lines.append("| --- | --- | --- | --- | --- |")
        for row in rows:
            lines.append(
                "| "
                + " | ".join(
                    [
                        f"[`{esc(str(row['id']))}`]({row['file']})",
                        esc(str(row["title"])),
                        esc(str(row["status"])),
                        esc(str(row["means_label"])),
                        esc(str(row["summary"])),
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


def render_readme_coverage_block(coverage: dict[str, object]) -> str:
    impl = coverage["rates"]["implementation_coverage"]
    started = coverage["rates"]["started_coverage"]
    filed = coverage["rates"]["filed_coverage"]
    e2e = coverage["rates"]["e2e_completion_spec_rate"]
    lines = [
        README_START,
        "## カバレッジ",
        "",
        f"主指標の **実装カバレッジ** はいま **{impl['percent']}**（`{impl['fraction']}`）です。"
        f"着手カバレッジは {started['percent']}（`{started['fraction']}`）、"
        f"起票完了率は {filed['percent']}（`{filed['fraction']}`）、"
        f"E2E 完了条件の記載率は {e2e['percent']}（`{e2e['fraction']}`）です。",
        "",
        "定義とドメイン別内訳は [`CATALOG.md`](CATALOG.md) の「カバレッジ」節、"
        "機械可読な値は [`coverage.json`](coverage.json) を見てください。",
        "",
        "```bash",
        "python3 Scripts/generate-testdocs-catalog.py",
        "```",
        "",
        README_END,
    ]
    return "\n".join(lines) + "\n"


def update_readme(coverage: dict[str, object]) -> None:
    readme_path = TESTDOCS / "README.md"
    text = readme_path.read_text(encoding="utf-8")
    block = render_readme_coverage_block(coverage)
    pattern = re.compile(
        re.escape(README_START) + r".*?" + re.escape(README_END) + r"\n?",
        re.S,
    )
    if pattern.search(text):
        text = pattern.sub(block, text, count=1)
    else:
        anchor = "## シナリオ索引"
        if anchor in text:
            text = text.replace(anchor, block + "\n" + anchor, 1)
        elif "## 実行コードの置き場" in text:
            text = text.replace(
                "## 実行コードの置き場",
                block + "\n## 実行コードの置き場",
                1,
            )
        else:
            text = text.rstrip() + "\n\n" + block
    if "coverage.json" not in text:
        text = text.replace(
            "  CATALOG.md\n",
            "  CATALOG.md\n  coverage.json\n",
            1,
        )
    readme_path.write_text(text, encoding="utf-8")


def main() -> None:
    scenarios = collect()
    coverage = compute_coverage(scenarios)

    catalog_path = TESTDOCS / "CATALOG.md"
    catalog_path.write_text(render_catalog(scenarios, coverage), encoding="utf-8")

    coverage_path = TESTDOCS / "coverage.json"
    coverage_path.write_text(
        json.dumps(coverage, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )

    update_readme(coverage)

    impl = coverage["rates"]["implementation_coverage"]
    print(
        f"wrote {catalog_path.relative_to(ROOT)}, "
        f"{coverage_path.relative_to(ROOT)}; "
        f"implementation_coverage={impl['percent']} ({impl['fraction']})"
    )


if __name__ == "__main__":
    main()
