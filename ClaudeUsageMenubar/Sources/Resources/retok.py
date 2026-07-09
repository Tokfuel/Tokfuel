#!/usr/bin/env python3
"""retok — Return of Token

Analyze AI coding agent transcripts — Claude Code (~/.claude/projects) and
OpenAI Codex CLI (~/.codex/sessions) — to measure token efficiency, estimate
cost, and suggest improvements.

Usage:
  retok [--days N] [--project NAME] [--provider claude|codex] [--top N]
        [--json] [--lang CODE] [--dirs DIR ...] [--codex-dirs DIR ...]
"""

import argparse
import json
import os
import sys
import textwrap
import unicodedata
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from pathlib import Path

# Claude pricing per MTok (USD). Cache write: 1.25x (5m TTL) / 2x (1h TTL) of
# input. Cache read: 0.1x of input. Source: platform.claude.com (2026-06).
PRICING = {
    "fable":  {"input": 10.0, "output": 50.0},
    "mythos": {"input": 10.0, "output": 50.0},
    "opus":   {"input": 5.0,  "output": 25.0},
    "sonnet": {"input": 3.0,  "output": 15.0},
    "haiku":  {"input": 1.0,  "output": 5.0},
}
CACHE_WRITE_5M = 1.25
CACHE_WRITE_1H = 2.0
CACHE_READ = 0.1

# OpenAI (Codex) pricing per MTok (USD), longest-prefix match. Cached input:
# 0.1x of input, no cache-write premium. Source: developers.openai.com (2026-07).
OPENAI_PRICING = [
    ("gpt-5.5",           {"input": 5.0,  "output": 30.0}),
    ("gpt-5.4",           {"input": 2.5,  "output": 15.0}),
    ("gpt-5.3",           {"input": 1.75, "output": 14.0}),
    ("gpt-5.2",           {"input": 1.75, "output": 14.0}),
    ("gpt-5.1-codex-max", {"input": 1.25, "output": 10.0}),
    ("gpt-5.1",           {"input": 1.25, "output": 10.0}),
    ("gpt-5-mini",        {"input": 0.25, "output": 2.0}),
    ("gpt-5-nano",        {"input": 0.05, "output": 0.4}),
    ("gpt-5",             {"input": 1.25, "output": 10.0}),
]
OPENAI_CACHE_READ = 0.1

CACHE_TTL_SECONDS = 5 * 60  # ephemeral 5m cache TTL
LARGE_CONTEXT_THRESHOLD = 120_000  # tokens; suggest /clear or /compact beyond this
SEARCH_TOOLS = {"Read", "Grep", "Glob", "Explore"}

C = {
    "reset": "\033[0m", "bold": "\033[1m", "dim": "\033[2m",
    "red": "\033[31m", "green": "\033[32m", "yellow": "\033[33m",
    "blue": "\033[34m", "magenta": "\033[35m", "cyan": "\033[36m",
}

