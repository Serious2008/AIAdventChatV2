#!/usr/bin/env node

const axios = require('axios');

// Замените на ваши реальные данные
const ORG_ID = '8000000000000004'; // Правильный ID из API ответа
const TOKEN = 'y0__xDP6dwCGNz0OiChisvcFL7Y6yWjHfTiqjFwIo82NUOmQhiu';   // Например: 'y0_AgAAAAAA...'

async function testYandexTrackerAPI() {
    console.log('🔍 Тестируем Yandex Tracker API...\n');

    if (ORG_ID === 'YOUR_ORG_ID_HERE' || TOKEN === 'YOUR_TOKEN_HERE') {
        console.log('❌ Сначала замените ORG_ID и TOKEN на ваши реальные данные!');
        console.log('📝 Отредактируйте файл test_yandex_api.js');
        return;
    }

    const client = axios.create({
        baseURL: 'https://api.tracker.yandex.net/v2',
        headers: {
            'Authorization': `OAuth ${TOKEN}`,
            'X-Org-ID': ORG_ID,
            'Content-Type': 'application/json',
        },
    });

    try {
        console.log('1️⃣ Тестируем подключение...');

        // Тест 1: Получить информацию об организации
        try {
            const orgResponse = await client.get('/myself');
            console.log('✅ Подключение успешно!');
            console.log(`👤 Пользователь: ${orgResponse.data.display}`);
            console.log(`🏢 Организация: ${orgResponse.data.trackerUid}`);
            console.log(`🔑 Токен работает для организации: ${orgResponse.data.trackerUid}`);
            
            // Если Organization ID не совпадает, используем правильный
            if (orgResponse.data.trackerUid !== ORG_ID) {
                console.log(`⚠️  Внимание: Токен работает для организации ${orgResponse.data.trackerUid}, а не ${ORG_ID}`);
                console.log(`💡 Используйте Organization ID: ${orgResponse.data.trackerUid}`);
            }
        } catch (error) {
            console.log('❌ Ошибка подключения:');
            console.log(`   Статус: ${error.response?.status}`);
            console.log(`   Ошибка: ${error.response?.data?.errorMessages?.[0] || error.message}`);
            
            // Попробуем без Organization ID
            console.log('\n🔄 Пробуем без Organization ID...');
            const clientNoOrg = axios.create({
                baseURL: 'https://api.tracker.yandex.net/v2',
                headers: {
                    'Authorization': `OAuth ${TOKEN}`,
                    'Content-Type': 'application/json',
                },
            });
            
            try {
                const orgResponseNoOrg = await clientNoOrg.get('/myself');
                console.log('✅ Подключение без Organization ID успешно!');
                console.log(`👤 Пользователь: ${orgResponseNoOrg.data.display}`);
                console.log(`🏢 Организация: ${orgResponseNoOrg.data.trackerUid}`);
                console.log(`💡 Используйте Organization ID: ${orgResponseNoOrg.data.trackerUid}`);
            } catch (errorNoOrg) {
                console.log('❌ Ошибка и без Organization ID:');
                console.log(`   Статус: ${errorNoOrg.response?.status}`);
                console.log(`   Ошибка: ${errorNoOrg.response?.data?.errorMessages?.[0] || errorNoOrg.message}`);
            }
            return;
        }

        console.log('\n2️⃣ Получаем список задач...');

        // Тест 2: Получить список задач
        try {
            const issuesResponse = await client.get('/issues', {
                params: {
                    perPage: 10
                }
            });

            const issues = issuesResponse.data;
            console.log(`✅ Найдено задач: ${issues.length}`);

            if (issues.length > 0) {
                console.log('\n📋 Последние задачи:');
                issues.slice(0, 5).forEach((issue, index) => {
                    console.log(`   ${index + 1}. ${issue.key}: ${issue.summary}`);
                    console.log(`      Статус: ${issue.status.display}`);
                    console.log(`      Исполнитель: ${issue.assignee?.display || 'Не назначен'}`);
                    console.log(`      Создана: ${new Date(issue.createdAt).toLocaleString()}`);
                    console.log('');
                });
            } else {
                console.log('⚠️  Задач не найдено. Возможные причины:');
                console.log('   - Задачи созданы в другой организации');
                console.log('   - У токена нет прав на чтение задач');
                console.log('   - Задачи находятся в проектах, к которым нет доступа');
            }

        } catch (error) {
            console.log('❌ Ошибка получения задач:');
            console.log(`   Статус: ${error.response?.status}`);
            console.log(`   Ошибка: ${error.response?.data?.errorMessages?.[0] || error.message}`);
        }

        console.log('\n3️⃣ Получаем статистику...');

        // Тест 3: Получить статистику
        try {
            const statsResponse = await client.get('/issues', {
                params: {
                    perPage: 1000
                }
            });

            const allIssues = statsResponse.data;
            const stats = {
                total: allIssues.length,
                open: 0,
                inProgress: 0,
                closed: 0,
                byStatus: {}
            };

            allIssues.forEach(issue => {
                const statusKey = issue.status.key.toLowerCase();
                const statusDisplay = issue.status.display;

                if (statusKey === 'open' || statusKey === 'new') {
                    stats.open++;
                } else if (statusKey === 'inprogress' || statusKey === 'in_progress' || statusKey === 'reviewing') {
                    stats.inProgress++;
                } else if (statusKey === 'closed' || statusKey === 'resolved' || statusKey === 'done') {
                    stats.closed++;
                }

                stats.byStatus[statusDisplay] = (stats.byStatus[statusDisplay] || 0) + 1;
            });

            console.log('📊 Статистика задач:');
            console.log(`   Всего: ${stats.total}`);
            console.log(`   Открытых: ${stats.open}`);
            console.log(`   В работе: ${stats.inProgress}`);
            console.log(`   Закрытых: ${stats.closed}`);
            console.log('\n📈 По статусам:');
            Object.entries(stats.byStatus).forEach(([status, count]) => {
                console.log(`   ${status}: ${count}`);
            });

        } catch (error) {
            console.log('❌ Ошибка получения статистики:');
            console.log(`   Статус: ${error.response?.status}`);
            console.log(`   Ошибка: ${error.response?.data?.errorMessages?.[0] || error.message}`);
        }

        } catch (error) {
            console.log('❌ Общая ошибка:', error.message);
        }
    }

    // Функция для создания тестовой задачи
    async function createTestTask() {
        console.log('\n4️⃣ Создаем тестовую задачу...');
        
        try {
            const taskData = {
                summary: `Тестовая задача от API - ${new Date().toLocaleString()}`,
                description: 'Эта задача создана автоматически через API для тестирования интеграции.',
                type: {
                    key: 'task' // или 'bug', 'story' в зависимости от вашего проекта
                },
                priority: {
                    key: 'normal' // или 'low', 'high', 'critical'
                }
            };
            
            const createResponse = await client.post('/issues', taskData);
            console.log('✅ Задача создана успешно!');
            console.log(`📋 Ключ задачи: ${createResponse.data.key}`);
            console.log(`📝 Название: ${createResponse.data.summary}`);
            console.log(`🔗 Ссылка: https://tracker.yandex.ru/${createResponse.data.key}`);
            
            return createResponse.data;
            
        } catch (error) {
            console.log('❌ Ошибка создания задачи:');
            console.log(`   Статус: ${error.response?.status}`);
            console.log(`   Ошибка: ${error.response?.data?.errorMessages?.[0] || error.message}`);
            
            if (error.response?.data) {
                console.log('   Детали:', JSON.stringify(error.response.data, null, 2));
            }
        }
    }

    // Функция для получения информации о проектах
    async function getProjects() {
        console.log('\n5️⃣ Получаем список проектов...');
        
        try {
            const projectsResponse = await client.get('/projects');
            const projects = projectsResponse.data;
            
            console.log(`✅ Найдено проектов: ${projects.length}`);
            
            if (projects.length > 0) {
                console.log('\n📁 Доступные проекты:');
                projects.forEach((project, index) => {
                    console.log(`   ${index + 1}. ${project.key} - ${project.name}`);
                    console.log(`      Описание: ${project.description || 'Нет описания'}`);
                    console.log(`      Статус: ${project.status}`);
                    console.log('');
                });
                
                return projects[0]; // Возвращаем первый проект для создания задачи
            } else {
                console.log('⚠️  Проектов не найдено');
                return null;
            }
            
        } catch (error) {
            console.log('❌ Ошибка получения проектов:');
            console.log(`   Статус: ${error.response?.status}`);
            console.log(`   Ошибка: ${error.response?.data?.errorMessages?.[0] || error.message}`);
            return null;
        }
    }

    // Основная функция тестирования
    async function runFullTest() {
        await testYandexTrackerAPI();
        
        // Если API работает, попробуем создать задачу
        if (ORG_ID !== 'YOUR_ORG_ID_HERE' && TOKEN !== 'YOUR_TOKEN_HERE') {
            try {
                const projects = await getProjects();
                if (projects) {
                    await createTestTask();
                }
            } catch (error) {
                console.log('❌ Ошибка в дополнительных тестах:', error.message);
            }
        }
    }

    // Запускаем полный тест
    runFullTest();
