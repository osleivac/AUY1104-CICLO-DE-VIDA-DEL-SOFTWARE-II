const http = require('http');

const COLOR = process.env.BUILD_COLOR || 'Blue';
const PORT = 3000;

const server = http.createServer((req, res) => {
  res.writeHead(200, {'Content-Type': 'text/html'});
  res.end(`<h1>Hola! Soy ${COLOR}.</h1>`);
});

server.listen(PORT, () => {
  console.log(`Servidor corriendo en puerto ${PORT} - Color: ${COLOR}`);
});
