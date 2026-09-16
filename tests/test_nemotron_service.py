import asyncio
import pytest
import json
from unittest.mock import AsyncMock, MagicMock, patch
from openai import APIStatusError
import httpx
from app.services.nemotron_service import NemotronService

@pytest.mark.asyncio
async def test_nemotron_complete_success():
    mock_client = MagicMock()
    mock_choice = MagicMock()
    mock_choice.message.content = "OK"
    mock_response = MagicMock(choices=[mock_choice])
    mock_client.chat.completions.create = AsyncMock(return_value=mock_response)

    svc = NemotronService(client=mock_client)
    res = await svc.complete("system prompt", "user prompt")
    assert res == "OK"

@pytest.mark.asyncio
async def test_nemotron_complete_error():
    mock_client = MagicMock()
    mock_client.chat.completions.create = AsyncMock(side_effect=Exception("Connection drop"))

    svc = NemotronService(client=mock_client)
    with pytest.raises(RuntimeError, match="Nemotron complete failed"):
        await svc.complete("system", "user")

@pytest.mark.asyncio
async def test_nemotron_503_retry_and_recover():
    mock_client = MagicMock()
    mock_choice = MagicMock()
    mock_choice.message.content = "Recovered"
    mock_response = MagicMock(choices=[mock_choice])

    req = httpx.Request("POST", "https://openrouter.ai/api/v1")
    resp = httpx.Response(503, request=req)
    err_503 = APIStatusError(message="Service Unavailable", response=resp, body=None)

    # Fail once with 503, then succeed on 2nd attempt
    mock_client.chat.completions.create = AsyncMock(side_effect=[err_503, mock_response])

    svc = NemotronService(client=mock_client)
    with patch("app.services.nemotron_service.asyncio.sleep", new_callable=AsyncMock) as mock_sleep:
        res = await svc.complete("system", "user")

    assert res == "Recovered"
    assert mock_client.chat.completions.create.call_count == 2
    mock_sleep.assert_called_once_with(10)

@pytest.mark.asyncio
async def test_nemotron_agent_loop():
    mock_client = MagicMock()

    # Turn 1: tool call
    tc = MagicMock()
    tc.id = "call_1"
    tc.function.name = "get_remaining_macros"
    tc.function.arguments = json.dumps({"today_diary": []})
    
    msg_1 = MagicMock()
    msg_1.content = ""
    msg_1.tool_calls = [tc]
    choice_1 = MagicMock(finish_reason="tool_calls", message=msg_1)
    resp_1 = MagicMock(choices=[choice_1])

    # Turn 2: final answer
    msg_2 = MagicMock()
    msg_2.content = '[{"recipe_name":"Dosa"}]'
    msg_2.tool_calls = None
    choice_2 = MagicMock(finish_reason="stop", message=msg_2)
    resp_2 = MagicMock(choices=[choice_2])

    mock_client.chat.completions.create = AsyncMock(side_effect=[resp_1, resp_2])

    dispatcher = AsyncMock(return_value={"remaining": {"calories": 1000}})
    svc = NemotronService(client=mock_client)

    result = await svc.run_agent_loop(
        system="system",
        user="user",
        tools=[],
        tool_dispatcher=dispatcher,
        max_iterations=5,
    )

    assert result == '[{"recipe_name":"Dosa"}]'
    dispatcher.assert_called_once_with("get_remaining_macros", {"today_diary": []})
    assert mock_client.chat.completions.create.call_count == 2

@pytest.mark.asyncio
async def test_nemotron_agent_loop_empty_choices():
    mock_client = MagicMock()
    mock_response = MagicMock(choices=[])
    mock_client.chat.completions.create = AsyncMock(return_value=mock_response)

    svc = NemotronService(client=mock_client)
    res = await svc.run_agent_loop("system", "user", [], AsyncMock())
    assert res == ""

@pytest.mark.asyncio
async def test_nemotron_agent_loop_tool_error_resilience():
    mock_client = MagicMock()

    tc = MagicMock()
    tc.id = "call_err"
    tc.function.name = "failing_tool"
    tc.function.arguments = "{}"

    msg_1 = MagicMock()
    msg_1.content = ""
    msg_1.tool_calls = [tc]
    choice_1 = MagicMock(finish_reason=None, message=msg_1)
    resp_1 = MagicMock(choices=[choice_1])

    msg_2 = MagicMock()
    msg_2.content = "Handled error"
    msg_2.tool_calls = None
    choice_2 = MagicMock(finish_reason="stop", message=msg_2)
    resp_2 = MagicMock(choices=[choice_2])

    mock_client.chat.completions.create = AsyncMock(side_effect=[resp_1, resp_2])

    failing_dispatcher = AsyncMock(side_effect=Exception("Database down"))
    svc = NemotronService(client=mock_client)

    result = await svc.run_agent_loop(
        system="system",
        user="user",
        tools=[{"type": "function", "function": {"name": "failing_tool"}}],
        tool_dispatcher=failing_dispatcher,
    )
    assert result == "Handled error"

@pytest.mark.asyncio
async def test_nemotron_timeout_enforcement():
    mock_client = MagicMock()

    async def hanging_call(*args, **kwargs):
        await asyncio.sleep(10)
        return MagicMock(choices=[MagicMock(message=MagicMock(content="Never"))])

    mock_client.chat.completions.create = AsyncMock(side_effect=hanging_call)

    svc = NemotronService(client=mock_client)
    with patch("app.services.nemotron_service.settings.ai_timeout_seconds", 0.05):
        with pytest.raises(RuntimeError, match="Nemotron complete failed: AI call timed out after"):
            await svc.complete("system", "user")

