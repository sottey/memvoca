from __future__ import annotations

import asyncio
import json
import unittest
from urllib.request import urlopen

from memvoca_server.receiver import MemvocaReceiver
from websockets.asyncio.client import connect
from websockets.asyncio.server import serve


class ReceiverTests(unittest.IsolatedAsyncioTestCase):
    async def asyncSetUp(self) -> None:
        self.receiver = MemvocaReceiver()
        self.server = await serve(self.receiver.handle, "127.0.0.1", 0, process_request=self.receiver.process_request)
        self.port = self.server.sockets[0].getsockname()[1]

    async def asyncTearDown(self) -> None:
        self.server.close()
        await self.server.wait_closed()

    async def test_health_reports_receiver_stats(self) -> None:
        response = await asyncio.to_thread(urlopen, f"http://127.0.0.1:{self.port}/health")
        self.assertEqual(json.loads(response.read())["status"], "ok")

    async def test_packet_updates_stats(self) -> None:
        metadata = {
            "type": "packet",
            "device_id": "device-id",
            "session_id": "session-id",
            "sequence": 4,
            "timestamp": "2026-09-11T00:00:00Z",
            "codec": "opus",
        }
        async with connect(f"ws://127.0.0.1:{self.port}/stream") as websocket:
            await websocket.send(json.dumps(metadata))
            await websocket.send(b"\x01\x02\x03")
            await asyncio.sleep(0)
        self.assertEqual(self.receiver.stats.packets_received, 1)
        self.assertEqual(self.receiver.stats.bytes_received, 3)

    async def test_binary_payload_requires_metadata(self) -> None:
        async with connect(f"ws://127.0.0.1:{self.port}/stream") as websocket:
            await websocket.send(b"orphaned")
            await websocket.wait_closed()
            self.assertEqual(websocket.close_code, 1002)
