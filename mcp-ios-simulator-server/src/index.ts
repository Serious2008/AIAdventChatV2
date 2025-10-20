import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { execSync, exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

// Типы для симулятора
interface Simulator {
  udid: string;
  name: string;
  state: string;
  runtime: string;
  deviceType: string;
}

// Получить список всех симуляторов
async function listSimulators(): Promise<Simulator[]> {
  try {
    const { stdout } = await execAsync('xcrun simctl list devices available --json');
    const data = JSON.parse(stdout);

    const simulators: Simulator[] = [];

    for (const [runtime, devices] of Object.entries(data.devices)) {
      if (Array.isArray(devices)) {
        for (const device of devices) {
          simulators.push({
            udid: device.udid,
            name: device.name,
            state: device.state,
            runtime: runtime.replace('com.apple.CoreSimulator.SimRuntime.', ''),
            deviceType: device.deviceTypeIdentifier.split('.').pop() || 'Unknown'
          });
        }
      }
    }

    return simulators;
  } catch (error: any) {
    throw new Error(`Не удалось получить список симуляторов: ${error.message}`);
  }
}

// Запустить симулятор
async function bootSimulator(udidOrName: string): Promise<string> {
  try {
    console.error(`🔍 Ищу симулятор: ${udidOrName}`);

    // Сначала попробуем найти симулятор по имени
    const simulators = await listSimulators();
    let targetUdid = udidOrName;

    const simByName = simulators.find(s => s.name.toLowerCase().includes(udidOrName.toLowerCase()));
    if (simByName) {
      console.error(`✅ Найден симулятор по имени: ${simByName.name} (${simByName.udid})`);
      targetUdid = simByName.udid;
    } else {
      console.error(`⚠️ Симулятор не найден по имени, пробую использовать как UDID`);
    }

    // Проверяем текущий статус
    const currentSim = simulators.find(s => s.udid === targetUdid);
    if (currentSim && currentSim.state === "Booted") {
      console.error(`ℹ️ Симулятор уже запущен`);
      return `✅ Симулятор "${currentSim.name}" уже запущен`;
    }

    // Запускаем симулятор
    console.error(`🚀 Запускаю симулятор: xcrun simctl boot ${targetUdid}`);
    await execAsync(`xcrun simctl boot ${targetUdid}`);
    console.error(`✅ Симулятор загружен`);

    // Открываем Simulator.app для визуализации
    console.error(`📱 Открываю Simulator.app`);
    await execAsync('open -a Simulator');
    console.error(`✅ Simulator.app открыт`);

    return `✅ Симулятор "${currentSim?.name || targetUdid}" успешно запущен`;
  } catch (error: any) {
    console.error(`❌ Ошибка при запуске симулятора: ${error.message}`);
    throw new Error(`Не удалось запустить симулятор: ${error.message}`);
  }
}

// Остановить симулятор
async function shutdownSimulator(udidOrName: string): Promise<string> {
  try {
    console.error(`🛑 Останавливаю симулятор: ${udidOrName}`);

    const simulators = await listSimulators();
    let targetUdid = udidOrName;

    const simByName = simulators.find(s => s.name.toLowerCase().includes(udidOrName.toLowerCase()));
    if (simByName) {
      console.error(`✅ Найден симулятор по имени: ${simByName.name} (${simByName.udid})`);
      targetUdid = simByName.udid;
    }

    const currentSim = simulators.find(s => s.udid === targetUdid);
    if (currentSim && currentSim.state === "Shutdown") {
      console.error(`ℹ️ Симулятор уже остановлен`);
      return `✅ Симулятор "${currentSim.name}" уже остановлен`;
    }

    console.error(`🛑 Выключаю симулятор: xcrun simctl shutdown ${targetUdid}`);
    await execAsync(`xcrun simctl shutdown ${targetUdid}`);
    console.error(`✅ Симулятор остановлен`);

    // Проверяем, остались ли запущенные симуляторы
    const updatedSimulators = await listSimulators();
    const bootedSimulators = updatedSimulators.filter(s => s.state === "Booted");
    const hasBootedSimulators = bootedSimulators.length > 0;

    if (!hasBootedSimulators) {
      // Если все симуляторы выключены, закрываем Simulator.app
      console.error(`🔴 Все симуляторы выключены, закрываю Simulator.app`);
      try {
        await execAsync('killall Simulator');
        console.error(`✅ Simulator.app закрыт`);
        return `✅ Симулятор "${currentSim?.name || targetUdid}" остановлен. Все симуляторы выключены, Simulator.app закрыт.`;
      } catch (killError) {
        // Не критично если приложение уже закрыто
        console.error(`ℹ️ Simulator.app уже закрыт или не запущен`);
        return `✅ Симулятор "${currentSim?.name || targetUdid}" остановлен. Simulator.app был уже закрыт.`;
      }
    } else {
      console.error(`ℹ️ Остались запущенные симуляторы (${bootedSimulators.length}), оставляю Simulator.app открытым`);
      const bootedNames = bootedSimulators.map(s => s.name).join(', ');
      return `✅ Симулятор "${currentSim?.name || targetUdid}" остановлен. Simulator.app остаётся открытым (работают: ${bootedNames})`;
    }
  } catch (error: any) {
    console.error(`❌ Ошибка при остановке симулятора: ${error.message}`);
    throw new Error(`Не удалось остановить симулятор: ${error.message}`);
  }
}

// Установить приложение
async function installApp(udidOrName: string, appPath: string): Promise<string> {
  try {
    const simulators = await listSimulators();
    let targetUdid = udidOrName;

    const simByName = simulators.find(s => s.name.toLowerCase().includes(udidOrName.toLowerCase()));
    if (simByName) {
      targetUdid = simByName.udid;
    }

    // Проверяем что симулятор запущен
    const currentSim = simulators.find(s => s.udid === targetUdid);
    if (currentSim && currentSim.state !== "Booted") {
      throw new Error(`Симулятор "${currentSim.name}" не запущен. Сначала запустите его командой boot_simulator`);
    }

    await execAsync(`xcrun simctl install ${targetUdid} "${appPath}"`);

    return `✅ Приложение успешно установлено на симулятор "${currentSim?.name || targetUdid}"`;
  } catch (error: any) {
    throw new Error(`Не удалось установить приложение: ${error.message}`);
  }
}

// Запустить приложение
async function launchApp(udidOrName: string, bundleId: string): Promise<string> {
  try {
    const simulators = await listSimulators();
    let targetUdid = udidOrName;

    const simByName = simulators.find(s => s.name.toLowerCase().includes(udidOrName.toLowerCase()));
    if (simByName) {
      targetUdid = simByName.udid;
    }

    const currentSim = simulators.find(s => s.udid === targetUdid);
    if (currentSim && currentSim.state !== "Booted") {
      throw new Error(`Симулятор "${currentSim.name}" не запущен`);
    }

    await execAsync(`xcrun simctl launch ${targetUdid} ${bundleId}`);

    return `✅ Приложение ${bundleId} запущено на симуляторе "${currentSim?.name || targetUdid}"`;
  } catch (error: any) {
    throw new Error(`Не удалось запустить приложение: ${error.message}`);
  }
}

// Сделать скриншот
async function takeScreenshot(udidOrName: string, outputPath?: string): Promise<string> {
  try {
    const simulators = await listSimulators();
    let targetUdid = udidOrName;

    const simByName = simulators.find(s => s.name.toLowerCase().includes(udidOrName.toLowerCase()));
    if (simByName) {
      targetUdid = simByName.udid;
    }

    const currentSim = simulators.find(s => s.udid === targetUdid);
    if (currentSim && currentSim.state !== "Booted") {
      throw new Error(`Симулятор "${currentSim.name}" не запущен`);
    }

    const timestamp = Date.now();
    const filename = outputPath || `~/Desktop/simulator_screenshot_${timestamp}.png`;

    await execAsync(`xcrun simctl io ${targetUdid} screenshot "${filename}"`);

    return `✅ Скриншот сохранён: ${filename}`;
  } catch (error: any) {
    throw new Error(`Не удалось сделать скриншот: ${error.message}`);
  }
}

// Получить информацию о приложении
async function getAppInfo(udidOrName: string): Promise<string> {
  try {
    console.error(`📋 Получаю список приложений для: ${udidOrName}`);

    const simulators = await listSimulators();
    let targetUdid = udidOrName;
    let simName = udidOrName;

    const simByName = simulators.find(s => s.name.toLowerCase().includes(udidOrName.toLowerCase()));
    if (simByName) {
      console.error(`✅ Найден симулятор: ${simByName.name} (${simByName.udid})`);
      targetUdid = simByName.udid;
      simName = simByName.name;
    }

    console.error(`🔍 Выполняю: xcrun simctl listapps ${targetUdid}`);
    const { stdout } = await execAsync(`xcrun simctl listapps ${targetUdid}`);

    // Парсим plist вывод для более читаемого формата
    console.error(`📊 Парсю результат...`);

    // Извлекаем Bundle IDs из вывода
    const bundleIdRegex = /"([^"]+)"\s*=/g;
    const matches = [...stdout.matchAll(bundleIdRegex)];
    const bundleIds = matches.map(m => m[1]);

    // Извлекаем CFBundleDisplayName для каждого приложения
    const apps: Array<{bundleId: string, displayName: string, type: string}> = [];

    for (const bundleId of bundleIds) {
      // Находим блок этого приложения
      const appBlockRegex = new RegExp(`"${bundleId.replace(/\./g, '\\.')}"\\s*=\\s*{([^}]+)}`, 's');
      const appBlock = stdout.match(appBlockRegex);

      if (appBlock) {
        const block = appBlock[1];

        // Извлекаем CFBundleDisplayName
        const displayNameMatch = block.match(/CFBundleDisplayName\s*=\s*([^;]+);/);
        const displayName = displayNameMatch ? displayNameMatch[1].trim() : bundleId;

        // Извлекаем ApplicationType
        const typeMatch = block.match(/ApplicationType\s*=\s*([^;]+);/);
        const type = typeMatch ? typeMatch[1].trim() : 'Unknown';

        apps.push({ bundleId, displayName, type });
      }
    }

    // Разделяем на системные и пользовательские
    const systemApps = apps.filter(a => a.type === 'System');
    const userApps = apps.filter(a => a.type === 'User');

    console.error(`✅ Найдено приложений: ${apps.length} (${systemApps.length} системных, ${userApps.length} пользовательских)`);

    let result = `📱 Установленные приложения на симуляторе "${simName}":\n\n`;

    if (userApps.length > 0) {
      result += `👤 ПОЛЬЗОВАТЕЛЬСКИЕ ПРИЛОЖЕНИЯ (${userApps.length}):\n`;
      userApps.forEach(app => {
        result += `  • ${app.displayName}\n`;
        result += `    Bundle ID: ${app.bundleId}\n`;
      });
      result += '\n';
    }

    result += `🍎 СИСТЕМНЫЕ ПРИЛОЖЕНИЯ (${systemApps.length}):\n`;
    systemApps.forEach(app => {
      result += `  • ${app.displayName}\n`;
      result += `    Bundle ID: ${app.bundleId}\n`;
    });

    return result;
  } catch (error: any) {
    console.error(`❌ Ошибка получения списка приложений: ${error.message}`);
    throw new Error(`Не удалось получить список приложений: ${error.message}`);
  }
}

