import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema, } from "@modelcontextprotocol/sdk/types.js";
import { exec } from "child_process";
import { promisify } from "util";
const execAsync = promisify(exec);
// Получить список всех симуляторов
async function listSimulators() {
    try {
        const { stdout } = await execAsync('xcrun simctl list devices available --json');
        const data = JSON.parse(stdout);
        const simulators = [];
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
    }
    catch (error) {
        throw new Error(`Не удалось получить список симуляторов: ${error.message}`);
    }
}
// Запустить симулятор
async function bootSimulator(udidOrName) {
    try {
        console.error(`🔍 Ищу симулятор: ${udidOrName}`);
        // Сначала попробуем найти симулятор по имени
        const simulators = await listSimulators();
        let targetUdid = udidOrName;
        const simByName = simulators.find(s => s.name.toLowerCase().includes(udidOrName.toLowerCase()));
        if (simByName) {
            console.error(`✅ Найден симулятор по имени: ${simByName.name} (${simByName.udid})`);
            targetUdid = simByName.udid;
        }
        else {
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
    }
    catch (error) {
        console.error(`❌ Ошибка при запуске симулятора: ${error.message}`);
        throw new Error(`Не удалось запустить симулятор: ${error.message}`);
    }
}
// Остановить симулятор
async function shutdownSimulator(udidOrName) {
    try {
        const simulators = await listSimulators();
        let targetUdid = udidOrName;
        const simByName = simulators.find(s => s.name.toLowerCase().includes(udidOrName.toLowerCase()));
        if (simByName) {
            targetUdid = simByName.udid;
        }
        const currentSim = simulators.find(s => s.udid === targetUdid);
        if (currentSim && currentSim.state === "Shutdown") {
            return `✅ Симулятор "${currentSim.name}" уже остановлен`;
        }
        await execAsync(`xcrun simctl shutdown ${targetUdid}`);
        return `✅ Симулятор "${currentSim?.name || targetUdid}" успешно остановлен`;
    }
    catch (error) {
        throw new Error(`Не удалось остановить симулятор: ${error.message}`);
    }
}
// Установить приложение
async function installApp(udidOrName, appPath) {
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
    }
    catch (error) {
        throw new Error(`Не удалось установить приложение: ${error.message}`);
    }
}
// Запустить приложение
async function launchApp(udidOrName, bundleId) {
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
    }
    catch (error) {
        throw new Error(`Не удалось запустить приложение: ${error.message}`);
    }
}
// Сделать скриншот
async function takeScreenshot(udidOrName, outputPath) {
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
    }
    catch (error) {
        throw new Error(`Не удалось сделать скриншот: ${error.message}`);
    }
}
// Получить информацию о приложении
async function getAppInfo(udidOrName) {
    try {
        const simulators = await listSimulators();
        let targetUdid = udidOrName;
        const simByName = simulators.find(s => s.name.toLowerCase().includes(udidOrName.toLowerCase()));
        if (simByName) {
            targetUdid = simByName.udid;
        }
        const { stdout } = await execAsync(`xcrun simctl listapps ${targetUdid}`);
        return stdout;
    }
    catch (error) {
        throw new Error(`Не удалось получить список приложений: ${error.message}`);
    }
}
const server = new Server({
    name: "mcp-ios-simulator-server",
    version: "1.0.0",
}, {
    capabilities: {
        tools: {},
    },
});
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
                description: "Остановить iOS симулятор. Можно указать UDID или имя.",
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
                const formatted = simulators.map(s => `📱 ${s.name}\n   UDID: ${s.udid}\n   Состояние: ${s.state}\n   Версия: ${s.runtime}\n`).join('\n');
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
                const simulator = request.params.arguments?.simulator;
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
                const simulator = request.params.arguments?.simulator;
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
                const simulator = request.params.arguments?.simulator;
                const appPath = request.params.arguments?.app_path;
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
                const simulator = request.params.arguments?.simulator;
                const bundleId = request.params.arguments?.bundle_id;
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
                const simulator = request.params.arguments?.simulator;
                const outputPath = request.params.arguments?.output_path;
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
                const simulator = request.params.arguments?.simulator;
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
    }
    catch (error) {
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