# ---------------------------------------------------------------------------
# i18n — English is embedded as the source of truth; other languages live in
# locales/<tag>.json next to this script and override these keys.
# ---------------------------------------------------------------------------
EN = {
    "title": "retok — Token Efficiency Report (last {days} days / {files} files)",
    "overview": "Overview",
    "provider_split": "Claude Code / Codex",
    "by_model": "By model",
    "by_project": "By project (top by cost)",
    "top_sessions": "Most expensive sessions",
    "daily_cost": "Daily cost",
    "advice": "Recommendations",
    "estimated_cost": "Estimated cost",
    "sessions_prompts": "Sessions / prompts",
    "api_requests": "API requests",
    "output_tokens": "Output tokens",
    "input_tokens": "Input tokens (uncached)",
    "cache_rw": "Cache read / write",
    "cache_hit_rate": "Cache hit rate",
    "cost_per_prompt": "Cost per prompt",
    "subagent_cost": "Subagent share",
    "no_transcripts": "No transcripts found in the selected period.",

    "adv_cache_hit_title": "Cache hit rate is low ({rate})",
    "adv_cache_hit_detail":
        "Cache reads cost one tenth of regular input. The usual cause of a low "
        "hit rate is response gaps longer than the cache TTL. Batch your "
        "instructions into a single message instead of trickling them in, and "
        "the hit rate goes up.",

    "adv_ttl_title": "Re-caching after cache TTL expiry: ~{mtok}M tokens (${cost})",
    "adv_ttl_detail":
        "Returning to a session left idle beyond the cache TTL (usually 1 hour) "
        "re-caches the entire context at twice the input rate. Before resuming "
        "after a break, run /compact to shrink the context — or, for a new "
        "task, start fresh with /clear or a new session.",

    "adv_fat_ctx_title": "{count} sessions exceeded {limit}k tokens of context (max {max}k)",
    "adv_fat_ctx_detail":
        "The larger the context, the more every single request pays in cache "
        "reads and rebuilds. Run /clear between tasks, and /compact when you "
        "need continuity within a long-running one.",

    "adv_delegate_title": "Heavy exploration on the main thread (Read/Grep/Glob = {pct} of tool calls)",
    "adv_delegate_detail":
        "Bulk file exploration inflates the main context and taxes every "
        "subsequent request. Delegate searches to subagents (Task/Explore) so "
        "intermediate results never enter the main context — ask for the "
        "conclusion, not the file dumps.",

    "adv_retry_title": "Repeated identical commands detected ({count} cases, up to {max} times)",
    "adv_retry_detail":
        "Example: `{cmd}` — retrying the same failing build or test burns "
        "tokens. After two failed fixes, change the approach and ask for a "
        "diagnosis of the root cause first.",

    "adv_interrupt_title": "Frequent user interruptions ({count} out of {prompts} prompts)",
    "adv_interrupt_detail":
        "Frequent interruptions are a sign the work is drifting from your "
        "intent. Include the scope, non-goals, and completion criteria in the "
        "first prompt, and use Plan Mode for uncertain tasks.",

    "adv_model_mix_title": "{count} tiny sessions on premium models (${cost})",
    "adv_model_mix_detail":
        "One-shot questions and quick checks are usually fine on Haiku or "
        "Sonnet. Switch with /model, or keep a separate profile for light "
        "tasks.",

    "adv_ok_title": "No major inefficiencies detected",
    "adv_ok_detail":
        "Cache hit rate, context sizes, and tool usage distribution all look "
        "healthy. Keep it up.",
}

CJK_LANGS = ("ja", "zh")


def resolve_lang(cli_lang):
    raw = (cli_lang or os.environ.get("RETOK_LANG")
           or os.environ.get("LC_ALL") or os.environ.get("LC_MESSAGES")
           or os.environ.get("LANG") or "en")
    tag = raw.split(".")[0].replace("_", "-")
    parts = tag.split("-")
    base = parts[0].lower()
    norm = base if len(parts) == 1 else f"{base}-{parts[1].upper()}"

    locales_dir = Path(__file__).resolve().parent / "locales"
    available = {p.stem for p in locales_dir.glob("*.json")} if locales_dir.is_dir() else set()
    if norm in available:
        return norm
    if base in available:
        return base
    for alias in sorted(available):
        if alias.lower().startswith(base + "-"):
            return alias
    return "en"


def load_messages(lang):
    msgs = dict(EN)
    if lang != "en":
        path = Path(__file__).resolve().parent / "locales" / f"{lang}.json"
        try:
            with open(path, encoding="utf-8") as fh:
                msgs.update(json.load(fh))
        except (OSError, json.JSONDecodeError):
            pass
    return msgs


def dwidth(s):
    return sum(2 if unicodedata.east_asian_width(ch) in "WF" else 1 for ch in s)


def pad(s, width):
    return s + " " * max(0, width - dwidth(s))


def wrap_text(text, lang, width=66):
    if lang.split("-")[0] in CJK_LANGS:
        lines, line, w = [], "", 0
        for ch in text:
            line += ch
            w += 2 if unicodedata.east_asian_width(ch) in "WF" else 1
            if w >= width and ch in "。、，,.;: ":
                lines.append(line)
                line, w = "", 0
        if line:
            lines.append(line)
        return lines
    return textwrap.wrap(text, width)


def color(text, *names, enabled=True):
    if not enabled:
        return text
    return "".join(C[n] for n in names) + str(text) + C["reset"]


def model_family(model_id):
    if not model_id:
        return None
    for key in PRICING:
        if key in model_id:
            return key
    return None


def openai_price(model_id):
    if not model_id:
        return None
    for prefix, price in OPENAI_PRICING:
        if model_id.startswith(prefix):
            return price
    return None