const server = new Server(
  {
    name: "mcp-ios-simulator-server",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

server.setRequestHandler(ListToolsRequestSchema, async () => {
  return {
    tools: [
      {
        name: "list_simulators",
        description: "Получить список всех доступных iOS симуляторов. Показывает имя, состояние (Booted/Shutdown), версию iOS и UDID.",
        inputSchema: {
          type: "object",
          properties: {},
          required: [],
        },
      },
      {
        name: "boot_simulator",
        description: "Запустить iOS симулятор. Можно указать UDID или имя симулятора (например: 'iPhone 16 Pro'). Симулятор откроется визуально в приложении Simulator.",
        inputSchema: {
          type: "object",
          properties: {
            simulator: {
              type: "string",
              description: "UDID или имя симулятора (например: 'iPhone 16 Pro', '69DC7937-8A37-4122-A0DC-C1B795FC00F7')",
            },
          },
          required: ["simulator"],
        },
      },
      {
        name: "shutdown_simulator",
        description: "Остановить iOS симулятор. Можно указать UDID или имя. Если это последний запущенный симулятор, автоматически закроется приложение Simulator.app.",
        inputSchema: {
          type: "object",
          properties: {
            simulator: {
              type: "string",
              description: "UDID или имя симулятора для остановки",
            },
          },
          required: ["simulator"],
        },
      },
      {
        name: "install_app",
        description: "Установить .app файл на симулятор. Симулятор должен быть запущен. Путь должен быть абсолютным до .app bundle.",
        inputSchema: {
          type: "object",
          properties: {
            simulator: {
              type: "string",
              description: "UDID или имя симулятора",
            },
            app_path: {
              type: "string",
              description: "Абсолютный путь к .app bundle (например: '/Users/user/Library/Developer/Xcode/DerivedData/.../MyApp.app')",
            },
          },
          required: ["simulator", "app_path"],
        },
      },
      {
        name: "launch_app",
        description: "Запустить установленное приложение на симуляторе. Симулятор должен быть запущен.",
        inputSchema: {
          type: "object",
          properties: {
            simulator: {
              type: "string",
              description: "UDID или имя симулятора",
            },
            bundle_id: {
              type: "string",
              description: "Bundle Identifier приложения (например: 'com.example.MyApp')",
            },
          },
          required: ["simulator", "bundle_id"],
        },
      },
      {
        name: "take_screenshot",
        description: "Сделать скриншот экрана симулятора. Симулятор должен быть запущен. По умолчанию сохраняется на Desktop.",
        inputSchema: {
          type: "object",
          properties: {
            simulator: {
              type: "string",
              description: "UDID или имя симулятора",
            },
            output_path: {
              type: "string",
              description: "Путь для сохранения скриншота (опционально, по умолчанию: ~/Desktop/simulator_screenshot_[timestamp].png)",
            },
          },
          required: ["simulator"],
        },
      },
      {
        name: "list_apps",
        description: "Получить список всех установленных приложений на симуляторе с их Bundle IDs.",
        inputSchema: {
          type: "object",
          properties: {
            simulator: {
              type: "string",
              description: "UDID или имя симулятора",
            },
          },
          required: ["simulator"],
        },
      },
    ],
  };
});

server.setRequestHandler(CallToolRequestSchema, async (request) => {
  try {
    switch (request.params.name) {
      case "list_simulators": {
        const simulators = await listSimulators();
        const formatted = simulators.map(s =>
          `📱 ${s.name}\n   UDID: ${s.udid}\n   Состояние: ${s.state}\n   Версия: ${s.runtime}\n`
        ).join('\n');

        return {
          content: [
            {
              type: "text",
              text: `Доступные симуляторы (${simulators.length}):\n\n${formatted}`,
            },
          ],
        };
      }

      case "boot_simulator": {
        const simulator = request.params.arguments?.simulator as string;
        if (!simulator) {
          return {
            content: [
              {
                type: "text",
                text: "Ошибка: параметр 'simulator' обязателен",
              },
            ],
          };
        }

        const result = await bootSimulator(simulator);
        return {
          content: [
            {
              type: "text",
              text: result,
            },
          ],
        };
      }

      case "shutdown_simulator": {
        const simulator = request.params.arguments?.simulator as string;
        if (!simulator) {
          return {
            content: [
              {
                type: "text",
                text: "Ошибка: параметр 'simulator' обязателен",
              },
            ],
          };
        }

        const result = await shutdownSimulator(simulator);
        return {
          content: [
            {
              type: "text",
              text: result,
            },
          ],
        };
      }

      case "install_app": {
        const simulator = request.params.arguments?.simulator as string;
        const appPath = request.params.arguments?.app_path as string;

        if (!simulator || !appPath) {
          return {
            content: [
              {
                type: "text",
                text: "Ошибка: параметры 'simulator' и 'app_path' обязательны",
              },
            ],
          };
        }

        const result = await installApp(simulator, appPath);
        return {
          content: [
            {
              type: "text",
              text: result,
            },
          ],
        };
      }

      case "launch_app": {
        const simulator = request.params.arguments?.simulator as string;
        const bundleId = request.params.arguments?.bundle_id as string;

        if (!simulator || !bundleId) {
          return {
            content: [
              {
                type: "text",
                text: "Ошибка: параметры 'simulator' и 'bundle_id' обязательны",
              },
            ],
          };
        }

        const result = await launchApp(simulator, bundleId);
        return {
          content: [
            {
              type: "text",
              text: result,
            },
          ],
        };
      }

      case "take_screenshot": {
        const simulator = request.params.arguments?.simulator as string;
        const outputPath = request.params.arguments?.output_path as string;

        if (!simulator) {
          return {
            content: [
              {
                type: "text",
                text: "Ошибка: параметр 'simulator' обязателен",
              },
            ],
          };
        }

        const result = await takeScreenshot(simulator, outputPath);
        return {
          content: [
            {
              type: "text",
              text: result,
            },
          ],
        };
      }

      case "list_apps": {
        const simulator = request.params.arguments?.simulator as string;

        if (!simulator) {
          return {
            content: [
              {
                type: "text",
                text: "Ошибка: параметр 'simulator' обязателен",
              },
            ],
          };
        }

        const result = await getAppInfo(simulator);
        return {
          content: [
            {
              type: "text",
              text: result,
            },
          ],
        };
      }

      default:
        return {
          content: [
            {
              type: "text",
              text: `Неизвестный инструмент: ${request.params.name}`,
            },
          ],
        };
    }
  } catch (error: any) {
    return {
      content: [
        {
          type: "text",
          text: `Ошибка: ${error.message}`,
        },
      ],
    };
  }
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
  console.error("MCP iOS Simulator Server running on stdio");
}

main().catch((error) => {
  console.error("Fatal error:", error);
  process.exit(1);
});
