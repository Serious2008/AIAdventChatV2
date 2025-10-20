import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

const transport = new StdioClientTransport({
  command: 'node',
  args: ['/Users/sergeymarkov/Documents/PetProject/AIAdventChatV2/mcp-ios-simulator-server/build/index.js']
});

const client = new Client({
  name: 'test-client',
  version: '1.0.0'
}, {
  capabilities: {}
});

try {
  console.log('🔌 Подключаюсь к MCP серверу...');
  await client.connect(transport);
  console.log('✅ Подключено к MCP серверу\n');

  // Сначала получим список симуляторов
  console.log('📱 Получаю список симуляторов...');
  const simulators = await client.callTool({
    name: 'list_simulators',
    arguments: {}
  });
  console.log('Симуляторы:');
  console.log(JSON.stringify(simulators, null, 2));
  console.log('\n');

  // Теперь вызываем list_apps для iPhone 15 Pro
  console.log('📋 Вызываю list_apps для iPhone 15 Pro...');
  const result = await client.callTool({
    name: 'list_apps',
    arguments: {
      simulator: 'iPhone 15 Pro'
    }
  });

  console.log('\n📄 Результат list_apps:');
  console.log(JSON.stringify(result, null, 2));

  await client.close();
  console.log('\n✅ Тест завершён');
} catch (error) {
  console.error('❌ Ошибка:', error.message);
  console.error(error);
  process.exit(1);
}
