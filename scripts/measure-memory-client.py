#!/usr/bin/env python3
"""Exercise Vibes over HTTP and the Phoenix LiveView WebSocket protocol.

The benchmark deliberately avoids a browser automation dependency.  It still
performs the same protocol work a LiveSocket does: it loads the disconnected
HTML, carries the signed session/static tokens into ``phx_join``, targets the
component CIDs rendered by the server, and waits for ``phx_reply`` messages.

This file only uses Python's standard library so the remote runner can use an
official Python container without installing packages on the production host.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import html as html_module
import http.client
import json
import os
import random
import re
import socket
import ssl
import statistics
import sys
import threading
import time
import traceback
import urllib.parse
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple


DEFAULT_PREFERENCES = {"theme": "vibes", "sub_theme": "cozy"}
DEFAULT_TIMEOUT_SECONDS = 10.0
MAX_FAILURE_TEXT = 240


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def trim_error(value: object) -> str:
    text = " ".join(str(value).split())
    return text[:MAX_FAILURE_TEXT]


def percentile(values: Sequence[float], quantile: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    if len(ordered) == 1:
        return round(ordered[0], 2)
    position = (len(ordered) - 1) * quantile
    lower = int(position)
    upper = min(lower + 1, len(ordered) - 1)
    fraction = position - lower
    return round(ordered[lower] + (ordered[upper] - ordered[lower]) * fraction, 2)


class Metrics:
    """Thread-safe operation timings and failures."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self.timings: Dict[str, List[float]] = {}
        self.failures: List[Dict[str, Any]] = []

    def timing(self, operation: str, milliseconds: float) -> None:
        with self._lock:
            self.timings.setdefault(operation, []).append(milliseconds)

    def failure(
        self,
        kind: str,
        endpoint: str,
        client: Optional[int],
        error: object,
    ) -> None:
        item: Dict[str, Any] = {
            "kind": kind,
            "endpoint": endpoint,
            "error": trim_error(error),
        }
        if client is not None:
            item["client"] = client
        with self._lock:
            self.failures.append(item)

    def snapshot(self) -> Tuple[Dict[str, List[float]], List[Dict[str, Any]]]:
        with self._lock:
            return (
                {name: list(values) for name, values in self.timings.items()},
                list(self.failures),
            )

    def report(self) -> Dict[str, Dict[str, Any]]:
        timings, _ = self.snapshot()
        report: Dict[str, Dict[str, Any]] = {}
        for operation, values in sorted(timings.items()):
            report[operation] = {
                "count": len(values),
                "min_ms": round(min(values), 2) if values else 0.0,
                "p50_ms": percentile(values, 0.50),
                "p95_ms": percentile(values, 0.95),
                "p99_ms": percentile(values, 0.99),
                "max_ms": round(max(values), 2) if values else 0.0,
            }
        return report


def parse_attribute(source: str, attribute: str) -> Optional[str]:
    """Read one HTML attribute without requiring an HTML parser package."""

    pattern = rf"\b{re.escape(attribute)}\s*=\s*(['\"])(.*?)\1"
    match = re.search(pattern, source, re.IGNORECASE | re.DOTALL)
    if not match:
        return None
    return html_module.unescape(match.group(2))


def parse_opening_tags(source: str) -> Iterable[Tuple[str, str]]:
    for match in re.finditer(r"<([A-Za-z][^<>]*?)>", source, re.DOTALL):
        tag = match.group(0)
        if tag.startswith("</") or tag.startswith("<!"):
            continue
        yield tag, match.group(1)


def component_ids(source: str) -> Dict[str, int]:
    """Return CIDs for the two components the load uses.

    CIDs are allocated by LiveView and must be discovered from the rendered
    HTML.  Hard-coding them would make this benchmark silently exercise the
    wrong event target after an unrelated template change.
    """

    found: Dict[str, int] = {}
    for tag, _ in parse_opening_tags(source):
        cid = parse_attribute(tag, "data-phx-component")
        element_id = parse_attribute(tag, "id")
        if cid is None or element_id is None:
            continue
        if element_id in ("controls", "themes"):
            try:
                found[element_id] = int(cid)
            except ValueError:
                continue
    return found


def root_attributes(source: str) -> Dict[str, Optional[str]]:
    root_tag: Optional[str] = None
    for tag, _ in parse_opening_tags(source):
        if re.search(r"\bdata-phx-main(?:\s|=|>)", tag, re.IGNORECASE):
            root_tag = tag
            break
    if root_tag is None:
        raise ValueError("response did not contain a data-phx-main LiveView")

    root_id = parse_attribute(root_tag, "id")
    session = parse_attribute(root_tag, "data-phx-session")
    static = parse_attribute(root_tag, "data-phx-static")
    if not root_id or not session:
        raise ValueError("LiveView root did not contain data-phx-session and id")
    return {"id": root_id, "session": session, "static": static}


