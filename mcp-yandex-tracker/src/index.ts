#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
  Tool,
} from "@modelcontextprotocol/sdk/types.js";
import axios, { AxiosInstance } from "axios";

// Интерфейсы для Яндекс Трекера
interface YandexTrackerConfig {
  orgId: string;
  token: string;
}

interface Issue {
  key: string;
  summary: string;
  status: {
    key: string;
    display: string;
  };
  assignee?: {
    display: string;
  };
  createdAt: string;
  updatedAt: string;
}

interface IssueStats {
  total: number;
  open: number;
  inProgress: number;
  closed: number;
  byStatus: Record<string, number>;
}

// Класс для работы с Яндекс Трекером
class YandexTrackerClient {
  private client: AxiosInstance;
  private config: YandexTrackerConfig;

  constructor(config: YandexTrackerConfig) {
    this.config = config;
    this.client = axios.create({
      baseURL: "https://api.tracker.yandex.net/v2",
      headers: {
        "Authorization": `OAuth ${config.token}`,
        "X-Org-ID": config.orgId,
        "Content-Type": "application/json",
      },
    });
  }

  // Получить список задач по фильтру
  async getIssues(filter?: string, limit: number = 50): Promise<Issue[]> {
    try {
      // Используем GET метод вместо POST для _search
      const params: any = {
        perPage: limit,
      };

      if (filter) {
        params.filter = filter;
      }

      const response = await this.client.get("/issues", { params });
      return response.data;
    } catch (error: any) {
      // Детальная информация об ошибке
      const status = error.response?.status;
      const statusText = error.response?.statusText;
      const errorData = error.response?.data;

      let detailedMessage = `Failed to fetch issues`;

      if (status === 403) {
        // Проверяем конкретный код ошибки Yandex Tracker
        if (errorData?.errorCode === 620345) {
          detailedMessage += `: Organization not found (error code 620345). Your Organization ID is incorrect or you don't have access to this organization. Organization ID should be a numeric ID (like '12345678'), not organization name. Check https://tracker.yandex.ru → Settings → About to find the correct ID.`;
        } else {
          detailedMessage += `: Access forbidden (403). Check that your OAuth token has 'tracker:read' permission and Organization ID is correct.`;
        }
      } else if (status === 401) {
        detailedMessage += `: Unauthorized (401). Check your OAuth token.`;
      } else if (status === 404) {
        detailedMessage += `: Not found (404). Check Organization ID.`;
      } else if (status) {
        detailedMessage += `: Status ${status} - ${statusText}`;
      } else {
        detailedMessage += `: ${error.message}`;
      }

      if (errorData) {
        detailedMessage += ` Details: ${JSON.stringify(errorData)}`;
      }

      throw new Error(detailedMessage);
    }
  }

  // Получить статистику по задачам
  async getIssueStats(filter?: string): Promise<IssueStats> {
    const issues = await this.getIssues(filter, 1000);

    const stats: IssueStats = {
      total: issues.length,
      open: 0,
      inProgress: 0,
      closed: 0,
      byStatus: {},
    };

    issues.forEach((issue) => {
      const statusKey = issue.status.key.toLowerCase();
      const statusDisplay = issue.status.display;

      // Подсчет по категориям
      if (statusKey === "open" || statusKey === "new") {
        stats.open++;
      } else if (
        statusKey === "inprogress" ||
        statusKey === "in_progress" ||
        statusKey === "reviewing"
      ) {
        stats.inProgress++;
      } else if (
        statusKey === "closed" ||
        statusKey === "resolved" ||
        statusKey === "done"
      ) {
        stats.closed++;
      }

      // Подсчет по статусам
      if (!stats.byStatus[statusDisplay]) {
        stats.byStatus[statusDisplay] = 0;
      }
      stats.byStatus[statusDisplay]++;
    });

    return stats;
  }

  // Получить конкретную задачу
  async getIssue(issueKey: string): Promise<Issue> {
    try {
      const response = await this.client.get(`/issues/${issueKey}`);
      return response.data;
    } catch (error: any) {
      throw new Error(`Failed to fetch issue ${issueKey}: ${error.message}`);
    }
  }

  // Получить мои задачи
  async getMyIssues(): Promise<Issue[]> {
    return this.getIssues("assignee: me()");
  }
}

// MCP Сервер
class YandexTrackerMCPServer {
  private server: Server;
  private trackerClient: YandexTrackerClient | null = null;

