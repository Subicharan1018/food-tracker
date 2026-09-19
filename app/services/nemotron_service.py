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

    async def _execute_with_retry(self, api_call_coro, timeout_seconds: float | None = None):
        """Retries on HTTP 503 up to 2 attempts with 5-second delay and enforces timeout."""
        call_timeout = timeout_seconds if timeout_seconds is not None else settings.ai_timeout_seconds
        max_attempts = 2
        for attempt in range(1, max_attempts + 1):
            try:
                return await asyncio.wait_for(
                    api_call_coro(),
                    timeout=call_timeout,
                )
            except APIStatusError as e:
                if e.status_code == 503 and attempt < max_attempts:
                    logger.warning(
                        "OpenRouter returned 503. Retrying in 5s (attempt %d/%d)...",
                        attempt, max_attempts
                    )
                    await asyncio.sleep(5)
                else:
                    raise
            except (asyncio.TimeoutError, TimeoutError):
                logger.error("AI call timed out after %ds", int(call_timeout))
                raise TimeoutError(f"AI call timed out after {int(call_timeout)}s")
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
            if not response or not getattr(response, "choices", None):
                return ""
            choice = response.choices[0]
            if not choice or not getattr(choice, "message", None):
                return ""
            return choice.message.content or ""

        try:
            return await self._execute_with_retry(_call)
        except Exception as e:
            raise RuntimeError(f"Nemotron complete failed: {e}") from e

    async def extract_with_tool(
        self,
        system: str,
        user: str,
        tool_name: str,
        tool_description: str,
        tool_schema: dict,
        max_tokens: int = 2500,
        timeout_seconds: float = 15.0,
    ) -> dict:
        """Force one typed extraction tool call and return only its arguments."""
        async def _call():
            return await self._client.chat.completions.create(
                model=settings.nemotron_model,
                messages=[
                    {"role": "system", "content": system},
                    {"role": "user", "content": user},
                ],
                tools=[{
                    "type": "function",
                    "function": {
                        "name": tool_name,
                        "description": tool_description,
                        "parameters": tool_schema,
                    },
                }],
                tool_choice={"type": "function", "function": {"name": tool_name}},
                max_tokens=max_tokens,
            )

        try:
            response = await self._execute_with_retry(_call, timeout_seconds=timeout_seconds)
            choice = response.choices[0] if response and response.choices else None
            message = getattr(choice, "message", None)
            tool_calls = getattr(message, "tool_calls", None) if message else None
            if not tool_calls:
                raise RuntimeError("Recipe extraction model did not call the required tool")
            raw_args = tool_calls[0].function.arguments or "{}"
            parsed = json.loads(raw_args) if isinstance(raw_args, str) else raw_args
            if not isinstance(parsed, dict):
                raise RuntimeError("Recipe extraction tool returned a non-object payload")
            return parsed
        except Exception as e:
            raise RuntimeError(f"Structured recipe extraction failed: {e}") from e

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
                    kwargs = {
                        "model": settings.nemotron_model,
                        "messages": messages,
                        "max_tokens": 4000,
                    }
                    if tools:
                        kwargs["tools"] = tools
                        kwargs["tool_choice"] = "auto"
                    return await self._client.chat.completions.create(**kwargs)

                response = await self._execute_with_retry(_call)
                if not response or not getattr(response, "choices", None):
                    logger.warning("Empty or null choices returned from AI model.")
                    break

                choice = response.choices[0]
                if not choice or not getattr(choice, "message", None):
                    logger.warning("Empty choice message returned from AI model.")
                    break

                message = choice.message
                if message.content:
                    last_content = message.content

                tool_calls = getattr(message, "tool_calls", None)
                if tool_calls:
                    assistant_msg = {
                        "role": "assistant",
                        "content": message.content or "",
                        "tool_calls": [
                            {
                                "id": tc.id,
                                "type": "function",
                                "function": {
                                    "name": tc.function.name,
                                    "arguments": tc.function.arguments or "{}",
                                },
                            }
                            for tc in tool_calls
                        ],
                    }
                    messages.append(assistant_msg)

                    for tc in tool_calls:
                        args_str = getattr(tc.function, "arguments", "") or "{}"
                        try:
                            args = json.loads(args_str) if isinstance(args_str, str) else (args_str or {})
                        except Exception:
                            args = {}

                        try:
                            result = await tool_dispatcher(tc.function.name, args)
                        except Exception as tool_err:
                            logger.warning("Tool %s execution failed: %s", tc.function.name, tool_err)
                            result = {"error": str(tool_err)}

                        messages.append({
                            "role": "tool",
                            "tool_call_id": tc.id,
                            "content": json.dumps(result),
                        })
                elif choice.finish_reason == "stop" or message.content:
                    return last_content
                else:
                    break

        except Exception as e:
            logger.error("Nemotron agent loop failed: %s", e)
            raise RuntimeError(f"Nemotron agent loop failed: {e}") from e

        return last_content

nemotron_service = NemotronService()