def codex_cost(model_id, inp_total, cached, out):
    """Cost of one Codex request. `cached` is a subset of `inp_total`."""
    p = openai_price(model_id)
    if p is None:
        return 0.0
    return (
        (inp_total - cached) * p["input"]
        + cached * p["input"] * OPENAI_CACHE_READ
        + out * p["output"]
    ) / 1_000_000


def entry_cost(model_id, usage):
    fam = model_family(model_id)
    if fam is None:
        return 0.0
    p = PRICING[fam]
    inp = usage.get("input_tokens", 0) or 0
    out = usage.get("output_tokens", 0) or 0
    read = usage.get("cache_read_input_tokens", 0) or 0
    write = usage.get("cache_creation_input_tokens", 0) or 0
    cc = usage.get("cache_creation") or {}
    w1h = cc.get("ephemeral_1h_input_tokens", 0) or 0
    w5m = cc.get("ephemeral_5m_input_tokens", 0) or 0
    if w1h + w5m == 0:
        w5m = write  # breakdown missing; assume 5m TTL
    cost = (
        inp * p["input"]
        + out * p["output"]
        + read * p["input"] * CACHE_READ
        + w5m * p["input"] * CACHE_WRITE_5M
        + w1h * p["input"] * CACHE_WRITE_1H
    )
    return cost / 1_000_000


def parse_ts(ts):
    if not ts:
        return None
    try:
        return datetime.fromisoformat(ts.replace("Z", "+00:00"))
    except ValueError:
        return None


def is_user_prompt(entry):
    """True if the entry is an actual human prompt (not a tool result / meta)."""
    if entry.get("isSidechain"):
        return False
    msg = entry.get("message") or {}
    if msg.get("role") != "user":
        return False
    content = msg.get("content")
    if isinstance(content, str):
        text = content
    elif isinstance(content, list):
        texts = [b.get("text", "") for b in content
                 if isinstance(b, dict) and b.get("type") == "text"]
        if not texts:
            return False  # tool_result-only message
        text = "\n".join(texts)
    else:
        return False
    if not text.strip():
        return False
    if text.startswith("[Request interrupted"):
        return False
    if text.startswith("<local-command") or text.startswith("Caveat:"):
        return False
    return True


def is_interruption(entry):
    msg = entry.get("message") or {}
    if msg.get("role") != "user":
        return False
    content = msg.get("content")
    if isinstance(content, str):
        return content.startswith("[Request interrupted")
    if isinstance(content, list):
        return any(isinstance(b, dict) and b.get("type") == "text"
                   and str(b.get("text", "")).startswith("[Request interrupted")
                   for b in content)
    return False


def new_session():
    return {
        "provider": None,
        "project": None,
        "first_ts": None,
        "last_ts": None,
        "prompts": 0,
        "interruptions": 0,
        "requests": 0,
        "input": 0, "output": 0, "cache_read": 0, "cache_write": 0,
        "sidechain_output": 0, "sidechain_cost": 0.0,
        "cost": 0.0,
        "max_context": 0,
        "expired_cache_write": 0,  # cache writes right after a >TTL gap
        "expired_cache_cost": 0.0,
        "tools": defaultdict(int),          # main-thread tool_use counts
        "sidechain_tools": defaultdict(int),
        "bash_commands": defaultdict(int),  # repeated-command detection
        "models": set(),
        "prev_req_ts": None,
    }


