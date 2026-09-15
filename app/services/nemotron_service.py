import asyncio
import json
from openai import AsyncOpenAI, APIStatusError
from app.config import settings, logger

class NemotronService:
    def __init__(self, client: AsyncOpenAI = None):
        self._client = client or AsyncOpenAI(
            api_key=settings.openrouter_api_key,
            base_url=settings.openrouter_base_url,
            default_headers={
                "HTTP-Referer": "com.kinetik.fitnessapp",
                "X-Title": "Kinetik Fitness",
            },
            timeout=settings.ai_timeout_seconds,
        )

    async def _execute_with_retry(self, api_call_coro):
        """Retries on HTTP 503 up to 3 attempts with 10-second delay."""
        max_attempts = 3
        for attempt in range(1, max_attempts + 1):
            try:
                return await api_call_coro()
            except APIStatusError as e:
                if e.status_code == 503 and attempt < max_attempts:
                    logger.warning(
                        "OpenRouter returned 503. Retrying in 10s (attempt %d/%d)...",
                        attempt, max_attempts
                    )
                    await asyncio.sleep(10)
                else:
                    raise
            except Exception:
                raise

    async def complete(
        self,
        system: str,
        user: str,
        max_tokens: int = 2000,
    ) -> str:
        """Single-turn completion. No tool use."""
        async def _call():
            response = await self._client.chat.completions.create(
                model=settings.nemotron_model,
                messages=[
                    {"role": "system", "content": system},
                    {"role": "user",   "content": user},
                ],
                max_tokens=max_tokens,
            )
            return response.choices[0].message.content or ""

        try:
            return await self._execute_with_retry(_call)
        except Exception as e:
            raise RuntimeError(f"Nemotron complete failed: {e}") from e

    async def run_agent_loop(
        self,
        system: str,
        user: str,
        tools: list[dict],
        tool_dispatcher,
        max_iterations: int = 10,
    ) -> str:
        """
        Full agentic loop with tool dispatch and 503 retry protection.
        tool_dispatcher: async callable(name: str, args: dict) -> any
        """
        messages = [
            {"role": "system", "content": system},
            {"role": "user",   "content": user},
        ]
        last_content = ""

        try:
            for _ in range(max_iterations):
                async def _call():
                    return await self._client.chat.completions.create(
                        model=settings.nemotron_model,
                        messages=messages,
                        tools=tools,
                        tool_choice="auto",
                        max_tokens=4000,
                    )

                response = await self._execute_with_retry(_call)
                choice = response.choices[0]
                last_content = choice.message.content or ""

                if choice.finish_reason == "stop":
                    return last_content

                if choice.finish_reason == "tool_calls" and choice.message.tool_calls:
                    messages.append(choice.message)
                    for tc in choice.message.tool_calls:
                        try:
                            args = json.loads(tc.function.arguments)
                        except Exception:
                            args = {}
                        result = await tool_dispatcher(tc.function.name, args)
                        messages.append({
                            "role": "tool",
                            "tool_call_id": tc.id,
                            "content": json.dumps(result),
                        })

        except Exception as e:
            raise RuntimeError(f"Nemotron agent loop failed: {e}") from e

        return last_content

nemotron_service = NemotronService()
