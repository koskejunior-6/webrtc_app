const WebSocket = require('ws');
const port = process.env.PORT || 3000;
const wss = new WebSocket.Server({ port: port, host: '0.0.0.0' });
console.log('Backend running on port', port);
let clients = {};
wss.on('connection', ws => {
  const id = Math.random().toString(36).substring(7);
  clients[id] = ws;
  console.log('NEW CLIENT:', id);
  ws.send(JSON.stringify({type:'id', id:id}));
  ws.on('message', msg => {
    let data = JSON.parse(msg);
    if(clients[data.to]) clients[data.to].send(JSON.stringify({...data, from:id}));
  });
  ws.on('close', ()=> { delete clients[id]; });
});