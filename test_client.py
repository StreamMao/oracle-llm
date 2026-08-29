#!/usr/bin/env python3
"""
Test client for oracle-llm (Qwen3-0.6B)
Usage:
    python3 test_client.py https://<your-oracle-llm-url>
"""

import sys
import time
import json
import urllib.request
import urllib.error

def wait_for_ready(base_url: str, max_retries: int = 15, delay: float = 2.0) -> bool:
    """Wait for server to finish loading model into memory during cold-start."""
    health_url = f"{base_url.rstrip('/')}/health"
    print("Checking server readiness", end="", flush=True)

    for _ in range(max_retries):
        try:
            req = urllib.request.Request(health_url)
            with urllib.request.urlopen(req, timeout=5) as response:
                if response.status == 200:
                    print(" -> Ready!\n")
                    return True
        except urllib.error.HTTPError as e:
            if e.code == 503:
                print(".", end="", flush=True)
                time.sleep(delay)
                continue
            else:
                print(f" (HTTP {e.code})", end="", flush=True)
                time.sleep(delay)
        except Exception:
            print(".", end="", flush=True)
            time.sleep(delay)

    print("\nWarning: Server took longer than expected to report ready. Trying chat anyway...\n")
    return False

def chat_stream(base_url: str, prompt: str):
    url = f"{base_url.rstrip('/')}/v1/chat/completions"
    payload = {
        "messages": [
            {"role": "system", "content": "You are a helpful and concise financial AI assistant."},
            {"role": "user", "content": prompt}
        ],
        "temperature": 0.7,
        "max_tokens": 512,
        "stream": True
    }
    
    headers = {
        "Content-Type": "application/json"
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        headers=headers,
        method="POST"
    )

    print(f"[Prompt]: {prompt}")
    print("[Response]: ", end="", flush=True)

    try:
        with urllib.request.urlopen(req, timeout=120) as response:
            for line in response:
                line = line.decode("utf-8").strip()
                if not line or line.startswith(":"):
                    continue
                if line.startswith("data: "):
                    data_str = line[6:]
                    if data_str == "[DONE]":
                        break
                    try:
                        data = json.loads(data_str)
                        delta = data.get("choices", [{}])[0].get("delta", {})
                        content = delta.get("content") or ""
                        print(content, end="", flush=True)
                    except json.JSONDecodeError:
                        pass
        print("\n")
    except urllib.error.HTTPError as e:
        print(f"\nHTTP Error {e.code}: {e.read().decode('utf-8')}\n")
    except Exception as e:
        print(f"\nError: {e}\n")

def main():
    if len(sys.argv) > 1:
        base_url = sys.argv[1]
    else:
        base_url = input("Enter Oracle LLM Service URL: ").strip()

    if not base_url:
        print("Error: URL cannot be empty.")
        sys.exit(1)

    print(f"\nConnecting to Oracle LLM: {base_url}")
    wait_for_ready(base_url)

    # Sample queries
    chat_stream(base_url, "你好，请用一句话介绍你自己。")
    chat_stream(base_url, "请翻译并提取要点：Tesla announced Q3 vehicle deliveries reached 462,890 units, up 6.4% year-over-year.")

if __name__ == "__main__":
    main()
