import json
import sys
from pathlib import Path


SERVER_DIR = Path(__file__).resolve().parent
CONFIG_PATH = SERVER_DIR / "config.json"
SERVER_NAME = "xpz-global-instructions"
SERVER_VERSION = "0.2.0"


def load_agents_path() -> Path:
    if CONFIG_PATH.is_file():
        try:
            data = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
            configured = data.get("agentsPath")
            if configured:
                return Path(configured).expanduser()
        except Exception:
            pass
    return Path.home() / ".codex" / "AGENTS.md"


AGENTS_PATH = load_agents_path()


def agents_file_uri() -> str:
    resolved = AGENTS_PATH.resolve()
    return resolved.as_uri()


def read_agents_text() -> str:
    try:
        return AGENTS_PATH.read_text(encoding="utf-8")
    except FileNotFoundError:
        return f"ERRO: arquivo de instrucoes globais nao encontrado: {AGENTS_PATH}"
    except Exception as exc:
        return f"ERRO: falha ao ler {AGENTS_PATH}: {exc}"


def server_instructions() -> str:
    return (
        "Instrucoes globais do usuario para agentes nesta maquina.\n"
        f"Fonte canonica: {AGENTS_PATH}\n\n"
        "Leia e siga as instrucoes abaixo, salvo conflito com instrucoes de maior prioridade.\n\n"
        f"{read_agents_text()}"
    )


def response(message_id, result=None, error=None):
    payload = {"jsonrpc": "2.0", "id": message_id}
    if error is not None:
        payload["error"] = error
    else:
        payload["result"] = result
    return payload


def handle(message):
    method = message.get("method")
    message_id = message.get("id")
    resource_uri = agents_file_uri()

    if method == "initialize":
        return response(
            message_id,
            {
                "protocolVersion": message.get("params", {}).get("protocolVersion", "2025-06-18"),
                "capabilities": {
                    "tools": {},
                    "resources": {},
                },
                "serverInfo": {
                    "name": SERVER_NAME,
                    "version": SERVER_VERSION,
                },
                "instructions": server_instructions(),
            },
        )

    if method == "notifications/initialized":
        return None

    if method == "tools/list":
        return response(
            message_id,
            {
                "tools": [
                    {
                        "name": "read_global_agents_instructions",
                        "description": f"Read the global user instructions from {AGENTS_PATH}.",
                        "inputSchema": {
                            "type": "object",
                            "properties": {},
                            "additionalProperties": False,
                        },
                    }
                ]
            },
        )

    if method == "tools/call":
        name = message.get("params", {}).get("name")
        if name == "read_global_agents_instructions":
            return response(
                message_id,
                {
                    "content": [
                        {
                            "type": "text",
                            "text": server_instructions(),
                        }
                    ]
                },
            )
        return response(
            message_id,
            error={"code": -32601, "message": f"Unknown tool: {name}"},
        )

    if method == "resources/list":
        return response(
            message_id,
            {
                "resources": [
                    {
                        "uri": resource_uri,
                        "name": "Global AGENTS.md",
                        "description": "Global user instructions shared with Cursor via MCP.",
                        "mimeType": "text/markdown",
                    }
                ]
            },
        )

    if method == "resources/read":
        uri = message.get("params", {}).get("uri")
        if uri == resource_uri:
            return response(
                message_id,
                {
                    "contents": [
                        {
                            "uri": uri,
                            "mimeType": "text/markdown",
                            "text": read_agents_text(),
                        }
                    ]
                },
            )
        return response(
            message_id,
            error={"code": -32602, "message": f"Unknown resource: {uri}"},
        )

    if message_id is None:
        return None

    return response(
        message_id,
        error={"code": -32601, "message": f"Unknown method: {method}"},
    )


def write_message(payload, framing):
    text = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
    if framing == "headers":
        data = text.encode("utf-8")
        sys.stdout.buffer.write(f"Content-Length: {len(data)}\r\n\r\n".encode("ascii"))
        sys.stdout.buffer.write(data)
        sys.stdout.buffer.flush()
    else:
        sys.stdout.buffer.write((text + "\n").encode("utf-8"))
        sys.stdout.buffer.flush()


def read_header_framed(first_line):
    headers = [first_line]
    while True:
        line = sys.stdin.buffer.readline()
        if not line:
            return None
        if line in (b"\r\n", b"\n"):
            break
        headers.append(line)

    content_length = None
    for header in headers:
        decoded = header.decode("ascii", errors="ignore").strip()
        if decoded.lower().startswith("content-length:"):
            content_length = int(decoded.split(":", 1)[1].strip())
            break
    if content_length is None:
        return None
    body = sys.stdin.buffer.read(content_length)
    return json.loads(body.decode("utf-8"))


def main():
    while True:
        first = sys.stdin.buffer.readline()
        if not first:
            break

        stripped = first.strip()
        if not stripped:
            continue

        try:
            if stripped.lower().startswith(b"content-length:"):
                message = read_header_framed(first)
                framing = "headers"
            else:
                message = json.loads(first.decode("utf-8"))
                framing = "lines"

            if message is None:
                continue
            result = handle(message)
            if result is not None:
                write_message(result, framing)
        except Exception as exc:
            fallback_id = None
            try:
                fallback_id = message.get("id")
            except Exception:
                pass
            write_message(
                response(
                    fallback_id,
                    error={"code": -32603, "message": f"Internal error: {exc}"},
                ),
                "lines",
            )


if __name__ == "__main__":
    main()