def scan(dirs, codex_dirs, since, project_filter, provider_filter):
    sessions = defaultdict(new_session)
    seen_msg_ids = set()
    daily = defaultdict(lambda: {"cost": 0.0, "output": 0})
    per_model = defaultdict(lambda: {"cost": 0.0, "input": 0, "output": 0,
                                     "cache_read": 0, "cache_write": 0,
                                     "requests": 0})
    files_scanned = 0

    # Main transcripts: <project>/<session>.jsonl
    # Subagent transcripts: <project>/<session>/subagents/agent-*.jsonl
    jsonl_files = []
    if provider_filter != "codex":
        for d in dirs:
            root = Path(d).expanduser()
            if not root.is_dir():
                continue
            jsonl_files.extend((p, False) for p in root.glob("*/*.jsonl"))
            jsonl_files.extend((p, True) for p in root.glob("*/*/subagents/*.jsonl"))

    since_epoch = since.timestamp()
    for path, is_subagent_file in jsonl_files:
        try:
            if path.stat().st_mtime < since_epoch:
                continue
        except OSError:
            continue
        files_scanned += 1
        try:
            fh = open(path, encoding="utf-8")
        except OSError:
            continue
        with fh:
            for line in fh:
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                etype = entry.get("type")
                if etype not in ("assistant", "user"):
                    continue
                ts = parse_ts(entry.get("timestamp"))
                if ts is None or ts < since:
                    continue
                if is_subagent_file:
                    # Attribute to the parent session (directory above subagents/)
                    sid = path.parent.parent.name
                else:
                    sid = entry.get("sessionId") or path.stem
                s = sessions[sid]
                s["provider"] = "claude"
                if s["project"] is None:
                    cwd = entry.get("cwd")
                    s["project"] = Path(cwd).name if cwd else path.parent.name
                if s["first_ts"] is None or ts < s["first_ts"]:
                    s["first_ts"] = ts
                if s["last_ts"] is None or ts > s["last_ts"]:
                    s["last_ts"] = ts

                if etype == "user":
                    if is_subagent_file:
                        pass  # subagent "user" turns are orchestrator prompts
                    elif is_user_prompt(entry):
                        s["prompts"] += 1
                    elif is_interruption(entry):
                        s["interruptions"] += 1
                    continue

                # assistant entry
                msg = entry.get("message") or {}
                usage = msg.get("usage")
                mid = msg.get("id")
                sidechain = is_subagent_file or bool(entry.get("isSidechain"))

                # Count tool_use blocks (once per message id + block id)
                content = msg.get("content")
                if isinstance(content, list):
                    for block in content:
                        if not (isinstance(block, dict) and block.get("type") == "tool_use"):
                            continue
                        bkey = (mid, block.get("id"))
                        if bkey in seen_msg_ids:
                            continue
                        seen_msg_ids.add(bkey)
                        name = block.get("name", "?")
                        bucket = s["sidechain_tools"] if sidechain else s["tools"]
                        bucket[name] += 1
                        if name == "Bash" and not sidechain:
                            cmd = (block.get("input") or {}).get("command", "")
                            if cmd:
                                s["bash_commands"][cmd.strip()] += 1

                if not usage or not mid:
                    continue
                # One API response is streamed into multiple entries sharing
                # message.id with identical usage — count it once, globally
                # (also dedupes files mirrored across scan roots).
                if mid in seen_msg_ids:
                    continue
                seen_msg_ids.add(mid)

                model = msg.get("model") or ""
                if model == "<synthetic>":
                    continue
                inp = usage.get("input_tokens", 0) or 0
                out = usage.get("output_tokens", 0) or 0
                read = usage.get("cache_read_input_tokens", 0) or 0
                write = usage.get("cache_creation_input_tokens", 0) or 0
                cost = entry_cost(model, usage)
                context = inp + read + write

                s["requests"] += 1
                s["input"] += inp
                s["output"] += out
                s["cache_read"] += read
                s["cache_write"] += write
                s["cost"] += cost
                s["models"].add(model)
                if sidechain:
                    s["sidechain_output"] += out
                    s["sidechain_cost"] += cost
                else:
                    s["max_context"] = max(s["max_context"], context)

                    # Cache-TTL expiry heuristic (main thread only): a large
                    # cache write right after a gap longer than the write's
                    # TTL means the expired prefix was re-cached from scratch.
                    cc = usage.get("cache_creation") or {}
                    is_1h = (cc.get("ephemeral_1h_input_tokens", 0) or 0) > \
                            (cc.get("ephemeral_5m_input_tokens", 0) or 0)
                    ttl = 3600 if is_1h else CACHE_TTL_SECONDS
                    prev = s["prev_req_ts"]
                    if (prev is not None and write > 20_000
                            and write > context * 0.5
                            and (ts - prev).total_seconds() > ttl):
                        s["expired_cache_write"] += write
                        fam = model_family(model)
                        if fam:
                            mult = CACHE_WRITE_1H if is_1h else CACHE_WRITE_5M
                            s["expired_cache_cost"] += (
                                write * PRICING[fam]["input"] * mult / 1e6)
                    s["prev_req_ts"] = ts

                day = ts.astimezone().strftime("%Y-%m-%d")
                daily[day]["cost"] += cost
                daily[day]["output"] += out
                m = per_model[model]
                m["cost"] += cost
                m["input"] += inp
                m["output"] += out
                m["cache_read"] += read
                m["cache_write"] += write
                m["requests"] += 1

    if provider_filter != "claude":
        files_scanned += scan_codex(codex_dirs, since, sessions, seen_msg_ids,
                                    daily, per_model)

    if project_filter:
        sessions = {k: v for k, v in sessions.items()
                    if v["project"] and project_filter.lower() in v["project"].lower()}
    # Drop sessions with no API traffic
    sessions = {k: v for k, v in sessions.items() if v["requests"] > 0}
    return sessions, daily, per_model, files_scanned


