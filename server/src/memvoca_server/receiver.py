"""A local-only WebSocket receiver for the Phase 1 iPhone transport proof."""

from __future__ import annotations

import argparse
import asyncio
import json
import logging
from collections.abc import Mapping
from dataclasses import asdict, dataclass
from datetime import UTC, datetime
from http import HTTPStatus
from typing import Any

from websockets.asyncio.server import ServerConnection, serve
from websockets.exceptions import ConnectionClosed

LOGGER = logging.getLogger(__name__)


@dataclass
class ReceiverStats:
    active_connections: int = 0
    total_connections: int = 0
    packets_received: int = 0
    bytes_received: int = 0
    last_received_at: str | None = None


class MemvocaReceiver:
    """Accept metadata JSON immediately followed by its binary packet payload."""

    def __init__(self) -> None:
        self.stats = ReceiverStats()

    async def handle(self, connection: ServerConnection) -> None:
        self.stats.active_connections += 1
        self.stats.total_connections += 1
        pending_metadata: Mapping[str, Any] | None = None
        LOGGER.info("stream connected from %s", connection.remote_address)
        try:
            async for message in connection:
                if isinstance(message, str):
                    pending_metadata = self._parse_metadata(message)
                    continue
                if pending_metadata is None:
                    await connection.close(1002, "binary payload requires preceding metadata")
                    return
                self._accept_packet(pending_metadata, message)
                pending_metadata = None
        except ConnectionClosed:
            pass
        finally:
            self.stats.active_connections -= 1
            LOGGER.info("stream disconnected from %s", connection.remote_address)

    def process_request(self, connection: ServerConnection, request: Any) -> Any:
        if request.path == "/stream":
            return None
        if request.path == "/health":
            response = connection.respond(HTTPStatus.OK, json.dumps({"status": "ok", **asdict(self.stats)}))
            response.headers["Content-Type"] = "application/json"
            return response
        return connection.respond(HTTPStatus.NOT_FOUND, "Not found\n")

    @staticmethod
    def _parse_metadata(message: str) -> Mapping[str, Any]:
        try:
            value = json.loads(message)
        except json.JSONDecodeError as error:
            raise ValueError("metadata must be JSON") from error
        if not isinstance(value, dict) or value.get("type") != "packet":
            raise ValueError("metadata must be an object with type=packet")
        for field in ("device_id", "session_id", "sequence", "timestamp"):
            if field not in value:
                raise ValueError(f"metadata is missing {field}")
        return value

    def _accept_packet(self, metadata: Mapping[str, Any], payload: bytes) -> None:
        self.stats.packets_received += 1
        self.stats.bytes_received += len(payload)
        self.stats.last_received_at = datetime.now(UTC).isoformat()
        LOGGER.info(
            "packet device=%s session=%s sequence=%s bytes=%d codec=%s",
            metadata["device_id"],
            metadata["session_id"],
            metadata["sequence"],
            len(payload),
            metadata.get("codec", "unknown"),
        )


async def run(host: str, port: int) -> None:
    receiver = MemvocaReceiver()
    async with serve(receiver.handle, host, port, max_size=1_048_576, process_request=receiver.process_request):
        LOGGER.info("Memvoca receiver listening at ws://%s:%d/stream", host, port)
        await asyncio.Future()


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the Memvoca Phase 1 receiver.")
    parser.add_argument("--host", default="127.0.0.1", help="Bind address (default: localhost)")
    parser.add_argument("--port", type=int, default=8766, help="Bind port (default: 8766)")
    args = parser.parse_args()
    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
    asyncio.run(run(args.host, args.port))
