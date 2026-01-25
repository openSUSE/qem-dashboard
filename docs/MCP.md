# Model Context Protocol (MCP) Support

The QEM Dashboard supports the [Model Context Protocol](https://modelcontextprotocol.io), allowing AI agents to interact with the dashboard data directly.

## Available Tools

- `list_submissions`: List active incidents/submissions.
- `get_submission_details`: Get details for a specific submission including openQA results.
- `list_blocked`: List incidents that are currently blocked.
- `get_repo_status`: Get status of various repositories/products.

## Example session

```
$ gemini -y "list all submissions blocked by tests on qem-dashboard"
I will list the incidents that are currently blocked.
The following submissions are currently blocked by tests on qem-dashboard:

1.  **Incident 16860 (perl-Mojolicious)**
    *   **Project:** SUSE:Maintenance:16860
    *   **Blocked by:**
        *   **SLE 12 SP4**: 1 failure

2.  **Incident 29722 (multipath-tools)**
    *   **Project:** SUSE:Maintenance:29722
    *   **Blocked by:**
        *   **SAP-DVD-Updates 15-SP4**: 1 failure in SAP/HA Maintenance
        *   **Server-DVD-Incidents 12-SP6**: 1 failure
```

## Transports

### HTTP/SSE (Remote)

The MCP server is available at the `/app/mcp` endpoint. It uses the standard MCP HTTP/SSE transport.

To use it with an AI agent, configure the agent to point to:
`https://<dashboard-url>/app/mcp`

Note: Authentication via Token might be required depending on the dashboard configuration.

### Stdio (Local)

For local interaction or use with desktop agents (like Claude Desktop), a stdio transport script is provided.

**Script**: `script/mcp-stdio`

#### Example configuration for Claude Desktop:

Add the following to your `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "qem-dashboard": {
      "command": "perl",
      "args": ["-Ilib", "script/mcp-stdio"],
      "cwd": "/path/to/qem-dashboard",
      "env": {
        "DASHBOARD_CONF": "dashboard.yml"
      }
    }
  }
}
```

## Development and Testing

To run the MCP server in stdio mode manually for testing:

```bash
make run-mcp-stdio
```

Then you can send JSON-RPC requests, for example:

```json
{"jsonrpc": "2.0", "id": 1, "method": "tools/list"}
```