def scan_codex(codex_dirs, since, sessions, seen_ids, daily, per_model):
    """Scan OpenAI Codex CLI rollout files (~/.codex/sessions/YYYY/MM/DD/)."""
    files_scanned = 0
    since_epoch = since.timestamp()
    for d in codex_dirs:
        root = Path(d).expanduser()
        if not root.is_dir():
            continue
        for path in root.glob("*/*/*/rollout-*.jsonl"):
            try:
                if path.stat().st_mtime < since_epoch:
                    continue
            except OSError:
                continue
            files_scanned += 1
            try:
                fh = open(path, encoding="utf-8")
            except OSError:
                continue
            sid = path.stem
            model = None
            with fh:
                for line in fh:
                    try:
                        entry = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    etype = entry.get("type")
                    payload = entry.get("payload") or {}
                    ts = parse_ts(entry.get("timestamp"))

                    if etype == "session_meta":
                        sid = payload.get("session_id") or sid
                        s = sessions[sid]
                        s["provider"] = "codex"
                        cwd = payload.get("cwd")
                        if cwd:
                            s["project"] = Path(cwd).name
                        continue

                    if etype == "turn_context":
                        model = payload.get("model") or model
                        continue

                    if ts is None or ts < since:
                        continue
                    s = sessions[sid]
                    s["provider"] = "codex"
                    if s["first_ts"] is None or ts < s["first_ts"]:
                        s["first_ts"] = ts
                    if s["last_ts"] is None or ts > s["last_ts"]:
                        s["last_ts"] = ts

                    ptype = payload.get("type")
                    if etype == "event_msg" and ptype == "user_message":
                        s["prompts"] += 1
                        continue

                    if etype == "response_item" and ptype == "function_call":
                        name = payload.get("name", "?")
                        s["tools"][name] += 1
                        if name in ("exec_command", "shell", "local_shell"):
                            try:
                                cmd = json.loads(payload.get("arguments") or "{}").get("cmd", "")
                            except (json.JSONDecodeError, AttributeError):
                                cmd = ""
                            if cmd:
                                s["bash_commands"][str(cmd).strip()] += 1
                        continue

                    if etype != "event_msg" or ptype != "token_count":
                        continue
                    info = payload.get("info")
                    if not info:
                        continue  # rate-limit-only heartbeat
                    last = info.get("last_token_usage") or {}
                    inp_total = last.get("input_tokens", 0) or 0
                    cached = last.get("cached_input_tokens", 0) or 0
                    out = last.get("output_tokens", 0) or 0
                    if inp_total + out == 0:
                        continue
                    # Resumed rollouts can replay history; dedupe on the
                    # cumulative counter which is unique per request.
                    total = (info.get("total_token_usage") or {}).get("total_tokens", 0)
                    key = (sid, entry.get("timestamp"), total)
                    if key in seen_ids:
                        continue
                    seen_ids.add(key)

                    mdl = model or "gpt-5"
                    cost = codex_cost(mdl, inp_total, cached, out)
                    s["requests"] += 1
                    s["input"] += inp_total - cached
                    s["cache_read"] += cached
                    s["output"] += out
                    s["cost"] += cost
                    s["models"].add(mdl)
                    s["max_context"] = max(s["max_context"], inp_total)

                    day = ts.astimezone().strftime("%Y-%m-%d")
                    daily[day]["cost"] += cost
                    daily[day]["output"] += out
                    m = per_model[mdl]
                    m["cost"] += cost
                    m["input"] += inp_total - cached
                    m["output"] += out
                    m["cache_read"] += cached
                    m["requests"] += 1
    return files_scanned


