import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { CallToolRequestSchema, ListToolsRequestSchema, } from "@modelcontextprotocol/sdk/types.js";
import axios from "axios";
const API_KEY = process.env.OPENWEATHER_API_KEY;
if (!API_KEY) {
    console.error("Error: OPENWEATHER_API_KEY environment variable is not set");
    process.exit(1);
}
async function getWeatherSummary(city) {
    try {
        const url = `https://api.openweathermap.org/data/2.5/weather`;
        const response = await axios.get(url, {
            params: {
                q: city,
                appid: API_KEY,
                units: "metric",
                lang: "ru"
            }
        });
        const data = response.data;
        const date = new Date(data.dt * 1000);
        return `🌤️ Погода в ${data.name}:
• Температура: ${data.main.temp}°C (ощущается как ${data.main.feels_like}°C)
• Состояние: ${data.weather[0].description}
• Ветер: ${data.wind.speed} м/с
• Влажность: ${data.main.humidity}%
• Облачность: ${data.clouds.all}%
• Давление: ${data.main.pressure} гПа
• Время обновления: ${date.toLocaleTimeString('ru-RU')}`;
    }
    catch (error) {
        if (error.response) {
            const status = error.response.status;
            if (status === 404) {
                throw new Error(`Город "${city}" не найден. Проверьте название города.`);
            }
            else if (status === 401) {
                throw new Error(`Неверный API ключ OpenWeatherMap. Проверьте OPENWEATHER_API_KEY.`);
            }
            else {
                throw new Error(`Ошибка API погоды (${status}): ${error.response.data.message || 'Неизвестная ошибка'}`);
            }
        }
        throw new Error(`Не удалось получить погоду: ${error.message}`);
    }
}
const server = new Server({
    name: "mcp-weather-server",
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
                name: "get_weather_summary",
                description: "Получить текущую информацию о погоде для указанного города. Возвращает температуру, состояние, ветер, влажность и другие параметры.",
                inputSchema: {
                    type: "object",
                    properties: {
                        city: {
                            type: "string",
                            description: "Название города для получения погоды (например: Москва, Санкт-Петербург, London)",
                        },
                    },
                    required: ["city"],
                },
            },
        ],
    };
});
server.setRequestHandler(CallToolRequestSchema, async (request) => {
    if (request.params.name === "get_weather_summary") {
        const city = request.params.arguments?.city;
        if (!city) {
            return {
                content: [
                    {
                        type: "text",
                        text: "Ошибка: параметр 'city' обязателен",
                    },
                ],
            };
        }
        try {
            const summary = await getWeatherSummary(city);
            return {
                content: [
                    {
                        type: "text",
                        text: summary,
                    },
                ],
            };
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
    }
    return {
        content: [
            {
                type: "text",
                text: `Неизвестный инструмент: ${request.params.name}`,
            },
        ],
    };
});
async function main() {
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error("MCP Weather Server running on stdio");
}
main().catch((error) => {
    console.error("Fatal error:", error);
    process.exit(1);
});
