// index.test.js

const { greet, calculateHeavyMetric, prepareData } = require('./index');
const moment = require('moment'); 

describe('Función de Saludo (greet) - Pruebas Rápidas', () => {
    
    // Fijamos el valor de APP_COLOR para evitar variación entre entornos
    beforeEach(() => {
        process.env.APP_COLOR = "Mundo";
    });

    // Prueba 1: Verifica el saludo con un nombre
    test('Debe saludar correctamente a un nombre dado', () => {
        const name = 'Desarrollador';
        const expected = 'Hola, Desarrollador! Bienvenido a CI/CD. (Desde Mundo)';
        expect(greet(name)).toBe(expected);
    });

    // Prueba 2: Verifica el saludo por defecto (sin nombre)
    test('Debe devolver el saludo por defecto si no se proporciona un nombre', () => {
        const expected = 'Hola! Soy Mundo';
        expect(greet()).toBe(expected);
    });
});


describe('Funciones de Datos Correlacionadas - Lodash y Moment', () => {
    const mockUsers = [
        { id: 101, name: 'Charlie', status: 'inactive', created: '2023-01-15' },
        { id: 102, name: 'Alice', status: 'active', created: '2024-03-20' },
        { id: 103, name: 'Bob', status: 'active', created: '2023-11-01' },
        { id: 104, name: 'Diana', status: 'active', created: '2024-05-10' },
        { id: 105, name: 'Eve', status: 'active', created: '2024-01-01' },
        { id: 106, name: 'Frank', status: 'active', created: '2024-06-01' },
    ];

    // Prueba 3: Verifica el uso correcto de Lodash (filtrar, ordenar y limitar)
    test('Debe filtrar solo usuarios activos, ordenar por nombre y limitar a 5', () => {
        const result = prepareData(mockUsers);
        
        // 1. Verificar la longitud (solo 5 de 6)
        expect(result.length).toBe(5); 

        // 2. Verificar que todos están activos
        const allActive = result.every(user => user.status === 'active');
        expect(allActive).toBe(true);

        // 3. Verificar el orden alfabético
        expect(result[0].name).toBe('Alice');
        expect(result[1].name).toBe('Bob');
        expect(result[2].name).toBe('Diana');
    });
    
    // Prueba 4: Prueba correlacionada usando Moment
    test('Debe verificar que el usuario más reciente es Frank', () => {
        const activeUsers = mockUsers.filter(user => user.status === 'active');
        
        let mostRecentDate = moment('2000-01-01');
        let mostRecentUser = null;

        activeUsers.forEach(user => {
            const userDate = moment(user.created);
            if (userDate.isAfter(mostRecentDate)) {
                mostRecentDate = userDate;
                mostRecentUser = user;
            }
        });

        expect(mostRecentUser.name).toBe('Frank');
    });
});


describe('Función de Carga Pesada (calculateHeavyMetric) - Prueba Lenta para Demostración', () => {

    test('Debe calcular la métrica pesada y la ejecución debe tomar tiempo', () => {
        const ITERATIONS_COUNT = 10000; 
        const START_TIME = Date.now();
        
        let finalResult = 0;

        // Ejecuta la función varias veces para garantizar lentitud
        for (let i = 0; i < 5; i++) { 
            finalResult += calculateHeavyMetric(ITERATIONS_COUNT);
        }
        
        const END_TIME = Date.now();
        const DURATION_MS = END_TIME - START_TIME;

        // La aserción asegura que el cálculo se realizó
        expect(finalResult).toBeGreaterThan(0);

        console.log(`Tiempo total de ejecución de la prueba pesada: ${DURATION_MS}ms`);

    }, 15000); // timeout de 15 segundos
});