def build_advice(sessions, totals):
    """Return [(severity, message_key_prefix, params_dict)] plus hit rate."""
    advice = []

    # 1. Cache hit rate
    denom = totals["input"] + totals["cache_read"] + totals["cache_write"]
    hit = totals["cache_read"] / denom if denom else 0.0
    if hit < 0.75 and denom > 1_000_000:
        advice.append(("high", "adv_cache_hit", {"rate": f"{hit:.0%}"}))

    # 2. Cache TTL expiry cost
    exp_cost = sum(s["expired_cache_cost"] for s in sessions.values())
    exp_tokens = sum(s["expired_cache_write"] for s in sessions.values())
    if exp_cost > 1.0:
        advice.append(("high", "adv_ttl",
                       {"mtok": f"{exp_tokens/1e6:.1f}", "cost": f"{exp_cost:.2f}"}))

    # 3. Oversized session contexts
    fat = [s for s in sessions.values()
           if s["max_context"] > LARGE_CONTEXT_THRESHOLD and s["prompts"] >= 3]
    if fat:
        worst = max(s["max_context"] for s in fat)
        advice.append(("high", "adv_fat_ctx",
                       {"count": len(fat),
                        "limit": LARGE_CONTEXT_THRESHOLD // 1000,
                        "max": worst // 1000}))

    # 4. Delegation: search-heavy main thread with little subagent use
    #    (Claude only — Codex has no equivalent subagent transcripts)
    claude_sessions = [s for s in sessions.values() if s["provider"] == "claude"]
    main_tool_total = sum(sum(s["tools"].values()) for s in claude_sessions)
    search_calls = sum(sum(v for k, v in s["tools"].items() if k in SEARCH_TOOLS)
                       for s in claude_sessions)
    agent_calls = sum(s["tools"].get("Agent", 0) + s["tools"].get("Task", 0)
                      for s in claude_sessions)
    if (main_tool_total > 200 and search_calls / main_tool_total > 0.45
            and agent_calls < main_tool_total * 0.02):
        advice.append(("medium", "adv_delegate",
                       {"pct": f"{search_calls/main_tool_total:.0%}"}))

    # 5. Repeated identical Bash commands (retry loops)
    loops = []
    for s in sessions.values():
        for cmd, n in s["bash_commands"].items():
            if n >= 5:
                loops.append((cmd, n))
    if loops:
        worst_cmd, worst_n = max(loops, key=lambda x: x[1])
        advice.append(("medium", "adv_retry",
                       {"count": len(loops), "max": worst_n,
                        "cmd": worst_cmd[:80]}))

    # 6. Frequent interruptions
    total_prompts = sum(s["prompts"] for s in sessions.values())
    total_intr = sum(s["interruptions"] for s in sessions.values())
    if total_prompts > 30 and total_intr > total_prompts * 0.12:
        advice.append(("medium", "adv_interrupt",
                       {"count": total_intr, "prompts": total_prompts}))

    # 7. Model mix: expensive model on tiny sessions
    tiny_expensive = [
        s for s in sessions.values()
        if s["cost"] > 0 and s["prompts"] <= 2 and s["output"] < 2000
        and any(model_family(m) in ("fable", "opus") for m in s["models"])
    ]
    if len(tiny_expensive) >= 10:
        waste = sum(s["cost"] for s in tiny_expensive)
        advice.append(("low", "adv_model_mix",
                       {"count": len(tiny_expensive), "cost": f"{waste:.2f}"}))

    if not advice:
        advice.append(("info", "adv_ok", {}))
    return advice, hit


def fmt_tokens(n):
    if n >= 1_000_000_000:
        return f"{n/1e9:.2f}B"
    if n >= 1_000_000:
        return f"{n/1e6:.1f}M"
    if n >= 1_000:
        return f"{n/1e3:.1f}k"
    return str(n)


def render(sessions, daily, per_model, files_scanned, args, lang, msgs, use_color):
    def c(text, *names):
        return color(text, *names, enabled=use_color)

    def t(key, **params):
        return msgs.get(key, EN.get(key, key)).format(**params)

    totals = {
        "cost": sum(s["cost"] for s in sessions.values()),
        "input": sum(s["input"] for s in sessions.values()),
        "output": sum(s["output"] for s in sessions.values()),
        "cache_read": sum(s["cache_read"] for s in sessions.values()),
        "cache_write": sum(s["cache_write"] for s in sessions.values()),
        "prompts": sum(s["prompts"] for s in sessions.values()),
        "requests": sum(s["requests"] for s in sessions.values()),
        "sidechain_cost": sum(s["sidechain_cost"] for s in sessions.values()),
    }
    advice, hit_rate = build_advice(sessions, totals)

    if args.json:
        out = {
            "period_days": args.days,
            "files_scanned": files_scanned,
            "totals": totals,
            "cache_hit_rate": hit_rate,
            "per_model": {k: dict(v) for k, v in per_model.items()},
            "daily": dict(sorted(daily.items())),
            "advice": [
                {"severity": sev, "key": key, "params": params,
                 "title": t(key + "_title", **params),
                 "detail": t(key + "_detail", **params)}
                for sev, key, params in advice
            ],
            "cost_by_provider": {
                p: round(sum(s["cost"] for s in sessions.values()
                             if s["provider"] == p), 4)
                for p in sorted({s["provider"] for s in sessions.values()})
            },
            "top_sessions": [
                {"session": sid, "provider": s["provider"],
                 "project": s["project"], "cost": round(s["cost"], 4),
                 "prompts": s["prompts"], "max_context": s["max_context"],
                 "output_tokens": s["output"]}
                for sid, s in sorted(sessions.items(), key=lambda kv: -kv[1]["cost"])[:args.top]
            ],
        }
        json.dump(out, sys.stdout, ensure_ascii=False, indent=2, default=str)
        print()
        return

    W = 74
    print(c("═" * W, "cyan"))
    print(c("  " + t("title", days=args.days, files=files_scanned), "bold", "cyan"))
    print(c("═" * W, "cyan"))

    # ── Overview ──
    print(c("\n■ " + t("overview"), "bold"))
    cost_per_prompt = totals["cost"] / totals["prompts"] if totals["prompts"] else 0
    side_str = "-"
    if totals["cost"]:
        side_str = "${:,.2f} ({:.0%})".format(
            totals["sidechain_cost"], totals["sidechain_cost"] / totals["cost"])
    rows = [
        (t("estimated_cost"), "${:,.2f}".format(totals["cost"])),
        (t("sessions_prompts"), f"{len(sessions)} / {totals['prompts']}"),
        (t("api_requests"), f"{totals['requests']:,}"),
        (t("output_tokens"), fmt_tokens(totals["output"])),
        (t("input_tokens"), fmt_tokens(totals["input"])),
        (t("cache_rw"), f"{fmt_tokens(totals['cache_read'])} / {fmt_tokens(totals['cache_write'])}"),
        (t("cache_hit_rate"), f"{hit_rate:.1%}"),
        (t("cost_per_prompt"), f"${cost_per_prompt:.3f}"),
        (t("subagent_cost"), side_str),
    ]
    codex_cost_total = sum(s["cost"] for s in sessions.values()
                           if s["provider"] == "codex")
    if codex_cost_total:
        claude_cost_total = totals["cost"] - codex_cost_total
        rows.insert(1, (t("provider_split"),
                        "${:,.2f} / ${:,.2f}".format(claude_cost_total,
                                                     codex_cost_total)))
    label_w = max(dwidth(label) for label, _ in rows) + 3
    for label, value in rows:
        print(f"  {pad(label, label_w)}{c(value, 'bold')}")

    # ── By model ──
    print(c("\n■ " + t("by_model"), "bold"))
    print(f"  {'model':<26}{'req':>6}{'in':>9}{'read':>9}{'write':>9}{'out':>9}{'cost':>10}")
    for model, m in sorted(per_model.items(), key=lambda kv: -kv[1]["cost"]):
        cost_str = "${:,.2f}".format(m["cost"])
        print(f"  {model[:25]:<26}{m['requests']:>6}"
              f"{fmt_tokens(m['input']):>9}{fmt_tokens(m['cache_read']):>9}"
              f"{fmt_tokens(m['cache_write']):>9}{fmt_tokens(m['output']):>9}"
              f"{cost_str:>10}")

    # ── By project ──
    proj = defaultdict(lambda: {"cost": 0.0, "sessions": 0, "prompts": 0, "output": 0})
    for s in sessions.values():
        p = proj[s["project"] or "?"]
        p["cost"] += s["cost"]
        p["sessions"] += 1
        p["prompts"] += s["prompts"]
        p["output"] += s["output"]
    print(c("\n■ " + t("by_project"), "bold"))
    print(f"  {'project':<32}{'sess':>6}{'prompts':>9}{'out':>9}{'cost':>10}")
    for name, p in sorted(proj.items(), key=lambda kv: -kv[1]["cost"])[:args.top]:
        cost_str = "${:,.2f}".format(p["cost"])
        print(f"  {name[:31]:<32}{p['sessions']:>6}{p['prompts']:>9}"
              f"{fmt_tokens(p['output']):>9}{cost_str:>10}")

    # ── Most expensive sessions ──
    print(c("\n■ " + t("top_sessions"), "bold"))
    print(f"  {'project':<24}{'prompts':>8}{'maxCtx':>9}{'out':>9}{'cost':>10}  session")
    for sid, s in sorted(sessions.items(), key=lambda kv: -kv[1]["cost"])[:5]:
        cost_str = "${:,.2f}".format(s["cost"])
        print(f"  {(s['project'] or '?')[:23]:<24}{s['prompts']:>8}"
              f"{fmt_tokens(s['max_context']):>9}{fmt_tokens(s['output']):>9}"
              f"{cost_str:>10}  {c(sid[:8], 'dim')}")

    # ── Daily cost ──
    print(c("\n■ " + t("daily_cost"), "bold"))
    days_sorted = sorted(daily.items())[-14:]
    max_cost = max((d["cost"] for _, d in days_sorted), default=0) or 1
    for day, d in days_sorted:
        bar = "█" * max(1, int(d["cost"] / max_cost * 34)) if d["cost"] else ""
        cost_str = "${:>8,.2f}".format(d["cost"])
        print(f"  {day}  {cost_str}  {c(bar, 'green')}")

    # ── Recommendations ──
    print(c("\n■ " + t("advice"), "bold"))
    sev_style = {"high": ("red", "!"), "medium": ("yellow", "△"),
                 "low": ("blue", "○"), "info": ("green", "✓")}
    for sev, key, params in advice:
        col, mark = sev_style[sev]
        print(f"\n  {c(mark + ' ' + t(key + '_title', **params), 'bold', col)}")
        for line in wrap_text(t(key + "_detail", **params), lang):
            print(f"    {line}")
    print()


def default_dirs():
    """Standard transcript roots: ~/.claude plus $CLAUDE_CONFIG_DIR if set."""
    dirs = []
    config_dir = os.environ.get("CLAUDE_CONFIG_DIR")
    if config_dir:
        dirs.append(str(Path(config_dir) / "projects"))
    dirs.append("~/.claude/projects")
    # De-duplicate while preserving order
    seen = set()
    return [d for d in dirs
            if str(Path(d).expanduser()) not in seen
            and not seen.add(str(Path(d).expanduser()))]


def main():
    ap = argparse.ArgumentParser(
        description="Token-efficiency report for AI coding agents "
                    "(Claude Code, OpenAI Codex CLI)")
    ap.add_argument("--days", type=int, default=30, help="lookback window (default: 30)")
    ap.add_argument("--project", help="filter by project name substring")
    ap.add_argument("--provider", choices=["claude", "codex"],
                    help="only include one provider")
    ap.add_argument("--top", type=int, default=10, help="rows in ranking tables")
    ap.add_argument("--json", action="store_true", help="emit JSON instead of a report")
    ap.add_argument("--lang", help="report language (e.g. en, ja, zh-CN; default: $LANG)")
    ap.add_argument("--dirs", nargs="*", default=default_dirs(),
                    help="Claude Code transcript roots "
                         "(default: ~/.claude/projects and $CLAUDE_CONFIG_DIR/projects)")
    ap.add_argument("--codex-dirs", nargs="*", default=["~/.codex/sessions"],
                    help="Codex CLI session roots (default: ~/.codex/sessions)")
    args = ap.parse_args()

    lang = resolve_lang(args.lang)
    msgs = load_messages(lang)

    since = datetime.now(timezone.utc) - timedelta(days=args.days)
    sessions, daily, per_model, files_scanned = scan(
        args.dirs, args.codex_dirs, since, args.project, args.provider)
    if not sessions:
        print(msgs.get("no_transcripts", EN["no_transcripts"]), file=sys.stderr)
        sys.exit(1)
    use_color = sys.stdout.isatty() and not args.json
    render(sessions, daily, per_model, files_scanned, args, lang, msgs, use_color)


if __name__ == "__main__":
    main()