def csrf_token(source: str) -> str:
    match = re.search(
        r"<meta\b[^>]*\bname\s*=\s*(['\"])csrf-token\1[^>]*>",
        source,
        re.IGNORECASE | re.DOTALL,
    )
    if not match:
        raise ValueError("response did not contain a csrf-token meta tag")
    token = parse_attribute(match.group(0), "content")
    if not token:
        raise ValueError("csrf-token meta tag was empty")
    return token


def hidden_csrf_token(source: str) -> Optional[str]:
    for tag, _ in parse_opening_tags(source):
        if parse_attribute(tag, "name") == "_csrf_token":
            return parse_attribute(tag, "value")
    return None


def first_form_video_id(source: str) -> Optional[str]:
    for tag, _ in parse_opening_tags(source):
        if parse_attribute(tag, "name") == "_id":
            value = parse_attribute(tag, "value")
            if value:
                return value
    return None


def form_video_ids(source: str) -> List[str]:
    values: List[str] = []
    for tag, _ in parse_opening_tags(source):
        if parse_attribute(tag, "name") == "_id":
            value = parse_attribute(tag, "value")
            if value:
                values.append(value)
    return values


def initial_video_id(source: str) -> Optional[str]:
    for tag, _ in parse_opening_tags(source):
        if parse_attribute(tag, "id") == "youtube-player-container":
            return parse_attribute(tag, "data-video-id")
    return None


class CookieJar:
    def __init__(self) -> None:
        self._cookies: Dict[str, str] = {}

    def update(self, headers: http.client.HTTPMessage) -> None:
        for raw in headers.get_all("Set-Cookie", []):
            first = raw.split(";", 1)[0]
            if "=" not in first:
                continue
            name, value = first.split("=", 1)
            self._cookies[name.strip()] = value.strip()

    def header(self) -> str:
        return "; ".join(f"{name}={value}" for name, value in self._cookies.items())


@dataclass
class HttpPage:
    status: int
    headers: http.client.HTTPMessage
    body: str


class HttpClient:
    def __init__(
        self,
        endpoint: str,
        timeout: float,
        metrics: Metrics,
        client: int,
        host_header: str,
    ):
        self.endpoint = endpoint.rstrip("/")
        parsed = urllib.parse.urlsplit(self.endpoint)
        if parsed.scheme not in ("http", "https") or not parsed.hostname:
            raise ValueError(f"unsupported HTTP endpoint: {endpoint}")
        self.scheme = parsed.scheme
        self.hostname = parsed.hostname
        self.port = parsed.port or (443 if self.scheme == "https" else 80)
        self.timeout = timeout
        self.metrics = metrics
        self.client = client
        self.host_header = host_header
        self.cookies = CookieJar()

    def request(
        self,
        method: str,
        path: str,
        body: Optional[bytes] = None,
        headers: Optional[Dict[str, str]] = None,
        operation: Optional[str] = None,
    ) -> HttpPage:
        request_headers = {
            "Accept": "text/html,application/xhtml+xml",
            "Accept-Encoding": "identity",
            "Connection": "close",
            # The load connects to private Docker aliases while emulating
            # the HTTPS host that normally sits behind the Kamal proxy.
            "Host": self.host_header,
            "X-Forwarded-Proto": "https",
            "X-Forwarded-Host": self.host_header,
        }
        cookie = self.cookies.header()
        if cookie:
            request_headers["Cookie"] = cookie
        if headers:
            request_headers.update(headers)

        started = time.monotonic()
        connection: http.client.HTTPConnection
        if self.scheme == "https":
            context = ssl.create_default_context()
            connection = http.client.HTTPSConnection(
                self.hostname, self.port, timeout=self.timeout, context=context
            )
        else:
            connection = http.client.HTTPConnection(
                self.hostname, self.port, timeout=self.timeout
            )
        try:
            connection.request(method, path, body=body, headers=request_headers)
            response = connection.getresponse()
            content = response.read()
            page = HttpPage(response.status, response.headers, content.decode("utf-8"))
            self.cookies.update(response.headers)
            if operation:
                self.metrics.timing(operation, (time.monotonic() - started) * 1000)
            return page
        finally:
            connection.close()


class WebSocketError(RuntimeError):
    pass


