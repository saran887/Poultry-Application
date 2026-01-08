const axios = require('axios');

async function test() {
    try {
        const res = await axios.get('http://127.0.0.1:8080/api/sensors/latest');
        console.log('Latest Sensors:', res.data);
    } catch (err) {
        console.error('Fetch Error:', err.message);
    }
}

test();
