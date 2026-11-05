Here is a table of all user-settable environment variables used to configure or control the behavior of the Hallux (`hx`) and associated tools.

### **Hallux Environment Variables**

| Variable Name | Category | Description & Usage Example |
| :--- | :--- | :--- |
| `HX_MODEL` | Model Configuration | Forces a specific model name for inference calls.<br>*Example:* `export HX_MODEL="gpt-4o"` |
| `HX_PROVIDERS` | Inference Provider Configuration | Forces a specific set of inference providers name for inference calls.<br>*Example:* `HX_PROVIDERS="open-inference,together"` |
| `HX_ICON_STYLE` | UI / Presentation | Toggles between using emojis or plain text characters for terminal output icons.<br>*Example:* `export HX_ICON_STYLE=emoji` (default) or `text`. |
| `HX_HOME` | Path Configuration | Defines the root directory where Hallux configuration and cache reside, bypassing standard search logic.<br>*Example:* `export HX_HOME="~/my-custom-config"` |
| `HX_STREAMING` | Runtime/Behavioral | Controls whether inference responses are streamed via SSE or returned as a single block.<br>*Example:* `export HX_STREAMING=0` (to disable streaming) |
| `HX_KEEP_TEMP_FILES` | Debugging / Lifecycle | If set, prevents the automatic deletion of temporary workspace directories in `$HALLUX_TMP_DIR`.<br>*Example:* `export HX_KEEP_TEMP_FILES=1` |
| `VIA_API_CHAT_BASE` | Connection Config | Sets the base URL for the LLM API. Overrides automatic subnet-based detection.<br>*Example:* `export VIA_API_CHAT_BASE="http://localhost:5000"` |
| `ENABLE_THINKING` | AI Feature Control | Boolean flag passed to the model's JSON payload to enable or disable "reasoning/thinking" features.<br>*Example:* `export ENABLE_THINKING=false` |
| `USER_AGENT` | Network Config | Customizes the User-Agent string sent by the `fetcher.sh` tool when scraping web content.<br>*Example:* `export USER_AGENT="MyCustomBot/1.0"` |
| `FETCHER` | Tooling / Runtime | Determines which command (`downlink`, `lynx`, or `links`) is used to retrieve remote HTML/text content.<br>*Example:* `export FETCHER=lynx` |
