var udp = require('dgram');
const {Pool} = require('pg');

// Creaste PG pool
const pool = new Pool({
  user: 'postgres',
  host: 'localhost',
  database: 'kong_metrics',
  password: 'admin',
  port: 5432,
});

// --------------------creating a udp server --------------------

// creating a udp server
var server = udp.createSocket('udp4');

// emits when any error occurs
server.on('error', function (error) {
  console.log('Error: ' + error);
  server.close();
});

// emits on new datagram msg
server.on('message', function (msg, info) {
  // console.log('Data received from client : ' + msg.toString());
  console.log('Data received from client : ', msg.toString());
  console.log('Received %d bytes from %s:%d\n', msg.length, info.address, info.port);

  var data = JSON.parse(msg.toString());

  var sql = 'insert into metrics ' +
    '(http_get, http_post, http_put, http_delete, uma_grant, client_crednetial_grant, client_authentications) values ' +
    '($1, $2, $3, $4, $5, $6, $7)';

  pool.query(sql, [(data.get || 0), (data.post || 0), (data.put || 0), (data.delete || 0), (data.uma_grant || 0), (data.client_crednetial_grant || 0), (data.client_authentications || 0)], function (err, res) {
    if (err) {
      console.log('Insert error : ', err)
    }

    console.log('Inserted: ', res)
  });

  // sending msg
  server.send(msg, info.port, 'localhost', function (error) {
    if (error) {
      client.close();
    } else {
      console.log('Data sent !!!');
    }
  });
});

//emits when socket is ready and listening for datagram msgs
server.on('listening', function () {
  var address = server.address();
  var port = address.port;
  var family = address.family;
  var ipaddr = address.address;
  console.log('Server is listening at port' + port);
  console.log('Server ip :' + ipaddr);
  console.log('Server is IP4/IP6 : ' + family);
});

//emits after the socket is closed using socket.close();
server.on('close', function () {
  console.log('Socket is closed !');
});

server.bind(5000);