  constructor() {
    this.server = new Server(
      {
        name: "yandex-tracker-mcp-server",
        version: "1.0.0",
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupHandlers();
  }

  private setupHandlers() {
    // Регистрация инструментов
    this.server.setRequestHandler(ListToolsRequestSchema, async () => {
      return {
        tools: this.getTools(),
      };
    });

    // Обработка вызова инструментов
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case "configure":
            return await this.handleConfigure(args);
          case "get_issues":
            return await this.handleGetIssues(args);
          case "get_issue_stats":
            return await this.handleGetIssueStats(args);
          case "get_issue":
            return await this.handleGetIssue(args);
          case "get_my_issues":
            return await this.handleGetMyIssues(args);
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error: any) {
        return {
          content: [
            {
              type: "text",
              text: `Error: ${error.message}`,
            },
          ],
          isError: true,
        };
      }
    });
  }

  private getTools(): Tool[] {
    return [
      {
        name: "configure",
        description:
          "Configure Yandex Tracker credentials (orgId and OAuth token)",
        inputSchema: {
          type: "object",
          properties: {
            orgId: {
              type: "string",
              description: "Your Yandex Tracker organization ID",
            },
            token: {
              type: "string",
              description: "Your OAuth token for Yandex Tracker API",
            },
          },
          required: ["orgId", "token"],
        },
      },
      {
        name: "get_issues",
        description: "Get list of issues with optional filter",
        inputSchema: {
          type: "object",
          properties: {
            filter: {
              type: "string",
              description:
                "Filter query (e.g., 'status: open', 'assignee: me()')",
            },
            limit: {
              type: "number",
              description: "Maximum number of issues to return (default: 50)",
            },
          },
        },
      },
      {
        name: "get_issue_stats",
        description: "Get statistics about issues (count by status)",
        inputSchema: {
          type: "object",
          properties: {
            filter: {
              type: "string",
              description: "Optional filter query",
            },
          },
        },
      },
      {
        name: "get_issue",
        description: "Get detailed information about a specific issue",
        inputSchema: {
          type: "object",
          properties: {
            issueKey: {
              type: "string",
              description: "Issue key (e.g., 'PROJECT-123')",
            },
          },
          required: ["issueKey"],
        },
      },
      {
        name: "get_my_issues",
        description: "Get issues assigned to me",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
    ];
  }

  // Обработчики инструментов

  private async handleConfigure(args: any) {
    const { orgId, token } = args;

    if (!orgId || !token) {
      throw new Error("orgId and token are required");
    }

    this.trackerClient = new YandexTrackerClient({ orgId, token });

    return {
      content: [
        {
          type: "text",
          text: "✅ Yandex Tracker configured successfully!",
        },
      ],
    };
  }

  private ensureConfigured() {
    if (!this.trackerClient) {
      throw new Error(
        "Yandex Tracker is not configured. Please call 'configure' first."
      );
    }
  }

  private async handleGetIssues(args: any) {
    this.ensureConfigured();

    const { filter, limit = 50 } = args;
    const issues = await this.trackerClient!.getIssues(filter, limit);

    const issueList = issues
      .map(
        (issue) =>
          `• ${issue.key}: ${issue.summary}\n  Status: ${issue.status.display}\n  Assignee: ${issue.assignee?.display || "Unassigned"}`
      )
      .join("\n\n");

    return {
      content: [
        {
          type: "text",
          text: `Found ${issues.length} issues:\n\n${issueList}`,
        },
      ],
    };
  }

  private async handleGetIssueStats(args: any) {
    this.ensureConfigured();

    const { filter } = args;
    const stats = await this.trackerClient!.getIssueStats(filter);

    const statusBreakdown = Object.entries(stats.byStatus)
      .map(([status, count]) => `  • ${status}: ${count}`)
      .join("\n");

    const text = `📊 Issue Statistics:

Total: ${stats.total}
Open: ${stats.open}
In Progress: ${stats.inProgress}
Closed: ${stats.closed}

By Status:
${statusBreakdown}`;

    return {
      content: [
        {
          type: "text",
          text,
        },
      ],
    };
  }

  private async handleGetIssue(args: any) {
    this.ensureConfigured();

    const { issueKey } = args;

    if (!issueKey) {
      throw new Error("issueKey is required");
    }

    const issue = await this.trackerClient!.getIssue(issueKey);

    const text = `📋 Issue: ${issue.key}

Summary: ${issue.summary}
Status: ${issue.status.display}
Assignee: ${issue.assignee?.display || "Unassigned"}
Created: ${new Date(issue.createdAt).toLocaleString()}
Updated: ${new Date(issue.updatedAt).toLocaleString()}`;

    return {
      content: [
        {
          type: "text",
          text,
        },
      ],
    };
  }

  private async handleGetMyIssues(args: any) {
    this.ensureConfigured();

    const issues = await this.trackerClient!.getMyIssues();

    const issueList = issues
      .map(
        (issue) =>
          `• ${issue.key}: ${issue.summary}\n  Status: ${issue.status.display}`
      )
      .join("\n\n");

    return {
      content: [
        {
          type: "text",
          text: `Found ${issues.length} issues assigned to you:\n\n${issueList}`,
        },
      ],
    };
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("Yandex Tracker MCP Server running on stdio");
  }
}

// Запуск сервера
const server = new YandexTrackerMCPServer();
server.run().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