class WebSocketConnection:
    """Minimal RFC 6455 client for Phoenix's text JSON protocol."""

    def __init__(
        self, endpoint: str, cookies: str, timeout: float, host_header: str
    ):
        parsed = urllib.parse.urlsplit(endpoint)
        if parsed.scheme not in ("ws", "wss") or not parsed.hostname:
            raise ValueError(f"unsupported WebSocket endpoint: {endpoint}")
        self.hostname = parsed.hostname
        self.port = parsed.port or (443 if parsed.scheme == "wss" else 80)
        self.timeout = timeout
        self.host_header = host_header
        raw_socket = socket.create_connection((self.hostname, self.port), timeout=timeout)
        if parsed.scheme == "wss":
            context = ssl.create_default_context()
            self.socket = context.wrap_socket(raw_socket, server_hostname=self.hostname)
        else:
            self.socket = raw_socket
        self.socket.settimeout(timeout)
        self.closed = False
        self._fragment_opcode: Optional[int] = None
        self._fragments: List[bytes] = []

        key = base64.b64encode(os.urandom(16)).decode("ascii")
        path = parsed.path or "/"
        query = parsed.query
        if query:
            path += "?" + query
        request = [
            f"GET {path} HTTP/1.1",
            f"Host: {self.host_header}",
            "Upgrade: websocket",
            "Connection: Upgrade",
            f"Sec-WebSocket-Key: {key}",
            "Sec-WebSocket-Version: 13",
            f"Origin: https://{self.host_header}",
            "X-Forwarded-Proto: https",
        ]
        if cookies:
            request.append(f"Cookie: {cookies}")
        request_bytes = ("\r\n".join(request) + "\r\n\r\n").encode("ascii")
        self.socket.sendall(request_bytes)

        response = self._read_http_headers()
        lines = response.split("\r\n")
        if not lines or not lines[0].startswith("HTTP/1.1 101"):
            self.close()
            raise WebSocketError(f"WebSocket upgrade failed: {lines[0] if lines else response}")
        response_headers: Dict[str, str] = {}
        for line in lines[1:]:
            if ":" not in line:
                continue
            name, value = line.split(":", 1)
            response_headers[name.lower().strip()] = value.strip()
        expected_accept = base64.b64encode(
            hashlib.sha1(
                (key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode("ascii")
            ).digest()
        ).decode("ascii")
        if response_headers.get("sec-websocket-accept") != expected_accept:
            self.close()
            raise WebSocketError("WebSocket upgrade returned an invalid accept key")

    def _read_http_headers(self) -> str:
        data = bytearray()
        while b"\r\n\r\n" not in data:
            chunk = self.socket.recv(4096)
            if not chunk:
                raise WebSocketError("WebSocket closed during HTTP upgrade")
            data.extend(chunk)
            if len(data) > 64 * 1024:
                raise WebSocketError("WebSocket upgrade headers exceeded 64 KiB")
        return bytes(data).split(b"\r\n\r\n", 1)[0].decode("latin-1")

    def _read_exact(self, size: int) -> bytes:
        data = bytearray()
        while len(data) < size:
            chunk = self.socket.recv(size - len(data))
            if not chunk:
                raise WebSocketError("WebSocket closed while reading a frame")
            data.extend(chunk)
        return bytes(data)

    def send_json(self, message: Sequence[Any]) -> None:
        self.send_frame(0x1, json.dumps(message, separators=(",", ":")).encode("utf-8"))

    def send_frame(self, opcode: int, payload: bytes) -> None:
        if self.closed:
            raise WebSocketError("WebSocket is closed")
        first = 0x80 | opcode
        length = len(payload)
        if length < 126:
            header = bytes((first, 0x80 | length))
        elif length < 65536:
            header = bytes((first, 0x80 | 126)) + length.to_bytes(2, "big")
        else:
            header = bytes((first, 0x80 | 127)) + length.to_bytes(8, "big")
        mask = os.urandom(4)
        masked = bytes(value ^ mask[index % 4] for index, value in enumerate(payload))
        self.socket.sendall(header + mask + masked)

    def recv_message(self, timeout: Optional[float] = None) -> Optional[Tuple[int, bytes]]:
        if self.closed:
            return None
        previous_timeout = self.socket.gettimeout()
        self.socket.settimeout(self.timeout if timeout is None else max(timeout, 0.001))
        try:
            while True:
                first_two = self._read_exact(2)
                first, second = first_two
                fin = (first & 0x80) != 0
                opcode = first & 0x0F
                masked = (second & 0x80) != 0
                length = second & 0x7F
                if length == 126:
                    length = int.from_bytes(self._read_exact(2), "big")
                elif length == 127:
                    length = int.from_bytes(self._read_exact(8), "big")
                    if length > 16 * 1024 * 1024:
                        raise WebSocketError("WebSocket frame exceeded 16 MiB")
                mask = self._read_exact(4) if masked else None
                payload = bytearray(self._read_exact(length))
                if mask:
                    for index in range(len(payload)):
                        payload[index] ^= mask[index % 4]
                payload_bytes = bytes(payload)

                if opcode == 0x8:
                    if not self.closed:
                        self.send_frame(0x8, payload_bytes[:2])
                    self.closed = True
                    return None
                if opcode == 0x9:
                    self.send_frame(0xA, payload_bytes)
                    continue
                if opcode == 0xA:
                    continue
                if opcode in (0x1, 0x2):
                    self._fragment_opcode = opcode
                    self._fragments = [payload_bytes]
                elif opcode == 0x0 and self._fragment_opcode is not None:
                    self._fragments.append(payload_bytes)
                else:
                    raise WebSocketError(f"unexpected WebSocket opcode {opcode}")

                if not fin:
                    continue
                complete_opcode = self._fragment_opcode
                complete_payload = b"".join(self._fragments)
                self._fragment_opcode = None
                self._fragments = []
                return complete_opcode, complete_payload
        except socket.timeout:
            return None
        finally:
            if not self.closed:
                self.socket.settimeout(previous_timeout)

    def close(self) -> None:
        if self.closed:
            return
        try:
            self.send_frame(0x8, b"\x03\xe8")
        except (OSError, WebSocketError):
            pass
        self.closed = True
        try:
            self.socket.close()
        except OSError:
            pass


def json_message(payload: bytes) -> Dict[str, Any]:
    try:
        value = json.loads(payload.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        raise WebSocketError(f"expected a JSON text frame: {error}") from error
    if not isinstance(value, list) or len(value) != 5:
        raise WebSocketError("Phoenix message was not a five-element list")
    return {
        "join_ref": value[0],
        "ref": value[1],
        "topic": value[2],
        "event": value[3],
        "payload": value[4],
    }


def websocket_endpoint(endpoint: str, csrf: str) -> str:
    parsed = urllib.parse.urlsplit(endpoint)
    scheme = "wss" if parsed.scheme == "https" else "ws"
    path = parsed.path.rstrip("/") + "/live/websocket"
    query = urllib.parse.urlencode({"_csrf_token": csrf, "vsn": "2.0.0"})
    return urllib.parse.urlunsplit((scheme, parsed.netloc, path, query, ""))


def rendered_strings(value: Any) -> Iterable[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for child in value.values():
            yield from rendered_strings(child)
    elif isinstance(value, list):
        for child in value:
            yield from rendered_strings(child)


def component_ids_from_rendered(rendered: Any) -> Dict[str, int]:
    """Find component CIDs in the compact diff returned by ``phx_join``."""

    if not isinstance(rendered, dict) or not isinstance(rendered.get("c"), dict):
        return {}
    found: Dict[str, int] = {}
    for raw_cid, component in rendered["c"].items():
        try:
            cid = int(raw_cid)
        except (TypeError, ValueError):
            continue
        text = "\n".join(rendered_strings(component))
        if 'id="themes"' in text:
            found["themes"] = cid
        elif 'phx-click="next_video"' in text:
            found["controls"] = cid
    return found


def nested_event_names(value: Any) -> Iterable[Tuple[str, Any]]:
    """Find LiveView push events in a diff's ``e`` field."""

    if isinstance(value, dict):
        for key, child in value.items():
            if key == "e" and isinstance(child, list):
                for item in child:
                    if isinstance(item, list) and len(item) >= 2 and isinstance(item[0], str):
                        yield item[0], item[1]
            yield from nested_event_names(child)
    elif isinstance(value, list):
        for child in value:
            yield from nested_event_names(child)


@dataclass
class Listener:
    client_id: int
    endpoint: str
    metrics: Metrics
    timeout: float
    action_interval: float
    start_event: threading.Event
    deadline: float
    station_refreshes: List[float]
    station_refresh_lock: threading.Lock
    failures: int = 0
    joined: bool = False
    action_count: int = 0
    socket: Optional[WebSocketConnection] = None
    thread: Optional[threading.Thread] = None
    stop_event: threading.Event = field(default_factory=threading.Event)
    host_header: str = "vibes-memory.invalid"
    ref_counter: int = 2

    def start(self) -> None:
        self.thread = threading.Thread(target=self.run, name=f"listener-{self.client_id}")
        self.thread.daemon = True
        self.thread.start()

    def join(self, timeout: Optional[float] = None) -> None:
        if self.thread:
            self.thread.join(timeout)

    def run(self) -> None:
        http_client = HttpClient(
            self.endpoint,
            self.timeout,
            self.metrics,
            self.client_id,
            self.host_header,
        )
        try:
            page_started = time.monotonic()
            page = http_client.request("GET", "/", operation="listener_http_get")
            if page.status != 200:
                raise RuntimeError(f"homepage returned HTTP {page.status}")
            self.metrics.timing(
                "listener_bootstrap_parse", (time.monotonic() - page_started) * 1000
            )
            attrs = root_attributes(page.body)
            cids = component_ids(page.body)

            csrf = csrf_token(page.body)
            ws_endpoint = websocket_endpoint(self.endpoint, csrf)
            ws_started = time.monotonic()
            self.socket = WebSocketConnection(
                ws_endpoint, http_client.cookies.header(), self.timeout, self.host_header
            )
            self.metrics.timing("listener_ws_upgrade", (time.monotonic() - ws_started) * 1000)

            topic = f"lv:{attrs['id']}"
            set_socket_topic(self.socket, topic)
            join_ref = "1"
            join_started = time.monotonic()
            self.socket.send_json(
                [
                    join_ref,
                    "1",
                    topic,
                    "phx_join",
                    {
                        "url": f"https://{self.host_header}/",
                        "params": {
                            "_csrf_token": csrf,
                            "preferences": DEFAULT_PREFERENCES,
                            "_mounts": 0,
                            "_mount_attempts": 0,
                        },
                        "session": attrs["session"],
                        "static": attrs["static"] or None,
                    },
                ]
            )
            reply = self.wait_for_reply("1", topic, join_started)
            if reply.get("status") != "ok":
                raise RuntimeError(f"LiveView join failed: {reply.get('response')}")
            response = reply.get("response")
            if isinstance(response, dict):
                cids.update(component_ids_from_rendered(response.get("rendered")))
            missing = [name for name in ("controls", "themes") if name not in cids]
            if missing:
                raise RuntimeError(f"missing LiveView component CIDs: {','.join(missing)}")
            self.metrics.timing("listener_join", (time.monotonic() - join_started) * 1000)
            self.joined = True
            self.start_event.wait(max(0.0, self.deadline - time.monotonic()))

            # Hold actions for a short, deterministic interval after the join
            # barrier.  This leaves the initial video selected when the admin
            # writer performs its removal, making the refresh assertion real.
            next_action = time.monotonic() + min(2.0, self.action_interval)
            heartbeat_at = time.monotonic() + 15.0
            rng = random.Random(self.client_id * 7919 + len(self.endpoint))
            while time.monotonic() < self.deadline and not self.stop_event.is_set():
                now = time.monotonic()
                if now >= heartbeat_at:
                    self.send_heartbeat()
                    heartbeat_at = now + 15.0
                if now >= next_action:
                    if self.action_count % 3 == 0:
                        event_name = "next_video"
                        cid = cids["controls"]
                        value: Dict[str, Any] = {}
                    elif self.action_count % 3 == 1:
                        event_name = "prev_video"
                        cid = cids["controls"]
                        value = {}
                    else:
                        event_name = "select_theme"
                        cid = cids["themes"]
                        choices = [
                            {"theme": "vibes", "sub_theme": "cozy"},
                            {"theme": "seasons", "sub_theme": "winter"},
                            {"theme": "vibes", "sub_theme": "rainy_day"},
                            {"theme": "seasons", "sub_theme": "spring"},
                        ]
                        value = choices[rng.randrange(len(choices))]
                    self.send_event(event_name, value, cid, event_name)
                    self.action_count += 1
                    next_action = now + self.action_interval
                timeout = max(0.05, min(0.5, self.deadline - time.monotonic()))
                self.receive_once(timeout)
        except Exception as error:  # noqa: BLE001 - benchmark reports every client error
            self.failures += 1
            self.metrics.failure("listener", self.endpoint, self.client_id, error)
        finally:
            if self.socket:
                self.socket.close()

    def receive_once(self, timeout: float) -> Optional[Dict[str, Any]]:
        if not self.socket:
            return None
        frame = self.socket.recv_message(timeout)
        if frame is None:
            return None
        opcode, payload = frame
        if opcode != 1:
            self.metrics.failure(
                "listener_frame", self.endpoint, self.client_id, "received a binary frame"
            )
            return None
        message = json_message(payload)
        event = message.get("event")
        if event == "diff":
            for name, _event_payload in nested_event_names(message.get("payload")):
                if name == "changeVideo":
                    with self.station_refresh_lock:
                        self.station_refreshes.append(time.monotonic())
        return message

    def wait_for_reply(self, ref: str, topic: str, started: float) -> Dict[str, Any]:
        while time.monotonic() - started < self.timeout:
            message = self.receive_once(self.timeout)
            if message is None:
                continue
            if (
                message.get("event") == "phx_reply"
                and message.get("ref") == ref
                and message.get("topic") == topic
            ):
                payload = message.get("payload")
                if not isinstance(payload, dict):
                    raise WebSocketError("Phoenix reply payload was not an object")
                return payload
        raise TimeoutError(f"timed out waiting for Phoenix reply ref {ref}")

    def send_event(
        self,
        event_name: str,
        value: Dict[str, Any],
        cid: Optional[int],
        operation: str,
    ) -> Optional[Dict[str, Any]]:
        if not self.socket:
            return None
        ref = str(self.ref_counter)
        self.ref_counter += 1
        payload: Dict[str, Any] = {
            "type": "event",
            "event": event_name,
            "value": value,
        }
        if cid is not None:
            payload["cid"] = cid
        started = time.monotonic()
        self.socket.send_json(["1", ref, self.socket_topic(), "event", payload])
        reply = self.wait_for_reply(ref, self.socket_topic(), started)
        self.metrics.timing(operation, (time.monotonic() - started) * 1000)
        if reply.get("status") != "ok":
            self.metrics.failure(
                "listener_reply", self.endpoint, self.client_id, f"{event_name}: {reply}"
            )
        return reply

    def send_heartbeat(self) -> None:
        if not self.socket:
            return
        ref = str(self.ref_counter)
        self.ref_counter += 1
        started = time.monotonic()
        self.socket.send_json([None, ref, "phoenix", "heartbeat", {}])
        self.metrics.timing("listener_heartbeat", (time.monotonic() - started) * 1000)

    def socket_topic(self) -> str:
        # The topic is populated by the join reply path in ``run``.  The
        # root id is stable for this socket, so retaining it avoids parsing
        # the rendered diff in a benchmark client.
        if not self.socket:
            raise WebSocketError("socket is not connected")
        topic = getattr(self.socket, "topic", None)
        if not topic:
            raise WebSocketError("socket topic was not initialized")
        return topic


def set_socket_topic(connection: WebSocketConnection, topic: str) -> None:
    connection.topic = topic  # type: ignore[attr-defined]


@dataclass
class AdminEdit:
    endpoint: str
    status: str
    listener_refreshes: int
    error: Optional[str] = None


def admin_remove_current(
    endpoint: str,
    password: str,
    metrics: Metrics,
    client_id: int,
    listeners: Sequence[Listener],
    refresh_cutoff: float,
    timeout: float,
    host_header: str,
) -> AdminEdit:
    """Log in through the real admin form and remove one current video."""

    http_client = HttpClient(endpoint, timeout, metrics, client_id, host_header)
    connection: Optional[WebSocketConnection] = None
    try:
        page = http_client.request("GET", "/admin/login", operation="admin_login_get")
        if page.status != 200:
            raise RuntimeError(f"admin login page returned HTTP {page.status}")
        login_token = hidden_csrf_token(page.body) or csrf_token(page.body)
        body = urllib.parse.urlencode(
            {"_csrf_token": login_token, "password": password}
        ).encode("utf-8")
        login_response = http_client.request(
            "POST",
            "/admin/login",
            body=body,
            headers={"Content-Type": "application/x-www-form-urlencoded"},
            operation="admin_login_post",
        )
        if login_response.status not in (302, 303):
            raise RuntimeError(f"admin login returned HTTP {login_response.status}")

        admin_page = http_client.request(
            "GET", "/admin?station=cozy", operation="admin_http_get"
        )
        if admin_page.status != 200:
            raise RuntimeError(f"admin page returned HTTP {admin_page.status}")
        video_id = first_form_video_id(admin_page.body)
        if not video_id:
            raise RuntimeError("admin page did not render a station video form")
        before_ids = set(form_video_ids(admin_page.body))
        attrs = root_attributes(admin_page.body)
        ws_endpoint = websocket_endpoint(endpoint, csrf_token(admin_page.body))
        ws_started = time.monotonic()
        connection = WebSocketConnection(
            ws_endpoint, http_client.cookies.header(), timeout, host_header
        )
        metrics.timing("admin_ws_upgrade", (time.monotonic() - ws_started) * 1000)
        topic = f"lv:{attrs['id']}"
        set_socket_topic(connection, topic)
        join_started = time.monotonic()
        connection.send_json(
            [
                "1",
                "1",
                topic,
                "phx_join",
                {
                    "url": f"https://{host_header}/admin?station=cozy",
                    "params": {
                        "_csrf_token": csrf_token(admin_page.body),
                        "_mounts": 0,
                        "_mount_attempts": 0,
                    },
                    "session": attrs["session"],
                    "static": attrs["static"] or None,
                },
            ]
        )
        join_reply = wait_connection_reply(connection, "1", topic, timeout, metrics, "admin_join")
        if join_reply.get("status") != "ok":
            raise RuntimeError(f"admin LiveView join failed: {join_reply}")

        edit_started = time.monotonic()
        connection.send_json(
            [
                "1",
                "2",
                topic,
                "event",
                {"type": "event", "event": "remove", "value": {"id": video_id}},
            ]
        )
        edit_reply = wait_connection_reply(connection, "2", topic, timeout, metrics, "admin_remove")
        metrics.timing("admin_remove", (time.monotonic() - edit_started) * 1000)
        if edit_reply.get("status") != "ok":
            raise RuntimeError(f"admin remove returned {edit_reply}")
        verification_page = http_client.request(
            "GET", "/admin?station=cozy", operation="admin_verify_get"
        )
        if verification_page.status != 200:
            raise RuntimeError(
                f"admin verification page returned HTTP {verification_page.status}"
            )
        after_ids = set(form_video_ids(verification_page.body))
        if video_id in after_ids or len(after_ids) >= len(before_ids):
            raise RuntimeError(
                "admin remove reply was ok but the station still contains the video"
            )
        connection.close()

        # The station update is delivered asynchronously to listener
        # processes.  Wait briefly for the changeVideo push generated when
        # the removed video was the currently selected video.
        wait_until = time.monotonic() + min(5.0, timeout)
        while time.monotonic() < wait_until:
            with listeners[0].station_refresh_lock if listeners else threading.Lock():
                refreshes = sum(
                    1
                    for listener in listeners
                    for stamp in listener.station_refreshes
                    if stamp >= refresh_cutoff
                )
            if refreshes:
                break
            time.sleep(0.05)
        with listeners[0].station_refresh_lock if listeners else threading.Lock():
            refreshes = sum(
                1
                for listener in listeners
                for stamp in listener.station_refreshes
                if stamp >= refresh_cutoff
            )
        return AdminEdit(endpoint, "ok", refreshes)
    except Exception as error:  # noqa: BLE001 - returned in machine-readable report
        metrics.failure("admin", endpoint, client_id, error)
        return AdminEdit(endpoint, "failed", 0, trim_error(error))
    finally:
        if connection:
            connection.close()


def wait_connection_reply(
    connection: WebSocketConnection,
    ref: str,
    topic: str,
    timeout: float,
    metrics: Metrics,
    operation: str,
) -> Dict[str, Any]:
    started = time.monotonic()
    while time.monotonic() - started < timeout:
        frame = connection.recv_message(timeout)
        if frame is None:
            continue
        opcode, payload = frame
        if opcode != 1:
            raise WebSocketError("Phoenix returned a binary frame")
        message = json_message(payload)
        if (
            message.get("event") == "phx_reply"
            and message.get("ref") == ref
            and message.get("topic") == topic
        ):
            response = message.get("payload")
            if not isinstance(response, dict):
                raise WebSocketError("Phoenix reply payload was not an object")
            metrics.timing(operation, (time.monotonic() - started) * 1000)
            return response
    raise TimeoutError(f"timed out waiting for admin Phoenix reply ref {ref}")


def endpoint_list(raw: Sequence[str]) -> List[str]:
    endpoints = [value.rstrip("/") for value in raw if value.strip()]
    if not endpoints:
        raise ValueError("at least one --endpoint is required")
    for endpoint in endpoints:
        parsed = urllib.parse.urlsplit(endpoint)
        if parsed.scheme not in ("http", "https") or not parsed.hostname:
            raise ValueError(f"invalid endpoint: {endpoint}")
    return endpoints


def run_phase(args: argparse.Namespace) -> Dict[str, Any]:
    endpoints = endpoint_list(args.endpoint)
    metrics = Metrics()
    refresh_lock = threading.Lock()
    listeners: List[Listener] = []
    started = time.monotonic()
    deadline = started + args.duration
    start_event = threading.Event()

    for client_id in range(args.clients):
        endpoint = endpoints[client_id % len(endpoints)]
        listener = Listener(
            client_id=client_id,
            endpoint=endpoint,
            metrics=metrics,
            timeout=args.timeout,
            action_interval=args.action_interval,
            start_event=start_event,
            deadline=deadline,
            station_refreshes=[],
            station_refresh_lock=refresh_lock,
            host_header=args.host_header,
        )
        listeners.append(listener)
        listener.start()

    startup_deadline = time.monotonic() + args.startup_timeout
    while time.monotonic() < startup_deadline:
        joined = sum(1 for listener in listeners if listener.joined)
        finished = sum(
            1
            for listener in listeners
            if listener.thread and not listener.thread.is_alive()
        )
        if joined == len(listeners) or finished == len(listeners):
            break
        time.sleep(0.05)

    joined = sum(1 for listener in listeners if listener.joined)
    failed_before_edit = sum(listener.failures for listener in listeners)
    if joined != len(listeners):
        start_event.set()
        for listener in listeners:
            listener.stop_event.set()
        for listener in listeners:
            listener.join(2.0)
        timings, failures = metrics.snapshot()
        return {
            "schema_version": 1,
            "phase_clients": args.clients,
            "duration_seconds": args.duration,
            "started_at": utc_now(),
            "endpoints": endpoints,
            "listeners": {"expected": args.clients, "joined": joined, "failed": args.clients - joined},
            "actions": {},
            "latencies_ms": metrics.report(),
            "admin_edits": [],
            "assertions": {
                "all_listeners_joined": False,
                "admin_edits_ok": False,
                "listener_refresh": False,
            },
            "failures": failures,
        }

    # Perform one real station edit through each candidate endpoint while all
    # listeners are alive.  The server-side station broadcast is local to the
    # app node, so each edit is checked against listeners on that same node.
    start_event.set()
    admin_edits: List[AdminEdit] = []
    password = os.environ.get("BENCHMARK_ADMIN_PASSWORD")
    if not password:
        metrics.failure("admin", "all", None, "BENCHMARK_ADMIN_PASSWORD is required")
    else:
        for endpoint_index, endpoint in enumerate(endpoints):
            endpoint_listeners = [
                listener for listener in listeners if listener.endpoint == endpoint
            ]
            refresh_cutoff = time.monotonic()
            admin_edits.append(
                admin_remove_current(
                    endpoint,
                    password,
                    metrics,
                    args.clients + endpoint_index,
                    endpoint_listeners,
                    refresh_cutoff,
                    args.timeout,
                    args.host_header,
                )
            )

    remaining = max(0.0, deadline - time.monotonic())
    if remaining:
        time.sleep(remaining)
    for listener in listeners:
        listener.stop_event.set()
    for listener in listeners:
        listener.join(args.timeout)

    timings, failures = metrics.snapshot()
    action_counts: Dict[str, int] = {}
    for listener in listeners:
        action_counts[listener.endpoint] = action_counts.get(listener.endpoint, 0) + listener.action_count
    refresh_counts = {
        endpoint: sum(
            1
            for listener in listeners
            if listener.endpoint == endpoint
            for stamp in listener.station_refreshes
            if stamp >= started
        )
        for endpoint in endpoints
    }
    admin_ok = bool(admin_edits) and all(edit.status == "ok" for edit in admin_edits)
    refresh_ok = bool(admin_edits) and all(
        edit.listener_refreshes > 0 for edit in admin_edits
    )
    return {
        "schema_version": 1,
        "phase_clients": args.clients,
        "duration_seconds": args.duration,
        "started_at": utc_now(),
        "endpoints": endpoints,
        "listeners": {
            "expected": args.clients,
            "joined": joined,
            "failed": sum(listener.failures for listener in listeners),
        },
        "actions": {
            "total": sum(listener.action_count for listener in listeners),
            "by_endpoint": action_counts,
        },
        "latencies_ms": metrics.report(),
        "admin_edits": [
            {
                "endpoint": edit.endpoint,
                "status": edit.status,
                "listener_refreshes": edit.listener_refreshes,
                **({"error": edit.error} if edit.error else {}),
            }
            for edit in admin_edits
        ],
        "listener_refreshes_by_endpoint": refresh_counts,
        "assertions": {
            "all_listeners_joined": joined == args.clients,
            "admin_edits_ok": admin_ok,
            "listener_refresh": refresh_ok,
        },
        "failures": failures,
    }


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--endpoint",
        action="append",
        required=True,
        help="candidate app HTTP endpoint; repeat once for each app container",
    )
    parser.add_argument("--clients", type=int, required=True)
    parser.add_argument("--duration", type=float, default=30.0)
    parser.add_argument("--startup-timeout", type=float, default=30.0)
    parser.add_argument("--action-interval", type=float, default=2.0)
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT_SECONDS)
    parser.add_argument(
        "--host-header",
        default="vibes-memory.invalid",
        help="Host/Origin used for private requests behind the emulated HTTPS proxy",
    )
    parser.add_argument("--output", required=True)
    args = parser.parse_args(argv)
    if args.clients < 1 or args.clients > 100:
        parser.error("--clients must be between 1 and 100")
    if args.duration <= 0 or args.duration > 180:
        parser.error("--duration must be between 0 and 180 seconds")
    if args.action_interval <= 0:
        parser.error("--action-interval must be positive")
    return args


def main(argv: Sequence[str]) -> int:
    args = parse_args(argv)
    try:
        result = run_phase(args)
        with open(args.output, "w", encoding="utf-8") as output:
            json.dump(result, output, indent=2, sort_keys=True)
            output.write("\n")
        print(json.dumps(result, sort_keys=True))
        assertions = result["assertions"]
        return 0 if all(assertions.values()) and not result["failures"] else 1
    except Exception as error:  # noqa: BLE001 - make runner failure diagnosable
        print(f"benchmark client failed: {trim_error(error)}", file=sys.stderr)
        traceback.print_exc(file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
