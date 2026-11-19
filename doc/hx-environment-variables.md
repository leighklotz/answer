Here is a table of all user-settable environment variables used to configure or control the behavior of the Hallux (`hx`) and associated tools.

### **Hallux Environment Variables**

| Variable Name | Category | Description & Usage Example |
| :--- | :--- | :--- |
| `HX_MODEL` | Model Configuration | Forces a specific model name for inference calls.<br>*Example:* `` `export HX_MODEL="gpt-4o"` `` |
| `HX_PROVIDERS` | Inference Provider Configuration | Forces a specific set of provider names for inference calls. Commas separate providers; leading/trailing whitespace is automatically trimmed.<br>*Example:* `` `export HX_PROVIDERS="open-inference,together"` `` |
| `HX_ICON_STYLE` | UI / Presentation | Toggles between using emojis or plain text characters for terminal output icons. Default is `emoji` or `text`.<br>*Example:* `` `export HX_ICON_STYLE=text` `` |
| `HX_HOME` | Path Configuration | Defines the root directory where Hallux configuration and cache reside, bypassing standard search logic.<br>*Example:* `` `export HX_HOME="~/my-custom-config"` `` |
| `HX_STREAMING` | Runtime/Behavioral | Controls whether inference responses are streamed via SSE or returned as a single block. Default is `1` (stream).<br>*Example:* `` `export HX_STREAMING=0` `` |
| `HX_KEEP_TEMP_FILES` | Debugging / Lifecycle | If set to a truthy value, prevents automatic deletion of temporary workspace directories in `$HALLUX_TMP_DIR`.<br>*Example:* `` `export HX_KEEP_TEMP_FILES=1` `` |
| `VIA_API_CHAT_BASE` | Connection Config | Sets the base URL for the LLM API. Overrides automatic subnet-based detection.<br>*Example:* `` `export VIA_API_CHAT_BASE="http://localhost:5000"` `` |
| `ENABLE_THINKING` | AI Feature Control | Boolean flag passed to the model's JSON payload to enable or disable reasoning features. Default is `true`.<br>*Example:* `` `export ENABLE_THINKING=false` `` |
| `REASONING_EFFORT` | AI Feature Control | Specifies the reasoning effort level. Default is `medium`.<br>Accepted values: `none`/`off` (0), `low` (2000), `medium` (8000), `high` (16384), `xhigh` (32768).<br>Controls the complexity of the model's reasoning process during inference.<br>*Example:* `` `export REASONING_EFFORT=high` `` |
| `THINKING_BUDGET` | AI Feature Control | Specifies the token budget for thinking. If omitted, the budget is automatically derived from `REASONING_EFFORT` (`low`→2000, `medium`→8000, `high`→16384, `xhigh`→32768).<br>*Example:* `` `export THINKING_BUDGET=8000` `` |
| `USER_AGENT` | Network Config | Customizes the User-Agent string sent by the `fetcher.sh` tool when scraping web content.<br>*Example:* `` `export USER_AGENT="MyCustomBot/1.0"` `` |
| `FETCHER` | Tooling / Runtime | Determines which command (`downlink`, `lynx`, or `links`) is used to retrieve remote HTML/text content.<br>*Example:* `` `export FETCHER=lynx` `` |
```

<tool_call>
<function=git_commit>
<parameter=commit-message>
Update hallux configuration documentation

Fix missing export keyword and backtick formatting in HX_PROVIDERS example.
Add default fallback values for ENABLE_THINKING, REASONING_EFFORT, and THINKING_BUDGET.