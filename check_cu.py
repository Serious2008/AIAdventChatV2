import anthropic, os

c = anthropic.Anthropic(api_key=os.environ['ANTHROPIC_API_KEY'])

# Пробуем разные комбинации модель + tool version + beta
configs = [
    ("claude-sonnet-4-6",          "computer_20251022", []),
    ("claude-sonnet-4-6",          "computer_20251022", ["computer-use-2025-01-24"]),
    ("claude-opus-4-7",            "computer_20251022", []),
    ("claude-opus-4-7",            "computer_20251022", ["computer-use-2025-01-24"]),
    ("claude-sonnet-4-6",          "computer_20250124", ["computer-use-2025-01-24"]),
]

for model, tool_type, betas in configs:
    try:
        kwargs = dict(
            model=model,
            max_tokens=100,
            tools=[{'type': tool_type, 'name': 'computer',
                    'display_width_px': 1280, 'display_height_px': 800, 'display_number': 1}],
            messages=[{'role': 'user', 'content': 'take a screenshot'}],
        )
        if betas:
            kwargs['betas'] = betas
        r = c.beta.messages.create(**kwargs)
        print(f"✅ РАБОТАЕТ: model={model} tool={tool_type} betas={betas}")
        print(f"   stop_reason={r.stop_reason}")
        break
    except Exception as e:
        print(f"❌ model={model} tool={tool_type} betas={betas}")
        print(f"   {e}")
        print()

